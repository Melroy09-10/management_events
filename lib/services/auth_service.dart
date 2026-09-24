import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/admin_request.dart';
import '../models/app_user.dart';
import '../models/user_role.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthResult {
  final bool success;
  final String? error;
  const AuthResult.ok() : success = true, error = null;
  const AuthResult.fail(String message) : success = false, error = message;
}

/// Result of [AuthService.addMember]: carries the new account's id on
/// success so it can be linked to the event it was allocated to.
class AddMemberResult {
  final bool success;
  final String? error;
  final String? userId;
  const AddMemberResult.ok(this.userId) : success = true, error = null;
  const AddMemberResult.fail(String message)
    : success = false,
      error = message,
      userId = null;
}

/// Backs the app with Firebase Authentication for credentials and
/// Cloud Firestore for the user's profile (name & role).
class AuthService extends ChangeNotifier {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');
  CollectionReference<Map<String, dynamic>> get _adminRequestsCollection =>
      _firestore.collection('admin_requests');

  AppUser? _currentUser;
  AuthStatus _status = AuthStatus.unknown;
  StreamSubscription<fb.User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _profileSubscription;

  AppUser? get currentUser => _currentUser;
  AuthStatus get status => _status;

  Future<void> init() async {
    _authSubscription = _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(fb.User? firebaseUser) async {
    await _profileSubscription?.cancel();
    _profileSubscription = null;

    if (firebaseUser == null) {
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    // A live subscription (rather than a one-time fetch) so an edit to the
    // user's own profile is reflected immediately across the app.
    _profileSubscription = _usersCollection
        .doc(firebaseUser.uid)
        .snapshots()
        .listen((doc) {
          if (!doc.exists) {
            _currentUser = null;
            _status = AuthStatus.unauthenticated;
          } else {
            _currentUser = AppUser.fromJson(doc.id, doc.data()!);
            _status = AuthStatus.authenticated;
          }
          notifyListeners();
        });
  }

  Future<AppUser?> _fetchProfile(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromJson(doc.id, doc.data()!);
  }

  Future<AuthResult> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String place,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final trimmedName = name.trim();
    final nameLower = trimmedName.toLowerCase();

    fb.User? firebaseUser;
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      firebaseUser = credential.user!;
      await firebaseUser.updateDisplayName(trimmedName);

      // The account is signed in at this point, so these queries run as
      // authenticated reads.
      final nameMatch = await _usersCollection
          .where('nameLower', isEqualTo: nameLower)
          .limit(1)
          .get();
      if (nameMatch.docs.isNotEmpty) {
        await firebaseUser.delete();
        return const AuthResult.fail(
          'This username is already used. Enter your full name.',
        );
      }

      // The very first account becomes Super Admin.
      final existingUsers = await _usersCollection.count().get();
      final role = (existingUsers.count ?? 0) == 0
          ? UserRole.superAdmin
          : UserRole.user;

      final user = AppUser(
        id: firebaseUser.uid,
        name: trimmedName,
        email: normalizedEmail,
        phone: phone.trim(),
        place: place.trim(),
        role: role,
      );
      await _usersCollection.doc(firebaseUser.uid).set({
        ...user.toJson(),
        'nameLower': nameLower,
      });

      // Require the user to log in explicitly rather than auto-signing them
      // in right after account creation.
      await _auth.signOut();
      return const AuthResult.ok();
    } on fb.FirebaseAuthException catch (e) {
      return AuthResult.fail(_messageForAuthError(e));
    } catch (e) {
      await firebaseUser?.delete();
      return const AuthResult.fail(
        'Could not finish creating your account. Please try again.',
      );
    }
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final profile = await _fetchProfile(credential.user!.uid);
      if (profile == null) {
        await _auth.signOut();
        return const AuthResult.fail('No profile found for this account.');
      }

      _currentUser = profile;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return const AuthResult.ok();
    } on fb.FirebaseAuthException catch (e) {
      return AuthResult.fail(_messageForAuthError(e));
    }
  }

  /// Sends a Firebase password-reset email to [email]. The user follows the
  /// link in that email to set a new password; nothing changes locally here.
  Future<AuthResult> resetPassword({required String email}) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      await _auth.sendPasswordResetEmail(email: normalizedEmail);
      return const AuthResult.ok();
    } on fb.FirebaseAuthException catch (e) {
      return AuthResult.fail(_messageForAuthError(e));
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Updates the current user's editable profile fields. Email and role
  /// cannot be changed here.
  Future<AuthResult> updateProfile({
    required String name,
    required String phone,
    required String place,
  }) async {
    final user = _currentUser;
    if (user == null) return const AuthResult.fail('You need to be signed in.');

    try {
      await _usersCollection.doc(user.id).update({
        'name': name.trim(),
        'phone': phone.trim(),
        'place': place.trim(),
      });
      return const AuthResult.ok();
    } catch (e) {
      return const AuthResult.fail(
        'Could not update your profile. Please try again.',
      );
    }
  }

  /// Sends (or re-sends, once resolved) a request from the current member to
  /// be promoted to Admin. Stored as one doc per user so a member can't pile
  /// up duplicate pending requests.
  Future<AuthResult> requestAdminPromotion() async {
    final user = _currentUser;
    if (user == null) return const AuthResult.fail('You need to be signed in.');

    final existing = await _adminRequestsCollection.doc(user.id).get();
    if (existing.exists) {
      final status = AdminRequestStatusX.fromStorage(
        existing.data()!['status'] as String,
      );
      if (status == AdminRequestStatus.pending) {
        return const AuthResult.fail('You already have a pending request.');
      }
    }

    await _adminRequestsCollection.doc(user.id).set({
      'userId': user.id,
      'name': user.name,
      'email': user.email,
      'status': AdminRequestStatus.pending.storageValue,
      'requestedAt': FieldValue.serverTimestamp(),
    });
    return const AuthResult.ok();
  }

  /// The current user's own promotion request, if any. Lets a member see
  /// their pending/approved/rejected status.
  Stream<AdminRequest?> myAdminRequest() {
    final user = _currentUser;
    if (user == null) return Stream.value(null);
    return _adminRequestsCollection
        .doc(user.id)
        .snapshots()
        .map(
          (doc) =>
              doc.exists ? AdminRequest.fromJson(doc.id, doc.data()!) : null,
        );
  }

  /// All pending promotion requests, for the Super Admin to review.
  Stream<List<AdminRequest>> pendingAdminRequests() {
    return _adminRequestsCollection
        .where('status', isEqualTo: AdminRequestStatus.pending.storageValue)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => AdminRequest.fromJson(d.id, d.data()))
              .toList(),
        );
  }

  /// All Member and Admin accounts (Super Admin excluded), for picking who
  /// to allocate to an event on the Add Members page. Sorted client-side to
  /// avoid needing a composite index for a role filter + name ordering.
  Stream<List<AppUser>> members() {
    return _usersCollection.snapshots().map((snap) {
      final users = snap.docs
          .map((d) => AppUser.fromJson(d.id, d.data()))
          .where((u) => u.role != UserRole.superAdmin)
          .toList();
      users.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return users;
    });
  }

  /// Lets an Admin/Super Admin create a new Member account directly,
  /// without going through self-signup. The account is created on a
  /// throwaway secondary Firebase app instance so the admin performing this
  /// stays signed in on the primary instance (creating a user normally
  /// switches the primary instance's signed-in user to the new account).
  Future<AddMemberResult> addMember({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String place,
  }) async {
    final requester = _currentUser;
    if (requester == null ||
        (requester.role != UserRole.admin &&
            requester.role != UserRole.superAdmin)) {
      return const AddMemberResult.fail(
        'You do not have permission to add members.',
      );
    }

    final normalizedEmail = email.trim().toLowerCase();
    final trimmedName = name.trim();
    final nameLower = trimmedName.toLowerCase();

    final nameMatch = await _usersCollection
        .where('nameLower', isEqualTo: nameLower)
        .limit(1)
        .get();
    if (nameMatch.docs.isNotEmpty) {
      return const AddMemberResult.fail(
        'This username is already used. Enter a different full name.',
      );
    }

    final secondaryApp = await Firebase.initializeApp(
      name: 'addMember-${DateTime.now().microsecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    try {
      final secondaryAuth = fb.FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final newUser = credential.user!;
      await newUser.updateDisplayName(trimmedName);
      await secondaryAuth.signOut();

      final user = AppUser(
        id: newUser.uid,
        name: trimmedName,
        email: normalizedEmail,
        phone: phone.trim(),
        place: place.trim(),
        role: UserRole.user,
      );
      await _usersCollection.doc(newUser.uid).set({
        ...user.toJson(),
        'nameLower': nameLower,
      });

      return AddMemberResult.ok(newUser.uid);
    } on fb.FirebaseAuthException catch (e) {
      return AddMemberResult.fail(_messageForAuthError(e));
    } catch (e) {
      return const AddMemberResult.fail(
        'Could not add the member. Please try again.',
      );
    } finally {
      await secondaryApp.delete();
    }
  }

  Future<void> approveAdminRequest(AdminRequest request) async {
    final batch = _firestore.batch();
    batch.update(_usersCollection.doc(request.userId), {
      'role': UserRole.admin.storageValue,
    });
    batch.update(_adminRequestsCollection.doc(request.id), {
      'status': AdminRequestStatus.approved.storageValue,
    });
    await batch.commit();
  }

  Future<void> rejectAdminRequest(String requestId) async {
    await _adminRequestsCollection.doc(requestId).update({
      'status': AdminRequestStatus.rejected.storageValue,
    });
  }

  String _messageForAuthError(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'weak-password':
        return 'Use at least 6 characters.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password. Please try again.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    super.dispose();
  }
}

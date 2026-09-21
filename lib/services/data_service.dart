import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../models/event_booking.dart';
import '../models/event_record.dart';
import '../models/event_type.dart';
import '../models/person.dart';

/// Result of [DataService.checkBookingSlot].
class BookingSlotCheck {
  final bool isDuplicate;
  final bool slotTaken;
  const BookingSlotCheck({required this.isDuplicate, required this.slotTaken});
}

/// Backs the Manage Data feature (Person Data & Event Details) with
/// Cloud Firestore. Every collection is nested under the signed-in user's
/// own `users/{uid}` document, so each Firebase account has completely
/// separate data — enforced both here and by Firestore security rules.
class DataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get _uid => fb.FirebaseAuth.instance.currentUser!.uid;
  DocumentReference<Map<String, dynamic>> get _ownerDoc =>
      _firestore.collection('users').doc(_uid);

  CollectionReference<Map<String, dynamic>> get _peopleCollection =>
      _ownerDoc.collection('people');
  CollectionReference<Map<String, dynamic>> get _eventTypesCollection =>
      _ownerDoc.collection('event_types');
  CollectionReference<Map<String, dynamic>> get _eventsCollection =>
      _ownerDoc.collection('events');
  CollectionReference<Map<String, dynamic>> get _eventBookingsCollection =>
      _ownerDoc.collection('event_bookings');

  // --- Person Data ---

  Stream<List<Person>> people() {
    return _peopleCollection
        .orderBy('name')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => Person.fromJson(d.id, d.data())).toList(),
        );
  }

  Future<void> addPerson({required String name, required String phone}) {
    return _peopleCollection.add({'name': name, 'phone': phone});
  }

  Future<void> updatePerson(
    String id, {
    required String name,
    required String phone,
  }) {
    return _peopleCollection.doc(id).update({'name': name, 'phone': phone});
  }

  Future<void> deletePerson(String id) {
    return _peopleCollection.doc(id).delete();
  }

  // --- Event types (the Event Type -> Event Name taxonomy) ---

  Stream<List<EventType>> eventTypes() {
    return _eventTypesCollection
        .orderBy('name')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => EventType.fromJson(d.id, d.data())).toList(),
        );
  }

  /// Adds a new Event Type, or reuses one that already exists with the same
  /// name (case/whitespace-insensitive) so the dropdown never shows
  /// duplicates. Returns the type's id and its stored (canonical) name.
  Future<(String id, String name)> addOrGetEventType(String name) async {
    final trimmed = name.trim();
    final normalized = trimmed.toLowerCase();

    final snapshot = await _eventTypesCollection.get();
    for (final doc in snapshot.docs) {
      final existingName = doc.data()['name'] as String;
      if (existingName.trim().toLowerCase() == normalized) {
        return (doc.id, existingName);
      }
    }

    final doc = await _eventTypesCollection.add({
      'name': trimmed,
      'eventNames': <String>[],
    });
    return (doc.id, trimmed);
  }

  /// Adds a new Event Name under a type, or reuses one that already exists
  /// with the same name (case/whitespace-insensitive). Returns the stored
  /// (canonical) name.
  Future<String> addOrGetEventName(String eventTypeId, String eventName) async {
    final trimmed = eventName.trim();
    final normalized = trimmed.toLowerCase();

    final doc = await _eventTypesCollection.doc(eventTypeId).get();
    final existingNames = List<String>.from(
      doc.data()?['eventNames'] as List? ?? const [],
    );
    for (final existing in existingNames) {
      if (existing.trim().toLowerCase() == normalized) return existing;
    }

    await _eventTypesCollection.doc(eventTypeId).update({
      'eventNames': FieldValue.arrayUnion([trimmed]),
    });
    return trimmed;
  }

  /// Whether [eventName] is registered under the given event type.
  Future<bool> eventNameBelongsToType(
    String eventTypeId,
    String eventName,
  ) async {
    final doc = await _eventTypesCollection.doc(eventTypeId).get();
    final names = List<String>.from(
      doc.data()?['eventNames'] as List? ?? const [],
    );
    return names.contains(eventName);
  }

  // --- Event Details ---

  Stream<List<EventRecord>> events() {
    return _eventsCollection
        .orderBy('eventType')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => EventRecord.fromJson(d.id, d.data()))
              .toList(),
        );
  }

  /// Whether an event with the same type & name already exists (Location and
  /// Day/Night amounts are intentionally ignored). Comparison is
  /// case-insensitive and trims whitespace. [excludingId] lets an edit check
  /// for duplicates without flagging itself.
  Future<bool> isDuplicateEvent({
    required String eventType,
    required String eventName,
    String? excludingId,
  }) async {
    final normalizedType = eventType.trim().toLowerCase();
    final normalizedName = eventName.trim().toLowerCase();

    final snapshot = await _eventsCollection.get();
    return snapshot.docs.any((doc) {
      if (doc.id == excludingId) return false;
      final data = doc.data();
      final existingType = (data['eventType'] as String).trim().toLowerCase();
      final existingName = (data['eventName'] as String).trim().toLowerCase();
      return existingType == normalizedType && existingName == normalizedName;
    });
  }

  Future<void> addEvent(EventRecord event) {
    return _eventsCollection.add(event.toJson());
  }

  Future<void> updateEvent(String id, EventRecord event) {
    return _eventsCollection.doc(id).update(event.toJson());
  }

  Future<void> deleteEvent(String id) {
    return _eventsCollection.doc(id).delete();
  }

  /// The catalog record (with Address & Day/Night Amount) for a Event
  /// Type + Event Name combination, used by Add Event to auto-fill those
  /// fields. Null if no such Event Details record exists.
  Future<EventRecord?> findEventRecord({
    required String eventTypeId,
    required String eventName,
  }) async {
    final snapshot = await _eventsCollection
        .where('eventTypeId', isEqualTo: eventTypeId)
        .where('eventName', isEqualTo: eventName)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return EventRecord.fromJson(doc.id, doc.data());
  }

  // --- Add Event (bookings) ---

  /// Runs the "already booked" checks for Add Event in a single Firestore
  /// fetch instead of two: whether the exact same Event Type + Event Name +
  /// Date + Shift is already booked, and whether any event at all already
  /// occupies that date & shift (a user may have at most one Day and one
  /// Night event per date). [excludingId] lets an edit check without
  /// flagging itself.
  Future<BookingSlotCheck> checkBookingSlot({
    required String eventType,
    required String eventName,
    required DateTime date,
    required Shift shift,
    String? excludingId,
  }) async {
    final normalizedType = eventType.trim().toLowerCase();
    final normalizedName = eventName.trim().toLowerCase();

    final snapshot = await _eventBookingsCollection
        .where('shift', isEqualTo: shift.storageValue)
        .get();
    var isDuplicate = false;
    var slotTaken = false;
    for (final doc in snapshot.docs) {
      if (doc.id == excludingId) continue;
      final data = doc.data();
      if (!_isSameDate((data['date'] as Timestamp).toDate(), date)) continue;
      slotTaken = true;
      final existingType = (data['eventType'] as String).trim().toLowerCase();
      final existingName = (data['eventName'] as String).trim().toLowerCase();
      if (existingType == normalizedType && existingName == normalizedName) {
        isDuplicate = true;
      }
    }
    return BookingSlotCheck(isDuplicate: isDuplicate, slotTaken: slotTaken);
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> addEventBooking(EventBooking booking) {
    return _eventBookingsCollection.add(booking.toJson());
  }

  Future<void> updateEventBooking(String id, EventBooking booking) {
    return _eventBookingsCollection.doc(id).update(booking.toJson());
  }

  Future<void> deleteEventBooking(String id) {
    return _eventBookingsCollection.doc(id).delete();
  }

  /// Records that a newly-created Member account has been allocated to work
  /// [eventId], for the Add Members / Allocation page.
  Future<void> assignMemberToEvent(
    String eventId, {
    required String memberId,
    required String memberName,
  }) {
    return _eventBookingsCollection.doc(eventId).update({
      'assignedMembers': FieldValue.arrayUnion([
        {'id': memberId, 'name': memberName},
      ]),
    });
  }

  /// Allocates several existing Member/Admin accounts to [eventId] in one
  /// write, for picking multiple people at once from the existing roster.
  Future<void> assignMembersToEvent(
    String eventId, {
    required List<({String id, String name})> members,
  }) {
    return _eventBookingsCollection.doc(eventId).update({
      'assignedMembers': FieldValue.arrayUnion([
        for (final m in members) {'id': m.id, 'name': m.name},
      ]),
    });
  }

  /// Still-upcoming events booked on [date], for the Today's Events
  /// dashboard section. Status is filtered client-side to avoid needing a
  /// composite index for a range (date) + equality (status) query.
  Stream<List<EventBooking>> eventBookingsForDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return _eventBookingsCollection
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => EventBooking.fromJson(d.id, d.data()))
              .where((b) => b.status == BookingStatus.upcoming)
              .toList(),
        );
  }

  /// All events (any date) that haven't been marked Done yet, for the
  /// Pending Events screen. Sorted client-side to avoid needing a composite
  /// index for an equality (status) + orderBy (date) query.
  Stream<List<EventBooking>> pendingEvents() {
    return _eventBookingsCollection
        .where('status', isEqualTo: BookingStatus.upcoming.storageValue)
        .snapshots()
        .map((snap) {
          final events = snap.docs
              .map((d) => EventBooking.fromJson(d.id, d.data()))
              .toList();
          events.sort((a, b) => a.date.compareTo(b.date));
          return events;
        });
  }

  /// Events marked Done and awaiting payment, for the Pending Payments
  /// screen.
  Stream<List<EventBooking>> pendingPayments() {
    return _eventBookingsCollection
        .where('status', isEqualTo: BookingStatus.pendingPayment.storageValue)
        .snapshots()
        .map((snap) {
          final events = snap.docs
              .map((d) => EventBooking.fromJson(d.id, d.data()))
              .toList();
          events.sort((a, b) => a.date.compareTo(b.date));
          return events;
        });
  }

  /// Events whose payment has been settled, for the History screen. Most
  /// recent first.
  Stream<List<EventBooking>> history() {
    return _eventBookingsCollection
        .where('status', isEqualTo: BookingStatus.paid.storageValue)
        .snapshots()
        .map((snap) {
          final events = snap.docs
              .map((d) => EventBooking.fromJson(d.id, d.data()))
              .toList();
          events.sort((a, b) => b.date.compareTo(a.date));
          return events;
        });
  }

  /// Marks a booking as Done, moving it from Pending Events to Pending
  /// Payments.
  Future<void> markBookingDone(String bookingId) {
    return _eventBookingsCollection.doc(bookingId).update({
      'status': BookingStatus.pendingPayment.storageValue,
    });
  }

  /// Marks a booking as paid, moving it from Pending Payments to History.
  Future<void> markBookingPaid(String bookingId) {
    return _eventBookingsCollection.doc(bookingId).update({
      'status': BookingStatus.paid.storageValue,
    });
  }

  /// Marks many bookings as paid at once, for Pending Payments' "Done All"
  /// bulk action.
  Future<void> markBookingsPaid(Iterable<String> bookingIds) {
    final batch = _firestore.batch();
    for (final id in bookingIds) {
      batch.update(_eventBookingsCollection.doc(id), {
        'status': BookingStatus.paid.storageValue,
      });
    }
    return batch.commit();
  }

  /// Updates just the Amount on a booking, editable at any time.
  Future<void> updateEventAmount(String bookingId, double amount) {
    return _eventBookingsCollection.doc(bookingId).update({'amount': amount});
  }

  /// Updates just the Tips amount on a booking, editable at any time.
  Future<void> updateEventTips(String bookingId, double tips) {
    return _eventBookingsCollection.doc(bookingId).update({'tips': tips});
  }

  /// Updates whether a booking has been copied (Pending Payments' Copied /
  /// Not Copied filter), persisted so it survives navigating away and
  /// reopening the app.
  Future<void> updateEventCopied(String bookingId, bool copied) {
    return _eventBookingsCollection.doc(bookingId).update({'copied': copied});
  }

  /// Bulk version of [updateEventCopied], used when marking/undoing several
  /// bookings as copied at once.
  Future<void> updateEventsCopied(Iterable<String> bookingIds, bool copied) {
    final batch = _firestore.batch();
    for (final id in bookingIds) {
      batch.update(_eventBookingsCollection.doc(id), {'copied': copied});
    }
    return batch.commit();
  }
}

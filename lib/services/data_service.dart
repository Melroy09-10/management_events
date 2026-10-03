import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../models/event_booking.dart';
import '../models/event_record.dart';
import '../models/event_type.dart';
import '../models/member.dart';
import '../models/payout.dart';
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
/// Sort order used for every event list in the app: newest date at the
/// top, oldest at the bottom.
int newestFirst(EventBooking a, EventBooking b) => b.date.compareTo(a.date);

class DataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get _uid => fb.FirebaseAuth.instance.currentUser!.uid;
  DocumentReference<Map<String, dynamic>> get _ownerDoc =>
      _firestore.collection('users').doc(_uid);

  CollectionReference<Map<String, dynamic>> get _peopleCollection =>
      _ownerDoc.collection('people');
  CollectionReference<Map<String, dynamic>> get _membersCollection =>
      _ownerDoc.collection('members');
  CollectionReference<Map<String, dynamic>> get _eventTypesCollection =>
      _ownerDoc.collection('event_types');
  CollectionReference<Map<String, dynamic>> get _eventsCollection =>
      _ownerDoc.collection('events');
  CollectionReference<Map<String, dynamic>> get _eventBookingsCollection =>
      _ownerDoc.collection('event_bookings');
  CollectionReference<Map<String, dynamic>> get _payoutsCollection =>
      _ownerDoc.collection('payouts');

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

  /// One-time snapshot of Person Data, for the duplicate phone-number check
  /// during a contacts import.
  Future<List<Person>> peopleOnce() async {
    final snap = await _peopleCollection.get();
    return snap.docs.map((d) => Person.fromJson(d.id, d.data())).toList();
  }

  /// Imports a batch of people in a single write: adds brand-new entries
  /// and updates the name/phone of existing ones the user chose to
  /// overwrite, leaving anything marked "keep existing" untouched.
  Future<void> importPeople({
    required List<({String name, String phone})> newPeople,
    required List<({String id, String name, String phone})> updatedPeople,
  }) {
    final batch = _firestore.batch();
    for (final p in newPeople) {
      batch.set(_peopleCollection.doc(), {'name': p.name, 'phone': p.phone});
    }
    for (final p in updatedPeople) {
      batch.update(_peopleCollection.doc(p.id), {
        'name': p.name,
        'phone': p.phone,
      });
    }
    return batch.commit();
  }

  // --- Members (the Admin's own roster, used for event allocation) ---

  Stream<List<Member>> members() {
    return _membersCollection
        .orderBy('name')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => Member.fromJson(d.id, d.data())).toList(),
        );
  }

  Future<void> addMemberEntry({required String name, required String phone}) {
    return _membersCollection.add({'name': name, 'phone': phone});
  }

  Future<void> updateMemberEntry(
    String id, {
    required String name,
    required String phone,
  }) {
    return _membersCollection.doc(id).update({'name': name, 'phone': phone});
  }

  Future<void> deleteMemberEntry(String id) {
    return _membersCollection.doc(id).delete();
  }

  /// One-time snapshot of this Admin's current roster, for the duplicate
  /// phone-number check during a contacts import.
  Future<List<Member>> membersOnce() async {
    final snap = await _membersCollection.get();
    return snap.docs.map((d) => Member.fromJson(d.id, d.data())).toList();
  }

  /// Imports a batch of Members in a single write: adds brand-new entries
  /// and updates the name/phone of existing ones the Admin chose to
  /// overwrite, leaving anything marked "keep existing" untouched.
  Future<void> importMembers({
    required List<({String name, String phone})> newMembers,
    required List<({String id, String name, String phone})> updatedMembers,
  }) {
    final batch = _firestore.batch();
    for (final m in newMembers) {
      batch.set(_membersCollection.doc(), {'name': m.name, 'phone': m.phone});
    }
    for (final m in updatedMembers) {
      batch.update(_membersCollection.doc(m.id), {
        'name': m.name,
        'phone': m.phone,
      });
    }
    return batch.commit();
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
  /// flagging itself. Admin staffing events ([staffing] true) and the user's
  /// own events are checked separately, so one never blocks the other.
  Future<BookingSlotCheck> checkBookingSlot({
    required String eventType,
    required String eventName,
    required DateTime date,
    required Shift shift,
    String? excludingId,
    bool staffing = false,
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
      final isStaffing = ((data['requiredMembers'] as num?)?.toInt() ?? 0) > 0;
      if (isStaffing != staffing) continue;
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

  /// Live view of one booking; emits null if it's deleted.
  Stream<EventBooking?> eventBooking(String id) {
    return _eventBookingsCollection
        .doc(id)
        .snapshots()
        .map(
          (doc) =>
              doc.exists ? EventBooking.fromJson(doc.id, doc.data()!) : null,
        );
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

  /// Unassigns a single member from [eventId], the inverse of
  /// [assignMemberToEvent]/[assignMembersToEvent].
  Future<void> removeMemberFromEvent(String eventId, AssignedMember member) {
    return _eventBookingsCollection.doc(eventId).update({
      'assignedMembers': FieldValue.arrayRemove([member.toJson()]),
      'presentMemberIds': FieldValue.arrayRemove([member.id]),
    });
  }

  /// Ticks or unticks [memberId] as present at [eventId].
  Future<void> setMemberPresent(
    String eventId,
    String memberId, {
    required bool present,
  }) {
    return _eventBookingsCollection.doc(eventId).update({
      'presentMemberIds': present
          ? FieldValue.arrayUnion([memberId])
          : FieldValue.arrayRemove([memberId]),
    });
  }

  /// Still-upcoming events the user booked themselves on [date], for the
  /// Today's Events dashboard section. Admin staffing events (those with a
  /// required-members target) are left out — see [staffingEventsForDate].
  Stream<List<EventBooking>> eventBookingsForDate(DateTime date) =>
      _upcomingBookingsForDate(date, staffing: false);

  /// Still-upcoming Admin staffing events on [date], for the dashboard's
  /// "Assigned Members" page (Admin only).
  Stream<List<EventBooking>> staffingEventsForDate(DateTime date) =>
      _upcomingBookingsForDate(date, staffing: true);

  /// Status and kind are filtered client-side to avoid needing a composite
  /// index for a range (date) + equality (status) query.
  Stream<List<EventBooking>> _upcomingBookingsForDate(
    DateTime date, {
    required bool staffing,
  }) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return _eventBookingsCollection
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((d) => EventBooking.fromJson(d.id, d.data()))
                  .where(
                    (b) =>
                        b.status == BookingStatus.upcoming &&
                        (b.requiredMembers > 0) == staffing,
                  )
                  .toList()
                ..sort(newestFirst),
        );
  }

  /// All events (any date) that haven't been marked Done yet, for the
  /// Pending Events screen, newest first. Sorted client-side to avoid needing a composite
  /// index for an equality (status) + orderBy (date) query.
  Stream<List<EventBooking>> pendingEvents() {
    return _eventBookingsCollection
        .where('status', isEqualTo: BookingStatus.upcoming.storageValue)
        .snapshots()
        .map((snap) {
          final events = snap.docs
              .map((d) => EventBooking.fromJson(d.id, d.data()))
              .toList();
          events.sort(newestFirst);
          return events;
        });
  }

  /// The user's own pending bookings (no staffing target), for the USER
  /// section's Pending Events screen.
  Stream<List<EventBooking>> pendingPersonalEvents() {
    return pendingEvents().map(
      (events) => events.where((e) => e.requiredMembers == 0).toList(),
    );
  }

  /// Pending events created from the Admin "Add Event" sheet (they carry a
  /// required-members target), for the ADMIN section's Pending Events screen.
  Stream<List<EventBooking>> pendingStaffingEvents() {
    return pendingEvents().map(
      (events) => events.where((e) => e.requiredMembers > 0).toList(),
    );
  }

  /// Events marked Done and awaiting payment, for the Pending Payments
  /// screen, newest first — plus still-upcoming events whose commission
  /// hasn't been received, so My Commission shows there from the moment
  /// the event is created.
  Stream<List<EventBooking>> pendingPayments() {
    return _eventBookingsCollection
        .where(
          'status',
          whereIn: [
            BookingStatus.pendingPayment.storageValue,
            BookingStatus.upcoming.storageValue,
          ],
        )
        .snapshots()
        .map((snap) {
          final events = snap.docs
              .map((d) => EventBooking.fromJson(d.id, d.data()))
              .where(
                (e) =>
                    e.status == BookingStatus.pendingPayment ||
                    (e.hasCommission && !e.commissionPaid),
              )
              .toList();
          events.sort(newestFirst);
          return events;
        });
  }

  /// Events whose payment has been settled, for the History screen, newest
  /// first.
  ///
  /// Also includes events whose commission has been received while the
  /// event itself isn't paid yet — History lists those as commission
  /// entries, so a commission marked Done shows up here straight away.
  Stream<List<EventBooking>> history() {
    return _eventBookingsCollection.snapshots().map((snap) {
      final events = snap.docs
          .map((d) => EventBooking.fromJson(d.id, d.data()))
          .where(
            (e) =>
                e.status == BookingStatus.paid ||
                (e.hasCommission && e.commissionPaid),
          )
          .toList();
      events.sort(newestFirst);
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

  /// Moves the user's own events whose date has passed (before today) and
  /// that were never marked Done into Pending Payments automatically, as if
  /// Done had been tapped. Admin staffing events have no Done button, so
  /// those with a commission move here too once their date has passed (so
  /// the commission shows up for payment); the rest are left untouched.
  Future<void> moveOverdueEventsToPendingPayments() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final snapshot = await _eventBookingsCollection
        .where('status', isEqualTo: BookingStatus.upcoming.storageValue)
        .get();

    final batch = _firestore.batch();
    var count = 0;
    for (final doc in snapshot.docs) {
      final booking = EventBooking.fromJson(doc.id, doc.data());
      final isStaffing = booking.requiredMembers > 0;
      if ((isStaffing && !booking.hasCommission) ||
          !booking.date.isBefore(today)) {
        continue;
      }
      batch.update(doc.reference, {
        'status': BookingStatus.pendingPayment.storageValue,
      });
      count++;
    }
    if (count > 0) await batch.commit();
  }

  /// Marks a booking as paid, moving it from Pending Payments to History.
  /// With [settleCommission], the event's commission is marked received in
  /// the same write, so it isn't left pending once the event is in History.
  Future<void> markBookingPaid(
    String bookingId, {
    bool settleCommission = false,
  }) {
    return _eventBookingsCollection.doc(bookingId).update({
      'status': BookingStatus.paid.storageValue,
      if (settleCommission) 'commissionPaid': true,
    });
  }

  /// Marks an event's commission as received (or back to pending),
  /// independently of the event payment.
  Future<void> setCommissionPaid(String bookingId, bool paid) {
    return _eventBookingsCollection.doc(bookingId).update({
      'commissionPaid': paid,
    });
  }

  /// Reverts a booking marked paid by mistake, moving it from History back
  /// to Pending Payments.
  Future<void> markBookingUnpaid(String bookingId) {
    return _eventBookingsCollection.doc(bookingId).update({
      'status': BookingStatus.pendingPayment.storageValue,
    });
  }

  /// Marks many bookings as paid at once, for Pending Payments' "Done All"
  /// bulk action.
  /// Bookings listed in [settleCommissionIds] also get their commission
  /// marked received.
  Future<void> markBookingsPaid(
    Iterable<String> bookingIds, {
    Set<String> settleCommissionIds = const {},
  }) {
    final batch = _firestore.batch();
    for (final id in bookingIds) {
      batch.update(_eventBookingsCollection.doc(id), {
        'status': BookingStatus.paid.storageValue,
        if (settleCommissionIds.contains(id)) 'commissionPaid': true,
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

  /// Sets the per-head tip every assigned member of [bookingId] gets on
  /// top of their payout.
  Future<void> updateMemberTipPerHead(String bookingId, double tip) {
    return _eventBookingsCollection.doc(bookingId).update({
      'memberTipPerHead': tip,
    });
  }

  /// Changes how many members a staffing event needs.
  Future<void> updateRequiredMembers(String bookingId, int requiredMembers) {
    return _eventBookingsCollection.doc(bookingId).update({
      'requiredMembers': requiredMembers,
    });
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

  // --- Payouts (what the Admin owes each assigned member per event) ---

  /// Every Admin staffing event (any status), newest first, for the Payouts
  /// page. Staffing is filtered client-side, like [pendingStaffingEvents].
  Stream<List<EventBooking>> staffingEvents() {
    return _eventBookingsCollection.snapshots().map((snap) {
      final events = snap.docs
          .map((d) => EventBooking.fromJson(d.id, d.data()))
          .where((e) => e.requiredMembers > 0)
          .toList();
      events.sort(newestFirst);
      return events;
    });
  }

  /// All stored payout records, live.
  Stream<List<Payout>> payouts() {
    return _payoutsCollection.snapshots().map(
      (snap) => snap.docs.map((d) => Payout.fromJson(d.id, d.data())).toList(),
    );
  }

  /// Sets the amount owed to [memberId] for [eventId], creating the payout
  /// record (as Pending) the first time. Refuses to change an amount that's
  /// already been paid.
  Future<void> setPayoutAmount({
    required String eventId,
    required String memberId,
    required String memberName,
    required double amount,
  }) {
    final ref = _payoutsCollection.doc(payoutDocId(eventId, memberId));
    return _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data != null &&
          PayoutStatusX.fromStorage(data['status'] as String?) ==
              PayoutStatus.paid) {
        throw StateError('This payout has already been paid.');
      }
      tx.set(ref, {
        'eventId': eventId,
        'memberId': memberId,
        'memberName': memberName,
        'amount': amount,
        if (data == null) 'status': PayoutStatus.pending.storageValue,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Map<String, dynamic> _paidPayoutData({
    required String eventId,
    required String memberId,
    required String memberName,
    required double amount,
    required double tip,
    String? note,
  }) => {
    'eventId': eventId,
    'memberId': memberId,
    'memberName': memberName,
    'amount': amount,
    'tip': tip,
    'status': PayoutStatus.paid.storageValue,
    'paidAt': FieldValue.serverTimestamp(),
    'note': ?note?.trim(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  /// Marks exactly one payout — [memberId] for [eventId] — as Paid at the
  /// [amount] the Admin confirmed, stamping the payment time. Creates the
  /// record if only the event's default amount existed.
  ///
  /// A plain write rather than a transaction, so it lands in the local cache
  /// (and on screen) instantly and syncs in the background — the returned
  /// future completes once the server has it. The record id is fixed per
  /// event + member, so repeating it can never create a duplicate payment.
  Future<void> markPayoutPaid({
    required String eventId,
    required String memberId,
    required String memberName,
    required double amount,
    double tip = 0,
    String note = '',
  }) {
    if (amount <= 0) {
      throw StateError('Set an amount before marking this paid.');
    }
    return _payoutsCollection
        .doc(payoutDocId(eventId, memberId))
        .set(
          _paidPayoutData(
            eventId: eventId,
            memberId: memberId,
            memberName: memberName,
            amount: amount,
            tip: tip,
            note: note,
          ),
          SetOptions(merge: true),
        );
  }

  /// "Mark All Paid" for one event: marks every listed payout of [eventId]
  /// as Paid in one batch — all recorded or none, applied locally at once
  /// (see [markPayoutPaid]). Only ids under [eventId] are written, so other
  /// events' payouts are never touched.
  Future<void> markEventPayoutsPaid(
    String eventId,
    List<({String memberId, String memberName, double amount, double tip})>
    payouts,
  ) {
    final batch = _firestore.batch();
    for (final p in payouts) {
      if (p.amount <= 0) continue;
      batch.set(
        _payoutsCollection.doc(payoutDocId(eventId, p.memberId)),
        _paidPayoutData(
          eventId: eventId,
          memberId: p.memberId,
          memberName: p.memberName,
          amount: p.amount,
          tip: p.tip,
        ),
        SetOptions(merge: true),
      );
    }
    return batch.commit();
  }

  /// Undoes Mark Paid / Mark All Paid: puts each payout back exactly as it
  /// was before ([previous] is the record then, or null if there wasn't one
  /// — in which case it's deleted so the event's default amount applies
  /// again).
  Future<void> restorePayouts(
    List<({String eventId, String memberId, Payout? previous})> payouts,
  ) {
    final batch = _firestore.batch();
    for (final p in payouts) {
      final ref = _payoutsCollection.doc(payoutDocId(p.eventId, p.memberId));
      final prev = p.previous;
      if (prev == null) {
        batch.delete(ref);
        continue;
      }
      batch.set(ref, {
        'eventId': prev.eventId,
        'memberId': prev.memberId,
        'memberName': prev.memberName,
        'amount': prev.amount ?? FieldValue.delete(),
        'tip': prev.tip ?? FieldValue.delete(),
        'status': prev.status.storageValue,
        'paidAt': prev.paidAt == null
            ? FieldValue.delete()
            : Timestamp.fromDate(prev.paidAt!),
        'note': prev.note,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    return batch.commit();
  }

  /// Moves a paid payout back to Pending (a payment recorded by mistake),
  /// keeping its amount. The recorded tip and payment time are cleared, so
  /// it follows the event's current tip again.
  Future<void> markPayoutUnpaid({
    required String eventId,
    required String memberId,
  }) {
    return _payoutsCollection.doc(payoutDocId(eventId, memberId)).update({
      'status': PayoutStatus.pending.storageValue,
      'paidAt': FieldValue.delete(),
      'tip': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// "Mark All Unpaid" for one event: moves the listed paid payouts of
  /// [eventId] back to Pending in one batch, like [markPayoutUnpaid] for
  /// each. Other events' payouts are never touched.
  Future<void> markEventPayoutsUnpaid(
    String eventId,
    Iterable<String> memberIds,
  ) {
    final batch = _firestore.batch();
    for (final memberId in memberIds) {
      batch.update(_payoutsCollection.doc(payoutDocId(eventId, memberId)), {
        'status': PayoutStatus.pending.storageValue,
        'paidAt': FieldValue.delete(),
        'tip': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    return batch.commit();
  }
}

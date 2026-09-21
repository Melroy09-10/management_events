import 'package:cloud_firestore/cloud_firestore.dart';

enum Shift { day, night }

extension ShiftX on Shift {
  String get label => this == Shift.day ? 'Day' : 'Night';

  String get storageValue => name;

  static Shift fromStorage(String value) {
    return Shift.values.firstWhere(
      (s) => s.name == value,
      orElse: () => Shift.day,
    );
  }
}

/// Lifecycle of a booking: newly added events are `upcoming`; tapping "Done"
/// on Pending Events moves them to `pendingPayment`; tapping "Done" on
/// Pending Payments settles them as `paid`, moving them into History.
enum BookingStatus { upcoming, pendingPayment, paid }

extension BookingStatusX on BookingStatus {
  String get storageValue => name;

  static BookingStatus fromStorage(String? value) {
    return BookingStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => BookingStatus.upcoming,
    );
  }
}

/// A scheduled booking of an event (from the Event Details catalog) on a
/// specific date & shift. Address and amount are copied from the matching
/// Event Details record at the time of booking.
class EventBooking {
  final String id;
  final String eventTypeId;
  final String eventType;
  final String eventName;
  final Shift shift;
  final DateTime date;
  final String personId;
  final String personName;
  final String location;
  final double amount;
  final double tips;
  final BookingStatus status;
  final bool copied;
  final List<AssignedMember> assignedMembers;
  final int requiredMembers;

  const EventBooking({
    required this.id,
    required this.eventTypeId,
    required this.eventType,
    required this.eventName,
    required this.shift,
    required this.date,
    required this.personId,
    required this.personName,
    required this.location,
    required this.amount,
    this.tips = 0,
    this.status = BookingStatus.upcoming,
    this.copied = false,
    this.assignedMembers = const [],
    this.requiredMembers = 0,
  });

  Map<String, dynamic> toJson() => {
    'eventTypeId': eventTypeId,
    'eventType': eventType,
    'eventName': eventName,
    'shift': shift.storageValue,
    'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
    'personId': personId,
    'personName': personName,
    'location': location,
    'amount': amount,
    'tips': tips,
    'status': status.storageValue,
    'copied': copied,
    'assignedMembers': [for (final m in assignedMembers) m.toJson()],
    'requiredMembers': requiredMembers,
  };

  factory EventBooking.fromJson(String id, Map<String, dynamic> json) =>
      EventBooking(
        id: id,
        eventTypeId: json['eventTypeId'] as String,
        eventType: json['eventType'] as String,
        eventName: json['eventName'] as String,
        shift: ShiftX.fromStorage(json['shift'] as String),
        date: (json['date'] as Timestamp).toDate(),
        personId: json['personId'] as String? ?? '',
        personName: json['personName'] as String? ?? '',
        location: json['location'] as String,
        amount: (json['amount'] as num).toDouble(),
        tips: (json['tips'] as num?)?.toDouble() ?? 0,
        status: BookingStatusX.fromStorage(json['status'] as String?),
        copied: json['copied'] as bool? ?? false,
        assignedMembers: [
          for (final m in (json['assignedMembers'] as List? ?? const []))
            AssignedMember.fromJson(Map<String, dynamic>.from(m as Map)),
        ],
        requiredMembers: (json['requiredMembers'] as num?)?.toInt() ?? 0,
      );
}

/// A Member account allocated to work an [EventBooking], recorded at the
/// time they're added so the card can show who's assigned without an extra
/// lookup.
class AssignedMember {
  final String id;
  final String name;
  const AssignedMember({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory AssignedMember.fromJson(Map<String, dynamic> json) =>
      AssignedMember(id: json['id'] as String, name: json['name'] as String);
}

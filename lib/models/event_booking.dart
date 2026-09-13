import 'package:cloud_firestore/cloud_firestore.dart';

enum Shift { day, night }

extension ShiftX on Shift {
  String get label => this == Shift.day ? 'Day' : 'Night';

  String get storageValue => name;

  static Shift fromStorage(String value) {
    return Shift.values.firstWhere((s) => s.name == value, orElse: () => Shift.day);
  }
}

/// Lifecycle of a booking: newly added events are `upcoming`; tapping "Done"
/// on Pending Events moves them to `pendingPayment`; tapping "Done" on
/// Pending Payments settles them as `paid`, moving them into History.
enum BookingStatus { upcoming, pendingPayment, paid }

extension BookingStatusX on BookingStatus {
  String get storageValue => name;

  static BookingStatus fromStorage(String? value) {
    return BookingStatus.values.firstWhere((s) => s.name == value, orElse: () => BookingStatus.upcoming);
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
      };

  factory EventBooking.fromJson(String id, Map<String, dynamic> json) => EventBooking(
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
      );
}

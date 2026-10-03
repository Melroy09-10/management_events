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

/// [EventBooking.personId] used when the signed-in Admin took the call
/// themselves ("Self") instead of someone from Person Data.
const selfCallerId = '__self__';

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

/// How an event's commission is counted: a fixed [total] for the event, or
/// an amount [perHead] multiplied by the event's members.
enum CommissionType { perHead, total }

extension CommissionTypeX on CommissionType {
  String get label => this == CommissionType.perHead ? 'Per Head' : 'Total';

  String get storageValue => name;

  static CommissionType fromStorage(String? value) {
    return CommissionType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => CommissionType.total,
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

  /// Ids of [assignedMembers] ticked as present on the dashboard's
  /// Assigned Members page — attendance only, nothing else depends on it.
  final List<String> presentMemberIds;

  /// Optional commission set on Admin staffing events; 0 means none. Read
  /// together with [commissionType] — see [totalCommission].
  final double commission;
  final CommissionType commissionType;

  /// Whether the Admin has received their commission — tracked separately
  /// from the event payment ([status]).
  final bool commissionPaid;

  /// Tip each assigned member gets on top of their payout (per head, so
  /// 100 means every member gets 100). Separate from [tips], which is what
  /// the client tipped for the event.
  final double memberTipPerHead;

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
    this.presentMemberIds = const [],
    this.commission = 0,
    this.commissionType = CommissionType.total,
    this.commissionPaid = false,
    this.memberTipPerHead = 0,
  });

  bool get isSelfCaller => personId == selfCallerId;

  bool get hasCommission => commission > 0;

  /// Members a per-head commission is counted for: those actually assigned,
  /// or — before anyone is assigned — the number the event requires.
  int get commissionMemberCount =>
      assignedMembers.isNotEmpty ? assignedMembers.length : requiredMembers;

  /// The commission in money terms: the flat amount for [CommissionType.total],
  /// or the per-head amount times [commissionMemberCount].
  double get totalCommission => commissionType == CommissionType.perHead
      ? commission * commissionMemberCount
      : commission;

  /// When payment for this event falls due, derived from the shift: a Day
  /// event at 12:00 PM on its date, a Night event at the 12:00 AM that ends
  /// its night (the start of the next day). Built from local date parts so
  /// it never drifts across a timezone or midnight boundary.
  DateTime get paymentDueAt => shift == Shift.day
      ? DateTime(date.year, date.month, date.day, 12)
      : DateTime(date.year, date.month, date.day + 1);

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
    'presentMemberIds': presentMemberIds,
    'commission': commission,
    'commissionType': commissionType.storageValue,
    'commissionPaid': commissionPaid,
    'memberTipPerHead': memberTipPerHead,
  };

  factory EventBooking.fromJson(String id, Map<String, dynamic> json) =>
      EventBooking(
        id: id,
        eventTypeId: json['eventTypeId'] as String? ?? '',
        eventType: json['eventType'] as String? ?? '',
        eventName: json['eventName'] as String? ?? '',
        shift: ShiftX.fromStorage(json['shift'] as String? ?? ''),
        date: (json['date'] as Timestamp).toDate(),
        personId: json['personId'] as String? ?? '',
        personName: json['personName'] as String? ?? '',
        location: json['location'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        tips: (json['tips'] as num?)?.toDouble() ?? 0,
        status: BookingStatusX.fromStorage(json['status'] as String?),
        copied: json['copied'] as bool? ?? false,
        assignedMembers: [
          for (final m in (json['assignedMembers'] as List? ?? const []))
            AssignedMember.fromJson(Map<String, dynamic>.from(m as Map)),
        ],
        requiredMembers: (json['requiredMembers'] as num?)?.toInt() ?? 0,
        presentMemberIds: [
          ...(json['presentMemberIds'] as List? ?? const [])
              .whereType<String>(),
        ],
        commission: (json['commission'] as num?)?.toDouble() ?? 0,
        commissionType: CommissionTypeX.fromStorage(
          json['commissionType'] as String?,
        ),
        commissionPaid: json['commissionPaid'] as bool? ?? false,
        memberTipPerHead: (json['memberTipPerHead'] as num?)?.toDouble() ?? 0,
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

  factory AssignedMember.fromJson(Map<String, dynamic> json) => AssignedMember(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
  );
}

import 'package:cloud_firestore/cloud_firestore.dart';

import 'event_booking.dart';

enum PayoutStatus { pending, paid }

extension PayoutStatusX on PayoutStatus {
  String get label => this == PayoutStatus.paid ? 'Paid' : 'Pending';

  String get storageValue => name;

  static PayoutStatus fromStorage(String? value) {
    return PayoutStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => PayoutStatus.pending,
    );
  }
}

/// The stable document id of the payout owed to [memberId] for working
/// [eventId]. Deterministic, so a member can only ever have one payout
/// record per event — writes update it instead of creating duplicates.
String payoutDocId(String eventId, String memberId) => '${eventId}_$memberId';

/// What the Admin owes one assigned member for one staffing event, stored in
/// `users/{uid}/payouts/{eventId}_{memberId}`. [amount] is the member's
/// base pay, saved when the Admin overrides it or marks it paid; [tip] is
/// the per-head tip frozen at the moment it was paid.
class Payout {
  final String id;
  final String eventId;
  final String memberId;
  final String memberName;
  final double? amount;
  final double? tip;
  final PayoutStatus status;
  final DateTime? paidAt;
  final String note;

  const Payout({
    required this.id,
    required this.eventId,
    required this.memberId,
    required this.memberName,
    this.amount,
    this.tip,
    this.status = PayoutStatus.pending,
    this.paidAt,
    this.note = '',
  });

  bool get isPaid => status == PayoutStatus.paid;

  factory Payout.fromJson(String id, Map<String, dynamic> json) => Payout(
    id: id,
    eventId: json['eventId'] as String? ?? '',
    memberId: json['memberId'] as String? ?? '',
    memberName: json['memberName'] as String? ?? '',
    amount: (json['amount'] as num?)?.toDouble(),
    tip: (json['tip'] as num?)?.toDouble(),
    status: PayoutStatusX.fromStorage(json['status'] as String?),
    paidAt: (json['paidAt'] as Timestamp?)?.toDate(),
    note: json['note'] as String? ?? '',
  );
}

/// One row on the Payouts page: an assigned member on a staffing event,
/// joined with their stored [payout] record (null if none saved yet). Both
/// the By Function and By Member views are built from the same list of
/// these, so their totals always agree.
class PayoutEntry {
  final EventBooking event;
  final String memberId;
  final String memberName;
  final Payout? payout;

  /// False for a paid payout whose member has since been removed from the
  /// event — kept so money already paid out still counts.
  final bool stillAssigned;

  const PayoutEntry({
    required this.event,
    required this.memberId,
    required this.memberName,
    this.payout,
    this.stillAssigned = true,
  });

  String get id => payoutDocId(event.id, memberId);

  /// The member's base pay: the amount saved on the payout record, or —
  /// until the Admin overrides it — the event's own Day/Night Amount (from
  /// Event Details). Null only when neither exists.
  double? get baseAmount =>
      payout?.amount ?? (event.amount > 0 ? event.amount : null);

  /// Whether [baseAmount] is the event's default rather than a saved figure.
  bool get isDefaultAmount => payout?.amount == null && event.amount > 0;

  /// The per-head tip: frozen on the record once paid, otherwise the
  /// event's current [EventBooking.memberTipPerHead].
  double get tip => isPaid ? (payout?.tip ?? 0) : event.memberTipPerHead;

  /// What the member is owed in total — base pay plus tip. Null while no
  /// base amount exists.
  double? get amount {
    final base = baseAmount;
    return base == null ? null : base + tip;
  }

  bool get hasAmount => amount != null;
  bool get isPaid => payout?.isPaid ?? false;
  PayoutStatus get status => isPaid ? PayoutStatus.paid : PayoutStatus.pending;
}

/// Paid / pending / total sums over a set of [PayoutEntry]s. Entries with
/// no amount set are counted in [unsetCount] but add nothing to the sums.
class PayoutTotals {
  final double paid;
  final double pending;
  final int paidCount;
  final int pendingCount;
  final int unsetCount;

  /// Tips included in [total] (paid tips as recorded, pending at the
  /// event's current rate).
  final double tips;

  const PayoutTotals({
    required this.paid,
    required this.pending,
    required this.paidCount,
    required this.pendingCount,
    required this.unsetCount,
    required this.tips,
  });

  /// Pending payouts that have an amount and so can be marked paid.
  int get payableCount => pendingCount - unsetCount;

  double get total => paid + pending;

  factory PayoutTotals.of(Iterable<PayoutEntry> entries) {
    var paid = 0.0;
    var pending = 0.0;
    var paidCount = 0;
    var pendingCount = 0;
    var unsetCount = 0;
    var tips = 0.0;
    for (final e in entries) {
      final amount = e.amount;
      if (amount != null) tips += e.tip;
      if (e.isPaid) {
        paid += amount ?? 0;
        paidCount++;
        continue;
      }
      pendingCount++;
      if (amount == null) {
        unsetCount++;
      } else {
        pending += amount;
      }
    }
    return PayoutTotals(
      paid: paid,
      pending: pending,
      paidCount: paidCount,
      pendingCount: pendingCount,
      unsetCount: unsetCount,
      tips: tips,
    );
  }
}

/// Joins every assigned member of every staffing event with their stored
/// payout record. A paid payout whose member was later unassigned is kept,
/// since that money really went out. This single list feeds both views.
List<PayoutEntry> buildPayoutEntries(
  List<EventBooking> events,
  List<Payout> payouts,
) {
  final payoutsByEvent = <String, List<Payout>>{};
  for (final p in payouts) {
    (payoutsByEvent[p.eventId] ??= []).add(p);
  }

  final entries = <PayoutEntry>[];
  for (final event in events) {
    final eventPayouts = {
      for (final p in payoutsByEvent[event.id] ?? const <Payout>[])
        p.memberId: p,
    };
    final seen = <String>{};
    for (final m in event.assignedMembers) {
      if (!seen.add(m.id)) continue;
      entries.add(
        PayoutEntry(
          event: event,
          memberId: m.id,
          memberName: m.name,
          payout: eventPayouts[m.id],
        ),
      );
    }
    for (final p in eventPayouts.values) {
      if (seen.contains(p.memberId) || !p.isPaid) continue;
      entries.add(
        PayoutEntry(
          event: event,
          memberId: p.memberId,
          memberName: p.memberName,
          payout: p,
          stillAssigned: false,
        ),
      );
    }
  }
  return entries;
}

import 'package:auth_app/models/event_booking.dart';
import 'package:auth_app/models/payout.dart';
import 'package:flutter_test/flutter_test.dart';

EventBooking _event(
  String id,
  List<(String, String)> members, {
  double amount = 0,
  double tip = 0,
}) => EventBooking(
  id: id,
  eventTypeId: 't',
  eventType: 'Type',
  eventName: 'Event $id',
  shift: Shift.day,
  date: DateTime(2026, 10, 2),
  personId: 'p',
  personName: 'P',
  location: '',
  amount: amount,
  memberTipPerHead: tip,
  requiredMembers: 3,
  commission: 100,
  commissionType: CommissionType.perHead,
  assignedMembers: [
    for (final (mid, name) in members) AssignedMember(id: mid, name: name),
  ],
);

Payout _payout(String e, String m, double? amount, {bool paid = false}) =>
    Payout(
      id: payoutDocId(e, m),
      eventId: e,
      memberId: m,
      memberName: m,
      amount: amount,
      status: paid ? PayoutStatus.paid : PayoutStatus.pending,
    );

void main() {
  final events = [
    _event('e1', [('ravi', 'Ravi'), ('kiran', 'Kiran'), ('manoj', 'Manoj')]),
    _event('e2', [('ravi', 'Ravi'), ('kiran', 'Kiran')], amount: 1000),
    _event('e3', [('manoj', 'Manoj')]),
  ];
  final payouts = [
    _payout('e1', 'ravi', 2000, paid: true),
    _payout('e1', 'kiran', 1500),
    _payout('e1', 'manoj', 1500),
    _payout('e2', 'ravi', 1500),
    // kiran on e2 has no record -> defaults to the event amount (1000)
    // manoj on e3 has no record and e3 has no amount -> not set
    _payout('e2', 'gone', 800, paid: true), // paid, then unassigned
    _payout('e2', 'gone2', 900), // pending, unassigned -> dropped
    _payout('deleted', 'ravi', 999), // event deleted -> ignored
  ];

  test('entries join members with their own payout record only', () {
    final entries = buildPayoutEntries(events, payouts);
    expect(entries.length, 7);
    expect(entries.map((e) => e.id).toSet().length, 7);
    final e2kiran = entries.firstWhere(
      (e) => e.event.id == 'e2' && e.memberId == 'kiran',
    );
    expect(e2kiran.amount, 1000);
    expect(e2kiran.isDefaultAmount, isTrue);
    final e2ravi = entries.firstWhere(
      (e) => e.event.id == 'e2' && e.memberId == 'ravi',
    );
    expect(e2ravi.amount, 1500); // saved override wins over the default
    final e3manoj = entries.firstWhere((e) => e.event.id == 'e3');
    expect(e3manoj.hasAmount, isFalse);
    final gone = entries.firstWhere((e) => e.memberId == 'gone');
    expect(gone.stillAssigned, isFalse);
  });

  test('totals: overall equals sum per event equals sum per member', () {
    final entries = buildPayoutEntries(events, payouts);
    final all = PayoutTotals.of(entries);
    expect(all.paid, 2800);
    expect(all.pending, 5500);
    expect(all.total, 8300);
    expect(all.unsetCount, 1);

    double sumBy(String Function(PayoutEntry) key) {
      final groups = <String, List<PayoutEntry>>{};
      for (final e in entries) {
        (groups[key(e)] ??= []).add(e);
      }
      return groups.values.fold(0.0, (s, g) => s + PayoutTotals.of(g).total);
    }

    expect(sumBy((e) => e.event.id), all.total);
    expect(sumBy((e) => e.memberId), all.total);

    final ravi = PayoutTotals.of(entries.where((e) => e.memberId == 'ravi'));
    expect((ravi.total, ravi.paid, ravi.pending), (3500, 2000, 1500));
  });

  test('per-head tip is added to every unpaid member, frozen once paid', () {
    final event = _event(
      't1',
      [('a', 'A'), ('b', 'B'), ('c', 'C')],
      amount: 1000,
      tip: 100,
    );
    final entries = buildPayoutEntries(
      [event],
      [
        // paid before the tip was raised to 100: tip recorded as 50
        Payout(
          id: payoutDocId('t1', 'a'),
          eventId: 't1',
          memberId: 'a',
          memberName: 'A',
          amount: 1000,
          tip: 50,
          status: PayoutStatus.paid,
        ),
        _payout('t1', 'b', 1200), // overridden base, still pending
      ],
    );
    final byId = {for (final e in entries) e.memberId: e};
    expect(byId['a']!.amount, 1050);
    expect(byId['b']!.amount, 1300);
    expect(byId['c']!.amount, 1100);
    final totals = PayoutTotals.of(entries);
    expect((totals.paid, totals.pending, totals.total), (1050, 2400, 3450));
    expect(totals.tips, 250); // 50 frozen on the paid one + 100 + 100
    expect((totals.paidCount, totals.payableCount), (1, 2));
  });
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/event_booking.dart';
import '../models/payout.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';
import '../widgets/app_drawer.dart';
import '../widgets/payment_chips.dart';
import '../widgets/responsive_center.dart';

enum _PayoutMode { byFunction, byMember }

enum _StatusFilter { all, pending, paid }

extension on _StatusFilter {
  String get label => switch (this) {
    _StatusFilter.all => 'All',
    _StatusFilter.pending => 'Pending',
    _StatusFilter.paid => 'Paid',
  };
}

enum _PayoutSort { newest, upcoming, highestPending, name }

extension on _PayoutSort {
  String get label => switch (this) {
    _PayoutSort.newest => 'Newest first',
    _PayoutSort.upcoming => 'Upcoming events',
    _PayoutSort.highestPending => 'Highest pending',
    _PayoutSort.name => 'Name (A–Z)',
  };
}

final _shortDateFormat = DateFormat('dd MMM');
final _paidAtFormat = DateFormat('dd MMM yyyy, h:mm a');
final _monthFormat = DateFormat('MMMM yyyy');
final _numericDateFormat = DateFormat('dd/MM/yyyy');

class _EventGroup {
  final EventBooking event;
  final List<PayoutEntry> entries;
  final PayoutTotals totals;
  _EventGroup(this.event, this.entries) : totals = PayoutTotals.of(entries);
}

class _MemberGroup {
  final String memberId;
  final String memberName;
  final List<PayoutEntry> entries;
  final PayoutTotals totals;
  _MemberGroup(this.memberId, this.memberName, this.entries)
    : totals = PayoutTotals.of(entries);
}

bool _isUpcoming(DateTime date) {
  final now = DateTime.now();
  return !date.isBefore(DateTime(now.year, now.month, now.day));
}

/// Admin/Super Admin only: what's owed to each member assigned to a staffing
/// event, viewable grouped by event (By Function) or by member (By Member).
class PayoutsScreen extends StatefulWidget {
  const PayoutsScreen({super.key});

  @override
  State<PayoutsScreen> createState() => _PayoutsScreenState();
}

class _PayoutsScreenState extends State<PayoutsScreen> {
  // Created once so a setState doesn't tear down the Firestore listeners.
  late final Stream<List<EventBooking>> _eventsStream;
  late final Stream<List<Payout>> _payoutsStream;

  _PayoutMode _mode = _PayoutMode.byFunction;
  _StatusFilter _filter = _StatusFilter.all;
  _PayoutSort _eventSort = _PayoutSort.newest;
  _PayoutSort _memberSort = _PayoutSort.highestPending;
  final _searchController = TextEditingController();
  String _query = '';
  final _expandedEvents = <String>{};
  final _expandedMembers = <String>{};

  @override
  void initState() {
    super.initState();
    final dataService = context.read<DataService>();
    _eventsStream = dataService.staffingEvents();
    _payoutsStream = dataService.payouts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DataService get _dataService => context.read<DataService>();

  void _setMode(_PayoutMode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _searchController.clear();
      _query = '';
    });
  }

  bool _passesFilter(PayoutTotals totals, int count) {
    return switch (_filter) {
      _StatusFilter.all => true,
      _StatusFilter.pending => totals.pendingCount > 0,
      _StatusFilter.paid => count > 0 && totals.pendingCount == 0,
    };
  }

  List<_EventGroup> _eventGroups(List<PayoutEntry> entries) {
    final byEvent = <String, List<PayoutEntry>>{};
    final events = <String, EventBooking>{};
    for (final e in entries) {
      (byEvent[e.event.id] ??= []).add(e);
      events[e.event.id] = e.event;
    }
    final q = _query.toLowerCase();
    final groups =
        [
          for (final id in byEvent.keys) _EventGroup(events[id]!, byEvent[id]!),
        ].where((g) {
          if (!_passesFilter(g.totals, g.entries.length)) return false;
          if (q.isEmpty) return true;
          final e = g.event;
          return e.eventName.toLowerCase().contains(q) ||
              e.eventType.toLowerCase().contains(q) ||
              formatEventDate(e.date).toLowerCase().contains(q) ||
              _numericDateFormat.format(e.date).contains(q);
        }).toList();

    switch (_eventSort) {
      case _PayoutSort.upcoming:
        // Upcoming soonest-first, then past events newest-first.
        groups.sort((a, b) {
          final au = _isUpcoming(a.event.date);
          final bu = _isUpcoming(b.event.date);
          if (au != bu) return au ? -1 : 1;
          return au
              ? a.event.date.compareTo(b.event.date)
              : b.event.date.compareTo(a.event.date);
        });
      case _PayoutSort.highestPending:
        groups.sort((a, b) => b.totals.pending.compareTo(a.totals.pending));
      case _PayoutSort.newest:
      case _PayoutSort.name:
        groups.sort((a, b) => newestFirst(a.event, b.event));
    }
    return groups;
  }

  List<_MemberGroup> _memberGroups(List<PayoutEntry> entries) {
    final byMember = <String, List<PayoutEntry>>{};
    for (final e in entries) {
      (byMember[e.memberId] ??= []).add(e);
    }
    final q = _query.toLowerCase();
    final groups = <_MemberGroup>[];
    for (final memberEntries in byMember.values) {
      memberEntries.sort((a, b) => newestFirst(a.event, b.event));
      final group = _MemberGroup(
        memberEntries.first.memberId,
        memberEntries.first.memberName,
        memberEntries,
      );
      if (!_passesFilter(group.totals, memberEntries.length)) continue;
      if (q.isNotEmpty && !group.memberName.toLowerCase().contains(q)) {
        continue;
      }
      groups.add(group);
    }

    int byName(_MemberGroup a, _MemberGroup b) =>
        a.memberName.toLowerCase().compareTo(b.memberName.toLowerCase());
    if (_memberSort == _PayoutSort.highestPending) {
      groups.sort((a, b) {
        final c = b.totals.pending.compareTo(a.totals.pending);
        return c != 0 ? c : byName(a, b);
      });
    } else {
      groups.sort(byName);
    }
    return groups;
  }

  // --- Actions ---

  void _showMessage(
    String message, {
    bool error = false,
    VoidCallback? onUndo,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? AppColors.danger : AppColors.success,
          duration: Duration(seconds: onUndo == null ? 4 : 6),
          // Auto-hide even with an action (Flutter keeps those by default).
          persist: false,
          action: onUndo == null
              ? null
              : SnackBarAction(
                  label: 'UNDO',
                  textColor: Colors.white,
                  onPressed: onUndo,
                ),
        ),
      );
  }

  String _errorText(Object e) =>
      e is StateError ? e.message : 'Something went wrong. Please try again.';

  /// Reports a background write failing. Writes land in the local cache
  /// (and on screen) straight away, so they're not awaited before showing
  /// success — this only speaks up if the server rejects them.
  void _reportFailure(Future<void> write) {
    write.catchError((Object e) {
      if (mounted) _showMessage(_errorText(e), error: true);
    });
  }

  /// Puts [entries]' payout records back exactly as they were before they
  /// were marked paid / unpaid.
  void _restore(List<PayoutEntry> entries, String message) {
    _reportFailure(
      _dataService.restorePayouts([
        for (final e in entries)
          (eventId: e.event.id, memberId: e.memberId, previous: e.payout),
      ]),
    );
    _showMessage(message);
  }

  Future<void> _setAmount(PayoutEntry entry) async {
    final amount = await showDialog<double>(
      context: context,
      builder: (_) => _SetAmountDialog(entry: entry),
    );
    if (amount == null || !mounted) return;
    try {
      await _dataService.setPayoutAmount(
        eventId: entry.event.id,
        memberId: entry.memberId,
        memberName: entry.memberName,
        amount: amount,
      );
      if (!mounted) return;
      _showMessage(
        'Payout for ${entry.memberName} set to ${formatCurrency(amount)}',
      );
    } catch (e) {
      if (mounted) _showMessage(_errorText(e), error: true);
    }
  }

  Future<void> _markPaid(PayoutEntry entry) async {
    if (!entry.hasAmount) return _setAmount(entry);
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _MarkPaidDialog(entry: entry),
    );
    if (note == null || !mounted) return;
    try {
      _reportFailure(
        _dataService.markPayoutPaid(
          eventId: entry.event.id,
          memberId: entry.memberId,
          memberName: entry.memberName,
          amount: entry.baseAmount!,
          tip: entry.tip,
          note: note,
        ),
      );
    } catch (e) {
      _showMessage(_errorText(e), error: true);
      return;
    }
    _showMessage(
      '${formatCurrency(entry.amount!)} marked paid to ${entry.memberName}',
      onUndo: () => _restore([entry], 'Payment to ${entry.memberName} undone'),
    );
  }

  /// Marks every pending payout of [group]'s event that has an amount as
  /// Paid, after confirmation, in one batch. Never touches other events.
  /// Undo puts every one of them back as it was.
  Future<void> _markAllPaid(_EventGroup group) async {
    final payable = [
      for (final e in group.entries)
        if (!e.isPaid && e.hasAmount) e,
    ];
    if (payable.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _MarkAllPaidDialog(
        event: group.event,
        entries: payable,
        skipped: group.totals.unsetCount,
      ),
    );
    if (confirmed != true || !mounted) return;
    _reportFailure(
      _dataService.markEventPayoutsPaid(group.event.id, [
        for (final e in payable)
          (
            memberId: e.memberId,
            memberName: e.memberName,
            amount: e.baseAmount!,
            tip: e.tip,
          ),
      ]),
    );
    final count = payable.length;
    _showMessage(
      '$count payment${count == 1 ? '' : 's'} marked paid for '
      '${group.event.eventName}',
      onUndo: () => _restore(
        payable,
        'Undone — $count payment${count == 1 ? '' : 's'} back to pending',
      ),
    );
  }

  /// Moves every paid payout of a fully settled event back to Pending,
  /// after confirmation (with Undo). Never touches other events.
  Future<void> _markAllUnpaid(_EventGroup group) async {
    final paid = [
      for (final e in group.entries)
        if (e.isPaid) e,
    ];
    if (paid.isEmpty) return;
    final count = paid.length;
    final total = paid.fold<double>(0, (acc, e) => acc + (e.amount ?? 0));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mark All Unpaid?'),
        content: Text(
          '$count payment${count == 1 ? '' : 's'} (${formatCurrency(total)}) '
          'for ${group.event.eventName} will move back to Pending.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text('Mark $count Unpaid'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _reportFailure(
      _dataService.markEventPayoutsUnpaid(group.event.id, [
        for (final e in paid) e.memberId,
      ]),
    );
    _showMessage(
      '$count payment${count == 1 ? '' : 's'} moved back to Pending',
      onUndo: () => _restore(
        paid,
        '$count payment${count == 1 ? '' : 's'} restored as paid',
      ),
    );
  }

  /// Moves a payment recorded by mistake back to Pending, after
  /// confirmation (with Undo).
  Future<void> _markUnpaid(PayoutEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mark as Unpaid?'),
        content: Text(
          'The ${formatCurrency(entry.amount!)} payment to '
          '${entry.memberName} for ${entry.event.eventName} will move back '
          'to Pending.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Mark Unpaid'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _reportFailure(
      _dataService.markPayoutUnpaid(
        eventId: entry.event.id,
        memberId: entry.memberId,
      ),
    );
    _showMessage(
      'Payment to ${entry.memberName} moved back to Pending',
      onUndo: () =>
          _restore([entry], 'Payment to ${entry.memberName} restored'),
    );
  }

  Future<void> _editTip(_EventGroup group) async {
    final tip = await showDialog<double>(
      context: context,
      builder: (_) => _TipDialog(
        event: group.event,
        paidCount: group.entries.where((e) => e.isPaid).length,
      ),
    );
    if (tip == null || !mounted) return;
    try {
      await _dataService.updateMemberTipPerHead(group.event.id, tip);
      if (!mounted) return;
      _showMessage(
        tip > 0
            ? 'Tip of ${formatCurrency(tip)} added for each member'
            : 'Tip removed',
      );
    } catch (e) {
      if (mounted) _showMessage(_errorText(e), error: true);
    }
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDark(context) ? null : _P.ivory,
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Payouts')),
      body: SafeArea(
        child: StreamBuilder<List<EventBooking>>(
          stream: _eventsStream,
          builder: (context, eventsSnap) {
            return StreamBuilder<List<Payout>>(
              stream: _payoutsStream,
              builder: (context, payoutsSnap) {
                final error = eventsSnap.error ?? payoutsSnap.error;
                if (error != null) {
                  final denied =
                      error is FirebaseException &&
                      error.code == 'permission-denied';
                  return _MessageState(
                    icon: Icons.error_outline_rounded,
                    title: 'Couldn\'t load payouts',
                    subtitle: denied
                        ? 'Permission denied. The Firestore security rules '
                              'for payouts haven\'t been published yet.'
                        : 'Check your connection and try again.',
                  );
                }
                if (!eventsSnap.hasData || !payoutsSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final entries = buildPayoutEntries(
                  eventsSnap.data!,
                  payoutsSnap.data!,
                );
                return _buildBody(entries);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(List<PayoutEntry> entries) {
    final totals = PayoutTotals.of(entries);
    final isFunction = _mode == _PayoutMode.byFunction;
    final eventGroups = isFunction ? _eventGroups(entries) : null;
    final memberGroups = isFunction ? null : _memberGroups(entries);
    final resultCount = eventGroups?.length ?? memberGroups!.length;

    return ResponsiveCenter(
      maxWidth: 820,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
        children: [
          Text('Payouts', style: AppTextStyles.pageTitle),
          const SizedBox(height: 2),
          Text(
            'Manage payments to assigned members.',
            style: AppTextStyles.label.copyWith(color: _secondaryText(context)),
          ),
          const SizedBox(height: 14),
          _ModeToggle(mode: _mode, onChanged: _setMode),
          if (totals.unsetCount > 0) ...[
            const SizedBox(height: 10),
            _UnsetNotice(count: totals.unsetCount),
          ],
          const SizedBox(height: 12),
          _SearchField(
            controller: _searchController,
            hint: isFunction
                ? 'Search event name or date'
                : 'Search member name',
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
          const SizedBox(height: 10),
          _FilterRow(
            filter: _filter,
            onFilter: (f) => setState(() => _filter = f),
            sort: isFunction ? _eventSort : _memberSort,
            sortOptions: isFunction
                ? const [
                    _PayoutSort.newest,
                    _PayoutSort.upcoming,
                    _PayoutSort.highestPending,
                  ]
                : const [_PayoutSort.highestPending, _PayoutSort.name],
            onSort: (s) => setState(() {
              if (isFunction) {
                _eventSort = s;
              } else {
                _memberSort = s;
              }
            }),
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            const _MessageState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No payouts yet',
              subtitle:
                  'Members you assign to events from Assign Members will appear here.',
            )
          else if (resultCount == 0)
            const _MessageState(
              icon: Icons.search_off_rounded,
              title: 'No matches',
              subtitle: 'Try a different search or filter.',
            )
          else if (isFunction)
            for (final g in eventGroups!) ...[
              _EventPayoutCard(
                group: g,
                expanded: _expandedEvents.contains(g.event.id),
                onToggle: () => setState(() {
                  if (!_expandedEvents.remove(g.event.id)) {
                    _expandedEvents.add(g.event.id);
                  }
                }),
                onMarkPaid: _markPaid,
                onMarkUnpaid: _markUnpaid,
                onSetAmount: _setAmount,
                onEditTip: () => _editTip(g),
                onMarkAllPaid: () => _markAllPaid(g),
                onMarkAllUnpaid: () => _markAllUnpaid(g),
              ),
              const SizedBox(height: 10),
            ]
          else
            for (final g in memberGroups!) ...[
              _MemberPayoutCard(
                group: g,
                expanded: _expandedMembers.contains(g.memberId),
                onToggle: () => setState(() {
                  if (!_expandedMembers.remove(g.memberId)) {
                    _expandedMembers.add(g.memberId);
                  }
                }),
                onMarkPaid: _markPaid,
                onMarkUnpaid: _markUnpaid,
                onSetAmount: _setAmount,
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

// --- Shared styling helpers ---

/// The Payouts page's Royal Navy / Gold / Ivory palette.
class _P {
  _P._();

  static const Color navyDeep = Color(0xFF04121F);
  static const Color navy = Color(0xFF071D33);
  static const Color navyLight = Color(0xFF0F2C4B);
  static const Color gold = Color(0xFFD8AD45);
  static const Color goldDark = Color(0xFFA9832A);
  static const Color goldLight = Color(0xFFEFD48C);
  static const Color ivory = Color(0xFFF8F6EF);
}

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color _borderColor(BuildContext context) =>
    _isDark(context) ? AppColors.borderDark : AppColors.border;

Color _secondaryText(BuildContext context) => _isDark(context)
    ? AppColors.textSecondaryDark
    : AppColors.textSecondaryLight;

Color _navy(BuildContext context) => onSurfaceAccent(context, _P.navy);

BoxDecoration _cardDecoration(BuildContext context) => BoxDecoration(
  color: Theme.of(context).colorScheme.surface,
  borderRadius: BorderRadius.circular(AppRadius.card),
  border: Border.all(color: _borderColor(context)),
  boxShadow: [
    BoxShadow(
      color: _P.navy.withValues(alpha: 0.05),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ],
);

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

// --- Header widgets ---

class _ModeToggle extends StatelessWidget {
  final _PayoutMode mode;
  final ValueChanged<_PayoutMode> onChanged;
  const _ModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget segment(_PayoutMode value, IconData icon, String label) {
      final selected = mode == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(value),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? _P.navy : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: selected
                  ? Border.all(color: _P.gold.withValues(alpha: 0.7))
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: selected ? _P.gold : _secondaryText(context),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: selected ? Colors.white : _secondaryText(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _borderColor(context)),
      ),
      child: Row(
        children: [
          segment(
            _PayoutMode.byFunction,
            Icons.event_note_rounded,
            'By Function',
          ),
          const SizedBox(width: 4),
          segment(_PayoutMode.byMember, Icons.groups_rounded, 'By Member'),
        ],
      ),
    );
  }
}

class _UnsetNotice extends StatelessWidget {
  final int count;
  const _UnsetNotice({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              count == 1
                  ? '1 payout has no amount set.'
                  : '$count payouts have no amount set.',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'Clear',
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final _StatusFilter filter;
  final ValueChanged<_StatusFilter> onFilter;
  final _PayoutSort sort;
  final List<_PayoutSort> sortOptions;
  final ValueChanged<_PayoutSort> onSort;

  const _FilterRow({
    required this.filter,
    required this.onFilter,
    required this.sort,
    required this.sortOptions,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in _StatusFilter.values) ...[
                  _FilterPill(
                    label: f.label,
                    selected: f == filter,
                    onTap: () => onFilter(f),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ),
        PopupMenuButton<_PayoutSort>(
          tooltip: 'Sort',
          initialValue: sort,
          onSelected: onSort,
          itemBuilder: (_) => [
            for (final s in sortOptions)
              PopupMenuItem(value: s, child: Text(s.label)),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _borderColor(context)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sort_rounded, size: 16, color: _navy(context)),
                const SizedBox(width: 4),
                Text(
                  sort.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _navy(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _P.navy : Theme.of(context).colorScheme.surface,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? _P.navy : _borderColor(context)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : _secondaryText(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 44, color: _P.gold),
          const SizedBox(height: 10),
          Text(title, style: AppTextStyles.cardTitle),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.small.copyWith(color: _secondaryText(context)),
          ),
        ],
      ),
    );
  }
}

// --- Row building blocks ---

class _StatusChip extends StatelessWidget {
  final bool paid;
  const _StatusChip({required this.paid});

  @override
  Widget build(BuildContext context) {
    final color = paid ? AppColors.success : AppColors.danger;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              paid ? Icons.check_circle_rounded : Icons.schedule_rounded,
              size: 12,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              paid ? 'Paid' : 'Pending',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The amount payable (base + tip) with the tip spelled out beneath it, or
/// "Not set". Pending amounts can be edited by tapping, paid ones are
/// locked.
class _AmountCell extends StatelessWidget {
  final PayoutEntry entry;
  final VoidCallback onEdit;
  const _AmountCell({required this.entry, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final amount = entry.amount;
    final tip = entry.tip;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                amount == null ? 'Not set' : formatCurrency(amount),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: amount == null
                      ? FontWeight.w600
                      : FontWeight.w800,
                  fontStyle: amount == null
                      ? FontStyle.italic
                      : FontStyle.normal,
                  color: amount == null ? AppColors.warning : null,
                ),
              ),
            ),
            if (!entry.isPaid) ...[
              const SizedBox(width: 3),
              Icon(
                Icons.edit_rounded,
                size: 11,
                color: _secondaryText(context).withValues(alpha: 0.7),
              ),
            ],
          ],
        ),
        if (amount != null && tip > 0)
          Text(
            '${formatCurrency(entry.baseAmount!)} + ${formatCurrency(tip)} tip',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.success,
            ),
          ),
      ],
    );
    if (entry.isPaid) return content;
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: content,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final PayoutEntry entry;
  final ValueChanged<PayoutEntry> onMarkPaid;
  final ValueChanged<PayoutEntry> onMarkUnpaid;
  final ValueChanged<PayoutEntry> onSetAmount;

  const _ActionButton({
    required this.entry,
    required this.onMarkPaid,
    required this.onMarkUnpaid,
    required this.onSetAmount,
  });

  static const double width = 86;

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.symmetric(horizontal: 8);
    const textStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w700);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );
    final Widget button;
    if (entry.isPaid) {
      button = OutlinedButton(
        onPressed: () => onMarkUnpaid(entry),
        style: OutlinedButton.styleFrom(
          padding: padding,
          minimumSize: const Size(0, 32),
          shape: shape,
          foregroundColor: AppColors.danger,
          side: BorderSide(color: AppColors.danger.withValues(alpha: 0.35)),
          textStyle: textStyle,
        ),
        child: const Text('Unpaid'),
      );
    } else if (!entry.hasAmount) {
      button = OutlinedButton(
        onPressed: () => onSetAmount(entry),
        style: OutlinedButton.styleFrom(
          padding: padding,
          minimumSize: const Size(0, 32),
          shape: shape,
          foregroundColor: AppColors.warning,
          side: BorderSide(color: AppColors.warning.withValues(alpha: 0.5)),
          textStyle: textStyle,
        ),
        child: const Text('Set Amount'),
      );
    } else {
      button = FilledButton(
        onPressed: () => onMarkPaid(entry),
        style: FilledButton.styleFrom(
          padding: padding,
          minimumSize: const Size(0, 32),
          shape: shape,
          backgroundColor: _P.navy,
          foregroundColor: Colors.white,
          textStyle: textStyle,
        ),
        child: const Text('Mark Paid'),
      );
    }
    return SizedBox(
      width: width,
      child: FittedBox(fit: BoxFit.scaleDown, child: button),
    );
  }
}

/// Column headings over a member list; [columns] are (label, flex) pairs,
/// followed by a fixed-width ACTION column matching [_ActionButton.width].
class _TableHeader extends StatelessWidget {
  final List<(String, int)> columns;
  const _TableHeader({required this.columns});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.6,
      color: _secondaryText(context),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Matches [_BorderedPayoutRow]: when rows stack, the first column
        // (the name) sits on its own line, so its label joins the next one.
        final cols =
            constraints.maxWidth < _stackRowsBelow && columns.length > 1
            ? [
                ('${columns[0].$1} / ${columns[1].$1}', columns[1].$2),
                ...columns.skip(2),
              ]
            : columns;
        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
          child: Row(
            children: [
              for (final (label, flex) in cols)
                Expanded(
                  flex: flex,
                  child: Text(label.toUpperCase(), style: style),
                ),
              SizedBox(
                width: _ActionButton.width,
                child: Text(
                  'ACTION',
                  style: style,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ExpandChevron extends StatelessWidget {
  final bool expanded;
  final bool onNavy;
  const _ExpandChevron({required this.expanded, this.onNavy = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: expanded ? 0.5 : 0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: onNavy
              ? _P.gold.withValues(alpha: 0.16)
              : _P.navy.withValues(alpha: 0.06),
          shape: BoxShape.circle,
          border: onNavy
              ? Border.all(color: _P.gold.withValues(alpha: 0.5))
              : null,
        ),
        child: Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 20,
          color: onNavy ? _P.gold : _navy(context),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final PayoutTotals totals;
  final bool onNavy;
  const _CountBadge({required this.totals, this.onNavy = false});

  @override
  Widget build(BuildContext context) {
    final allPaid = totals.pendingCount == 0;
    final color = allPaid
        ? (onNavy ? const Color(0xFF6FD3A6) : AppColors.success)
        : (onNavy ? const Color(0xFFFF8A80) : AppColors.danger);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: onNavy ? 0.16 : 0.1),
        borderRadius: BorderRadius.circular(20),
        border: onNavy ? Border.all(color: color.withValues(alpha: 0.4)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            allPaid ? Icons.check_circle_rounded : Icons.schedule_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            allPaid ? 'All Paid' : '${totals.pendingCount} Pending',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Plain Total / Paid / Pending footer, used on By Member cards.
class _FooterTotals extends StatelessWidget {
  final PayoutTotals totals;
  final String totalLabel;
  const _FooterTotals({required this.totals, required this.totalLabel});

  @override
  Widget build(BuildContext context) {
    Widget item(String label, double amount, Color? color) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: _secondaryText(context)),
        ),
        const SizedBox(height: 2),
        Text(
          formatCurrency(amount),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 2),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _borderColor(context))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 16,
            runSpacing: 8,
            children: [
              item(totalLabel, totals.total, _navy(context)),
              item('Paid', totals.paid, AppColors.success),
              item('Pending', totals.pending, AppColors.danger),
            ],
          ),
          if (totals.unsetCount > 0) ...[
            const SizedBox(height: 6),
            Text(
              '${totals.unsetCount} without an amount — not counted',
              style: const TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: AppColors.warning,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One member's payout inside a single bordered row: avatar + full name,
/// amount (tip beneath), status and action — the border wraps all of it.
class _BorderedPayoutRow extends StatelessWidget {
  final Widget leading;
  final int leadingFlex;
  final List<(Widget, int)> middle;
  final Widget action;
  final bool paid;

  const _BorderedPayoutRow({
    required this.leading,
    required this.leadingFlex,
    required this.middle,
    required this.action,
    required this.paid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: paid
            ? AppColors.success.withValues(
                alpha: _isDark(context) ? 0.08 : 0.04,
              )
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: paid
              ? AppColors.success.withValues(alpha: 0.25)
              : _P.gold.withValues(alpha: 0.35),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cells = [
            for (final (child, flex) in middle)
              Expanded(
                flex: flex,
                child: Align(alignment: Alignment.centerLeft, child: child),
              ),
            action,
          ];
          // Too narrow for one line: the name gets the full width on top,
          // the cells sit beneath it — still inside the same border.
          if (constraints.maxWidth + 20 < _stackRowsBelow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                leading,
                const SizedBox(height: 8),
                Row(children: cells),
              ],
            );
          }
          return Row(
            children: [
              Expanded(flex: leadingFlex, child: leading),
              ...cells,
            ],
          );
        },
      ),
    );
  }
}

/// Below this width a member list switches to stacked rows (see
/// [_BorderedPayoutRow]) so names never get squeezed.
const double _stackRowsBelow = 440;

class _Avatar extends StatelessWidget {
  final String name;
  final double size;
  const _Avatar({required this.name, this.size = 30});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _P.navy,
        border: Border.all(color: _P.gold, width: 1.2),
      ),
      child: Text(
        _initials(name),
        style: TextStyle(
          color: _P.gold,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}

// --- By Function ---

class _EventPayoutCard extends StatelessWidget {
  final _EventGroup group;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<PayoutEntry> onMarkPaid;
  final ValueChanged<PayoutEntry> onMarkUnpaid;
  final ValueChanged<PayoutEntry> onSetAmount;
  final VoidCallback onEditTip;
  final VoidCallback onMarkAllPaid;
  final VoidCallback onMarkAllUnpaid;

  const _EventPayoutCard({
    required this.group,
    required this.expanded,
    required this.onToggle,
    required this.onMarkPaid,
    required this.onMarkUnpaid,
    required this.onSetAmount,
    required this.onEditTip,
    required this.onMarkAllPaid,
    required this.onMarkAllUnpaid,
  });

  @override
  Widget build(BuildContext context) {
    final totals = group.totals;
    final radius = BorderRadius.circular(AppRadius.card);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: radius,
        border: Border.all(color: _P.gold.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: _P.navy.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _EventHeader(group: group, expanded: expanded, onTap: onToggle),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: _TipRow(
                tip: group.event.memberTipPerHead,
                onEdit: onEditTip,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: !expanded
                  ? const SizedBox(width: double.infinity, height: 12)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _EventSummaryGrid(totals: totals),
                          const SizedBox(height: 12),
                          _MarkAllPaidButton(
                            totals: totals,
                            onPressed: onMarkAllPaid,
                            onMarkAllUnpaid: onMarkAllUnpaid,
                          ),
                          const SizedBox(height: 12),
                          const _TableHeader(
                            columns: [
                              ('Member', 5),
                              ('Amount', 4),
                              ('Status', 3),
                            ],
                          ),
                          for (final entry in group.entries)
                            _EventMemberRow(
                              entry: entry,
                              onMarkPaid: onMarkPaid,
                              onMarkUnpaid: onMarkUnpaid,
                              onSetAmount: onSetAmount,
                            ),
                          const SizedBox(height: 4),
                          _EventBottomSummary(totals: totals),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The navy header of an event card: name, date, shift, members, pending
/// count, total payout and the expand control.
class _EventHeader extends StatelessWidget {
  final _EventGroup group;
  final bool expanded;
  final VoidCallback onTap;

  const _EventHeader({
    required this.group,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final event = group.event;
    final members = group.entries.where((e) => e.stillAssigned).length;
    final muted = Colors.white.withValues(alpha: 0.72);
    final isDay = event.shift == Shift.day;

    Widget meta(IconData icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12.5, color: _P.gold),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    return InkWell(
      onTap: onTap,
      child: Ink(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_P.navyDeep, _P.navy, _P.navyLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border(bottom: BorderSide(color: _P.gold, width: 1.2)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.eventName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      meta(
                        Icons.calendar_today_rounded,
                        formatEventDate(event.date),
                      ),
                      meta(
                        isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                        event.shift.label,
                      ),
                      meta(
                        Icons.people_alt_rounded,
                        '$members member${members == 1 ? '' : 's'}',
                      ),
                      _CountBadge(totals: group.totals, onNavy: true),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'TOTAL PAYOUT',
                  style: TextStyle(
                    fontSize: 9.5,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatCurrency(group.totals.total),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _P.gold,
                  ),
                ),
                const SizedBox(height: 8),
                _ExpandChevron(expanded: expanded, onNavy: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Tips per member" line below an event's header, with an Add / Edit
/// button.
class _TipRow extends StatelessWidget {
  final double tip;
  final VoidCallback onEdit;
  const _TipRow({required this.tip, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final hasTip = tip > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
      decoration: BoxDecoration(
        color: _P.gold.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _P.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard_rounded, size: 17, color: _P.goldDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              hasTip
                  ? TextSpan(
                      children: [
                        const TextSpan(text: 'Tip per member  '),
                        TextSpan(
                          text: formatCurrency(tip),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _P.goldDark,
                          ),
                        ),
                      ],
                    )
                  : const TextSpan(text: 'No tip added'),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: hasTip ? null : _secondaryText(context),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onEdit,
            icon: Icon(
              hasTip ? Icons.edit_rounded : Icons.add_rounded,
              size: 15,
            ),
            label: Text(hasTip ? 'Edit' : 'Add Tip'),
            style: TextButton.styleFrom(
              foregroundColor: _navy(context),
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Total Amount / Total Tips / Paid / Pending tiles for one event — four
/// across on wide cards, a 2×2 grid on phones.
class _EventSummaryGrid extends StatelessWidget {
  final PayoutTotals totals;
  const _EventSummaryGrid({required this.totals});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _SummaryTile(
        icon: Icons.account_balance_wallet_rounded,
        label: 'Total Amount',
        amount: totals.total,
        color: _navy(context),
      ),
      _SummaryTile(
        icon: Icons.card_giftcard_rounded,
        label: 'Total Tips',
        amount: totals.tips,
        color: _P.goldDark,
      ),
      _SummaryTile(
        icon: Icons.check_circle_rounded,
        label: 'Paid Amount',
        amount: totals.paid,
        color: AppColors.success,
      ),
      _SummaryTile(
        icon: Icons.schedule_rounded,
        label: 'Pending Amount',
        amount: totals.pending,
        color: AppColors.danger,
      ),
    ];
    const gap = 8.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final perRow = constraints.maxWidth >= 520 ? 4 : 2;
        final width = (constraints.maxWidth - gap * (perRow - 1)) / perRow;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final t in tiles) SizedBox(width: width, child: t)],
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final double amount;
  final Color color;

  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: _isDark(context)
            ? Theme.of(context).colorScheme.surface
            : _P.ivory,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _P.gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _secondaryText(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatCurrency(amount),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gold "Mark All Paid" for one event. Disabled (with the reason) when
/// nothing payable is pending.
class _MarkAllPaidButton extends StatelessWidget {
  final PayoutTotals totals;
  final VoidCallback onPressed;

  /// Offered next to "All payments settled" to reverse the whole event.
  final VoidCallback onMarkAllUnpaid;

  const _MarkAllPaidButton({
    required this.totals,
    required this.onPressed,
    required this.onMarkAllUnpaid,
  });

  @override
  Widget build(BuildContext context) {
    final payable = totals.payableCount;
    final enabled = payable > 0;
    final String label;
    if (totals.pendingCount == 0) {
      label = 'All payments settled';
    } else if (payable == 0) {
      label = 'Set amounts to mark paid';
    } else {
      label = 'Mark All Paid ($payable)';
    }

    final bar = SizedBox(
      height: 46,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: [_P.goldDark, _P.gold, _P.goldLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: enabled ? null : _P.gold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: _P.gold.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  totals.pendingCount == 0
                      ? Icons.verified_rounded
                      : Icons.done_all_rounded,
                  size: 19,
                  color: enabled ? _P.navy : _P.goldDark,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: enabled ? _P.navy : _P.goldDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (totals.pendingCount > 0 || totals.paidCount == 0) return bar;
    final unpaidButton = SizedBox(
      height: 46,
      child: OutlinedButton.icon(
        onPressed: onMarkAllUnpaid,
        icon: const Icon(Icons.undo_rounded, size: 17),
        label: const Text('Mark All Unpaid'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.danger,
          side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          // The app theme makes outlined buttons full-width, which a
          // Row can't lay out.
          minimumSize: const Size(0, 46),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Side by side when there's room; stacked on narrow phones.
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [bar, const SizedBox(height: 8), unpaidButton],
          );
        }
        return Row(
          children: [
            Expanded(child: bar),
            const SizedBox(width: 8),
            unpaidButton,
          ],
        );
      },
    );
  }
}

class _EventMemberRow extends StatelessWidget {
  final PayoutEntry entry;
  final ValueChanged<PayoutEntry> onMarkPaid;
  final ValueChanged<PayoutEntry> onMarkUnpaid;
  final ValueChanged<PayoutEntry> onSetAmount;

  const _EventMemberRow({
    required this.entry,
    required this.onMarkPaid,
    required this.onMarkUnpaid,
    required this.onSetAmount,
  });

  @override
  Widget build(BuildContext context) {
    return _BorderedPayoutRow(
      paid: entry.isPaid,
      leadingFlex: 5,
      leading: Row(
        children: [
          _Avatar(name: entry.memberName),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full name — wraps instead of being cut off.
                Text(
                  entry.memberName,
                  softWrap: true,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                if (!entry.stillAssigned)
                  Text(
                    'No longer assigned',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: _secondaryText(context),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      middle: [
        (_AmountCell(entry: entry, onEdit: () => onSetAmount(entry)), 4),
        (_StatusChip(paid: entry.isPaid), 3),
      ],
      action: _ActionButton(
        entry: entry,
        onMarkPaid: onMarkPaid,
        onMarkUnpaid: onMarkUnpaid,
        onSetAmount: onSetAmount,
      ),
    );
  }
}

/// Navy-and-gold Total / Paid / Pending panel closing an expanded event
/// card, three even, centered sections.
class _EventBottomSummary extends StatelessWidget {
  final PayoutTotals totals;
  const _EventBottomSummary({required this.totals});

  @override
  Widget build(BuildContext context) {
    Widget section(String label, double amount, String? caption, Color color) {
      return Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9.5,
                letterSpacing: 0.7,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatCurrency(amount),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
            if (caption != null) ...[
              const SizedBox(height: 2),
              Text(
                caption,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  color: Colors.white.withValues(alpha: 0.65),
                ),
              ),
            ],
          ],
        ),
      );
    }

    Widget divider() =>
        Container(width: 1, height: 38, color: _P.gold.withValues(alpha: 0.35));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_P.navyDeep, _P.navy],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _P.gold.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          section('Total Amount', totals.total, null, _P.gold),
          divider(),
          section(
            'Paid',
            totals.paid,
            '${totals.paidCount} paid',
            const Color(0xFF6FD3A6),
          ),
          divider(),
          section(
            'Pending',
            totals.pending,
            '${totals.pendingCount} pending',
            const Color(0xFFFF8A80),
          ),
        ],
      ),
    );
  }
}

// --- By Member ---

class _MemberPayoutCard extends StatelessWidget {
  final _MemberGroup group;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<PayoutEntry> onMarkPaid;
  final ValueChanged<PayoutEntry> onMarkUnpaid;
  final ValueChanged<PayoutEntry> onSetAmount;

  const _MemberPayoutCard({
    required this.group,
    required this.expanded,
    required this.onToggle,
    required this.onMarkPaid,
    required this.onMarkUnpaid,
    required this.onSetAmount,
  });

  @override
  Widget build(BuildContext context) {
    final totals = group.totals;
    final eventCount = group.entries.length;
    final radius = BorderRadius.circular(AppRadius.card);

    Widget stat(String label, double amount, Color? color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10.5, color: _secondaryText(context)),
          ),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatCurrency(amount),
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );

    return Container(
      decoration: _cardDecoration(context),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _Avatar(name: group.memberName, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.memberName,
                                style: AppTextStyles.cardTitle.copyWith(
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    '$eventCount event${eventCount == 1 ? '' : 's'} assigned',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _secondaryText(context),
                                    ),
                                  ),
                                  _CountBadge(totals: totals),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _ExpandChevron(expanded: expanded),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _P.gold.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          stat('Total', totals.total, _navy(context)),
                          stat('Paid', totals.paid, AppColors.success),
                          stat('Pending', totals.pending, AppColors.danger),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: !expanded
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 520;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _TableHeader(
                                columns: wide
                                    ? const [
                                        ('Event', 4),
                                        ('Date', 2),
                                        ('Shift', 2),
                                        ('Amount', 3),
                                        ('Status', 3),
                                      ]
                                    : const [
                                        ('Event', 5),
                                        ('Amount', 3),
                                        ('Status', 3),
                                      ],
                              ),
                              for (final entry in group.entries)
                                _MemberEventRow(
                                  entry: entry,
                                  wide: wide,
                                  onMarkPaid: onMarkPaid,
                                  onMarkUnpaid: onMarkUnpaid,
                                  onSetAmount: onSetAmount,
                                ),
                              _FooterTotals(
                                totals: totals,
                                totalLabel: 'Total Payout',
                              ),
                            ],
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberEventRow extends StatelessWidget {
  final PayoutEntry entry;
  final bool wide;
  final ValueChanged<PayoutEntry> onMarkPaid;
  final ValueChanged<PayoutEntry> onMarkUnpaid;
  final ValueChanged<PayoutEntry> onSetAmount;

  const _MemberEventRow({
    required this.entry,
    required this.wide,
    required this.onMarkPaid,
    required this.onMarkUnpaid,
    required this.onSetAmount,
  });

  @override
  Widget build(BuildContext context) {
    final event = entry.event;
    final secondary = TextStyle(fontSize: 11.5, color: _secondaryText(context));
    final name = Text(
      event.eventName,
      softWrap: true,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
    );
    final amount = _AmountCell(entry: entry, onEdit: () => onSetAmount(entry));
    final status = _StatusChip(paid: entry.isPaid);

    return _BorderedPayoutRow(
      paid: entry.isPaid,
      leadingFlex: wide ? 4 : 5,
      leading: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: wide
            ? name
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  name,
                  const SizedBox(height: 2),
                  Text(
                    '${_shortDateFormat.format(event.date)} · ${event.shift.label}',
                    style: secondary,
                  ),
                ],
              ),
      ),
      middle: [
        if (wide) ...[
          (Text(_shortDateFormat.format(event.date), style: secondary), 2),
          (ShiftBadge(shift: event.shift), 2),
        ],
        (amount, 3),
        (status, 3),
      ],
      action: _ActionButton(
        entry: entry,
        onMarkPaid: onMarkPaid,
        onMarkUnpaid: onMarkUnpaid,
        onSetAmount: onSetAmount,
      ),
    );
  }
}

// --- Dialogs ---

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailLine(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: _secondaryText(context)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _eventLine(EventBooking e) =>
    '${formatEventDate(e.date)} · ${e.shift.label}';

/// Base pay / Tip / Total lines for a dialog; just the total when there's
/// no tip.
List<Widget> _amountLines(PayoutEntry entry, {required String totalLabel}) {
  final total = _DetailLine(
    totalLabel,
    formatCurrency(entry.amount!),
    valueColor: AppColors.success,
  );
  if (entry.tip <= 0) return [total];
  return [
    _DetailLine('Base pay', formatCurrency(entry.baseAmount!)),
    _DetailLine('Tip', formatCurrency(entry.tip)),
    total,
  ];
}

/// Edits an event's per-head member tip. Pops the new value (0 clears it),
/// or null on cancel.
class _TipDialog extends StatefulWidget {
  final EventBooking event;
  final int paidCount;
  const _TipDialog({required this.event, required this.paidCount});

  @override
  State<_TipDialog> createState() => _TipDialogState();
}

class _TipDialogState extends State<_TipDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    final tip = widget.event.memberTipPerHead;
    _controller = TextEditingController(
      text: tip <= 0
          ? ''
          : (tip == tip.roundToDouble()
                ? tip.toStringAsFixed(0)
                : tip.toString()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    final value = text.isEmpty ? 0.0 : double.tryParse(text);
    if (value == null || value < 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    return AlertDialog(
      title: const Text('Tips per Member'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DetailLine('Event', event.eventName),
          _DetailLine('Date', _eventLine(event)),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              labelText: 'Tip for each member',
              prefixText: '₹ ',
              errorText: _error,
              helperText: 'Every member on this event gets this amount extra.',
              helperMaxLines: 2,
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (widget.paidCount > 0) ...[
            const SizedBox(height: 10),
            Text(
              '${widget.paidCount} member${widget.paidCount == 1 ? ' is' : 's are'} '
              "already paid — their recorded payment won't change.",
              style: const TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

/// Confirms Mark All Paid for one event: names the event and how many
/// pending members (and how much) will be marked paid.
class _MarkAllPaidDialog extends StatelessWidget {
  final EventBooking event;
  final List<PayoutEntry> entries;
  final int skipped;

  const _MarkAllPaidDialog({
    required this.event,
    required this.entries,
    required this.skipped,
  });

  @override
  Widget build(BuildContext context) {
    final total = entries.fold<double>(0, (acc, e) => acc + e.amount!);
    final count = entries.length;
    return AlertDialog(
      title: const Text('Mark All Paid?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DetailLine('Event', event.eventName),
          _DetailLine('Date', _eventLine(event)),
          _DetailLine('Pending', '$count member${count == 1 ? '' : 's'}'),
          _DetailLine(
            'Total',
            formatCurrency(total),
            valueColor: AppColors.success,
          ),
          const SizedBox(height: 8),
          Text(
            'Confirm these payments have actually been made. Only this '
            "event's pending payments will be marked paid.",
            style: TextStyle(fontSize: 12.5, color: _secondaryText(context)),
          ),
          if (skipped > 0) ...[
            const SizedBox(height: 8),
            Text(
              '$skipped member${skipped == 1 ? ' has' : 's have'} no amount '
              'set and will be skipped.',
              style: const TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: _P.gold,
            foregroundColor: _P.navy,
          ),
          child: Text('Mark $count Paid'),
        ),
      ],
    );
  }
}

class _SetAmountDialog extends StatefulWidget {
  final PayoutEntry entry;
  const _SetAmountDialog({required this.entry});

  @override
  State<_SetAmountDialog> createState() => _SetAmountDialogState();
}

class _SetAmountDialogState extends State<_SetAmountDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    final amount = widget.entry.baseAmount;
    _controller = TextEditingController(
      text: amount == null
          ? ''
          : (amount == amount.roundToDouble()
                ? amount.toStringAsFixed(0)
                : amount.toString()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = double.tryParse(_controller.text.trim());
    if (value == null || value <= 0) {
      setState(() => _error = 'Enter an amount greater than 0');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return AlertDialog(
      title: Text(entry.hasAmount ? 'Edit Payout Amount' : 'Set Payout Amount'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DetailLine('Member', entry.memberName),
          _DetailLine('Event', entry.event.eventName),
          _DetailLine('Date', _eventLine(entry.event)),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              labelText: entry.tip > 0
                  ? 'Base amount (+ ${formatCurrency(entry.tip)} tip)'
                  : 'Amount',
              prefixText: '₹ ',
              errorText: _error,
              helperText: entry.event.amount > 0
                  ? 'Event ${entry.event.shift.label} Amount: '
                        '${formatCurrency(entry.event.amount)}'
                  : null,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

/// Confirms a payment has really been made before recording it. Pops the
/// (possibly empty) note on confirm, or null on cancel.
class _MarkPaidDialog extends StatefulWidget {
  final PayoutEntry entry;
  const _MarkPaidDialog({required this.entry});

  @override
  State<_MarkPaidDialog> createState() => _MarkPaidDialogState();
}

class _MarkPaidDialogState extends State<_MarkPaidDialog> {
  final _noteController = TextEditingController();
  bool _confirmed = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return AlertDialog(
      title: const Text('Confirm Payment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DetailLine('Member', entry.memberName),
            _DetailLine('Event', entry.event.eventName),
            _DetailLine('Date', _eventLine(entry.event)),
            ..._amountLines(entry, totalLabel: 'Total'),
            const SizedBox(height: 10),
            TextField(
              controller: _noteController,
              maxLines: 2,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note / reference (optional)',
                hintText: 'e.g. Paid in cash',
              ),
            ),
            const SizedBox(height: 6),
            CheckboxListTile(
              value: _confirmed,
              onChanged: (v) => setState(() => _confirmed = v ?? false),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'I confirm this payment has actually been made.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _confirmed
              ? () => Navigator.of(context).pop(_noteController.text)
              : null,
          child: const Text('Mark Paid'),
        ),
      ],
    );
  }
}

// --- Payment history ---

/// Admin sidebar "History": asks whose payment history to see — a
/// searchable list of every member with payouts — then opens that member's
/// full record. Live, from the same payout records as the Payouts page.
class PayoutHistoryScreen extends StatefulWidget {
  const PayoutHistoryScreen({super.key});

  @override
  State<PayoutHistoryScreen> createState() => _PayoutHistoryScreenState();
}

class _PayoutHistoryScreenState extends State<PayoutHistoryScreen> {
  late final Stream<List<EventBooking>> _eventsStream;
  late final Stream<List<Payout>> _payoutsStream;
  String _query = '';

  @override
  void initState() {
    super.initState();
    final dataService = context.read<DataService>();
    _eventsStream = dataService.staffingEvents();
    _payoutsStream = dataService.payouts();
  }

  void _open(_MemberGroup member) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _MemberHistoryScreen(
          memberId: member.memberId,
          memberName: member.memberName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDark(context) ? null : _P.ivory,
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('History')),
      body: SafeArea(
        child: StreamBuilder<List<EventBooking>>(
          stream: _eventsStream,
          builder: (context, eventsSnap) => StreamBuilder<List<Payout>>(
            stream: _payoutsStream,
            builder: (context, payoutsSnap) {
              final error = eventsSnap.error ?? payoutsSnap.error;
              if (error != null) {
                final denied =
                    error is FirebaseException &&
                    error.code == 'permission-denied';
                return _MessageState(
                  icon: Icons.error_outline_rounded,
                  title: "Couldn't load history",
                  subtitle: denied
                      ? 'Permission denied. The Firestore security rules '
                            "for payouts haven't been published yet."
                      : 'Check your connection and try again.',
                );
              }
              if (!eventsSnap.hasData || !payoutsSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return _buildBody(
                buildPayoutEntries(eventsSnap.data!, payoutsSnap.data!),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody(List<PayoutEntry> entries) {
    final byMember = <String, List<PayoutEntry>>{};
    for (final e in entries) {
      (byMember[e.memberId] ??= []).add(e);
    }
    final q = _query.toLowerCase();
    final members =
        [
          for (final list in byMember.values)
            _MemberGroup(list.first.memberId, list.first.memberName, list),
        ].where((m) => m.memberName.toLowerCase().contains(q)).toList()..sort(
          (a, b) =>
              a.memberName.toLowerCase().compareTo(b.memberName.toLowerCase()),
        );

    return ResponsiveCenter(
      maxWidth: 820,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          Text('History', style: AppTextStyles.pageTitle),
          const SizedBox(height: 2),
          Text(
            'Whose history do you want to see?',
            style: AppTextStyles.label.copyWith(color: _secondaryText(context)),
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (v) => setState(() => _query = v.trim()),
            decoration: const InputDecoration(
              hintText: 'Search member name',
              isDense: true,
              prefixIcon: Icon(Icons.search_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          if (byMember.isEmpty)
            const _MessageState(
              icon: Icons.history_rounded,
              title: 'No history yet',
              subtitle:
                  'Members you assign to events from Assign Members will appear here.',
            )
          else if (members.isEmpty)
            const _MessageState(
              icon: Icons.person_search_rounded,
              title: 'No members found',
              subtitle: 'Try a different name.',
            )
          else
            for (final m in members) ...[
              _MemberPickerTile(member: m, onTap: () => _open(m)),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _MemberPickerTile extends StatelessWidget {
  final _MemberGroup member;
  final VoidCallback onTap;
  const _MemberPickerTile({required this.member, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final totals = member.totals;
    final events = member.entries.length;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: _P.gold.withValues(alpha: 0.35)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              _Avatar(name: member.memberName, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.memberName,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$events event${events == 1 ? '' : 's'} · '
                      '${formatCurrency(totals.paid)} paid',
                      style: TextStyle(
                        fontSize: 12,
                        color: _secondaryText(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (totals.pending > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    '${formatCurrency(totals.pending)} due',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              Icon(Icons.chevron_right_rounded, color: _secondaryText(context)),
            ],
          ),
        ),
      ),
    );
  }
}

/// One member's full payment record: totals, then every event they were
/// paid (or are still owed) for, newest first and grouped by month. Live,
/// from the same payout records as the Payouts page.
class _MemberHistoryScreen extends StatefulWidget {
  final String memberId;
  final String memberName;

  const _MemberHistoryScreen({
    required this.memberId,
    required this.memberName,
  });

  @override
  State<_MemberHistoryScreen> createState() => _MemberHistoryScreenState();
}

class _MemberHistoryScreenState extends State<_MemberHistoryScreen> {
  late final Stream<List<EventBooking>> _eventsStream;
  late final Stream<List<Payout>> _payoutsStream;
  _StatusFilter _filter = _StatusFilter.all;

  @override
  void initState() {
    super.initState();
    final dataService = context.read<DataService>();
    _eventsStream = dataService.staffingEvents();
    _payoutsStream = dataService.payouts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDark(context) ? null : _P.ivory,
      appBar: AppBar(title: const Text('Payment History')),
      body: SafeArea(
        child: StreamBuilder<List<EventBooking>>(
          stream: _eventsStream,
          builder: (context, eventsSnap) => StreamBuilder<List<Payout>>(
            stream: _payoutsStream,
            builder: (context, payoutsSnap) {
              if (eventsSnap.hasError || payoutsSnap.hasError) {
                return const _MessageState(
                  icon: Icons.error_outline_rounded,
                  title: "Couldn't load history",
                  subtitle: 'Check your connection and try again.',
                );
              }
              if (!eventsSnap.hasData || !payoutsSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final entries =
                  buildPayoutEntries(
                      eventsSnap.data!,
                      payoutsSnap.data!,
                    ).where((e) => e.memberId == widget.memberId).toList()
                    ..sort((a, b) => newestFirst(a.event, b.event));
              return _buildBody(entries);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody(List<PayoutEntry> entries) {
    final totals = PayoutTotals.of(entries);
    final paidTips = entries
        .where((e) => e.isPaid)
        .fold<double>(0, (acc, e) => acc + e.tip);
    final shown = entries.where((e) {
      return switch (_filter) {
        _StatusFilter.all => true,
        _StatusFilter.paid => e.isPaid,
        _StatusFilter.pending => !e.isPaid,
      };
    }).toList();

    final months = <String, List<PayoutEntry>>{};
    for (final e in shown) {
      (months[_monthFormat.format(e.event.date)] ??= []).add(e);
    }

    return ResponsiveCenter(
      maxWidth: 820,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          _HistoryProfileCard(
            name: entries.isEmpty
                ? widget.memberName
                : entries.first.memberName,
            eventCount: entries.length,
            paidCount: totals.paidCount,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryTile(
                  icon: Icons.check_circle_rounded,
                  label: 'Total Paid',
                  amount: totals.paid,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryTile(
                  icon: Icons.schedule_rounded,
                  label: 'Pending',
                  amount: totals.pending,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryTile(
                  icon: Icons.card_giftcard_rounded,
                  label: 'Tips Paid',
                  amount: paidTips,
                  color: _P.goldDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final f in _StatusFilter.values) ...[
                _FilterPill(
                  label: f.label,
                  selected: f == _filter,
                  onTap: () => setState(() => _filter = f),
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 6),
          if (shown.isEmpty)
            _MessageState(
              icon: Icons.receipt_long_rounded,
              title: entries.isEmpty ? 'No payments yet' : 'Nothing here',
              subtitle: entries.isEmpty
                  ? 'This member has no payouts recorded.'
                  : 'No ${_filter.label.toLowerCase()} payments.',
            )
          else
            for (final MapEntry(key: month, value: items)
                in months.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                child: Row(
                  children: [
                    Text(
                      month.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: _secondaryText(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: _P.gold.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ),
              for (final e in items) _HistoryTile(entry: e),
            ],
        ],
      ),
    );
  }
}

class _HistoryProfileCard extends StatelessWidget {
  final String name;
  final int eventCount;
  final int paidCount;

  const _HistoryProfileCard({
    required this.name,
    required this.eventCount,
    required this.paidCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_P.navyDeep, _P.navy, _P.navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: _P.gold.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          _Avatar(name: name, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$eventCount event${eventCount == 1 ? '' : 's'} · '
                  '$paidCount paid',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One event in a member's history: event, date & shift, amount (with the
/// tip spelled out), status, and when it was paid.
class _HistoryTile extends StatelessWidget {
  final PayoutEntry entry;
  const _HistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final event = entry.event;
    final amount = entry.amount;
    final paidAt = entry.payout?.paidAt;
    final note = entry.payout?.note ?? '';
    final secondary = TextStyle(fontSize: 12, color: _secondaryText(context));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: entry.isPaid
            ? AppColors.success.withValues(
                alpha: _isDark(context) ? 0.08 : 0.04,
              )
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: entry.isPaid
              ? AppColors.success.withValues(alpha: 0.25)
              : _P.gold.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  event.eventName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                amount == null ? 'Not set' : formatCurrency(amount),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: amount == null
                      ? AppColors.warning
                      : (entry.isPaid ? AppColors.success : null),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 10,
            runSpacing: 2,
            children: [
              Text(
                '${formatEventDate(event.date)} · ${event.shift.label}',
                style: secondary,
              ),
              if (amount != null && entry.tip > 0)
                Text(
                  '${formatCurrency(entry.baseAmount!)} + '
                  '${formatCurrency(entry.tip)} tip',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _StatusChip(paid: entry.isPaid),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.isPaid
                      ? (paidAt == null
                            ? 'Paid'
                            : 'Paid on ${_paidAtFormat.format(paidAt)}')
                      : 'Not paid yet',
                  style: secondary,
                ),
              ),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Note: $note',
              style: secondary.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}

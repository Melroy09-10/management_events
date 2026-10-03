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

final _paidAtFormat = DateFormat('dd MMM yyyy, h:mm a');
final _shortDateFormat = DateFormat('dd MMM');
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

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? AppColors.danger : AppColors.success,
        ),
      );
  }

  String _errorText(Object e) =>
      e is StateError ? e.message : 'Something went wrong. Please try again.';

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
      await _dataService.markPayoutPaid(
        eventId: entry.event.id,
        memberId: entry.memberId,
        memberName: entry.memberName,
        amount: entry.baseAmount!,
        tip: entry.tip,
        note: note,
      );
      if (!mounted) return;
      _showMessage(
        '${formatCurrency(entry.amount!)} marked paid to ${entry.memberName}',
      );
    } catch (e) {
      if (mounted) _showMessage(_errorText(e), error: true);
    }
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

  void _view(PayoutEntry entry) {
    showDialog<void>(
      context: context,
      builder: (_) => _ViewPaymentDialog(entry: entry),
    );
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                onView: _view,
                onSetAmount: _setAmount,
                onEditTip: () => _editTip(g),
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
                onView: _view,
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

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color _borderColor(BuildContext context) =>
    _isDark(context) ? AppColors.borderDark : AppColors.border;

Color _secondaryText(BuildContext context) => _isDark(context)
    ? AppColors.textSecondaryDark
    : AppColors.textSecondaryLight;

Color _navy(BuildContext context) =>
    onSurfaceAccent(context, AppColors.primary);

BoxDecoration _cardDecoration(BuildContext context) => BoxDecoration(
  color: Theme.of(context).colorScheme.surface,
  borderRadius: BorderRadius.circular(AppRadius.card),
  border: Border.all(color: _borderColor(context)),
  boxShadow: [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.05),
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
              color: selected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: selected
                  ? Border.all(color: AppColors.gold.withValues(alpha: 0.7))
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: selected ? AppColors.gold : _secondaryText(context),
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
      color: selected
          ? AppColors.primary
          : Theme.of(context).colorScheme.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? AppColors.primary : _borderColor(context),
        ),
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
          Icon(icon, size: 44, color: AppColors.gold),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          paid ? 'Paid' : 'Pending',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

/// Tappable amount; shows "Not set" when no amount is recorded. Pending
/// amounts can be edited by tapping, paid ones are locked.
class _AmountCell extends StatelessWidget {
  final PayoutEntry entry;
  final VoidCallback onEdit;
  const _AmountCell({required this.entry, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final amount = entry.amount;
    final total = Text(
      amount == null ? 'Not set' : formatCurrency(amount),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13,
        fontWeight: amount == null ? FontWeight.w600 : FontWeight.w700,
        fontStyle: amount == null ? FontStyle.italic : FontStyle.normal,
        color: amount == null ? AppColors.warning : null,
      ),
    );
    final Widget text = amount == null || entry.tip <= 0
        ? total
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              total,
              Text(
                'incl. ${formatCurrency(entry.tip)} tip',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            ],
          );
    if (entry.isPaid) return text;
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: text),
            const SizedBox(width: 3),
            Icon(
              Icons.edit_rounded,
              size: 12,
              color: _secondaryText(context).withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final PayoutEntry entry;
  final ValueChanged<PayoutEntry> onMarkPaid;
  final ValueChanged<PayoutEntry> onView;
  final ValueChanged<PayoutEntry> onSetAmount;

  const _ActionButton({
    required this.entry,
    required this.onMarkPaid,
    required this.onView,
    required this.onSetAmount,
  });

  static const double width = 90;

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
        onPressed: () => onView(entry),
        style: OutlinedButton.styleFrom(
          padding: padding,
          minimumSize: const Size(0, 32),
          shape: shape,
          foregroundColor: _navy(context),
          side: BorderSide(color: _borderColor(context)),
          textStyle: textStyle,
        ),
        child: const Text('View'),
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
          backgroundColor: AppColors.primary,
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

class _TableHeader extends StatelessWidget {
  final List<(String, int)> columns;
  const _TableHeader({required this.columns});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.4,
      color: _secondaryText(context),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          for (final (label, flex) in columns)
            Expanded(
              flex: flex,
              child: Text(label.toUpperCase(), style: style),
            ),
          SizedBox(
            width: _ActionButton.width,
            child: Text('ACTION', style: style, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

class _ExpandChevron extends StatelessWidget {
  final bool expanded;
  const _ExpandChevron({required this.expanded});

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: expanded ? 0.5 : 0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 20,
          color: _navy(context),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final PayoutTotals totals;
  const _CountBadge({required this.totals});

  @override
  Widget build(BuildContext context) {
    final allPaid = totals.pendingCount == 0;
    final color = allPaid ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
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

// --- By Function ---

class _EventPayoutCard extends StatelessWidget {
  final _EventGroup group;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<PayoutEntry> onMarkPaid;
  final ValueChanged<PayoutEntry> onView;
  final ValueChanged<PayoutEntry> onSetAmount;

  const _EventPayoutCard({
    required this.group,
    required this.expanded,
    required this.onToggle,
    required this.onMarkPaid,
    required this.onView,
    required this.onSetAmount,
    required this.onEditTip,
  });

  final VoidCallback onEditTip;

  @override
  Widget build(BuildContext context) {
    final event = group.event;
    final assigned = group.entries.where((e) => e.stillAssigned).length;
    final radius = BorderRadius.circular(AppRadius.card);

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
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.celebration_rounded,
                        color: AppColors.gold,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.eventName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.cardTitle.copyWith(
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 8,
                            runSpacing: 5,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 12,
                                    color: _secondaryText(context),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    formatEventDate(event.date),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _secondaryText(context),
                                    ),
                                  ),
                                ],
                              ),
                              ShiftBadge(shift: event.shift),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.people_alt_rounded,
                                    size: 13,
                                    color: _secondaryText(context),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$assigned member${assigned == 1 ? '' : 's'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _secondaryText(context),
                                    ),
                                  ),
                                ],
                              ),
                              _CountBadge(totals: group.totals),
                              if (event.memberTipPerHead > 0)
                                _TipBadge(tip: event.memberTipPerHead),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatCurrency(group.totals.total),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _navy(context),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _ExpandChevron(expanded: expanded),
                      ],
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _TipRow(
                            tip: event.memberTipPerHead,
                            onEdit: onEditTip,
                          ),
                          const SizedBox(height: 8),
                          const _TableHeader(
                            columns: [
                              ('Member', 4),
                              ('Amount', 3),
                              ('Status', 3),
                            ],
                          ),
                          for (final entry in group.entries)
                            _EventMemberRow(
                              entry: entry,
                              onMarkPaid: onMarkPaid,
                              onView: onView,
                              onSetAmount: onSetAmount,
                            ),
                          _FooterTotals(
                            totals: group.totals,
                            totalLabel: 'Event Total',
                          ),
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

class _TipBadge extends StatelessWidget {
  final double tip;
  const _TipBadge({required this.tip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.card_giftcard_rounded,
            size: 12,
            color: AppColors.goldDark,
          ),
          const SizedBox(width: 4),
          Text(
            '${formatCurrency(tip)} tip/head',
            style: const TextStyle(
              color: AppColors.goldDark,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Tips per member" line at the top of an expanded event card, with an
/// Add / Edit button.
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
        color: AppColors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.card_giftcard_rounded,
            size: 16,
            color: AppColors.goldDark,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasTip
                  ? 'Tips: ${formatCurrency(tip)} per member'
                  : 'No tips added',
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
              size: 16,
            ),
            label: Text(hasTip ? 'Edit' : 'Add Tips'),
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

class _EventMemberRow extends StatelessWidget {
  final PayoutEntry entry;
  final ValueChanged<PayoutEntry> onMarkPaid;
  final ValueChanged<PayoutEntry> onView;
  final ValueChanged<PayoutEntry> onSetAmount;

  const _EventMemberRow({
    required this.entry,
    required this.onMarkPaid,
    required this.onView,
    required this.onSetAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: _borderColor(context).withValues(alpha: 0.6),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.memberName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _AmountCell(
                entry: entry,
                onEdit: () => onSetAmount(entry),
              ),
            ),
          ),
          Expanded(flex: 3, child: _StatusChip(paid: entry.isPaid)),
          _ActionButton(
            entry: entry,
            onMarkPaid: onMarkPaid,
            onView: onView,
            onSetAmount: onSetAmount,
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
  final ValueChanged<PayoutEntry> onView;
  final ValueChanged<PayoutEntry> onSetAmount;

  const _MemberPayoutCard({
    required this.group,
    required this.expanded,
    required this.onToggle,
    required this.onMarkPaid,
    required this.onView,
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
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                            border: Border.all(color: AppColors.gold),
                          ),
                          child: Text(
                            _initials(group.memberName),
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.memberName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                        color: AppColors.gold.withValues(alpha: 0.07),
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
                                  onView: onView,
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
  final ValueChanged<PayoutEntry> onView;
  final ValueChanged<PayoutEntry> onSetAmount;

  const _MemberEventRow({
    required this.entry,
    required this.wide,
    required this.onMarkPaid,
    required this.onView,
    required this.onSetAmount,
  });

  @override
  Widget build(BuildContext context) {
    final event = entry.event;
    final secondary = TextStyle(fontSize: 11.5, color: _secondaryText(context));
    final name = Text(
      event.eventName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: _borderColor(context).withValues(alpha: 0.6),
          ),
        ),
      ),
      child: Row(
        children: [
          if (wide) ...[
            Expanded(flex: 4, child: name),
            Expanded(
              flex: 2,
              child: Text(
                _shortDateFormat.format(event.date),
                style: secondary,
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: ShiftBadge(shift: event.shift),
              ),
            ),
          ] else
            Expanded(
              flex: 5,
              child: Column(
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
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _AmountCell(
                entry: entry,
                onEdit: () => onSetAmount(entry),
              ),
            ),
          ),
          Expanded(flex: 3, child: _StatusChip(paid: entry.isPaid)),
          _ActionButton(
            entry: entry,
            onMarkPaid: onMarkPaid,
            onView: onView,
            onSetAmount: onSetAmount,
          ),
        ],
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

class _ViewPaymentDialog extends StatelessWidget {
  final PayoutEntry entry;
  const _ViewPaymentDialog({required this.entry});

  @override
  Widget build(BuildContext context) {
    final payout = entry.payout;
    final paidAt = payout?.paidAt;
    final note = payout?.note ?? '';
    return AlertDialog(
      title: const Text('Payment Details'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DetailLine('Member', entry.memberName),
          _DetailLine('Event', entry.event.eventName),
          _DetailLine('Date', _eventLine(entry.event)),
          if (entry.amount == null)
            const _DetailLine('Amount paid', 'Not recorded')
          else
            ..._amountLines(entry, totalLabel: 'Amount paid'),
          _DetailLine(
            'Status',
            entry.status.label,
            valueColor: entry.isPaid ? AppColors.success : AppColors.danger,
          ),
          _DetailLine(
            'Paid on',
            paidAt == null ? 'Not recorded' : _paidAtFormat.format(paidAt),
          ),
          _DetailLine('Notes', note.isEmpty ? 'None' : note),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

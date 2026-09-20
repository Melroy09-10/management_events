import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/event_booking.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/payment_chips.dart';

enum _CopyFilter { all, copied, notCopied }

extension on _CopyFilter {
  String get label => switch (this) {
    _CopyFilter.all => 'All',
    _CopyFilter.copied => 'Copied',
    _CopyFilter.notCopied => 'Not Copied',
  };

  bool matches(EventBooking event) => switch (this) {
    _CopyFilter.all => true,
    _CopyFilter.copied => event.copied,
    _CopyFilter.notCopied => !event.copied,
  };
}

/// Events that have been completed and are awaiting payment collection,
/// grouped by the person who called. Tapping Done settles the payment and
/// moves the event into History.
class PendingPaymentsScreen extends StatefulWidget {
  const PendingPaymentsScreen({super.key});

  @override
  State<PendingPaymentsScreen> createState() => _PendingPaymentsScreenState();
}

class _PendingPaymentsScreenState extends State<PendingPaymentsScreen> {
  _CopyFilter _filter = _CopyFilter.all;

  // The most recent batch of events copied together via "Select Events" —
  // shown as one group with a single Done button, so the whole batch can be
  // marked paid together instead of one by one. Not set when "All Events"
  // is copied instead.
  List<EventBooking>? _copiedGroup;

  // Created once and reused across rebuilds. Calling dataService
  // .pendingPayments() again inside build() would hand StreamBuilder a
  // brand-new Firestore listener on every setState (e.g. right after a
  // copy), which tears down the old subscription and resets the screen to
  // loading/empty until the new one catches up.
  late final Stream<List<EventBooking>> _pendingPaymentsStream;

  @override
  void initState() {
    super.initState();
    _pendingPaymentsStream = context.read<DataService>().pendingPayments();
  }

  Future<void> _markCopied(Iterable<String> ids, DataService dataService) {
    return dataService.updateEventsCopied(ids, true);
  }

  Future<void> _unmarkCopied(Iterable<String> ids, DataService dataService) {
    return dataService.updateEventsCopied(ids, false);
  }

  void _setCopiedGroup(List<EventBooking> group) {
    setState(() => _copiedGroup = group);
  }

  void _clearCopiedGroup() => setState(() => _copiedGroup = null);

  Future<void> _doneGroup(
    BuildContext context,
    DataService dataService,
    List<EventBooking> group,
  ) async {
    final n = group.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Mark $n copied ${n == 1 ? 'event' : 'events'} as paid?'),
        content: Text(
          'This will mark $n ${n == 1 ? 'event' : 'events'} as paid and '
          'move ${n == 1 ? 'it' : 'them'} to History.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await dataService.markBookingsPaid(group.map((e) => e.id));
    _clearCopiedGroup();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$n ${n == 1 ? 'event' : 'events'} marked as paid — moved to '
            'History',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataService = context.read<DataService>();

    return StreamBuilder<List<EventBooking>>(
      stream: _pendingPaymentsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Pending Payments')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Pending Payments')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load pending payments:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            ),
          );
        }

        final events = snapshot.data ?? const <EventBooking>[];
        if (events.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Pending Payments')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.payments_outlined,
                      size: 56,
                      color: AppColors.textSecondaryLight,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No pending payments',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final filtered = events.where(_filter.matches).toList();
        final grandTotal = filtered.fold<double>(
          0,
          (sum, e) => sum + e.amount + e.tips,
        );
        final personNames = <String>{
          for (final e in filtered) e.personName,
        }.toList()..sort();
        final grouped = <String, List<EventBooking>>{
          for (final name in personNames)
            name: filtered.where((e) => e.personName == name).toList()
              ..sort((a, b) => a.date.compareTo(b.date)),
        };

        // Keep the tracked group in sync with live data (an event marked
        // paid/deleted elsewhere drops out on its own).
        final copiedGroupLive = _copiedGroup == null
            ? const <EventBooking>[]
            : events
                  .where((e) => _copiedGroup!.any((g) => g.id == e.id))
                  .toList();

        return Scaffold(
          appBar: AppBar(title: const Text('Pending Payments')),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _FilterBar(
                  filter: _filter,
                  onChanged: (f) => setState(() => _filter = f),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No ${_filter.label.toLowerCase()} events',
                          style: const TextStyle(
                            color: AppColors.textSecondaryLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : ListView(
                        // Every item below carries a stable key (person name
                        // / event id) rather than relying on list position,
                        // so Flutter can't confuse one card's element/render
                        // tree for another's when the list reshuffles right
                        // after a copy or a Done action.
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        children: [
                          _GrandTotalCard(
                            key: const ValueKey('grand-total'),
                            total: grandTotal,
                            eventCount: filtered.length,
                            personCount: personNames.length,
                          ),
                          for (final name in personNames)
                            Padding(
                              key: ValueKey('person-group-$name'),
                              padding: const EdgeInsets.only(top: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _PersonHeader(
                                    name: name,
                                    events: grouped[name]!,
                                    onCopied: (ids) =>
                                        _markCopied(ids, dataService),
                                    onUndoCopied: (ids) =>
                                        _unmarkCopied(ids, dataService),
                                    onGroupCopied: _setCopiedGroup,
                                  ),
                                  const SizedBox(height: 12),
                                  for (final event in grouped[name]!)
                                    Padding(
                                      key: ValueKey('event-${event.id}'),
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: _PendingPaymentCard(
                                        event: event,
                                        dataService: dataService,
                                        copied: event.copied,
                                        onUndoCopied: () => _unmarkCopied([
                                          event.id,
                                        ], dataService),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
          bottomNavigationBar: copiedGroupLive.isEmpty
              ? null
              : _CopiedGroupBar(
                  count: copiedGroupLive.length,
                  total: copiedGroupLive.fold<double>(
                    0,
                    (sum, e) => sum + e.amount + e.tips,
                  ),
                  onClear: _clearCopiedGroup,
                  onDone: () =>
                      _doneGroup(context, dataService, copiedGroupLive),
                ),
        );
      },
    );
  }
}

class _FilterBar extends StatelessWidget {
  final _CopyFilter filter;
  final ValueChanged<_CopyFilter> onChanged;
  const _FilterBar({required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<_CopyFilter>(
        showSelectedIcon: false,
        segments: [
          for (final f in _CopyFilter.values)
            ButtonSegment(value: f, label: Text(f.label)),
        ],
        selected: {filter},
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}

/// Sticky bar shown while a batch of events copied together via "Select
/// Events" is still pending — offers one confirmed Done button for the
/// whole group instead of marking each event individually.
class _CopiedGroupBar extends StatelessWidget {
  final int count;
  final double total;
  final VoidCallback onClear;
  final VoidCallback onDone;
  const _CopiedGroupBar({
    required this.count,
    required this.total,
    required this.onClear,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: paymentOrangeDark,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: paymentOrangeDark.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$count copied ${count == 1 ? 'event' : 'events'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      formatCurrency(total),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onClear,
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                child: const Text('Clear'),
              ),
              const SizedBox(width: 4),
              ElevatedButton.icon(
                onPressed: onDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: doneGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text(
                  'Done',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GrandTotalCard extends StatelessWidget {
  final double total;
  final int eventCount;
  final int personCount;
  const _GrandTotalCard({
    super.key,
    required this.total,
    required this.eventCount,
    required this.personCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [paymentOrange, paymentOrangeDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: paymentOrangeDark.withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Grand Total Pending',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  formatCurrency(total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 30,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$eventCount events',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$personCount ${personCount == 1 ? 'person' : 'persons'}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PersonHeader extends StatelessWidget {
  final String name;
  final List<EventBooking> events;
  final Future<void> Function(Iterable<String> ids) onCopied;
  final Future<void> Function(Iterable<String> ids) onUndoCopied;
  final ValueChanged<List<EventBooking>> onGroupCopied;
  const _PersonHeader({
    required this.name,
    required this.events,
    required this.onCopied,
    required this.onUndoCopied,
    required this.onGroupCopied,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: paymentOrange.withValues(alpha: 0.16),
            child: Text(
              initial,
              style: TextStyle(
                color: paymentOrangeDark,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${events.length} pending payment${events.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: AppColors.textSecondaryLight,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_all_outlined),
            color: paymentOrange,
            onPressed: () => _copySummary(context, name, events),
          ),
        ],
      ),
    );
  }

  Future<void> _copySummary(
    BuildContext context,
    String name,
    List<EventBooking> events,
  ) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Copy Payments'),
        content: const Text(
          'Copy every pending payment for this person, or pick specific events?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('select'),
            child: const Text('Select Events'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop('all'),
            child: const Text('All Events'),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;

    List<EventBooking> chosen;
    var isSelection = false;
    if (choice == 'all') {
      chosen = events;
    } else {
      final picked = await _pickEvents(context, events);
      if (picked == null || picked.isEmpty || !context.mounted) return;
      chosen = picked;
      isSelection = true;
    }
    chosen = [...chosen]..sort((a, b) => a.date.compareTo(b.date));

    await Clipboard.setData(ClipboardData(text: _buildSummary(name, chosen)));
    if (!context.mounted) return;
    final copiedIds = chosen.map((e) => e.id).toList();

    // Only a specifically selected batch becomes a trackable group with its
    // own single Done button — "Copy All" behaves as before.
    if (isSelection) onGroupCopied(chosen);

    // Give feedback immediately — the clipboard copy already happened, so
    // the user shouldn't wait on a network write to know it worked. The
    // "copied" flag is persisted in the background below; a slow or failed
    // write must not make the whole action look stuck.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Payment summary copied'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () => onUndoCopied(copiedIds),
        ),
      ),
    );

    unawaited(
      onCopied(copiedIds).catchError((Object e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save copied status: $e')),
          );
        }
      }),
    );
  }

  Future<List<EventBooking>?> _pickEvents(
    BuildContext context,
    List<EventBooking> events,
  ) {
    final selected = <EventBooking>{};
    return showDialog<List<EventBooking>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Select Events'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: events.map((e) {
                return CheckboxListTile(
                  value: selected.contains(e),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(e.eventName),
                  subtitle: Text(
                    '${formatEventDate(e.date)} · ${e.shift.label}',
                  ),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        selected.add(e);
                      } else {
                        selected.remove(e);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.of(dialogContext).pop(selected.toList()),
              child: const Text('Copy'),
            ),
          ],
        ),
      ),
    );
  }

  String _buildSummary(String name, List<EventBooking> events) {
    final buffer = StringBuffer('$name Pending Payments\n\n');
    var grandTotal = 0.0;
    for (final e in events) {
      final shiftEmoji = e.shift == Shift.day ? '☀️' : '🌙';
      final total = e.amount + e.tips;
      grandTotal += total;
      buffer.writeln('🍽️ ${e.eventName}');
      buffer.writeln('📅 ${formatEventDate(e.date)}');
      buffer.writeln('$shiftEmoji ${e.shift.label}');
      buffer.writeln('💰 Amount : ${formatCurrency(e.amount)}');
      buffer.writeln('🎁 Tips : ${formatCurrency(e.tips)}');
      buffer.writeln('🧾 Total : ${formatCurrency(total)}');
      buffer.writeln();
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('💵 Grand Total : ${formatCurrency(grandTotal)}');
    return buffer.toString().trimRight();
  }
}

class _PendingPaymentCard extends StatelessWidget {
  final EventBooking event;
  final DataService dataService;
  final bool copied;
  final Future<void> Function()? onUndoCopied;
  const _PendingPaymentCard({
    required this.event,
    required this.dataService,
    this.copied = false,
    this.onUndoCopied,
  });

  void _undo(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Marked as not copied')),
    );
    unawaited(
      onUndoCopied?.call().catchError((Object e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not update: $e')),
          );
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: copied ? doneGreen.withValues(alpha: 0.16) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: copied ? doneGreen : Colors.black12.withValues(alpha: 0.05),
          width: copied ? 1.8 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  event.eventName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
              ),
              if (copied) ...[
                Tooltip(
                  message: 'Tap to undo',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _undo(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: doneGreen,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Copied',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                            ),
                          ),
                          SizedBox(width: 3),
                          Icon(
                            Icons.undo_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              ShiftBadge(shift: event.shift),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 15,
                color: AppColors.textSecondaryLight,
              ),
              const SizedBox(width: 6),
              Text(
                formatEventDate(event.date),
                style: const TextStyle(
                  color: AppColors.textSecondaryLight,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 16),
              const Icon(
                Icons.location_on_outlined,
                size: 15,
                color: AppColors.textSecondaryLight,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  event.location,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondaryLight,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: EditableAmountChip(
                  label: 'Amount',
                  value: event.amount,
                  background: amountChipBg,
                  valueColor: AppColors.textPrimaryLight,
                  onDoubleTap: () => _editAmount(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: EditableAmountChip(
                  label: 'Tips',
                  value: event.tips,
                  background: tipsChipBg,
                  valueColor: tipsChipText,
                  onDoubleTap: () => _editTips(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: TotalChip(value: event.amount + event.tips)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _markPaid(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: doneGreen,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded, color: Colors.white),
                    label: const Text(
                      'Done',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 52,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => _editTips(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: paymentOrange,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 52,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => _delete(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: deleteChipBg,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Icon(Icons.close_rounded, color: deleteChipIcon),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editAmount(BuildContext context) async {
    final value = await promptForAmount(
      context,
      title: 'Amount',
      initial: event.amount,
    );
    if (value != null) await dataService.updateEventAmount(event.id, value);
  }

  Future<void> _editTips(BuildContext context) async {
    final value = await promptForAmount(
      context,
      title: 'Tips',
      initial: event.tips,
    );
    if (value != null) await dataService.updateEventTips(event.id, value);
  }

  Future<void> _markPaid(BuildContext context) async {
    await dataService.markBookingPaid(event.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marked as paid — moved to History')),
      );
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await confirmDelete(context);
    if (!confirmed || !context.mounted) return;
    await dataService.deleteEventBooking(event.id);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Event deleted')));
    }
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/event_booking.dart';
import '../services/data_service.dart';
import '../utils/currency.dart';
import '../widgets/app_drawer.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/history_widgets.dart' show HistoryEmptyState;
import '../widgets/payment_chips.dart';
import '../widgets/pending_payment_widgets.dart';

/// Shows [message] (with an optional [subtitle] line) as a plain, non-
/// interactive floating toast centered on screen — no buttons, no tap
/// actions — auto-dismissing after 3 seconds.
void _showCenteredToast(
  BuildContext context,
  String message, {
  String? subtitle,
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (context) => Positioned(
      left: 24,
      right: 24,
      top: MediaQuery.of(context).size.height / 2 - 28,
      child: IgnorePointer(
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xE6323232),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  Future.delayed(const Duration(seconds: 3), () {
    if (entry.mounted) entry.remove();
  });
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
  // Search (event / person / location / type) and single-date filter —
  // both applied on the client to the already-loaded list.
  bool _searching = false;
  final _searchController = TextEditingController();
  String _query = '';
  DateTime? _dateFilter;

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DataService get _dataService => context.read<DataService>();

  Future<void> _markCopied(Iterable<String> ids) {
    return _dataService.updateEventsCopied(ids, true);
  }

  Future<void> _unmarkCopied(Iterable<String> ids) {
    return _dataService.updateEventsCopied(ids, false);
  }

  bool _matchesSearch(EventBooking e) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return e.eventName.toLowerCase().contains(q) ||
        e.personName.toLowerCase().contains(q) ||
        e.location.toLowerCase().contains(q) ||
        e.eventType.toLowerCase().contains(q);
  }

  bool _matchesDate(EventBooking e) =>
      _dateFilter == null || DateUtils.isSameDay(e.date, _dateFilter);

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _searchController.clear();
        _query = '';
      }
    });
  }

  Future<void> _pickDate(List<EventBooking> events) async {
    final now = DateTime.now();
    final dates = events.map((e) => e.date).toList()..sort();
    final first = dates.isEmpty ? DateTime(now.year - 1) : dates.first;
    final last = dates.isEmpty ? now : dates.last;
    final initial = _dateFilter ?? (last.isBefore(now) ? last : now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first)
          ? first
          : (initial.isAfter(last) ? last : initial),
      firstDate: DateTime(first.year, first.month, first.day),
      lastDate: DateTime(last.year, last.month, last.day),
      helpText: 'Show pending payments for',
    );
    if (picked == null || !mounted) return;
    setState(() => _dateFilter = DateUtils.dateOnly(picked));
  }

  Scaffold _scaffold({required Widget body, List<EventBooking>? events}) {
    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: PayColors.background,
      appBar: AppBar(
        title: const Text('Pending Payments'),
        actions: events == null
            ? null
            : [
                PaymentHeaderButton(
                  icon: _searching ? Icons.close_rounded : Icons.search_rounded,
                  tooltip: _searching ? 'Close search' : 'Search',
                  active: _searching,
                  onPressed: _toggleSearch,
                ),
                const SizedBox(width: 8),
                PaymentHeaderButton(
                  icon: Icons.calendar_month_rounded,
                  tooltip: 'Filter by date',
                  active: _dateFilter != null,
                  onPressed: () => _pickDate(events),
                ),
                const SizedBox(width: 12),
              ],
      ),
      body: body,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EventBooking>>(
      stream: _pendingPaymentsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _scaffold(
            body: const Center(
              child: CircularProgressIndicator(color: PayColors.navy),
            ),
          );
        }
        if (snapshot.hasError) {
          return _scaffold(
            body: Center(
              child: HistoryEmptyState(
                icon: Icons.error_outline_rounded,
                accent: PayColors.danger,
                title: 'Could not load pending payments',
                message: '${snapshot.error}',
              ),
            ),
          );
        }

        final events = snapshot.data ?? const <EventBooking>[];
        if (events.isEmpty) {
          return _scaffold(
            body: const Center(
              child: HistoryEmptyState(
                icon: Icons.payments_outlined,
                title: 'No pending payments',
                message:
                    'Events you mark as Done will wait here until '
                    'they are paid.',
              ),
            ),
          );
        }

        final filtered =
            events.where((e) => _matchesSearch(e) && _matchesDate(e)).toList()
              ..sort(newestFirst);
        final grandTotal = filtered.fold<double>(
          0,
          (sum, e) => sum + e.amount + e.tips,
        );
        // Newest events on top: within each person, and the person whose
        // latest event is newest comes first. [filtered] is already
        // newest-first, so a person's first appearance is their latest event.
        // (A set literal keeps first-insertion order.)
        final personNames = <String>{
          for (final e in filtered) e.personName,
        }.toList();
        final grouped = <String, List<EventBooking>>{
          for (final name in personNames)
            name: filtered.where((e) => e.personName == name).toList(),
        };

        return _scaffold(
          events: events,
          body: SafeArea(
            top: false,
            child: ListView(
              // Every item below carries a stable key (person name / event
              // id) rather than relying on list position, so Flutter can't
              // confuse one card's element/render tree for another's when
              // the list reshuffles right after a copy or a Done action.
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                if (_searching)
                  Padding(
                    key: const ValueKey('search'),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search event, person or place',
                        prefixIcon: const Icon(Icons.search_rounded),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: PayColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: PayColors.border),
                        ),
                      ),
                      onChanged: (value) =>
                          setState(() => _query = value.trim()),
                    ),
                  ),
                if (_dateFilter != null)
                  Padding(
                    key: const ValueKey('date-chip'),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: InputChip(
                        avatar: const Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                          color: PayColors.navy,
                        ),
                        label: Text(formatEventDate(_dateFilter!)),
                        labelStyle: const TextStyle(
                          color: PayColors.navy,
                          fontWeight: FontWeight.w700,
                        ),
                        backgroundColor: PayColors.card,
                        side: const BorderSide(color: PayColors.border),
                        onDeleted: () => setState(() => _dateFilter = null),
                      ),
                    ),
                  ),
                const SizedBox(key: ValueKey('gap-summary'), height: 8),
                PaymentSummaryCard(
                  key: const ValueKey('grand-total'),
                  total: grandTotal,
                  eventCount: filtered.length,
                  personCount: personNames.length,
                ),
                if (filtered.isEmpty)
                  Padding(
                    key: const ValueKey('no-match'),
                    padding: const EdgeInsets.only(top: 40),
                    child: Text(
                      'No pending payments match your search.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: PayColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                for (final name in personNames)
                  Padding(
                    key: ValueKey('person-group-$name'),
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PaymentPersonHeader(
                          name: name,
                          count: grouped[name]!.length,
                          onCopy: () => _copySummary(name, grouped[name]!),
                        ),
                        for (final event in grouped[name]!)
                          Padding(
                            key: ValueKey('event-${event.id}'),
                            padding: const EdgeInsets.only(top: 10),
                            child: PaymentEventCard(
                              event: event,
                              onDone: () => _markPaid(event),
                              onAddTip: () => _editTips(event),
                              onDelete: () => _delete(event),
                              onEditAmount: () => _editAmount(event),
                              onEditTips: () => _editTips(event),
                              onUndoCopied: () => _undoCopied(event),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Copy ---

  Future<void> _copySummary(String name, List<EventBooking> events) async {
    final choice = await showCopyPaymentsDialog(context);
    if (choice == null || !mounted) return;

    List<EventBooking> chosen;
    List<EventBooking> toUnmark = const [];
    if (choice == CopyChoice.all) {
      chosen = events;
    } else {
      final picked = await showSelectEventsDialog(context, events);
      if (picked == null || !mounted) return;
      if (picked.markPaid) {
        await _markSelectedPaid(picked.toCopy);
        return;
      }
      if (picked.toCopy.isEmpty && picked.toUnmark.isEmpty) return;
      chosen = picked.toCopy;
      toUnmark = picked.toUnmark;
    }

    if (toUnmark.isNotEmpty) {
      unawaited(
        _unmarkCopied(toUnmark.map((e) => e.id)).catchError((Object e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not update copied status: $e')),
            );
          }
        }),
      );
    }

    if (chosen.isEmpty) {
      // The user only unticked previously-copied events — nothing to copy.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Marked ${toUnmark.length} ${toUnmark.length == 1 ? 'event' : 'events'} as not copied',
            ),
          ),
        );
      }
      return;
    }

    chosen = [...chosen]..sort(newestFirst);

    await Clipboard.setData(ClipboardData(text: _buildSummary(name, chosen)));
    if (!mounted) return;
    final copiedIds = chosen.map((e) => e.id).toList();
    final total = chosen.fold<double>(0, (sum, e) => sum + e.amount + e.tips);

    // Give feedback immediately — the clipboard copy already happened, so
    // the user shouldn't wait on a network write to know it worked. The
    // "copied" flag is persisted in the background below; a slow or failed
    // write must not make the whole action look stuck.
    _showCenteredToast(
      context,
      'Payment summary copied',
      subtitle:
          '${chosen.length} ${chosen.length == 1 ? 'event' : 'events'} · ${formatCurrency(total)}',
    );

    unawaited(
      _markCopied(copiedIds).catchError((Object e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save copied status: $e')),
          );
        }
      }),
    );
  }

  /// Payment Done from the Select Events dialog: settles every selected
  /// event at once, moving them to History.
  Future<void> _markSelectedPaid(List<EventBooking> events) async {
    if (events.isEmpty) return;
    try {
      await _dataService.markBookingsPaid(events.map((e) => e.id));
      if (!mounted) return;
      final total = events.fold<double>(0, (sum, e) => sum + e.amount + e.tips);
      _showCenteredToast(
        context,
        'Payment done — moved to History',
        subtitle:
            '${events.length} ${events.length == 1 ? 'event' : 'events'} · ${formatCurrency(total)}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not mark as paid: $e')));
      }
    }
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

  // --- Per-event actions ---

  void _undoCopied(EventBooking event) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Marked as not copied')));
    unawaited(
      _unmarkCopied([event.id]).catchError((Object e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Could not update: $e')));
        }
      }),
    );
  }

  Future<void> _editAmount(EventBooking event) async {
    final value = await promptForAmount(
      context,
      title: 'Amount',
      initial: event.amount,
    );
    if (value != null) await _dataService.updateEventAmount(event.id, value);
  }

  Future<void> _editTips(EventBooking event) async {
    final value = await promptForAmount(
      context,
      title: 'Tips',
      initial: event.tips,
    );
    if (value != null) await _dataService.updateEventTips(event.id, value);
  }

  Future<void> _markPaid(EventBooking event) async {
    await _dataService.markBookingPaid(event.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marked as paid — moved to History')),
      );
    }
  }

  Future<void> _delete(EventBooking event) async {
    final confirmed = await confirmDelete(context);
    if (!confirmed || !mounted) return;
    await _dataService.deleteEventBooking(event.id);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Event deleted')));
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/event_booking.dart';
import '../services/data_service.dart';
import '../utils/currency.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/history_widgets.dart';
import '../widgets/searchable_dropdown_field.dart';

final _monthKeyFormat = DateFormat('yyyy-MM');
final _monthLabelFormat = DateFormat('MMM yyyy');

/// Events whose payment has been settled (marked Done from Pending
/// Payments). Each record can be restored to Pending Payments or deleted.
/// Filterable by month and event type, with a running Total Events / Total
/// Amount summary for the current filter.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _maxContentWidth = 760.0;

  String? _monthFilter;
  String? _eventTypeFilter;
  bool _showFilteredDetails = false;

  /// Ids of records currently animating out after a restore/delete.
  final Set<String> _leaving = {};

  // Created once so setState (filters, exit animations) doesn't hand
  // StreamBuilder a fresh Firestore listener and flash the loading state.
  late final Stream<List<EventBooking>> _historyStream;

  @override
  void initState() {
    super.initState();
    _historyStream = context.read<DataService>().history();
  }

  @override
  Widget build(BuildContext context) {
    final dataService = context.read<DataService>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: HistoryColors.ivory,
        body: StreamBuilder<List<EventBooking>>(
          stream: _historyStream,
          builder: (context, snapshot) => CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: HistoryHeader()),
              ..._buildBody(snapshot, dataService),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 24 + MediaQuery.paddingOf(context).bottom,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBody(
    AsyncSnapshot<List<EventBooking>> snapshot,
    DataService dataService,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: CircularProgressIndicator(color: HistoryColors.navy),
          ),
        ),
      ];
    }
    if (snapshot.hasError) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: HistoryEmptyState(
              icon: Icons.error_outline_rounded,
              accent: HistoryColors.danger,
              title: 'Could not load history',
              message: '${snapshot.error}',
            ),
          ),
        ),
      ];
    }

    final events = snapshot.data ?? const <EventBooking>[];
    if (events.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: HistoryEmptyState(
              icon: Icons.history_rounded,
              title: 'No completed payments yet',
              message:
                  'Events you mark as paid in Pending Payments will appear here.',
            ),
          ),
        ),
      ];
    }

    // Forget exit-animation ids once their records have left the stream, so
    // a record that is later paid again shows up normally.
    _leaving.removeWhere((id) => !events.any((e) => e.id == id));

    final months =
        events.map((e) => _monthKeyFormat.format(e.date)).toSet().toList()
          ..sort((a, b) => b.compareTo(a));
    final eventTypes = events.map((e) => e.eventType).toSet().toList()..sort();

    final filtered = events.where((e) {
      final matchesMonth =
          _monthFilter == null ||
          _monthKeyFormat.format(e.date) == _monthFilter;
      final matchesType =
          _eventTypeFilter == null || e.eventType == _eventTypeFilter;
      return matchesMonth && matchesType;
    }).toList();
    final totalAmount = filtered.fold<double>(
      0,
      (sum, e) => sum + e.amount + e.tips,
    );
    final hasFilter = _monthFilter != null || _eventTypeFilter != null;
    final showList =
        filtered.isNotEmpty && (!hasFilter || _showFilteredDetails);

    return [
      _boxed(
        HistoryAppear(
          child: Row(
            children: [
              Expanded(
                child: HistorySummaryCard(
                  icon: Icons.calendar_month_rounded,
                  label: 'Total Events',
                  value: '${filtered.length}',
                  background: HistoryColors.navy,
                  iconBackground: HistoryColors.navySoft,
                  foreground: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: HistorySummaryCard(
                  icon: Icons.currency_rupee_rounded,
                  label: 'Total Amount',
                  value: formatCurrency(totalAmount),
                  background: HistoryColors.gold,
                  iconBackground: HistoryColors.goldDeep.withValues(
                    alpha: 0.35,
                  ),
                  foreground: HistoryColors.navyDeep,
                ),
              ),
            ],
          ),
        ),
        top: 20,
      ),
      _boxed(
        HistoryFilterPanel(
          onClear: hasFilter
              ? () => setState(() {
                  _monthFilter = null;
                  _eventTypeFilter = null;
                  _showFilteredDetails = false;
                })
              : null,
          fields: [
            SearchableDropdownField<String?>(
              key: ValueKey('month-$_monthFilter'),
              value: _monthFilter,
              label: 'Month',
              icon: Icons.calendar_month_outlined,
              hintText: 'Search a month…',
              options: [
                const SearchableDropdownOption<String?>(
                  value: null,
                  label: 'All months',
                ),
                for (final month in months)
                  SearchableDropdownOption<String?>(
                    value: month,
                    label: _monthLabelFormat.format(
                      DateTime.parse('$month-01'),
                    ),
                  ),
              ],
              onSelected: (value) => setState(() {
                _monthFilter = value;
                _showFilteredDetails = false;
              }),
            ),
            SearchableDropdownField<String?>(
              key: ValueKey('type-$_eventTypeFilter'),
              value: _eventTypeFilter,
              label: 'Event Type',
              icon: Icons.event_outlined,
              hintText: 'Search an event type…',
              options: [
                const SearchableDropdownOption<String?>(
                  value: null,
                  label: 'All events',
                ),
                for (final type in eventTypes)
                  SearchableDropdownOption<String?>(value: type, label: type),
              ],
              onSelected: (value) => setState(() {
                _eventTypeFilter = value;
                _showFilteredDetails = false;
              }),
            ),
          ],
        ),
        top: 20,
      ),
      _boxed(
        SizedBox(
          height: 40,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Completed Events',
                  style: TextStyle(
                    color: HistoryColors.text,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (hasFilter && _showFilteredDetails && filtered.isNotEmpty)
                TextButton.icon(
                  onPressed: () => setState(() => _showFilteredDetails = false),
                  style: TextButton.styleFrom(
                    foregroundColor: HistoryColors.goldDeep,
                  ),
                  icon: const Icon(Icons.expand_less_rounded, size: 18),
                  label: const Text('Hide details'),
                ),
            ],
          ),
        ),
        top: 24,
      ),
      if (filtered.isEmpty)
        _boxed(
          const HistoryEmptyState(
            icon: Icons.search_off_rounded,
            title: 'No matching records',
            message:
                'No history matches these filters. Try another month '
                'or event type.',
          ),
        )
      else if (!showList)
        _boxed(
          HistoryAppear(
            child: HistoryFilteredSummary(
              filterLabel: _filterLabel(),
              count: filtered.length,
              totalAmount: totalAmount,
              onDoubleTap: () => setState(() => _showFilteredDetails = true),
            ),
          ),
          top: 8,
        )
      else
        SliverPadding(
          padding: const EdgeInsets.only(top: 8),
          sliver: SliverList.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final event = filtered[index];
              return _constrained(
                KeyedSubtree(
                  key: ValueKey('history-${event.id}'),
                  child: HistoryExit(
                    leaving: _leaving.contains(event.id),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: HistoryAppear(
                        index: index,
                        child: HistoryEventCard(
                          event: event,
                          onRestore: () => _restore(event, dataService),
                          onDelete: () => _delete(event, dataService),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
    ];
  }

  /// Wraps a non-sliver [child] with the page's horizontal margins and max
  /// content width.
  Widget _boxed(Widget child, {double top = 0}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.only(top: top),
        child: _constrained(child),
      ),
    );
  }

  Widget _constrained(Widget child) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: child,
        ),
      ),
    );
  }

  /// A human label for the currently active filter(s), e.g. "Sep 2026"
  /// or "Sep 2026 • Catering", shown on the filtered summary.
  String _filterLabel() {
    final monthLabel = _monthFilter == null
        ? null
        : _monthLabelFormat.format(DateTime.parse('$_monthFilter-01'));
    final parts = <String>[?monthLabel, ?_eventTypeFilter];
    return parts.join(' • ');
  }

  Future<void> _restore(EventBooking event, DataService dataService) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Move Back to Pending?'),
        content: Text(
          '"${event.eventName}" will be removed from History and shown again '
          'in Pending Payments.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Move Back'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _animateOutThen(
      event.id,
      () => dataService.markBookingUnpaid(event.id),
      successMessage: 'Moved back to Pending Payments',
    );
  }

  Future<void> _delete(EventBooking event, DataService dataService) async {
    final confirmed = await confirmDelete(context);
    if (!confirmed || !mounted) return;
    await _animateOutThen(
      event.id,
      () => dataService.deleteEventBooking(event.id),
      successMessage: 'Event deleted',
    );
  }

  /// Plays the card's exit animation, then runs [action]. If it fails the
  /// card is brought back and the error shown.
  Future<void> _animateOutThen(
    String id,
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    setState(() => _leaving.add(id));
    await Future<void>.delayed(HistoryExit.duration);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _leaving.remove(id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Something went wrong: $e')));
    }
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/event_booking.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/payment_chips.dart';
import '../widgets/responsive_center.dart';

final _monthKeyFormat = DateFormat('yyyy-MM');
final _monthLabelFormat = DateFormat('MMM yyyy');

/// Events whose payment has been settled (marked Done from Pending
/// Payments). Read-only besides Delete. Filterable by month and event type,
/// with a running Total Events / Total Amount summary for the current
/// filter.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String? _monthFilter;
  String? _eventTypeFilter;
  bool _showFilteredDetails = false;

  @override
  Widget build(BuildContext context) {
    final dataService = context.read<DataService>();

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: SafeArea(
        child: StreamBuilder<List<EventBooking>>(
          stream: dataService.history(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load history:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.danger),
                  ),
                ),
              );
            }

            final events = snapshot.data ?? const <EventBooking>[];
            if (events.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 56,
                        color: AppColors.textSecondaryLight,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No completed payments yet',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              );
            }

            final months =
                events
                    .map((e) => _monthKeyFormat.format(e.date))
                    .toSet()
                    .toList()
                  ..sort((a, b) => b.compareTo(a));
            final eventTypes = events.map((e) => e.eventType).toSet().toList()
              ..sort();

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

            return ResponsiveCenter(
              maxWidth: 760,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SummaryTile(
                            icon: Icons.event_note_rounded,
                            label: 'Total Events',
                            value: '${filtered.length}',
                            background: AppColors.primary,
                            foreground: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryTile(
                            icon: Icons.currency_rupee_rounded,
                            label: 'Total Amount',
                            value: formatCurrency(totalAmount),
                            background: AppColors.gold,
                            foreground: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.filter_alt_outlined,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Filters',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String?>(
                                  initialValue: _monthFilter,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Month',
                                    prefixIcon: Icon(
                                      Icons.calendar_month_outlined,
                                    ),
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text('All months'),
                                    ),
                                    for (final month in months)
                                      DropdownMenuItem(
                                        value: month,
                                        child: Text(
                                          _monthLabelFormat.format(
                                            DateTime.parse('$month-01'),
                                          ),
                                        ),
                                      ),
                                  ],
                                  onChanged: (value) => setState(() {
                                    _monthFilter = value;
                                    _showFilteredDetails = false;
                                  }),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String?>(
                                  initialValue: _eventTypeFilter,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Event Type',
                                    prefixIcon: Icon(Icons.category_outlined),
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text('All events'),
                                    ),
                                    for (final type in eventTypes)
                                      DropdownMenuItem(
                                        value: type,
                                        child: Text(type),
                                      ),
                                  ],
                                  onChanged: (value) => setState(() {
                                    _eventTypeFilter = value;
                                    _showFilteredDetails = false;
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'No history matches these filters.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textSecondaryLight,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                        : (hasFilter && !_showFilteredDetails)
                        ? Align(
                            alignment: Alignment.topCenter,
                            child: _ViewDetailsPrompt(
                              filterLabel: _filterLabel(),
                              count: filtered.length,
                              totalAmount: totalAmount,
                              onDoubleTap: () =>
                                  setState(() => _showFilteredDetails = true),
                            ),
                          )
                        : Column(
                            children: [
                              if (hasFilter)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    0,
                                    12,
                                    4,
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: () => setState(
                                        () => _showFilteredDetails = false,
                                      ),
                                      icon: const Icon(
                                        Icons.expand_less_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('Hide details'),
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    16,
                                  ),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) => _HistoryCard(
                                    event: filtered[index],
                                    dataService: dataService,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// A human label for the currently active filter(s), e.g. "September 2026"
  /// or "September 2026 • Catering", shown on the details prompt.
  String _filterLabel() {
    final monthLabel = _monthFilter == null
        ? null
        : _monthLabelFormat.format(DateTime.parse('$_monthFilter-01'));
    final parts = <String>[?monthLabel, ?_eventTypeFilter];
    return parts.join(' • ');
  }
}

/// Shown instead of the full record list while a filter is active — a
/// compact summary (what's filtered, how many events, total amount) with a
/// double-tap to reveal every matching record in full.
class _ViewDetailsPrompt extends StatelessWidget {
  final String filterLabel;
  final int count;
  final double totalAmount;
  final VoidCallback onDoubleTap;
  const _ViewDetailsPrompt({
    required this.filterLabel,
    required this.count,
    required this.totalAmount,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onDoubleTap: onDoubleTap,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryDark, AppColors.primary],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(17),
                      topRight: Radius.circular(17),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.receipt_long_outlined,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          filterLabel.isEmpty
                              ? 'Filtered results'
                              : filterLabel,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _MiniStat(
                              label: 'Total Events',
                              value: '$count',
                              valueColor: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            width: 1,
                            height: 34,
                            color: AppColors.border,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _MiniStat(
                              label: 'Total Amount',
                              value: formatCurrency(totalAmount),
                              valueColor: AppColors.goldDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Icon(
                            Icons.touch_app_outlined,
                            size: 14,
                            color: AppColors.goldDark,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Double-tap to view the full details',
                            style: TextStyle(
                              color: AppColors.textSecondaryLight,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondaryLight,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimaryLight,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color background;
  final Color foreground;
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: background.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: foreground.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: foreground, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground.withValues(alpha: 0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final EventBooking event;
  final DataService dataService;
  const _HistoryCard({required this.event, required this.dataService});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.eventName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      event.eventType,
                      style: TextStyle(
                        color: AppColors.textSecondaryLight,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              ShiftBadge(shift: event.shift),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 19),
                color: AppColors.danger,
                visualDensity: VisualDensity.compact,
                onPressed: () => _delete(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 15,
                color: AppColors.textSecondaryLight,
              ),
              const SizedBox(width: 6),
              Text(
                formatEventDate(event.date),
                style: TextStyle(
                  color: AppColors.textSecondaryLight,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.call_outlined,
                size: 15,
                color: AppColors.textSecondaryLight,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  event.personName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondaryLight,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 15,
                color: AppColors.textSecondaryLight,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  event.location,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
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
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: EditableAmountChip(
                  label: 'Tips',
                  value: event.tips,
                  background: tipsChipBg,
                  valueColor: tipsChipText,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: TotalChip(value: event.amount + event.tips)),
            ],
          ),
        ],
      ),
    );
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

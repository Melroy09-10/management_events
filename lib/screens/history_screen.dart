import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/event_booking.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/payment_chips.dart';

/// Events whose payment has been settled (marked Done from Pending
/// Payments). Read-only besides Delete.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

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
                      Icon(Icons.history_rounded, size: 56, color: AppColors.textSecondaryLight),
                      const SizedBox(height: 12),
                      Text(
                        'No completed payments yet',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _HistoryCard(event: events[index], dataService: dataService),
            );
          },
        ),
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
        border: Border.all(color: Colors.black12.withValues(alpha: 0.06)),
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
                    Text(event.eventName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 3),
                    Text(event.eventType, style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 12.5)),
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
              Icon(Icons.calendar_today_outlined, size: 15, color: AppColors.textSecondaryLight),
              const SizedBox(width: 6),
              Text(formatEventDate(event.date), style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13)),
              const SizedBox(width: 16),
              Icon(Icons.call_outlined, size: 15, color: AppColors.textSecondaryLight),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  event.personName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 15, color: AppColors.textSecondaryLight),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  event.location,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13),
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
                  valueColor: Colors.black87,
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event deleted')));
    }
  }
}

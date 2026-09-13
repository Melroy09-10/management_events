import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/event_booking.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/event_booking_card.dart';
import 'add_event_screen.dart';

/// All of the current user's events that haven't been marked Done yet
/// (any date). Tapping Done here moves an event to Pending Payments — same
/// card look and action as the Today's Events dashboard section.
class PendingEventsScreen extends StatelessWidget {
  const PendingEventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dataService = context.read<DataService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Pending Events')),
      body: SafeArea(
        child: StreamBuilder<List<EventBooking>>(
          stream: dataService.pendingEvents(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load pending events:\n${snapshot.error}',
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
                      Icon(Icons.event_available_rounded, size: 56, color: AppColors.textSecondaryLight),
                      const SizedBox(height: 12),
                      Text(
                        'No pending events',
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
              itemBuilder: (context, index) {
                final event = events[index];
                return EventBookingCard(
                  event: event,
                  showDate: true,
                  onDone: () async {
                    await dataService.markBookingDone(event.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Moved to Pending Payments')),
                      );
                    }
                  },
                  onEdit: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => AddEventScreen(existing: event)),
                    );
                  },
                  onDelete: () async {
                    final confirmed = await confirmDelete(context);
                    if (!confirmed || !context.mounted) return;
                    await dataService.deleteEventBooking(event.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event deleted')));
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

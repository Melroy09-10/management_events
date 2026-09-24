import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/event_booking.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/payment_chips.dart';
import 'add_member_screen.dart';

const _months = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];

/// Admin/Super Admin only: staffing events created from the Admin "Add
/// Event" sheet that haven't been marked Done yet — separate from the USER
/// section's Pending Events, which lists the admin's own bookings. Each card
/// shows just the name, shift, date and member staffing, with edit, delete
/// and assign actions.
class AdminPendingEventsScreen extends StatelessWidget {
  const AdminPendingEventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dataService = context.read<DataService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Pending Events')),
      body: SafeArea(
        child: StreamBuilder<List<EventBooking>>(
          stream: dataService.pendingStaffingEvents(),
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
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) => _StaffingEventCard(event: events[index]),
            );
          },
        ),
      ),
    );
  }
}

class _StaffingEventCard extends StatelessWidget {
  final EventBooking event;
  const _StaffingEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final assigned = event.assignedMembers.length;
    final required = event.requiredMembers;
    final isFull = assigned >= required;
    final progressColor = isFull ? AppColors.success : AppColors.gold;
    final accent = onSurfaceAccent(context, AppColors.primary);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _DateTile(date: event.date),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.eventName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    ShiftBadge(shift: event.shift),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _RoundIconButton(
                icon: Icons.edit_outlined,
                background: accent.withValues(alpha: 0.1),
                color: accent,
                onPressed: () => showEditStaffingEventSheet(context, event),
              ),
              const SizedBox(width: 8),
              _RoundIconButton(
                icon: Icons.delete_outline_rounded,
                background: deleteChipBg,
                color: deleteChipIcon,
                onPressed: () => _delete(context),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            decoration: BoxDecoration(
              color: progressColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.groups_rounded, size: 22, color: progressColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isFull ? 'Fully staffed' : '$assigned of $required members assigned',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          value: (assigned / required).clamp(0, 1).toDouble(),
                          minHeight: 6,
                          backgroundColor: Colors.black12.withValues(alpha: 0.06),
                          valueColor: AlwaysStoppedAnimation(progressColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (isFull)
                  Icon(Icons.check_circle_rounded, color: AppColors.success, size: 26)
                else
                  FilledButton.icon(
                    onPressed: () => showAddMembersSheet(context, event),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: const Text('Assign', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await confirmDelete(context);
    if (!confirmed || !context.mounted) return;
    await context.read<DataService>().deleteEventBooking(event.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event deleted')));
    }
  }
}

/// Calendar-style day/month block on the left of each card.
class _DateTile extends StatelessWidget {
  final DateTime date;
  const _DateTile({required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            _months[date.month - 1],
            style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.8),
          ),
          Text(
            '${date.day}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22, height: 1.1),
          ),
          Text(
            '${date.year}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 10.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color color;
  final VoidCallback onPressed;
  const _RoundIconButton({
    required this.icon,
    required this.background,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

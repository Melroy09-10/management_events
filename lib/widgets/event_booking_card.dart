import 'package:flutter/material.dart';

import '../models/event_booking.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Shared card look for a booked event, used by the Today's Events dashboard
/// section, Pending Events and Pending Payments so they all match exactly.
class EventBookingCard extends StatelessWidget {
  final EventBooking event;
  final bool showDate;
  final VoidCallback? onDone;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final ValueChanged<double>? onEditTips;

  const EventBookingCard({
    super.key,
    required this.event,
    this.showDate = false,
    this.onDone,
    this.onEdit,
    this.onDelete,
    this.onEditTips,
  });

  @override
  Widget build(BuildContext context) {
    final shiftColor = event.shift == Shift.day ? AppColors.warning : AppColors.accent;
    final shiftIcon = event.shift == Shift.day ? Icons.wb_sunny_rounded : Icons.nightlight_round;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              if (onEdit != null)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 19),
                  color: AppColors.textSecondaryLight,
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 19),
                  color: AppColors.danger,
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: shiftColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(shiftIcon, size: 14, color: shiftColor),
                    const SizedBox(width: 5),
                    Text(
                      event.shift.label,
                      style: TextStyle(color: shiftColor, fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (showDate) ...[
                const SizedBox(width: 10),
                Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.textSecondaryLight),
                const SizedBox(width: 4),
                Text(
                  _formatDate(event.date),
                  style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
              const Spacer(),
              Text(
                formatCurrency(event.amount),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16.5, color: AppColors.success),
              ),
            ],
          ),
          const Divider(height: 22),
          _InfoLine(icon: Icons.call_outlined, text: event.personName),
          const SizedBox(height: 6),
          _InfoLine(icon: Icons.location_on_outlined, text: event.location),
          if (onEditTips != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.volunteer_activism_outlined, size: 15, color: AppColors.gold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event.tips > 0 ? 'Tips: ${formatCurrency(event.tips)}' : 'No tips added',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: event.tips > 0 ? AppColors.gold : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _showTipsDialog(context),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.edit_outlined, size: 15, color: AppColors.textSecondaryLight),
                  ),
                ),
              ],
            ),
          ],
          if (onDone != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onDone,
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: const Text('Done'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.success,
                  side: BorderSide(color: AppColors.success.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')} ${_months[date.month - 1]} ${date.year}';
  }

  Future<void> _showTipsDialog(BuildContext context) async {
    final controller = TextEditingController(
      text: event.tips > 0 ? _trimTrailingZeros(event.tips) : '',
    );
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tips'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Tips amount', prefixIcon: Icon(Icons.currency_rupee_rounded)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(double.tryParse(controller.text.trim()) ?? 0),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) onEditTips!(result);
  }

  static String _trimTrailingZeros(double value) {
    return value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toString();
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondaryLight),
        const SizedBox(width: 8),
        Expanded(child: Text(text, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
      ],
    );
  }
}

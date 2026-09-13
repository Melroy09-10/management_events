import 'package:flutter/material.dart';

import '../models/event_booking.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';

// The payments flow (Dashboard, Pending Payments & History) shares the
// app's single Royal Navy + Champagne Gold design system — these names are
// kept as the shared vocabulary for that flow's cards/chips.
const paymentOrange = AppColors.primary;
const paymentOrangeDark = AppColors.primaryDark;
const amountChipBg = Color(0xFFEFF2F6);
const tipsChipBg = Color(0xFFE3F3EC);
const tipsChipText = AppColors.success;
const totalChipBg = AppColors.gold;
const shiftDayBg = Color(0xFFF6ECC9);
const shiftDayText = AppColors.goldDark;
const shiftNightBg = Color(0xFFE3E8F0);
const shiftNightText = AppColors.secondary;
const deleteChipBg = Color(0xFFF8E3E0);
const deleteChipIcon = AppColors.danger;
const doneGreen = AppColors.success;

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatEventDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')} ${_months[date.month - 1]} ${date.year}';
}

class ShiftBadge extends StatelessWidget {
  final Shift shift;
  const ShiftBadge({super.key, required this.shift});

  @override
  Widget build(BuildContext context) {
    final bg = shift == Shift.day ? shiftDayBg : shiftNightBg;
    final text = shift == Shift.day ? shiftDayText : shiftNightText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        shift.label,
        style: TextStyle(
          color: text,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
      ),
    );
  }
}

/// A colored Amount/Tips chip. Double-tap opens [onDoubleTap] to edit the
/// value; when null the chip is display-only (no "double-tap to edit" hint).
class EditableAmountChip extends StatelessWidget {
  final String label;
  final double value;
  final Color background;
  final Color valueColor;
  final VoidCallback? onDoubleTap;

  const EditableAmountChip({
    super.key,
    required this.label,
    required this.value,
    required this.background,
    required this.valueColor,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondaryLight,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatCurrency(value),
              style: TextStyle(
                color: valueColor,
                fontWeight: FontWeight.w800,
                fontSize: 15.5,
              ),
            ),
            if (onDoubleTap != null) ...[
              const SizedBox(height: 2),
              Text(
                'double-tap to edit',
                style: TextStyle(
                  color: AppColors.textSecondaryLight.withValues(alpha: 0.7),
                  fontSize: 8.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class TotalChip extends StatelessWidget {
  final double value;
  const TotalChip({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: totalChipBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Text(
            'Total',
            style: TextStyle(
              color: AppColors.primaryDark,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatCurrency(value),
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w800,
              fontSize: 15.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Prompts for a currency amount, prefilled with [initial]. Returns null if
/// cancelled.
Future<double?> promptForAmount(
  BuildContext context, {
  required String title,
  required double initial,
}) {
  final controller = TextEditingController(
    text: initial > 0 ? _trimTrailingZeros(initial) : '',
  );
  return showDialog<double>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Amount',
          prefixIcon: Icon(Icons.currency_rupee_rounded),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            dialogContext,
          ).pop(double.tryParse(controller.text.trim()) ?? 0),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

String _trimTrailingZeros(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
}

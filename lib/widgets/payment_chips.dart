import 'package:flutter/material.dart';

import '../models/event_booking.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';

// A distinct, vivid palette for the payments flow (Pending Payments &
// History) — deliberately separate from the app's main royal/gold theme.
const paymentOrange = Color(0xFFFF7A1A);
const paymentOrangeDark = Color(0xFFE0451A);
const amountChipBg = Color(0xFFFCE7C2);
const tipsChipBg = Color(0xFFDFF5E1);
const tipsChipText = Color(0xFF2E9E4F);
const totalChipBg = Color(0xFFFDB44B);
const shiftDayBg = Color(0xFFD7E9FB);
const shiftDayText = Color(0xFF2472C8);
const shiftNightBg = Color(0xFFE3D9F7);
const shiftNightText = Color(0xFF6C3FC5);
const deleteChipBg = Color(0xFFFAD6D6);
const deleteChipIcon = Color(0xFFE0453C);
const doneGreen = Color(0xFF2FAE4E);

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
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
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(shift.label, style: TextStyle(color: text, fontWeight: FontWeight.w700, fontSize: 12.5)),
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
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(formatCurrency(value), style: TextStyle(color: valueColor, fontWeight: FontWeight.w800, fontSize: 15.5)),
            if (onDoubleTap != null) ...[
              const SizedBox(height: 2),
              Text(
                'double-tap to edit',
                style: TextStyle(color: AppColors.textSecondaryLight.withValues(alpha: 0.7), fontSize: 8.5),
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
      decoration: BoxDecoration(color: totalChipBg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          const Text('Total', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(formatCurrency(value), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15.5)),
        ],
      ),
    );
  }
}

/// Prompts for a currency amount, prefilled with [initial]. Returns null if
/// cancelled.
Future<double?> promptForAmount(BuildContext context, {required String title, required double initial}) {
  final controller = TextEditingController(text: initial > 0 ? _trimTrailingZeros(initial) : '');
  return showDialog<double>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Amount', prefixIcon: Icon(Icons.currency_rupee_rounded)),
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
}

String _trimTrailingZeros(double value) {
  return value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toString();
}

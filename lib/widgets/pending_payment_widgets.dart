import 'package:flutter/material.dart';

import '../models/event_booking.dart';
import '../utils/currency.dart';
import 'payment_chips.dart';

/// The Pending Payments flow's design system: Royal Navy + the existing
/// Total gold on a warm off-white canvas. Amount / Tips / Total keep the
/// colors already used across the payments flow.
class PayColors {
  PayColors._();

  static const Color navy = Color(0xFF0B2545);
  static const Color navyDeep = Color(0xFF071A33);
  static const Color gold = totalChipBg;
  static const Color goldBright = Color(0xFFE2BE4E);
  static const Color goldLight = Color(0xFFF4E7B5);
  static const Color background = Color(0xFFFAF9F5);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE6E2D6);
  static const Color text = Color(0xFF12233A);
  static const Color textSecondary = Color(0xFF687386);
  static const Color amountBg = amountChipBg;
  static const Color tipsBg = tipsChipBg;
  static const Color tipsText = tipsChipText;
  static const Color green = doneGreen;
  static const Color danger = deleteChipIcon;
  static const Color dangerBg = deleteChipBg;
  static const Color selectedBg = Color(0xFFEEF3FA);
  static const Color dayBg = Color(0xFFF7EDCB);
  static const Color dayText = Color(0xFF9C7612);
  static const Color nightBg = Color(0xFFE2ECF8);
  static const Color nightText = Color(0xFF2F5A8A);

  static const double radius = 16;
}

// --- Small building blocks ---

/// Soft warm-yellow Day / light-blue Night badge.
class PaymentShiftBadge extends StatelessWidget {
  final Shift shift;
  final bool compact;
  const PaymentShiftBadge({
    super.key,
    required this.shift,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDay = shift == Shift.day;
    final fg = isDay ? PayColors.dayText : PayColors.nightText;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: isDay ? PayColors.dayBg : PayColors.nightBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round,
            size: compact ? 12 : 14,
            color: fg,
          ),
          const SizedBox(width: 4),
          Text(
            shift.label,
            style: TextStyle(
              color: fg,
              fontSize: compact ? 11 : 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// One Amount / Tips / Total box. With [onDoubleTap] it shows a small
/// "double-tap to edit" hint; [dense] is the smaller variant used inside the
/// Select Events dialog.
class PaymentAmountBox extends StatelessWidget {
  final String label;
  final double value;
  final Color background;
  final Color labelColor;
  final Color valueColor;
  final VoidCallback? onDoubleTap;
  final bool dense;

  const PaymentAmountBox({
    super.key,
    required this.label,
    required this.value,
    required this.background,
    this.labelColor = PayColors.textSecondary,
    this.valueColor = PayColors.text,
    this.onDoubleTap,
    this.dense = false,
  });

  /// The standard trio for [event]: Amount (neutral), Tips (green),
  /// Total (gold).
  static Widget row(
    EventBooking event, {
    VoidCallback? onEditAmount,
    VoidCallback? onEditTips,
    bool dense = false,
  }) {
    final gap = SizedBox(width: dense ? 6 : 8);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: PaymentAmountBox(
              label: 'Amount',
              value: event.amount,
              background: PayColors.amountBg,
              onDoubleTap: onEditAmount,
              dense: dense,
            ),
          ),
          gap,
          Expanded(
            child: PaymentAmountBox(
              label: 'Tips',
              value: event.tips,
              background: PayColors.tipsBg,
              valueColor: PayColors.tipsText,
              onDoubleTap: onEditTips,
              dense: dense,
            ),
          ),
          gap,
          Expanded(
            child: PaymentAmountBox(
              label: 'Total',
              value: event.amount + event.tips,
              background: PayColors.gold,
              labelColor: PayColors.navyDeep,
              valueColor: PayColors.navyDeep,
              dense: dense,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: dense ? 6 : 9, horizontal: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(dense ? 10 : 12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: labelColor,
                fontSize: dense ? 10 : 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: dense ? 1 : 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatCurrency(value),
                style: TextStyle(
                  color: valueColor,
                  fontSize: dense ? 13 : 15.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (onDoubleTap != null && !dense)
              Text(
                'double-tap to edit',
                maxLines: 1,
                style: TextStyle(
                  color: labelColor.withValues(alpha: 0.65),
                  fontSize: 8.5,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Rounded segmented control: selected segment is navy, the rest light.
class PaymentSegmentedControl<T> extends StatelessWidget {
  final List<(T, String)> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  const PaymentSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: PayColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PayColors.border),
      ),
      child: Row(
        children: [
          for (final (value, label) in segments)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == selected
                        ? PayColors.navy
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: value == selected
                          ? Colors.white
                          : PayColors.textSecondary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small square icon button used in the page header (Search, Calendar).
class PaymentHeaderButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onPressed;

  const PaymentHeaderButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? PayColors.navy : PayColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: active ? PayColors.navy : PayColors.border),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onPressed,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 20,
              color: active ? Colors.white : PayColors.navy,
            ),
          ),
        ),
      ),
    );
  }
}

// --- Page sections ---

/// Navy "Grand Total Pending" card: gold amount, event & person counts.
class PaymentSummaryCard extends StatelessWidget {
  final double total;
  final int eventCount;
  final int personCount;

  const PaymentSummaryCard({
    super.key,
    required this.total,
    required this.eventCount,
    required this.personCount,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [PayColors.navy, PayColors.navyDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: PayColors.navy.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -40,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: PayColors.gold.withValues(alpha: 0.18),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Grand Total Pending',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            formatCurrency(total),
                            style: const TextStyle(
                              color: PayColors.goldBright,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$eventCount ${eventCount == 1 ? 'event' : 'events'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$personCount ${personCount == 1 ? 'person' : 'persons'}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A person's group header: initial avatar, name, pending count, a Copy
/// button and an expand/collapse chevron (the whole row also toggles).
class PaymentPersonHeader extends StatelessWidget {
  final String name;
  final int count;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onCopy;

  const PaymentPersonHeader({
    super.key,
    required this.name,
    required this.count,
    required this.expanded,
    required this.onToggle,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final radius = BorderRadius.circular(PayColors.radius);
    return Material(
      color: PayColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: PayColors.border),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: PayColors.goldLight,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: PayColors.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PayColors.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 16.5,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '$count pending payment${count == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: PayColors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: PayColors.navy,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onCopy,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.copy_all_rounded,
                          size: 16,
                          color: PayColors.goldBright,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Copy',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: PayColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A pending-payment event: name + shift, date & location, the Amount /
/// Tips / Total boxes, and Done / + (add tip) / Delete. A copied event gets
/// a green tint and a "Copied" pill that undoes the copied mark on tap.
class PaymentEventCard extends StatelessWidget {
  final EventBooking event;
  final VoidCallback onDone;
  final VoidCallback onAddTip;
  final VoidCallback onDelete;
  final VoidCallback onEditAmount;
  final VoidCallback onEditTips;
  final VoidCallback onUndoCopied;

  const PaymentEventCard({
    super.key,
    required this.event,
    required this.onDone,
    required this.onAddTip,
    required this.onDelete,
    required this.onEditAmount,
    required this.onEditTips,
    required this.onUndoCopied,
  });

  static const _meta = TextStyle(color: PayColors.textSecondary, fontSize: 13);

  @override
  Widget build(BuildContext context) {
    final copied = event.copied;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: copied
            ? PayColors.green.withValues(alpha: 0.07)
            : PayColors.card,
        borderRadius: BorderRadius.circular(PayColors.radius),
        border: Border.all(
          color: copied ? PayColors.green : PayColors.border,
          width: copied ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  event.eventName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PayColors.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 16.5,
                    height: 1.25,
                  ),
                ),
              ),
              if (copied) ...[
                const SizedBox(width: 6),
                _CopiedPill(onTap: onUndoCopied),
              ],
              const SizedBox(width: 6),
              PaymentShiftBadge(shift: event.shift),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: PayColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(formatEventDate(event.date), style: _meta),
              const SizedBox(width: 12),
              const Icon(
                Icons.location_on_outlined,
                size: 15,
                color: PayColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  event.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _meta,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PaymentAmountBox.row(
            event,
            onEditAmount: onEditAmount,
            onEditTips: onEditTips,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: onDone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PayColors.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 19),
                    label: const Text(
                      'Done',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SquareAction(
                icon: Icons.add_rounded,
                tooltip: 'Add tip',
                color: Colors.white,
                background: PayColors.navy,
                onTap: onAddTip,
              ),
              const SizedBox(width: 8),
              _SquareAction(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Delete',
                color: PayColors.danger,
                background: PayColors.dangerBg,
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CopiedPill extends StatelessWidget {
  final VoidCallback onTap;
  const _CopiedPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Tap to undo',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: PayColors.green,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, size: 12, color: Colors.white),
              SizedBox(width: 4),
              Text(
                'Copied',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              SizedBox(width: 3),
              Icon(Icons.undo_rounded, size: 11, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _SquareAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  const _SquareAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 44,
            child: Icon(icon, color: color, size: 21),
          ),
        ),
      ),
    );
  }
}

// --- Copy Payments dialog ---

enum CopyChoice { all, select }

/// Custom "Copy Payments" modal: All Events (primary) or Select Events.
Future<CopyChoice?> showCopyPaymentsDialog(BuildContext context) {
  return showDialog<CopyChoice>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: PayColors.card,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 28),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: PayColors.goldLight,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              color: PayColors.navy,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Copy Payments',
                                  style: TextStyle(
                                    color: PayColors.text,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Copy every pending payment for this '
                                  'person, or pick specific events?',
                                  style: TextStyle(
                                    color: PayColors.textSecondary,
                                    fontSize: 13,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    CopyOptionTile(
                      icon: Icons.copy_all_rounded,
                      title: 'All Events',
                      subtitle: 'Copy all pending payments for this person',
                      primary: true,
                      onTap: () =>
                          Navigator.of(dialogContext).pop(CopyChoice.all),
                    ),
                    const SizedBox(height: 10),
                    CopyOptionTile(
                      icon: Icons.checklist_rounded,
                      title: 'Select Events',
                      subtitle: 'Choose specific events to copy',
                      onTap: () =>
                          Navigator.of(dialogContext).pop(CopyChoice.select),
                    ),
                    const SizedBox(height: 14),
                    PaymentCancelButton(
                      onTap: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded),
                  color: PayColors.textSecondary,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A tappable option row in the Copy Payments dialog. [primary] renders it
/// navy; otherwise white with a thin border.
class CopyOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool primary;
  final VoidCallback onTap;

  const CopyOptionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(PayColors.radius);
    return Material(
      color: primary ? PayColors.navy : PayColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: primary ? PayColors.navy : PayColors.border),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: primary
                      ? Colors.white.withValues(alpha: 0.12)
                      : PayColors.navy.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 21,
                  color: primary ? PayColors.goldBright : PayColors.navy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: primary ? Colors.white : PayColors.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: primary
                            ? Colors.white.withValues(alpha: 0.75)
                            : PayColors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: primary ? PayColors.goldBright : PayColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width soft-red Cancel button used at the bottom of the dialogs.
class PaymentCancelButton extends StatelessWidget {
  final VoidCallback onTap;
  const PaymentCancelButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return Material(
      color: PayColors.dangerBg,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: const SizedBox(
          height: 46,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.close_rounded, size: 19, color: PayColors.danger),
              SizedBox(width: 6),
              Text(
                'Cancel',
                style: TextStyle(
                  color: PayColors.danger,
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Select Events dialog ---

/// Result of the Select Events dialog: events to copy (and mark copied),
/// and previously-copied events the user unticked (to unmark instead).
class EventSelectionResult {
  final List<EventBooking> toCopy;
  final List<EventBooking> toUnmark;
  const EventSelectionResult({required this.toCopy, required this.toUnmark});
}

/// Custom Select Events modal. Events already marked copied start ticked;
/// unticking one and confirming unmarks it instead of copying.
Future<EventSelectionResult?> showSelectEventsDialog(
  BuildContext context,
  List<EventBooking> events,
) {
  return showDialog<EventSelectionResult>(
    context: context,
    builder: (_) => _SelectEventsDialog(events: events),
  );
}

class _SelectEventsDialog extends StatefulWidget {
  final List<EventBooking> events;
  const _SelectEventsDialog({required this.events});

  @override
  State<_SelectEventsDialog> createState() => _SelectEventsDialogState();
}

class _SelectEventsDialogState extends State<_SelectEventsDialog> {
  late final Set<String> _selectedIds = {
    for (final e in widget.events)
      if (e.copied) e.id,
  };

  void _toggle(EventBooking event) {
    setState(() {
      if (!_selectedIds.remove(event.id)) _selectedIds.add(event.id);
    });
  }

  void _toggleAll() {
    setState(() {
      if (_selectedIds.length == widget.events.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(widget.events.map((e) => e.id));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final events = widget.events;
    final selected = events.where((e) => _selectedIds.contains(e.id)).toList();
    final toUnmark = events
        .where((e) => e.copied && !_selectedIds.contains(e.id))
        .toList();
    final selectedTotal = selected.fold<double>(
      0,
      (sum, e) => sum + e.amount + e.tips,
    );
    final canConfirm = selected.isNotEmpty || toUnmark.isNotEmpty;
    final allSelected = selected.length == events.length;
    final noneSelected = selected.isEmpty;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Dialog(
      backgroundColor: PayColors.card,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: screenHeight * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 8, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Events',
                          style: TextStyle(
                            color: PayColors.text,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Choose the events you want to copy',
                          style: TextStyle(
                            color: PayColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded),
                    color: PayColors.textSecondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Material(
                color: PayColors.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: PayColors.border),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _toggleAll,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        _CheckMark(
                          state: allSelected
                              ? true
                              : (noneSelected ? false : null),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Select All',
                            style: TextStyle(
                              color: PayColors.text,
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                            ),
                          ),
                        ),
                        Text(
                          '${events.length} ${events.length == 1 ? 'event' : 'events'}',
                          style: const TextStyle(
                            color: PayColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                itemCount: events.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final event = events[index];
                  return SelectableEventTile(
                    key: ValueKey('select-${event.id}'),
                    event: event,
                    selected: _selectedIds.contains(event.id),
                    onTap: () => _toggle(event),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: _SelectionSummary(
                count: selected.length,
                total: selectedTotal,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: PayColors.danger,
                          backgroundColor: PayColors.dangerBg,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 46,
                      child: FilledButton.icon(
                        onPressed: canConfirm
                            ? () => Navigator.of(context).pop(
                                EventSelectionResult(
                                  toCopy: selected,
                                  toUnmark: toUnmark,
                                ),
                              )
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: PayColors.navy,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: PayColors.navy.withValues(
                            alpha: 0.18,
                          ),
                          disabledForegroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.copy_all_rounded, size: 18),
                        // Only unticking already-copied events saves that
                        // change instead of copying anything.
                        label: Text(
                          selected.isEmpty && toUnmark.isNotEmpty
                              ? 'Save'
                              : 'Copy Selected',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Navy "Selected Events / Total Amount" bar, updated live as events are
/// ticked.
class _SelectionSummary extends StatelessWidget {
  final int count;
  final double total;
  const _SelectionSummary({required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    final label = TextStyle(
      color: Colors.white.withValues(alpha: 0.72),
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: PayColors.navy,
        borderRadius: BorderRadius.circular(PayColors.radius),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Selected Events', style: label),
                const SizedBox(height: 2),
                Text(
                  '$count ${count == 1 ? 'event' : 'events'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 34,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: Colors.white.withValues(alpha: 0.18),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Total Amount', style: label),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    formatCurrency(total),
                    style: const TextStyle(
                      color: PayColors.goldBright,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact, tappable event row in the Select Events dialog.
class SelectableEventTile extends StatelessWidget {
  final EventBooking event;
  final bool selected;
  final VoidCallback onTap;

  const SelectableEventTile({
    super.key,
    required this.event,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return Material(
      color: selected ? PayColors.selectedBg : PayColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: selected ? PayColors.navy : PayColors.border,
          width: selected ? 1.6 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: _CheckMark(state: selected),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.eventName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: PayColors.text,
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                            ),
                          ),
                        ),
                        if (event.copied) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 15,
                            color: PayColors.green,
                          ),
                        ],
                        const SizedBox(width: 6),
                        PaymentShiftBadge(shift: event.shift, compact: true),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${formatEventDate(event.date)}  ·  ${event.location}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PayColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    PaymentAmountBox.row(event, dense: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded checkbox: filled navy with a tick when [state] is true, a dash
/// when null (partial), empty when false.
class _CheckMark extends StatelessWidget {
  final bool? state;
  const _CheckMark({required this.state});

  @override
  Widget build(BuildContext context) {
    final filled = state != false;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: filled ? PayColors.navy : PayColors.card,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: filled ? PayColors.navy : PayColors.textSecondary,
          width: 1.6,
        ),
      ),
      child: filled
          ? Icon(
              state == true ? Icons.check_rounded : Icons.remove_rounded,
              size: 16,
              color: Colors.white,
            )
          : null,
    );
  }
}

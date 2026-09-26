import 'package:flutter/material.dart';

import '../models/event_booking.dart';
import '../utils/currency.dart';
import 'payment_chips.dart' show formatEventDate;

/// The Pending Events screen's Royal Navy + Gold + Ivory palette.
class PendingEventColors {
  PendingEventColors._();

  static const Color navy = Color(0xFF092642);
  static const Color navySoft = Color(0xFF1C3D63);
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldDeep = Color(0xFFA8861F);
  static const Color cream = Color(0xFFF7EDCB);
  static const Color skyBg = Color(0xFFE2ECF8);
  static const Color sky = Color(0xFF2F5A8A);
  static const Color card = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF12233A);
  static const Color textSecondary = Color(0xFF5F6F84);
  static const Color border = Color(0xFFB8C4D0);
  static const Color divider = Color(0xFFDCE3EA);
  static const Color green = Color(0xFF16845F);
  static const Color greenBg = Color(0xFFE6F4EE);
  static const Color editBg = Color(0xFFEDF1F6);
  static const Color danger = Color(0xFFC62828);
  static const Color dangerBg = Color(0xFFFDECEC);
}

/// A compact stat card: icon, big count and a short label.
class PendingSummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color background;
  final Color iconBackground;
  final Color iconColor;
  final Color foreground;
  final Color labelColor;
  final Color? borderColor;

  const PendingSummaryCard({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.background,
    required this.iconBackground,
    required this.iconColor,
    required this.foreground,
    required this.labelColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [background, Color.lerp(background, Colors.white, 0.14)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor ?? iconColor.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: PendingEventColors.navy.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Label on top (with its icon), the count centered underneath.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 15, color: iconColor),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$count',
              style: TextStyle(
                color: foreground,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 22,
            height: 3,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact Day (light gold, sun) / Night (soft blue, moon) badge.
class PendingShiftBadge extends StatelessWidget {
  final Shift shift;
  const PendingShiftBadge({super.key, required this.shift});

  @override
  Widget build(BuildContext context) {
    final isDay = shift == Shift.day;
    final fg = isDay ? PendingEventColors.goldDeep : PendingEventColors.sky;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDay ? PendingEventColors.cream : PendingEventColors.skyBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round,
            size: 16,
            color: fg,
          ),
          const SizedBox(width: 5),
          Text(
            shift.label,
            style: TextStyle(
              color: fg,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Square, touch-friendly icon button with a tinted rounded background.
class PendingIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final Color background;
  final VoidCallback? onPressed;

  const PendingIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.background,
    this.onPressed,
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
          onTap: onPressed,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }
}

/// A compact pending-event card:
///   name / type                 [edit] [delete]
///   [shift] | date                     amount
///   caller          |          location
///   [              ✓ Done              ]
class PendingEventCard extends StatelessWidget {
  final EventBooking event;
  final VoidCallback onDone;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const PendingEventCard({
    super.key,
    required this.event,
    required this.onDone,
    required this.onEdit,
    required this.onDelete,
  });

  static const _metaStyle = TextStyle(
    color: PendingEventColors.textSecondary,
    fontSize: 15,
    fontWeight: FontWeight.w500,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: PendingEventColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PendingEventColors.border, width: 1.6),
        boxShadow: [
          BoxShadow(
            color: PendingEventColors.navy.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: name + type, edit / delete.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.eventName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PendingEventColors.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      event.eventType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PendingEventColors.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PendingIconButton(
                icon: Icons.edit_outlined,
                tooltip: 'Edit',
                color: PendingEventColors.navy,
                background: PendingEventColors.editBg,
                onPressed: onEdit,
              ),
              const SizedBox(width: 8),
              PendingIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Delete',
                color: PendingEventColors.danger,
                background: PendingEventColors.dangerBg,
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Row 2: shift | date ........ amount.
          Row(
            children: [
              PendingShiftBadge(shift: event.shift),
              const _VerticalRule(),
              const Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: PendingEventColors.goldDeep,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  formatEventDate(event.date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _metaStyle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatCurrency(event.amount),
                style: const TextStyle(
                  color: PendingEventColors.green,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Row 3: caller | location.
          Row(
            children: [
              Expanded(
                child: _Meta(icon: Icons.call_outlined, text: event.personName),
              ),
              const _VerticalRule(),
              Expanded(
                child: _Meta(
                  icon: Icons.location_on_outlined,
                  text: event.location,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Row 4: Done.
          SizedBox(
            height: 48,
            child: Material(
              color: PendingEventColors.greenBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(
                  color: PendingEventColors.green,
                  width: 1.6,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onDone,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: PendingEventColors.green,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Done',
                      style: TextStyle(
                        color: PendingEventColors.green,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: PendingEventColors.goldDeep),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PendingEventCard._metaStyle,
          ),
        ),
      ],
    );
  }
}

class _VerticalRule extends StatelessWidget {
  const _VerticalRule();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: PendingEventColors.divider,
    );
  }
}

import 'package:flutter/material.dart';

import '../models/event_booking.dart';
import '../utils/currency.dart';
import 'payment_chips.dart' show formatEventDate;

/// The History screen's Royal Navy + Gold + Ivory palette.
class HistoryColors {
  HistoryColors._();

  static const Color navyDeep = Color(0xFF092642);
  static const Color navy = Color(0xFF0B2947);
  static const Color navySoft = Color(0xFF1C3D63);
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldDeep = Color(0xFFB08D24);
  static const Color goldLight = Color(0xFFF4E7B5);
  static const Color ivory = Color(0xFFFAF9F5);
  static const Color card = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF12233A);
  static const Color textSecondary = Color(0xFF687386);
  static const Color border = Color(0xFFECE8DC);
  static const Color amountBg = Color(0xFFEEF2F7);
  static const Color tipsBg = Color(0xFFDFF3EA);
  static const Color tipsText = Color(0xFF1B7A55);
  static const Color danger = Color(0xFFC62828);
  static const Color dangerBg = Color(0xFFFDECEC);
}

/// Navy header with a back arrow, the page title and a faint gold wave.
class HistoryHeader extends StatelessWidget {
  final String title;
  const HistoryHeader({super.key, this.title = 'History'});

  static const _radius = BorderRadius.vertical(bottom: Radius.circular(28));

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [HistoryColors.navyDeep, HistoryColors.navy],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: _radius,
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _GoldWavePainter())),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(canPop ? 4 : 20, 8, 20, 26),
                child: Row(
                  children: [
                    if (canPop) ...[
                      IconButton(
                        tooltip: 'Back',
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: Colors.white,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 34,
                            height: 3,
                            decoration: BoxDecoration(
                              color: HistoryColors.gold,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoldWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawCircle(
      Offset(w * 0.95, h * 0.05),
      h * 0.75,
      Paint()..color = HistoryColors.gold.withValues(alpha: 0.06),
    );

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = HistoryColors.gold.withValues(alpha: 0.38);
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.30, h)
        ..cubicTo(w * 0.52, h * 0.52, w * 0.74, h * 1.05, w, h * 0.30),
      stroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.48, h)
        ..cubicTo(w * 0.66, h * 0.68, w * 0.84, h * 0.98, w, h * 0.58),
      stroke..color = HistoryColors.gold.withValues(alpha: 0.18),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// One of the two headline stat cards (Total Events / Total Amount).
class HistorySummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color background;
  final Color iconBackground;
  final Color foreground;

  const HistorySummaryCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.background,
    required this.iconBackground,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: background.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: foreground, size: 20),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: foreground,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// White rounded container holding the filter dropdowns. Fields stack
/// vertically on phones (so labels like "All months" never truncate) and
/// sit side by side on wider screens.
class HistoryFilterPanel extends StatelessWidget {
  final List<Widget> fields;
  final VoidCallback? onClear;

  const HistoryFilterPanel({super.key, required this.fields, this.onClear});

  @override
  Widget build(BuildContext context) {
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: HistoryColors.border),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: HistoryColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HistoryColors.border),
        boxShadow: [
          BoxShadow(
            color: HistoryColors.navy.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 40,
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: HistoryColors.goldLight,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.filter_alt_outlined,
                    size: 17,
                    color: HistoryColors.navy,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Filters',
                    style: TextStyle(
                      color: HistoryColors.text,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (onClear != null)
                  TextButton(
                    onPressed: onClear,
                    style: TextButton.styleFrom(
                      foregroundColor: HistoryColors.goldDeep,
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          DropdownMenuTheme(
            data: DropdownMenuThemeData(
              textStyle: const TextStyle(
                color: HistoryColors.text,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
              inputDecorationTheme: InputDecorationThemeData(
                filled: true,
                fillColor: HistoryColors.ivory,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
                labelStyle: const TextStyle(
                  color: HistoryColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                floatingLabelStyle: const TextStyle(
                  color: HistoryColors.navy,
                  fontWeight: FontWeight.w700,
                ),
                prefixIconColor: HistoryColors.goldDeep,
                suffixIconColor: HistoryColors.navy,
                border: fieldBorder,
                enabledBorder: fieldBorder,
                focusedBorder: fieldBorder.copyWith(
                  borderSide: const BorderSide(
                    color: HistoryColors.gold,
                    width: 1.6,
                  ),
                ),
              ),
              menuStyle: MenuStyle(
                backgroundColor: const WidgetStatePropertyAll(
                  HistoryColors.card,
                ),
                surfaceTintColor: const WidgetStatePropertyAll(
                  Colors.transparent,
                ),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 520) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < fields.length; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        Expanded(child: fields[i]),
                      ],
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < fields.length; i++) ...[
                      if (i > 0) const SizedBox(height: 14),
                      fields[i],
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A colored Amount / Tips / Total tile on a history card.
class HistoryAmountTile extends StatelessWidget {
  final String label;
  final double value;
  final Color background;
  final Color labelColor;
  final Color valueColor;

  const HistoryAmountTile({
    super.key,
    required this.label,
    required this.value,
    required this.background,
    this.labelColor = HistoryColors.textSecondary,
    this.valueColor = HistoryColors.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: labelColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatCurrency(value),
              style: TextStyle(
                color: valueColor,
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact tappable pill button (Restore / Delete) with a ripple.
class HistoryActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;
  final Color? borderColor;
  final VoidCallback? onPressed;

  const HistoryActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
    this.borderColor,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: borderColor == null
          ? BorderSide.none
          : BorderSide(color: borderColor!),
    );
    return Material(
      color: background,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: foreground),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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

/// Gold pill showing the event's shift.
class HistoryShiftPill extends StatelessWidget {
  final Shift shift;
  const HistoryShiftPill({super.key, required this.shift});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: HistoryColors.goldLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            shift == Shift.day
                ? Icons.wb_sunny_outlined
                : Icons.nightlight_outlined,
            size: 16,
            color: HistoryColors.goldDeep,
          ),
          const SizedBox(width: 5),
          Text(
            shift.label,
            style: const TextStyle(
              color: HistoryColors.navy,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// A settled event in History: name/type, shift + Restore/Delete actions,
/// date/caller/location metadata, and the Amount/Tips/Total tiles.
class HistoryEventCard extends StatelessWidget {
  final EventBooking event;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const HistoryEventCard({
    super.key,
    required this.event,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          event.eventName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: HistoryColors.text,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          event.eventType,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: HistoryColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );

    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        HistoryShiftPill(shift: event.shift),
        HistoryActionButton(
          icon: Icons.undo_rounded,
          label: 'Restore',
          foreground: HistoryColors.navy,
          background: HistoryColors.card,
          borderColor: HistoryColors.border,
          onPressed: onRestore,
        ),
        HistoryActionButton(
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          foreground: HistoryColors.danger,
          background: HistoryColors.dangerBg,
          onPressed: onDelete,
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: HistoryColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HistoryColors.border),
        boxShadow: [
          BoxShadow(
            color: HistoryColors.navy.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 460) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: titleBlock),
                    const SizedBox(width: 12),
                    actions,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [titleBlock, const SizedBox(height: 12), actions],
              );
            },
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _MetaItem(
                icon: Icons.calendar_today_outlined,
                text: formatEventDate(event.date),
              ),
              _MetaItem(icon: Icons.call_outlined, text: event.personName),
              _MetaItem(icon: Icons.location_on_outlined, text: event.location),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(
              height: 1,
              thickness: 1,
              color: HistoryColors.border,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: HistoryAmountTile(
                  label: 'Amount',
                  value: event.amount,
                  background: HistoryColors.amountBg,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: HistoryAmountTile(
                  label: 'Tips',
                  value: event.tips,
                  background: HistoryColors.tipsBg,
                  valueColor: HistoryColors.tipsText,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: HistoryAmountTile(
                  label: 'Total',
                  value: event.amount + event.tips,
                  background: HistoryColors.gold,
                  labelColor: HistoryColors.navyDeep,
                  valueColor: HistoryColors.navyDeep,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: HistoryColors.goldDeep),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: HistoryColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// Fades and slides [child] up into place the first time it's built.
/// [index] staggers the timing so a list of cards cascades in.
class HistoryAppear extends StatelessWidget {
  final int index;
  final Widget child;
  const HistoryAppear({super.key, this.index = 0, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + 60 * index.clamp(0, 6)),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 18),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Fades out and collapses [child] to zero height when [leaving] flips to
/// true — used when a record is restored or deleted.
class HistoryExit extends StatelessWidget {
  static const duration = Duration(milliseconds: 300);

  final bool leaving;
  final Widget child;
  const HistoryExit({super.key, required this.leaving, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: leaving ? 0 : 1,
      duration: duration,
      child: ClipRect(
        child: AnimatedAlign(
          alignment: Alignment.topCenter,
          heightFactor: leaving ? 0 : 1,
          duration: duration,
          curve: Curves.easeInOutCubic,
          child: child,
        ),
      ),
    );
  }
}

/// Centered icon + title + message, for empty / no-match / error states.
class HistoryEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color accent;

  const HistoryEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.accent = HistoryColors.navy,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: HistoryColors.goldLight.withValues(alpha: 0.6),
              border: Border.all(
                color: HistoryColors.gold.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Icon(icon, size: 40, color: accent),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: HistoryColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: HistoryColors.textSecondary,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown instead of the full record list while a filter is active — a
/// compact summary (what's filtered, how many events, total amount) with a
/// double-tap to reveal every matching record in full.
class HistoryFilteredSummary extends StatelessWidget {
  final String filterLabel;
  final int count;
  final double totalAmount;
  final VoidCallback onDoubleTap;

  const HistoryFilteredSummary({
    super.key,
    required this.filterLabel,
    required this.count,
    required this.totalAmount,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return Material(
      color: HistoryColors.card,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onDoubleTap: onDoubleTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: HistoryColors.gold.withValues(alpha: 0.45),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [HistoryColors.navyDeep, HistoryColors.navy],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.receipt_long_outlined,
                      color: HistoryColors.gold,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        filterLabel.isEmpty ? 'Filtered results' : filterLabel,
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
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 34,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          color: HistoryColors.border,
                        ),
                        Expanded(
                          child: _MiniStat(
                            label: 'Total Amount',
                            value: formatCurrency(totalAmount),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Row(
                      children: [
                        Icon(
                          Icons.touch_app_outlined,
                          size: 15,
                          color: HistoryColors.goldDeep,
                        ),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Double-tap to view the full details',
                            style: TextStyle(
                              color: HistoryColors.textSecondary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
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
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: HistoryColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              color: HistoryColors.text,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ),
      ],
    );
  }
}

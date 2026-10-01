import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/event_booking.dart';
import '../theme/app_theme.dart';
import 'payment_chips.dart';

/// The dashboard's navy + gold design system. Light values follow the
/// design reference; the context-aware helpers swap in dark surfaces so the
/// dashboard stays readable in dark mode.
class DashColors {
  DashColors._();

  static const navy = Color(0xFF062442);
  static const navyLight = Color(0xFF08294A);
  static const gold = Color(0xFFD9A928);
  static const goldLight = Color(0xFFE7BE55);
  static const goldDeep = Color(0xFF9C7612);
  static const cream = Color(0xFFFAF8F1);
  static const lightBlue = Color(0xFFEEF5FC);
  static const lightGreen = Color(0xFFEAF8F1);
  static const lightRed = Color(0xFFFDECEC);
  static const lightGray = Color(0xFFF2F4F7);
  static const text = Color(0xFF10233F);
  static const textSecondary = Color(0xFF667085);
  static const border = Color(0xFFE5E7EB);
  static const green = Color(0xFF1E9E6A);
  static const red = Color(0xFFE5484D);

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color surface(BuildContext context) =>
      _isDark(context) ? AppColors.surfaceDark : Colors.white;

  static Color textPrimary(BuildContext context) =>
      _isDark(context) ? AppColors.textPrimaryDark : text;

  static Color textMuted(BuildContext context) =>
      _isDark(context) ? AppColors.textSecondaryDark : textSecondary;

  static Color line(BuildContext context) =>
      _isDark(context) ? AppColors.borderDark : border;

  /// A soft tinted background: the [light] reference tint in light mode, a
  /// faint wash of [accent] in dark mode.
  static Color tint(
    BuildContext context, {
    required Color light,
    required Color accent,
  }) => _isDark(context) ? accent.withValues(alpha: 0.12) : light;

  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: navy.withValues(alpha: 0.06),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];
}

enum GoldCurveCorner { topRight, bottomRight }

/// The decorative sweeping gold lines used on the header and event cards.
class GoldCurvePainter extends CustomPainter {
  final GoldCurveCorner corner;

  /// Where along the edge (0–1 of the width) the main curve starts.
  final double start;
  const GoldCurvePainter({
    this.corner = GoldCurveCorner.topRight,
    this.start = 0.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final flip = corner == GoldCurveCorner.bottomRight;
    if (flip) {
      canvas.save();
      canvas.translate(0, h);
      canvas.scale(1, -1);
    }

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(w * start, 0)
        ..quadraticBezierTo(w * 0.80, h * 0.64, w, h * 0.58),
      stroke
        ..color = DashColors.gold.withValues(alpha: 0.9)
        ..strokeWidth = 2.2,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * (start + 0.1), 0)
        ..quadraticBezierTo(w * 0.86, h * 0.46, w, h * 0.42),
      stroke
        ..color = DashColors.goldLight.withValues(alpha: 0.45)
        ..strokeWidth = 1.2,
    );

    if (flip) canvas.restore();
  }

  @override
  bool shouldRepaint(GoldCurvePainter oldDelegate) =>
      oldDelegate.corner != corner || oldDelegate.start != start;
}

/// Full-width navy header: menu button, big title, subtitle and a gold
/// curved accent toward the upper-right. Extends behind the status bar.
class DashboardHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onMenu;
  const DashboardHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        height: topInset + 116,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [DashColors.navy, DashColors.navyLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(26),
            bottomRight: Radius.circular(26),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(
          painter: const GoldCurvePainter(start: 0.55),
          child: Padding(
            padding: EdgeInsets.fromLTRB(8, topInset + 8, 20, 18),
            child: Row(
              children: [
                IconButton(
                  onPressed: onMenu,
                  tooltip: 'Menu',
                  icon: const Icon(
                    Icons.menu_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
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

/// A compact summary tile ("Today's Events", "Today's Payments"). Both
/// tiles share one cream + thin gold border treatment: icon and label on
/// top, the value large and centered toward the bottom, and a small caption
/// under it. Display-only.
class DashSummaryCard extends StatelessWidget {
  static const _bg = Color(0xFFFCF6E6);
  static const _iconBg = Color(0xFFF5E6B8);

  final IconData icon;
  final String label;
  final String value;
  final String caption;
  const DashSummaryCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(20);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: isDark ? DashColors.gold.withValues(alpha: 0.10) : _bg,
        borderRadius: radius,
        border: Border.all(
          color: DashColors.gold.withValues(alpha: 0.55),
          width: 1.2,
        ),
        boxShadow: DashColors.softShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDark
                      ? DashColors.gold.withValues(alpha: 0.18)
                      : _iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: DashColors.goldDeep, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: DashColors.textPrimary(context),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: DashColors.textPrimary(context),
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: DashColors.textMuted(context),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular light-gray count badge next to a section title.
class DashCountBadge extends StatelessWidget {
  final int count;
  const DashCountBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 30),
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: DashColors.tint(
          context,
          light: DashColors.lightGray,
          accent: Colors.white,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: DashColors.textPrimary(context),
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }
}

/// Rounded "📅 25 Sep 2026 ⌄" date selector.
class DashDateSelector extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;
  const DashDateSelector({super.key, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = DashColors.textPrimary(context);
    return Material(
      color: DashColors.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: DashColors.line(context)),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today_outlined, size: 16, color: color),
              const SizedBox(width: 7),
              Text(
                formatEventDate(date),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

/// One option of [DashEventTabs].
class DashTab {
  final IconData icon;
  final String label;
  const DashTab(this.icon, this.label);
}

/// Large rounded segmented control. The selected option is navy with a gold
/// border and gold icon; the others sit on light gray.
class DashEventTabs extends StatelessWidget {
  final List<DashTab> tabs;
  final int selected;
  final ValueChanged<int> onChanged;
  const DashEventTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: DashColors.tint(
          context,
          light: DashColors.lightGray,
          accent: Colors.white,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(child: _option(context, i)),
        ],
      ),
    );
  }

  Widget _option(BuildContext context, int index) {
    final isSelected = selected == index;
    final tab = tabs[index];
    final textColor = isSelected
        ? Colors.white
        : DashColors.textPrimary(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? DashColors.navy : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? DashColors.gold : Colors.transparent,
            width: 1.4,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: DashColors.navy.withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              tab.icon,
              size: 19,
              color: isSelected ? DashColors.gold : textColor,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small tinted statistic tile: icon + label, then a progress bar with an
/// optional trailing value (e.g. "0%").
class DashStatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color lightTint;
  final String label;
  final double progress;
  final Color progressColor;
  final String? trailing;
  const DashStatCard({
    super.key,
    required this.icon,
    required this.color,
    required this.lightTint,
    required this.label,
    required this.progress,
    required this.progressColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: DashColors.tint(context, light: lightTint, accent: color),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: DashColors.surface(context),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: DashColors.textPrimary(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0, 1).toDouble(),
                    minHeight: 7,
                    backgroundColor: DashColors.textSecondary.withValues(
                      alpha: 0.18,
                    ),
                    valueColor: AlwaysStoppedAnimation(progressColor),
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Text(
                  trailing!,
                  style: TextStyle(
                    color: DashColors.textMuted(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Soft pastel (background, foreground) pairs for initial avatars.
const _avatarPastels = [
  (Color(0xFFE8F0FE), Color(0xFF3056D3)),
  (Color(0xFFFFF4DB), Color(0xFFB7791F)),
  (DashColors.lightGreen, DashColors.green),
  (Color(0xFFF3E8FF), Color(0xFF7C3AED)),
  (DashColors.lightRed, Color(0xFFD64545)),
];

/// A member row: present checkbox, pastel initial avatar, name, and a
/// pink circular delete button.
class DashMemberRow extends StatelessWidget {
  final String name;
  final bool present;
  final ValueChanged<bool> onPresentChanged;
  final VoidCallback onDelete;

  /// Long-press anywhere on the row (outside the checkbox / delete button)
  /// to call this member.
  final VoidCallback? onCall;
  const DashMemberRow({
    super.key,
    required this.name,
    required this.present,
    required this.onPresentChanged,
    required this.onDelete,
    this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
    final pastel = trimmed.isEmpty
        ? _avatarPastels.first
        : _avatarPastels[trimmed.codeUnitAt(0) % _avatarPastels.length];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final row = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(4, 6, 10, 6),
      decoration: BoxDecoration(
        color: DashColors.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DashColors.line(context)),
      ),
      child: Row(
        children: [
          Checkbox(
            value: present,
            onChanged: (value) => onPresentChanged(value ?? false),
            activeColor: DashColors.navy,
            checkColor: DashColors.goldLight,
            side: BorderSide(color: DashColors.line(context), width: 1.8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: isDark
                ? pastel.$2.withValues(alpha: 0.2)
                : pastel.$1,
            child: Text(
              initial,
              style: TextStyle(
                color: pastel.$2,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onPresentChanged(!present),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: DashColors.textPrimary(context),
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          DashCircleButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Remove from event',
            background: isDark
                ? DashColors.red.withValues(alpha: 0.16)
                : DashColors.lightRed,
            color: DashColors.red,
            onPressed: onDelete,
          ),
        ],
      ),
    );
    if (onCall == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () {
        HapticFeedback.mediumImpact();
        onCall!();
      },
      child: row,
    );
  }
}

/// Small circular icon button.
class DashCircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color background;
  final Color color;
  final VoidCallback onPressed;
  final double size;
  final BoxBorder? border;
  const DashCircleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.background,
    required this.color,
    required this.onPressed,
    this.size = 36,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: size,
        height: size,
        child: Material(
          color: background,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Ink(
              decoration: BoxDecoration(shape: BoxShape.circle, border: border),
              child: Icon(icon, size: size * 0.5, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

/// An Admin staffing event: navy header (name, edit, shift & date pills,
/// gold curve), assigned/present statistics, and the members A–Z.
class DashStaffingEventCard extends StatelessWidget {
  final EventBooking event;
  final VoidCallback onEdit;
  final void Function(AssignedMember member, bool present) onPresentChanged;
  final ValueChanged<AssignedMember> onRemove;
  final ValueChanged<AssignedMember>? onCall;
  const DashStaffingEventCard({
    super.key,
    required this.event,
    required this.onEdit,
    required this.onPresentChanged,
    required this.onRemove,
    this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final assigned = event.assignedMembers.length;
    final required = event.requiredMembers;
    final present = event.assignedMembers
        .where((m) => event.presentMemberIds.contains(m.id))
        .length;
    final isFull = required > 0 && assigned >= required;
    final presentRatio = assigned == 0 ? 0.0 : present / assigned;
    final members = [...event.assignedMembers]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Container(
      decoration: BoxDecoration(
        color: DashColors.surface(context),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: DashColors.line(context)),
        boxShadow: DashColors.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: DashStatCard(
                          icon: Icons.groups_rounded,
                          color: DashColors.green,
                          lightTint: DashColors.lightGreen,
                          label: '$assigned of $required assigned',
                          progress: required == 0 ? 0 : assigned / required,
                          progressColor: isFull
                              ? DashColors.green
                              : DashColors.gold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DashStatCard(
                          icon: Icons.person_rounded,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? DashColors.goldLight
                              : DashColors.navy,
                          lightTint: DashColors.lightBlue,
                          label: '$present present',
                          progress: presentRatio,
                          progressColor: DashColors.navy,
                          trailing: '${(presentRatio * 100).round()}%',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Assigned Members ($assigned)',
                  style: TextStyle(
                    color: DashColors.textPrimary(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                if (members.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'No members assigned yet',
                      style: TextStyle(
                        color: DashColors.textMuted(context),
                        fontSize: 13.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                else
                  for (final member in members)
                    DashMemberRow(
                      name: member.name,
                      present: event.presentMemberIds.contains(member.id),
                      onPresentChanged: (value) =>
                          onPresentChanged(member, value),
                      onDelete: () => onRemove(member),
                      onCall: onCall == null ? null : () => onCall!(member),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final isDay = event.shift == Shift.day;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [DashColors.navy, DashColors.navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: CustomPaint(
        painter: const GoldCurvePainter(
          corner: GoldCurveCorner.bottomRight,
          start: 0.62,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 14, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        event.eventName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  DashCircleButton(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit event',
                    size: 40,
                    background: Colors.white.withValues(alpha: 0.12),
                    color: Colors.white,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                    onPressed: onEdit,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeaderPill(
                    icon: isDay
                        ? Icons.wb_sunny_rounded
                        : Icons.nightlight_round,
                    label: event.shift.label,
                    background: isDay
                        ? const Color(0xFFFBEFCB)
                        : const Color(0xFFDDE7F5),
                    foreground: isDay ? DashColors.goldDeep : DashColors.navy,
                  ),
                  _HeaderPill(
                    icon: Icons.calendar_today_outlined,
                    label: formatEventDate(event.date),
                    background: Colors.white.withValues(alpha: 0.12),
                    foreground: Colors.white,
                    border: Colors.white.withValues(alpha: 0.2),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final Color? border;
  const _HeaderPill({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: border == null ? null : Border.all(color: border!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty-state card ("No events scheduled…").
class DashEmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const DashEmptyCard({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: DashColors.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DashColors.line(context)),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: DashColors.tint(
                context,
                light: DashColors.cream,
                accent: DashColors.gold,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: DashColors.gold, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: DashColors.textPrimary(context),
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating navy pill "Add Event" button with a gold border.
class DashAddEventButton extends StatelessWidget {
  final VoidCallback onPressed;
  const DashAddEventButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: DashColors.navy,
      foregroundColor: Colors.white,
      elevation: 6,
      highlightElevation: 10,
      shape: const StadiumBorder(
        side: BorderSide(color: DashColors.gold, width: 1.6),
      ),
      icon: const Icon(Icons.add_rounded, size: 24),
      label: const Text(
        'Add Event',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    );
  }
}

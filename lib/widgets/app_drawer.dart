import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/admin_request.dart';
import '../models/user_role.dart';
import '../screens/add_event_screen.dart';
import '../screens/add_member_screen.dart';
import '../screens/admin_pending_events_screen.dart';
import '../screens/admin_requests_screen.dart';
import '../screens/history_screen.dart';
import '../screens/manage_data_screen.dart';
import '../screens/members_screen.dart';
import '../screens/pending_events_screen.dart';
import '../screens/payouts_screen.dart';
import '../screens/pending_payments_screen.dart';
import '../screens/profile_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// The first word of a full name, with its first letter capitalized — used
/// so a long "First Last" (or "First Middle Last") name shows compactly in
/// the drawer header.
String _firstName(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+'));
  final first = parts.isEmpty ? '' : parts.first;
  if (first.isEmpty) return first;
  return first[0].toUpperCase() + first.substring(1);
}

/// Closes the drawer and opens [screen] in place of whatever page the
/// drawer was opened from, so the stack is always Dashboard → [screen]
/// (system back returns to the Dashboard) instead of piling up pages.
void _openFromDrawer(BuildContext context, Widget screen) {
  final navigator = Navigator.of(context);
  navigator.pop();
  navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => screen),
    (route) => route.isFirst,
  );
}

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  // Drives the Admin/User swipeable pages below, for an Admin/Super Admin
  // only. Irrelevant for a plain User, who only ever sees their own menu.
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser!;
    final isSuperAdmin = user.role == UserRole.superAdmin;
    final isAdmin = user.role == UserRole.admin;
    final hasAdminAccess = isSuperAdmin || isAdmin;

    return Drawer(
      backgroundColor: _DrawerColors.ivory,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DrawerHeader(
            name: _firstName(user.name),
            avatar: _ProfileAvatar(role: user.role, size: 58),
            role: user.role,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _DrawerItem(
              icon: Icons.dashboard_rounded,
              label: 'Dashboard',
              variant: _DrawerItemVariant.highlighted,
              onTap: () {
                // Close the drawer, then any page opened from it.
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.popUntil((route) => route.isFirst);
              },
            ),
          ),
          Expanded(
            child: !hasAdminAccess
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    children: [
                      const _SectionLabel('MENU'),
                      _PendingEventsDrawerItem(),
                      _PendingPaymentsDrawerItem(),
                      _HistoryDrawerItem(),
                      _ManageDataDrawerItem(),
                      _ProfileDrawerItem(),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(
                        child: PageView(
                          controller: _pageController,
                          onPageChanged: (index) =>
                              setState(() => _page = index),
                          children: [
                            ListView(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              children: [
                                const _SectionLabel('ADMIN · EVENTS'),
                                _AddStaffingEventDrawerItem(),
                                _AddMembersDrawerItem(),
                                const _SectionLabel('ADMIN · MANAGE'),
                                _AdminPendingEventsDrawerItem(),
                                _PayoutsDrawerItem(),
                                _ContactDrawerItem(),
                                _PayoutHistoryDrawerItem(),
                                if (isSuperAdmin) _AdminRequestsDrawerItem(),
                              ],
                            ),
                            ListView(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              children: [
                                const _SectionLabel('USER'),
                                _AddEventDrawerItem(),
                                _PendingEventsDrawerItem(),
                                _PendingPaymentsDrawerItem(),
                                _HistoryDrawerItem(),
                                _ManageDataDrawerItem(),
                                _ProfileDrawerItem(),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < 2; i++)
                            GestureDetector(
                              onTap: () => _pageController.animateToPage(
                                i,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                width: _page == i ? 18 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _page == i
                                      ? _DrawerColors.gold
                                      : _DrawerColors.navy.withValues(
                                          alpha: 0.2,
                                        ),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 2),
                        child: Text(
                          _page == 0
                              ? 'Admin  ·  swipe for User →'
                              : '← swipe for Admin  ·  User',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _DrawerColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(
                    height: 20,
                    thickness: 1,
                    color: _DrawerColors.border,
                  ),
                  _DrawerItem(
                    icon: Icons.logout_rounded,
                    label: 'Log out',
                    variant: _DrawerItemVariant.danger,
                    onTap: () => _confirmLogout(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to use the app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Log out', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final auth = context.read<AuthService>();
    // Close the drawer and any page opened from it, back to the root, so
    // nothing is left stacked above the sign-in screen.
    Navigator.of(context).popUntil((route) => route.isFirst);
    await auth.logout();
  }
}

/// The circular role icon at the top of the drawer. For a User, tapping it
/// 4 times in quick succession offers to send an admin-promotion request to
/// the Super Admin.
class _ProfileAvatar extends StatefulWidget {
  final UserRole role;
  final double size;
  const _ProfileAvatar({required this.role, this.size = 64});

  @override
  State<_ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<_ProfileAvatar> {
  static const _requiredTaps = 4;
  static const _tapWindow = Duration(seconds: 3);

  int _tapCount = 0;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  void _onTap() {
    if (widget.role != UserRole.user) return;

    _tapCount++;
    _resetTimer?.cancel();
    _resetTimer = Timer(_tapWindow, () => _tapCount = 0);

    if (_tapCount >= _requiredTaps) {
      _tapCount = 0;
      _resetTimer?.cancel();
      _showRequestDialog();
    }
  }

  Future<void> _showRequestDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Become an Admin?'),
        content: const Text(
          'This sends a request to the Super Admin asking to promote your account to Admin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final result = await context.read<AuthService>().requestAdminPromotion();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? 'Request sent to the Super Admin'
              : (result.error ?? 'Something went wrong'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: _DrawerColors.gold, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          widget.role.icon,
          color: Colors.white,
          size: widget.size * 0.46,
        ),
      ),
    );
  }
}

/// Small rounded pill that spells out the signed-in user's role, e.g.
/// "User" or "Admin".
class _RoleChip extends StatelessWidget {
  final UserRole role;
  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _DrawerColors.gold.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _DrawerColors.gold.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(role.icon, size: 12, color: _DrawerColors.goldLight),
          const SizedBox(width: 5),
          Text(
            role.label,
            style: const TextStyle(
              color: _DrawerColors.goldLight,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small uppercase heading used to group drawer items into sections.
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: _DrawerColors.textSecondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: _DrawerColors.border)),
        ],
      ),
    );
  }
}

class _PendingEventsDrawerItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _DrawerItem(
      icon: Icons.pending_actions_rounded,
      label: 'Pending Events',
      onTap: () {
        _openFromDrawer(context, const PendingEventsScreen());
      },
    );
  }
}

/// Admin-only: pending staffing events (from the Admin "Add Event" sheet),
/// separate from the USER section's own Pending Events.
class _AdminPendingEventsDrawerItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _DrawerItem(
      icon: Icons.pending_actions_rounded,
      label: 'Pending Events',
      onTap: () {
        _openFromDrawer(context, const AdminPendingEventsScreen());
      },
    );
  }
}

/// Admin-only: what's owed to each member assigned to staffing events.
class _PayoutsDrawerItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _DrawerItem(
      icon: Icons.account_balance_wallet_rounded,
      label: 'Payouts',
      onTap: () {
        _openFromDrawer(context, const PayoutsScreen());
      },
    );
  }
}

/// Admin-only: each member's payment history, picked by name.
class _PayoutHistoryDrawerItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _DrawerItem(
      icon: Icons.manage_history_rounded,
      label: 'History',
      onTap: () {
        _openFromDrawer(context, const PayoutHistoryScreen());
      },
    );
  }
}

class _PendingPaymentsDrawerItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _DrawerItem(
      icon: Icons.payments_outlined,
      label: 'Pending Payments',
      onTap: () {
        _openFromDrawer(context, const PendingPaymentsScreen());
      },
    );
  }
}

class _HistoryDrawerItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _DrawerItem(
      icon: Icons.history_rounded,
      label: 'History',
      onTap: () {
        _openFromDrawer(context, const HistoryScreen());
      },
    );
  }
}

class _ManageDataDrawerItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _DrawerItem(
      icon: Icons.storage_rounded,
      label: 'Manage Data',
      onTap: () {
        _openFromDrawer(context, const ManageDataScreen());
      },
    );
  }
}

class _AddEventDrawerItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _DrawerItem(
      icon: Icons.add_circle_outline_rounded,
      label: 'Add Event',
      onTap: () {
        _openFromDrawer(context, const AddEventScreen());
      },
    );
  }
}

class _AddMembersDrawerItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _DrawerItem(
      icon: Icons.assignment_ind_rounded,
      label: 'Assign Members',
      onTap: () {
        _openFromDrawer(context, const AddMemberScreen());
      },
    );
  }
}

/// Admin-only: creates an event that needs staffing (person who called,
/// event type, event name, date, shift, how many members required) — a
/// different form from the personal "Add Event" in the USER section, which
/// has no staffing concept. Assigning people to the event it creates
/// happens separately, from "Assign Members".
class _AddStaffingEventDrawerItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _DrawerItem(
      icon: Icons.add_circle_outline_rounded,
      label: 'Add Event',
      onTap: () {
        Navigator.of(context).pop();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const AddEventSheet(),
        );
      },
    );
  }
}

class _ProfileDrawerItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _DrawerItem(
      icon: Icons.person_outline_rounded,
      label: 'Profile',
      onTap: () {
        _openFromDrawer(context, const ProfileScreen());
      },
    );
  }
}

class _ContactDrawerItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _DrawerItem(
      icon: Icons.contacts_rounded,
      label: 'Contact',
      onTap: () {
        _openFromDrawer(context, const MembersScreen());
      },
    );
  }
}

class _AdminRequestsDrawerItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    return StreamBuilder<List<AdminRequest>>(
      stream: auth.pendingAdminRequests(),
      builder: (context, snapshot) {
        final count = snapshot.data?.length ?? 0;
        return _DrawerItem(
          icon: Icons.admin_panel_settings_outlined,
          label: 'Admin Requests',
          trailing: count == 0
              ? null
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
          onTap: () {
            _openFromDrawer(context, const AdminRequestsScreen());
          },
        );
      },
    );
  }
}

/// The drawer's Royal Navy + Gold + Ivory palette.
class _DrawerColors {
  _DrawerColors._();

  static const Color navyDeep = Color(0xFF071B33);
  static const Color navy = Color(0xFF0B2947);
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFF4E7B5);
  static const Color ivory = Color(0xFFFAF9F5);
  static const Color card = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF12233A);
  static const Color textSecondary = Color(0xFF687386);
  static const Color border = Color(0xFFECE8DC);
  static const Color iconBg = Color(0xFFEEF2F7);
  static const Color danger = Color(0xFFC62828);
  static const Color dangerBg = Color(0xFFFDECEC);
}

/// Navy header with the role avatar, first name, role badge and a faint
/// gold wave. Extends under the status bar.
class _DrawerHeader extends StatelessWidget {
  final String name;
  final Widget avatar;
  final UserRole role;
  const _DrawerHeader({
    required this.name,
    required this.avatar,
    required this.role,
  });

  static const _radius = BorderRadius.only(bottomRight: Radius.circular(28));

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_DrawerColors.navyDeep, _DrawerColors.navy],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: _radius,
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: CustomPaint(
          painter: _HeaderWavePainter(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, topInset + 22, 20, 22),
            child: Row(
              children: [
                avatar,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 21,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _RoleChip(role: role),
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

class _HeaderWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawCircle(
      Offset(w * 0.98, h * 0.08),
      h * 0.7,
      Paint()..color = _DrawerColors.gold.withValues(alpha: 0.07),
    );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = _DrawerColors.gold.withValues(alpha: 0.35);
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.35, h)
        ..cubicTo(w * 0.55, h * 0.6, w * 0.78, h * 1.02, w, h * 0.42),
      stroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.55, h)
        ..cubicTo(w * 0.72, h * 0.75, w * 0.88, h * 0.98, w, h * 0.7),
      stroke..color = _DrawerColors.gold.withValues(alpha: 0.16),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum _DrawerItemVariant { normal, highlighted, danger }

/// One drawer row: tinted icon tile, label, optional trailing badge and a
/// chevron. [variant] picks the plain white, highlighted navy (Dashboard)
/// or soft red (Log out) look.
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final _DrawerItemVariant variant;
  final Widget? trailing;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.variant = _DrawerItemVariant.normal,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isHighlighted = variant == _DrawerItemVariant.highlighted;
    final isDanger = variant == _DrawerItemVariant.danger;

    final Color bg;
    final Color border;
    final Color iconBg;
    final Color iconColor;
    final Color textColor;
    switch (variant) {
      case _DrawerItemVariant.highlighted:
        bg = _DrawerColors.navy;
        border = _DrawerColors.gold.withValues(alpha: 0.7);
        iconBg = _DrawerColors.gold.withValues(alpha: 0.2);
        iconColor = _DrawerColors.gold;
        textColor = Colors.white;
      case _DrawerItemVariant.danger:
        bg = _DrawerColors.dangerBg;
        border = _DrawerColors.danger.withValues(alpha: 0.18);
        iconBg = _DrawerColors.danger.withValues(alpha: 0.12);
        iconColor = _DrawerColors.danger;
        textColor = _DrawerColors.danger;
      case _DrawerItemVariant.normal:
        bg = _DrawerColors.card;
        border = _DrawerColors.border;
        iconBg = _DrawerColors.iconBg;
        iconColor = _DrawerColors.navy;
        textColor = _DrawerColors.text;
    }
    final radius = BorderRadius.circular(14);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: _DrawerColors.navy.withValues(
                alpha: isHighlighted ? 0.22 : 0.04,
              ),
              blurRadius: isHighlighted ? 14 : 8,
              offset: Offset(0, isHighlighted ? 6 : 3),
            ),
          ],
        ),
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: border, width: isHighlighted ? 1.2 : 1),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                  if (!isDanger) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: isHighlighted
                          ? _DrawerColors.gold
                          : _DrawerColors.textSecondary.withValues(alpha: 0.7),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

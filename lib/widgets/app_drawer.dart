import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/admin_request.dart';
import '../models/user_role.dart';
import '../screens/add_event_screen.dart';
import '../screens/admin_requests_screen.dart';
import '../screens/coming_soon_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/history_screen.dart';
import '../screens/manage_data_screen.dart';
import '../screens/pending_events_screen.dart';
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

class AppDrawer extends StatelessWidget {
  /// When true, only the header (avatar/name/role) and Log out are shown —
  /// used by the Admin Dashboard, which is its own separate space reached by
  /// double-tapping the "Admin" role chip, without the regular nav menu.
  final bool minimal;
  const AppDrawer({super.key, this.minimal = false});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser!;
    final isSuperAdmin = user.role == UserRole.superAdmin;

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.heroGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _ProfileAvatar(role: user.role, size: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _firstName(user.name),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (user.role == UserRole.admin)
                    GestureDetector(
                      onDoubleTap: () {
                        Navigator.of(context).pop(); // close the drawer
                        if (minimal) {
                          // On the Admin Dashboard (home) — switch to the
                          // regular member-style dashboard.
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const DashboardScreen(),
                            ),
                          );
                        } else {
                          // On the regular dashboard (pushed on top of the
                          // Admin Dashboard) — switch back to it.
                          Navigator.of(context).pop();
                        }
                      },
                      child: _RoleChip(role: user.role),
                    )
                  else
                    _RoleChip(role: user.role),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: minimal
                  ? const SizedBox.shrink()
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      children: isSuperAdmin
                          ? [
                              const _SectionLabel('MENU'),
                              _DrawerItem(
                                icon: Icons.add_circle_outline_rounded,
                                label: 'Add Event',
                                onTap: () {
                                  Navigator.of(context).pop();
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const AddEventScreen(),
                                    ),
                                  );
                                },
                              ),
                              _DrawerItem(
                                icon: Icons.event_note_rounded,
                                label: 'Manage Event',
                                onTap: () => _open(
                                  context,
                                  'Manage Event',
                                  Icons.event_note_rounded,
                                ),
                              ),
                              _PendingEventsDrawerItem(),
                              _PendingPaymentsDrawerItem(),
                              _HistoryDrawerItem(),
                              _ManageDataDrawerItem(),
                              const _SectionLabel('ADMIN'),
                              _AdminRequestsDrawerItem(),
                              const _SectionLabel('ACCOUNT'),
                              _ProfileDrawerItem(),
                            ]
                          : [
                              const _SectionLabel('MENU'),
                              _PendingEventsDrawerItem(),
                              _PendingPaymentsDrawerItem(),
                              _HistoryDrawerItem(),
                              _ManageDataDrawerItem(),
                              _ProfileDrawerItem(),
                            ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: _DrawerItem(
                icon: Icons.logout_rounded,
                label: 'Log out',
                color: AppColors.danger,
                onTap: () => _confirmLogout(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, String title, IconData icon) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ComingSoonScreen(title: title, icon: icon),
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
    Navigator.of(context).pop();
    await context.read<AuthService>().logout();
  }
}

/// The circular role icon at the top of the drawer. For a Member, tapping it
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
    if (widget.role != UserRole.member) return;

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
          color: Colors.white.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.75),
            width: 1.8,
          ),
        ),
        child: Icon(
          widget.role.icon,
          color: Colors.white,
          size: widget.size * 0.47,
        ),
      ),
    );
  }
}

/// Small colored pill that spells out the signed-in user's role, e.g. "Admin".
class _RoleChip extends StatelessWidget {
  final UserRole role;
  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(role.icon, size: 13, color: role.color),
          const SizedBox(width: 5),
          Text(
            role.label,
            style: TextStyle(
              color: role.color,
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
        ),
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
        Navigator.of(context).pop();
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const PendingEventsScreen()));
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
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PendingPaymentsScreen()),
        );
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
        Navigator.of(context).pop();
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
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
        Navigator.of(context).pop();
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ManageDataScreen()));
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
        Navigator.of(context).pop();
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
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
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminRequestsScreen()),
            );
          },
        );
      },
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final Widget? trailing;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final tint = onSurfaceAccent(context, color ?? AppColors.primary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: tint.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: tint, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

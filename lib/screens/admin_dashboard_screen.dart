import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';

/// A separate admin-only space, reached by double-tapping the "Admin" role
/// chip in the drawer. Shares the app's drawer chrome (header + Log out)
/// but leaves out the regular navigation menu, since it's meant to hold
/// admin-specific tools rather than the everyday event/payment flows.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser!;

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      drawer: const AppDrawer(minimal: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome,', style: Theme.of(context).textTheme.bodyMedium),
              Text(
                user.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: AppColors.admin.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_rounded,
                          color: AppColors.admin,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Admin tools coming soon',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'This space is reserved for admin-only features.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondaryLight),
                      ),
                    ],
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

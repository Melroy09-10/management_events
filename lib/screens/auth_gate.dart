import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    switch (auth.status) {
      case AuthStatus.unknown:
        return const Scaffold(
          backgroundColor: AppColors.backgroundLight,
          body: Center(child: CircularProgressIndicator()),
        );
      case AuthStatus.authenticated:
        final user = auth.currentUser!;
        final profileIncomplete =
            user.name.trim().isEmpty ||
            user.phone.trim().isEmpty ||
            user.place.trim().isEmpty;
        if (profileIncomplete) return const ProfileScreen();
        return const DashboardScreen();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}

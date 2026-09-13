import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  static const _minSplashDuration = Duration(seconds: 3);
  bool _splashElapsed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(_minSplashDuration, () {
      if (mounted) setState(() => _splashElapsed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    // Always show the splash for at least _minSplashDuration, regardless of
    // how quickly Firebase Auth resolves the signed-in state.
    if (!_splashElapsed) return const _SplashScreen();

    switch (auth.status) {
      case AuthStatus.unknown:
        return const _SplashScreen();
      case AuthStatus.authenticated:
        final user = auth.currentUser!;
        final profileIncomplete =
            user.name.trim().isEmpty ||
            user.phone.trim().isEmpty ||
            user.place.trim().isEmpty;
        return profileIncomplete
            ? const ProfileScreen()
            : const DashboardScreen();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}

/// Shown while Firebase Auth resolves the signed-in state, matching the
/// native launch splash (see flutter_native_splash config in pubspec.yaml)
/// so there's no visual jump from native splash into the Flutter UI.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: Image(image: AssetImage('assets/branding/logo.png')),
        ),
      ),
    );
  }
}

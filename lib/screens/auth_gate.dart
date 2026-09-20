import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'admin_dashboard_screen.dart';
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
        if (profileIncomplete) return const ProfileScreen();
        return user.role == UserRole.admin
            ? const AdminDashboardScreen()
            : const DashboardScreen();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}

/// Shown while Firebase Auth resolves the signed-in state, matching the
/// native launch splash (see flutter_native_splash config in pubspec.yaml)
/// so there's no visual jump from native splash into the Flutter UI. The
/// logo fades and scales in rather than just appearing.
class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.6, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: FadeTransition(
            opacity: _opacity,
            child: ScaleTransition(
              scale: _scale,
              child: const Image(image: AssetImage('assets/branding/logo.png')),
            ),
          ),
        ),
      ),
    );
  }
}

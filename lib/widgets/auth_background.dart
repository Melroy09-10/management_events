import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Plain light backdrop shared by the login and sign-up screens.
class AuthBackground extends StatelessWidget {
  final Widget child;
  const AuthBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundLight,
      child: SafeArea(child: child),
    );
  }
}

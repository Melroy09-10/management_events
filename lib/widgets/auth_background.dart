import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Decorative gradient backdrop with soft blurred blobs, shared by the
/// login and sign-up screens.
class AuthBackground extends StatelessWidget {
  final Widget child;
  const AuthBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [AppColors.backgroundDark, AppColors.backgroundDark]
                  : [AppColors.backgroundLight, const Color(0xFFEFEBFF)],
            ),
          ),
        ),
        Positioned(
          top: -80,
          left: -60,
          child: _blob(AppColors.primary.withValues(alpha: isDark ? 0.28 : 0.35), 220),
        ),
        Positioned(
          bottom: -100,
          right: -80,
          child: _blob(AppColors.secondary.withValues(alpha: isDark ? 0.22 : 0.3), 260),
        ),
        Positioned(
          top: 160,
          right: -60,
          child: _blob(AppColors.accent.withValues(alpha: isDark ? 0.16 : 0.22), 160),
        ),
        SafeArea(child: child),
      ],
    );
  }

  Widget _blob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

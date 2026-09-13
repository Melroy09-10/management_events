import 'package:flutter/material.dart';

/// Centers [child] within a maximum content width on tablet/desktop so wide
/// screens don't just stretch the mobile layout edge-to-edge, while staying
/// full-width (a no-op) on phones. Used by scrollable screen bodies.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveCenter({super.key, required this.child, this.maxWidth = 720});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Keeps every screen to a comfortable reading width on iPads and other
/// wide displays. On phones the screen is already narrower than
/// [maxWidth], so nothing changes there.
class AppFrame extends StatelessWidget {
  const AppFrame({super.key, required this.child});

  /// Widest content column, in logical points.
  static const double maxWidth = 760;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

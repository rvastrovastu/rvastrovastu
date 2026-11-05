import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The RV Astro Vastu emblem. With [glow], a soft marigold halo sits
/// behind it, used on the splash, onboarding and welcome screens.
class AppLogo extends StatelessWidget {
  static const asset = 'assets/images/logo.png';

  final double size;
  final bool glow;

  const AppLogo({super.key, this.size = 96, this.glow = false});

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      asset,
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'RV Astro Vastu',
      // Tests and broken bundles still get a sensible placeholder.
      errorBuilder: (context, error, stack) => Icon(
        Icons.auto_awesome,
        size: size * 0.6,
        color: AppColors.primary,
      ),
    );

    if (!glow) return SizedBox.square(dimension: size, child: image);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: size * 0.35,
            spreadRadius: size * 0.04,
          ),
        ],
      ),
      child: image,
    );
  }
}

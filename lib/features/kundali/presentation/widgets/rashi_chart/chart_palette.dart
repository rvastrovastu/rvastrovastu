import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// Traditional planet colours, tuned to read well on the dark theme.
Color planetColor(String planet) => switch (planet) {
  'Sun' => const Color(0xFFFFA048),
  'Moon' => const Color(0xFFE6E4FF),
  'Mars' => const Color(0xFFFF6E6E),
  'Mercury' => const Color(0xFF6FD69E),
  'Jupiter' => const Color(0xFFFFD45C),
  'Venus' => const Color(0xFFF7A8D8),
  'Saturn' => const Color(0xFF86AEFF),
  'Rahu' => const Color(0xFFB9A2F0),
  'Ketu' => const Color(0xFFDDAE7E),
  _ => AppColors.textPrimary,
};

/// Chart text size for a chart [side] pixels wide.
double chartFontSize(double side, {double factor = 0.037}) =>
    (side * factor).clamp(9.0, 16.0);

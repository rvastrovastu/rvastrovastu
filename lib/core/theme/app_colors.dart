import 'package:flutter/material.dart';

/// "Celestial premium" palette.
///
/// Named after the night sky and puja colours the app's audience already
/// knows: a deep indigo night (Raatri), marigold garland gold (Genda),
/// moonlight lilac (Chandra) for anything lunar, and kumkum red reserved
/// for active doshas and errors.
abstract final class AppColors {
  /// Raatri — app background.
  static const background = Color(0xFF0D1033);

  /// Gagan — cards and sheets.
  static const surface = Color(0xFF171B47);

  /// Akash — raised elements, selected chips, the hero card.
  static const surfaceLight = Color(0xFF232861);

  /// Hairline borders.
  static const outline = Color(0xFF353B7A);

  /// Genda (marigold) — primary actions and highlights.
  static const primary = Color(0xFFF0B43C);
  static const primaryLight = Color(0xFFF7CF78);
  static const onPrimary = Color(0xFF2A1A00);

  /// Chandra (moonlight) — Moon, tithi and other lunar elements.
  static const accent = Color(0xFFC9C6F2);
  static const onAccent = Color(0xFF1B1950);

  /// Chandni — text on the night background.
  static const textPrimary = Color(0xFFF4EFE2);
  static const textSecondary = Color(0xFFB4B1D3);
  static const textMuted = Color(0xFF7F7CA8);

  static const success = Color(0xFF6FC79A);
  static const warning = Color(0xFFF0B43C);

  /// Kumkum — errors and active doshas only.
  static const error = Color(0xFFE0605A);

  static const divider = Color(0x33353B7A);
}

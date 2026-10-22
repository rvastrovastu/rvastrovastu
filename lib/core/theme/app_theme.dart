import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Noto Sans throughout: Google's family for every script, whose Latin
/// letters are based on Open Sans. Each Indian language uses its own
/// Noto Sans script family (which also has matching Latin letters), so
/// every language gets the same look. Plain Noto Sans also covers
/// Devanagari, so mantras and aartis match on English screens too.
abstract final class AppTheme {
  static const String latinFamily = 'Noto Sans';

  static const Map<String, String> _scriptFamilies = {
    'hi': 'Noto Sans Devanagari',
    'mr': 'Noto Sans Devanagari',
    'gu': 'Noto Sans Gujarati',
    'bn': 'Noto Sans Bengali',
    'pa': 'Noto Sans Gurmukhi',
    'ta': 'Noto Sans Tamil',
    'te': 'Noto Sans Telugu',
    'kn': 'Noto Sans Kannada',
    'ml': 'Noto Sans Malayalam',
  };

  /// The font family for the app language [languageCode].
  static String familyFor(String languageCode) =>
      _scriptFamilies[languageCode] ?? latinFamily;

  static ThemeData dark([String languageCode = 'en']) {
    final family = familyFor(languageCode);
    final base = ThemeData.dark(useMaterial3: true);

    const scheme = ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: Color(0xFF4A3A12),
      onPrimaryContainer: AppColors.primaryLight,
      secondary: AppColors.accent,
      onSecondary: AppColors.onAccent,
      secondaryContainer: Color(0xFF2E2C6B),
      onSecondaryContainer: AppColors.accent,
      tertiary: AppColors.primaryLight,
      tertiaryContainer: Color(0xFF4A3A12),
      onTertiaryContainer: AppColors.primaryLight,
      error: AppColors.error,
      errorContainer: Color(0xFF5A1E22),
      onErrorContainer: Color(0xFFFFD9D6),
      surface: AppColors.background,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceContainerLowest: Color(0xFF0A0C29),
      surfaceContainerLow: AppColors.surface,
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.surfaceLight,
      surfaceContainerHighest: Color(0xFF2B3170),
      outline: AppColors.outline,
      outlineVariant: AppColors.outline,
    );

    final body = GoogleFonts.getTextTheme(family, base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    // Headings: the same family, heavier.
    TextStyle? display(
      TextStyle? style, {
      double? height,
      FontWeight weight = FontWeight.w700,
    }) => GoogleFonts.getFont(
      family,
      textStyle: style?.copyWith(height: height, fontWeight: weight),
    );

    final textTheme = body.copyWith(
      displayLarge: display(body.displayLarge, height: 1.1),
      displayMedium: display(body.displayMedium, height: 1.1),
      displaySmall: display(body.displaySmall, height: 1.15),
      headlineLarge: display(body.headlineLarge, height: 1.2),
      headlineMedium: display(body.headlineMedium, height: 1.2),
      headlineSmall: display(body.headlineSmall, height: 1.25),
      titleLarge: display(
        body.titleLarge,
        height: 1.3,
        weight: FontWeight.w600,
      ),
      bodyLarge: body.bodyLarge?.copyWith(height: 1.5),
      bodyMedium: body.bodyMedium?.copyWith(height: 1.5),
      bodySmall: body.bodySmall?.copyWith(
        height: 1.45,
        color: AppColors.textSecondary,
      ),
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      dividerColor: AppColors.divider,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.outline, width: 0.8),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.surfaceLight,
        side: const BorderSide(color: AppColors.outline, width: 0.8),
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelLarge,
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(
          color: AppColors.primary,
        ),
        checkmarkColor: AppColors.primary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size(64, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(64, 50),
          side: const BorderSide(color: AppColors.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF0A0C29),
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.surfaceLight,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textMuted,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textMuted,
          ),
        ),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        shape: Border(),
        collapsedShape: Border(),
        iconColor: AppColors.primary,
        collapsedIconColor: AppColors.textSecondary,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.surfaceLight,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        contentTextStyle: textTheme.bodyMedium,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
    );
  }
}

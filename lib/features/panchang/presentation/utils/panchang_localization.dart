import 'package:rv_astro_vastu/l10n/app_localizations.dart';

/// Converts a canonical Panchang value containing spaces into the
/// underscore-separated key expected by the ICU select localization.
String _selectKey(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), '_');
}

/// Converts Panchang Tithi values returned by the calculation engine
/// into localized display strings.
///
/// The calculation layer always keeps canonical English values.
/// Localization belongs exclusively in the presentation layer.
String localizedTithi(AppLocalizations l10n, String value) {
  final normalized = value.trim();

  if (normalized.isEmpty) {
    return normalized;
  }

  return l10n.tithiName(_selectKey(normalized));
}

/// Converts Panchang Nakshatra values returned by the calculation engine
/// into localized display strings.
///
/// The calculation layer always keeps canonical English values.
/// Localization belongs exclusively in the presentation layer.
String localizedNakshatra(AppLocalizations l10n, String value) {
  final normalized = value.trim();

  if (normalized.isEmpty) {
    return normalized;
  }

  return l10n.nakshatraName(_selectKey(normalized));
}

/// Converts Panchang Yoga values returned by the calculation engine
/// into localized display strings.
String localizedYoga(AppLocalizations l10n, String value) {
  final normalized = value.trim();

  if (normalized.isEmpty) {
    return normalized;
  }

  return l10n.yogaName(normalized);
}

import '../../../../l10n/app_localizations.dart';

String localizedPlanet(AppLocalizations l10n, String planet) {
  switch (planet.trim().toLowerCase()) {
    case 'sun':
      return l10n.sun;
    case 'moon':
      return l10n.moon;
    case 'mars':
      return l10n.mars;
    case 'mercury':
      return l10n.mercury;
    case 'jupiter':
      return l10n.jupiter;
    case 'venus':
      return l10n.venus;
    case 'saturn':
      return l10n.saturn;
    case 'rahu':
      return l10n.rahu;
    case 'ketu':
      return l10n.ketu;
    default:
      return planet;
  }
}

String localizedNakshatra(AppLocalizations l10n, String value) {
  final normalized = value.trim();

  if (normalized.isEmpty) {
    return normalized;
  }

  final key = normalized.replaceAll(RegExp(r'\s+'), '_');

  return l10n.nakshatraName(key);
}

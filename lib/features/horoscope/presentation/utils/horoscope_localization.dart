import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/daily_horoscope.dart';

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
    default:
      return planet;
  }
}

String localizedCareer(AppLocalizations l10n, DailyHoroscope horoscope) {
  return l10n.horoscopeCareer(
    horoscope.careerKey,
    localizedPlanet(l10n, horoscope.mahadasha),
    localizedPlanet(l10n, horoscope.antardasha),
  );
}

String localizedFinance(AppLocalizations l10n, DailyHoroscope horoscope) {
  return l10n.horoscopeFinance(
    horoscope.financeKey,
    localizedPlanet(l10n, horoscope.mahadasha),
    localizedPlanet(l10n, horoscope.antardasha),
  );
}

String localizedRelationships(AppLocalizations l10n, DailyHoroscope horoscope) {
  return l10n.horoscopeRelationships(
    horoscope.relationshipsKey,
    localizedNakshatra(l10n, horoscope.nakshatra),
  );
}

String localizedNakshatra(AppLocalizations l10n, String value) {
  final normalized = value.trim();

  if (normalized.isEmpty) {
    return normalized;
  }

  final key = normalized.replaceAll(RegExp(r'\s+'), '_');

  return l10n.nakshatraName(key);
}

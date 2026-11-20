import '../../../../../l10n/app_localizations.dart';
import '../../../../astrology/domain/entities/rashi_chart.dart';
import '../../../../astrology/presentation/utils/astrology_localization.dart';

/// What a screen reader says for one house of a chart, for example
/// "House 1 · Aries, Lagna. Sun, Moon Retrograde". The drawn chart is
/// lines and short marks that mean nothing read aloud.
String houseSpokenLabel(AppLocalizations l10n, RashiHouse house) {
  final title = l10n.chartHouseTitle(house.house, l10n.rashiName(house.sign));
  final lagna = house.house == 1 ? ', ${l10n.chartLagnaMark}' : '';
  final planets = house.planets.isEmpty
      ? l10n.chartHouseEmpty
      : house.planets
            .map(
              (p) => p.retrograde
                  ? '${l10n.planetName(p.planet)} ${l10n.retrograde}'
                  : l10n.planetName(p.planet),
            )
            .join(', ');
  return '$title$lagna. $planets';
}

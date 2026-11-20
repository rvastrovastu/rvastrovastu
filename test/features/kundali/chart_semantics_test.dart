import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/astrology/domain/entities/planet_position.dart';
import 'package:rv_astro_vastu/features/astrology/domain/entities/rashi_chart.dart';
import 'package:rv_astro_vastu/features/kundali/presentation/widgets/rashi_chart/chart_semantics.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  test('reads the Lagna house with its planets', () {
    const house = RashiHouse(
      house: 1,
      sign: 'Aries',
      planets: [
        PlanetPosition(
          planet: 'Sun',
          sign: 'Aries',
          house: 1,
          longitude: 10,
          degree: 10,
        ),
        PlanetPosition(
          planet: 'Saturn',
          sign: 'Aries',
          house: 1,
          longitude: 20,
          degree: 20,
          retrograde: true,
        ),
      ],
    );
    final label = houseSpokenLabel(l10n, house);
    expect(label, contains('House 1'));
    expect(label, contains(l10n.chartLagnaMark));
    expect(label, contains(l10n.sun));
    expect(label, contains('${l10n.saturn} ${l10n.retrograde}'));
  });

  test('says when a house is empty', () {
    const house = RashiHouse(house: 7, sign: 'Libra', planets: []);
    final label = houseSpokenLabel(l10n, house);
    expect(label, contains('House 7'));
    expect(label, isNot(contains(l10n.chartLagnaMark)));
    expect(label, contains(l10n.chartHouseEmpty));
  });
}

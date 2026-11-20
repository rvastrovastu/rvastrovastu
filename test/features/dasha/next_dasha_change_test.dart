import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/dasha/domain/entities/dasha_birth_data.dart';
import 'package:rv_astro_vastu/features/dasha/domain/entities/dasha_period.dart';
import 'package:rv_astro_vastu/features/dasha/domain/usecases/calculate_vimshottari_dasha.dart';
import 'package:rv_astro_vastu/features/dasha/domain/usecases/next_dasha_change.dart';

void main() {
  // Reference chart (see dasha_birth_instant_test): Moon mahadasha runs to
  // late 2021, then Mars.
  final timeline = CalculateVimshottariDasha()(
    birthData: DashaBirthData(
      birthDate: DateTime.utc(1950, 9, 17, 5, 30),
      moonLongitude: 218.8079,
    ),
  );
  final moon = timeline.periods.firstWhere(
    (p) => p.level == 1 && p.planet == DashaPlanet.moon,
  );

  test('the last antardasha leads into the next mahadasha', () {
    final change = nextDashaChange(
      timeline,
      moon.endDate.subtract(const Duration(days: 10)),
    );
    expect(change, isNotNull);
    expect(change!.isMahadasha, isTrue);
    expect(change.planet, DashaPlanet.mars);
    expect(change.date, moon.endDate);
  });

  test('a change inside a mahadasha names the next antardasha', () {
    final antardashas = CalculateVimshottariDasha().antardashas(moon);
    final first = antardashas.first;
    final change = nextDashaChange(
      timeline,
      first.endDate.subtract(const Duration(days: 5)),
    );
    expect(change!.isMahadasha, isFalse);
    expect(change.planet, antardashas.elementAt(1).planet);
  });

  test('nothing is reported when the next change is far away', () {
    final antardashas = CalculateVimshottariDasha().antardashas(moon);
    final first = antardashas.first;
    expect(
      nextDashaChange(timeline, first.startDate, within: const Duration(days: 1)),
      isNull,
    );
  });
}

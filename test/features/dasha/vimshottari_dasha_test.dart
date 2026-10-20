import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/dasha/domain/entities/dasha_birth_data.dart';
import 'package:rv_astro_vastu/features/dasha/domain/entities/dasha_period.dart';
import 'package:rv_astro_vastu/features/dasha/domain/usecases/calculate_vimshottari_dasha.dart';

void main() {
  group('Vimshottari Dasha', () {
    test('uses Moon longitude to determine starting Mahadasha', () {
      final birthData = DashaBirthData(
        birthDate: DateTime(1983, 1, 3, 6, 0),
        moonLongitude: 48.4,
      );

      final timeline = CalculateVimshottariDasha().call(birthData: birthData);

      expect(timeline.periods, isNotEmpty);
      expect(timeline.periods.first.level, 1);

      final firstPlanet = timeline.periods.first.planet;

      expect(DashaPlanet.values, contains(firstPlanet));

      expect(timeline.periods.first.startDate, equals(birthData.birthDate));

      expect(
        timeline.periods.first.endDate.isAfter(
          timeline.periods.first.startDate,
        ),
        isTrue,
      );
    });

    test('generates nine Mahadasha periods', () {
      final birthData = DashaBirthData(
        birthDate: DateTime(1983, 1, 3, 6, 0),
        moonLongitude: 48.4,
      );

      final timeline = CalculateVimshottariDasha().call(birthData: birthData);

      expect(timeline.periods.length, 9);
      expect(timeline.periods.every((period) => period.level == 1), isTrue);
    });

    test('generates Antardashas inside a Mahadasha', () {
      final birthData = DashaBirthData(
        birthDate: DateTime(1983, 1, 3, 6, 0),
        moonLongitude: 48.4,
      );

      final timeline = CalculateVimshottariDasha().call(birthData: birthData);

      final mahadasha = timeline.periods.first;

      final antardashas = CalculateVimshottariDasha().antardashas(mahadasha);

      expect(antardashas.length, 9);

      expect(antardashas.every((period) => period.level == 2), isTrue);

      expect(antardashas.first.startDate, equals(mahadasha.startDate));

      expect(antardashas.last.endDate, equals(mahadasha.endDate));
    });
  });
}

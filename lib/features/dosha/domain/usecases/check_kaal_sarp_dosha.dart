import '../../../astrology/domain/entities/kundali.dart';
import '../../../astrology/domain/entities/planet_position.dart';
import '../entities/kaal_sarp_result.dart';

/// Checks Kaal Sarp yoga: whether the seven classical planets (Sun to
/// Saturn) all fall on one side of the Rahu–Ketu axis.
///
/// Uses exact sidereal longitudes rather than signs, so a planet in the
/// same sign as Rahu but behind it is correctly treated as outside the arc.
/// A planet sitting exactly on the axis counts as outside.
class CheckKaalSarpDosha {
  static const List<String> classicalPlanets = [
    'Sun',
    'Moon',
    'Mars',
    'Mercury',
    'Jupiter',
    'Venus',
    'Saturn',
  ];

  const CheckKaalSarpDosha();

  KaalSarpResult call(Kundali kundali) {
    final rahu = _planet(kundali, 'Rahu');
    final ketu = _planet(kundali, 'Ketu');

    final rahuToKetuSide = <String>[];
    final ketuToRahuSide = <String>[];

    for (final name in classicalPlanets) {
      final planet = _planet(kundali, name);
      final offset = _normalize(planet.longitude - rahu.longitude);

      if (offset > 0 && offset < 180) {
        rahuToKetuSide.add(name);
      } else if (offset > 180 && offset < 360) {
        ketuToRahuSide.add(name);
      }
      // Exactly 0° or 180° (on the axis) belongs to neither side.
    }

    final total = classicalPlanets.length;

    KaalSarpDirection? direction;
    List<String> outside = const [];
    var status = KaalSarpStatus.none;

    if (rahuToKetuSide.length == total) {
      status = KaalSarpStatus.full;
      direction = KaalSarpDirection.rahuToKetu;
    } else if (ketuToRahuSide.length == total) {
      status = KaalSarpStatus.full;
      direction = KaalSarpDirection.ketuToRahu;
    } else if (rahuToKetuSide.length == total - 1) {
      status = KaalSarpStatus.partial;
      direction = KaalSarpDirection.rahuToKetu;
      outside = _others(rahuToKetuSide);
    } else if (ketuToRahuSide.length == total - 1) {
      status = KaalSarpStatus.partial;
      direction = KaalSarpDirection.ketuToRahu;
      outside = _others(ketuToRahuSide);
    }

    return KaalSarpResult(
      status: status,
      direction: direction,
      type: status == KaalSarpStatus.none
          ? null
          : kaalSarpTypeForRahuHouse(rahu.house),
      rahuHouse: rahu.house,
      ketuHouse: ketu.house,
      planetsOutside: outside,
    );
  }

  List<String> _others(List<String> inside) =>
      classicalPlanets.where((p) => !inside.contains(p)).toList();

  double _normalize(double degrees) {
    final value = degrees % 360.0;
    return value < 0 ? value + 360.0 : value;
  }

  PlanetPosition _planet(Kundali kundali, String name) {
    for (final planet in kundali.planets) {
      if (planet.planet == name) return planet;
    }
    throw ArgumentError('Kundali is missing $name.');
  }
}

import 'dart:math' as math;

import '../../../astrology/domain/entities/kundali.dart';
import '../../../astrology/domain/entities/planet_position.dart';
import '../../../astrology/domain/entities/rashi_chart.dart';
import '../../../dosha/domain/entities/zodiac_signs.dart';

/// The charts the Kundali can show: the birth chart, the Moon chart and
/// the sixteen Parashari divisional charts (Shodashvarga).
enum Varga {
  d1,
  moon,
  d9,
  d10,
  d7,
  d2,
  d3,
  d4,
  d12,
  d16,
  d20,
  d24,
  d27,
  d30,
  d40,
  d45,
  d60,
}

extension VargaInfo on Varga {
  /// Free for everyone; the rest are Premium.
  bool get isFree => this == Varga.d1 || this == Varga.moon;

  /// The division number (1 for D1 and the Moon chart).
  int get division => switch (this) {
    Varga.d1 || Varga.moon => 1,
    Varga.d2 => 2,
    Varga.d3 => 3,
    Varga.d4 => 4,
    Varga.d7 => 7,
    Varga.d9 => 9,
    Varga.d10 => 10,
    Varga.d12 => 12,
    Varga.d16 => 16,
    Varga.d20 => 20,
    Varga.d24 => 24,
    Varga.d27 => 27,
    Varga.d30 => 30,
    Varga.d40 => 40,
    Varga.d45 => 45,
    Varga.d60 => 60,
  };
}

/// A divisional chart with whole-sign houses from its own Lagna.
class VargaChart {
  final Varga varga;
  final RashiChart chart;
  final String lagnaSign;

  const VargaChart({
    required this.varga,
    required this.chart,
    required this.lagnaSign,
  });
}

/// Builds any [Varga] from a Kundali using the Parashari rules.
class CalculateVarga {
  const CalculateVarga();

  /// The sign (Aries = 0) and degree within it that sidereal [longitude]
  /// falls in, in [varga].
  static (int, double) place(Varga varga, double longitude) {
    final lon = ((longitude % 360) + 360) % 360;
    final sign = lon ~/ 30;
    final deg = lon - sign * 30;
    final odd = sign.isEven; // Aries, the first sign, is odd.
    final modality = sign % 3; // 0 movable, 1 fixed, 2 dual

    // [n] equal parts; part p goes to sign start + p * step.
    (int, double) parts(int n, int start, {int step = 1}) {
      final span = 30 / n;
      final p = math.min((deg / span).floor(), n - 1);
      return ((start + p * step) % 12, (deg - p * span) / span * 30);
    }

    switch (varga) {
      case Varga.d1:
      case Varga.moon:
        return (sign, deg);
      case Varga.d2:
        // Hora: Sun's hora is Leo, Moon's is Cancer.
        final first = deg < 15;
        final sunHora = odd == first;
        return (sunHora ? 4 : 3, (deg % 15) * 2);
      case Varga.d3:
        return parts(3, sign, step: 4);
      case Varga.d4:
        return parts(4, sign, step: 3);
      case Varga.d7:
        return parts(7, odd ? sign : sign + 6);
      case Varga.d9:
        return parts(9, sign * 9 % 12);
      case Varga.d10:
        return parts(10, odd ? sign : sign + 8);
      case Varga.d12:
        return parts(12, sign);
      case Varga.d16:
        return parts(16, const [0, 4, 8][modality]);
      case Varga.d20:
        return parts(20, const [0, 8, 4][modality]);
      case Varga.d24:
        return parts(24, odd ? 4 : 3);
      case Varga.d27:
        return parts(27, sign * 27 % 12);
      case Varga.d30:
        return _trimshamsha(deg, odd);
      case Varga.d40:
        return parts(40, odd ? 0 : 6);
      case Varga.d45:
        return parts(45, const [0, 4, 8][modality]);
      case Varga.d60:
        return parts(60, sign);
    }
  }

  /// Trimshamsha: five unequal parts ruled by Mars, Saturn, Jupiter,
  /// Mercury and Venus (reversed for even signs).
  static (int, double) _trimshamsha(double deg, bool odd) {
    // (end degree, sign) pairs.
    const oddParts = [(5.0, 0), (10.0, 10), (18.0, 8), (25.0, 2), (30.0, 6)];
    const evenParts = [(5.0, 1), (12.0, 5), (20.0, 11), (25.0, 9), (30.0, 7)];
    var start = 0.0;
    for (final (end, sign) in odd ? oddParts : evenParts) {
      if (deg < end || end == 30) {
        return (sign, (deg - start) / (end - start) * 30);
      }
      start = end;
    }
    throw StateError('unreachable');
  }

  VargaChart call(Kundali kundali, Varga varga) {
    final ascendantIndex = zodiacSignIndex(kundali.ascendant);
    if (ascendantIndex < 0) {
      throw ArgumentError('Unknown ascendant sign: "${kundali.ascendant}".');
    }

    final int lagnaIndex;
    if (varga == Varga.moon) {
      lagnaIndex = ((kundali.moonLongitude % 360 + 360) % 360) ~/ 30;
    } else {
      lagnaIndex = place(varga, ascendantIndex * 30 + kundali.ascendantDegree).$1;
    }

    final planets = [
      for (final planet in kundali.planets)
        if (place(varga, planet.longitude) case (final sign, final degree))
          PlanetPosition(
            planet: planet.planet,
            sign: zodiacSigns[sign],
            house: (sign - lagnaIndex + 12) % 12 + 1,
            longitude: sign * 30 + degree,
            degree: degree,
            retrograde: planet.retrograde,
            // Nakshatras belong to the birth chart's longitudes.
            nakshatra: varga.division == 1 ? planet.nakshatra : null,
            nakshatraPada: varga.division == 1 ? planet.nakshatraPada : null,
          ),
    ];

    return VargaChart(
      varga: varga,
      lagnaSign: zodiacSigns[lagnaIndex],
      chart: RashiChart(
        houses: [
          for (var house = 1; house <= 12; house++)
            RashiHouse(
              house: house,
              sign: zodiacSigns[(lagnaIndex + house - 1) % 12],
              planets: [
                for (final p in planets)
                  if (p.house == house) p,
              ],
            ),
        ],
      ),
    );
  }
}

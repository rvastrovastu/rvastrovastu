import '../../astrology/domain/entities/kundali.dart';
import '../../dasha/domain/entities/dasha_period.dart';
import '../../dosha/domain/entities/zodiac_signs.dart';
import '../../gochar/domain/entities/transit.dart';

String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// The chart summary sent with each question. Only what the reading
/// needs: no name, birthplace or exact birth time.
Map<String, Object?> buildChartContext({
  required Kundali kundali,
  required DateTime today,
  DashaPeriod? mahadasha,
  DashaPeriod? antardasha,
  GocharReport? gochar,
}) {
  Map<String, Object?> dasha(DashaPeriod p) => {
    'planet': p.planet.name,
    'from': _date(p.startDate),
    'to': _date(p.endDate),
  };

  String? sadeSati;
  for (final t in gochar?.current ?? const <TransitReading>[]) {
    if (t.planet != TransitPlanet.saturn) continue;
    sadeSati = switch (t.houseFromMoon) {
      12 => 'rising phase',
      1 => 'peak phase',
      2 => 'setting phase',
      _ => 'not running',
    };
  }

  return {
    'today': _date(today),
    'system': 'Vedic, sidereal Lahiri, whole-sign houses',
    'lagna': {
      'sign': kundali.ascendant,
      'degree': double.parse(kundali.ascendantDegree.toStringAsFixed(1)),
    },
    'moon': {
      'sign': kundali.moonSign,
      'nakshatra': kundali.nakshatra,
      'pada': kundali.nakshatraPada,
    },
    'sun_sign': kundali.sunSign,
    'planets': [
      for (final p in kundali.planets)
        {
          'planet': p.planet,
          'sign': p.sign,
          'house': p.house,
          'degree': double.parse(p.degree.toStringAsFixed(1)),
          if (p.retrograde) 'retrograde': true,
          if (p.nakshatra != null) 'nakshatra': p.nakshatra,
        },
    ],
    'vimshottari_dasha': {
      if (mahadasha != null) 'mahadasha': dasha(mahadasha),
      if (antardasha != null) 'antardasha': dasha(antardasha),
    },
    if (gochar != null)
      'transits_now': [
        for (final t in gochar.current)
          {
            'planet': t.planet.displayKey,
            'sign': zodiacSigns[t.signIndex],
            'house_from_moon': t.houseFromMoon,
            'house_from_lagna': t.houseFromLagna,
            'reading': t.tone.name,
            if (t.until != null) 'until': _date(t.until!),
          },
      ],
    if (sadeSati != null) 'sade_sati': sadeSati,
  };
}

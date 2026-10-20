import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/astrology/domain/entities/kundali.dart';
import 'package:rv_astro_vastu/features/astrology/domain/entities/planet_position.dart';
import 'package:rv_astro_vastu/features/astrology/domain/entities/rashi_chart.dart';
import 'package:rv_astro_vastu/features/dasha/domain/entities/dasha_period.dart';
import 'package:rv_astro_vastu/features/dosha/domain/entities/zodiac_signs.dart';
import 'package:rv_astro_vastu/features/dosha/domain/usecases/calculate_sade_sati.dart';
import 'package:rv_astro_vastu/features/dosha/domain/usecases/check_kaal_sarp_dosha.dart';
import 'package:rv_astro_vastu/features/dosha/domain/usecases/check_manglik_dosha.dart';
import 'package:rv_astro_vastu/features/dosha/presentation/providers/dosha_provider.dart';
import 'package:rv_astro_vastu/features/gochar/domain/entities/transit.dart';
import 'package:rv_astro_vastu/features/kundali/data/services/kundli_pdf_service.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';

import '../dosha/dosha_test_helpers.dart' show saturnPeriods;

Kundali _kundali() {
  const lagna = 5; // Virgo
  PlanetPosition p(String name, double longitude, {bool retro = false}) {
    final signIndex = (longitude / 30).floor();
    return PlanetPosition(
      planet: name,
      sign: zodiacSigns[signIndex],
      house: houseFrom(lagna, signIndex),
      longitude: longitude,
      degree: longitude % 30,
      retrograde: retro,
      nakshatra: 'Rohini',
      nakshatraPada: 2,
    );
  }

  final planets = [
    p('Sun', 236.53),
    p('Moon', 139.01),
    p('Mars', 198.55),
    p('Mercury', 230.70),
    p('Jupiter', 356.09, retro: true),
    p('Venus', 264.59),
    p('Saturn', 239.52),
    p('Rahu', 334.50, retro: true),
    p('Ketu', 154.50, retro: true),
  ];

  return Kundali(
    ascendant: 'Virgo',
    ayanamsa: 23.69,
    ascendantDegree: 2.92,
    moonLongitude: 139.01,
    moonSign: 'Leo',
    sunSign: 'Scorpio',
    nakshatra: 'Purva Phalguni',
    nakshatraPada: 2,
    planets: planets,
    rashiChart: RashiChart(
      houses: [
        for (var h = 1; h <= 12; h++)
          RashiHouse(
            house: h,
            sign: zodiacSigns[(lagna + h - 1) % 12],
            planets: [
              for (final planet in planets)
                if (planet.house == h) planet,
            ],
          ),
      ],
    ),
  );
}

KundliReportData _fullReport() {
  final kundali = _kundali();
  return KundliReportData(
    name: 'LV',
    dateOfBirth: DateTime(1987, 12, 13),
    birthTime: '00:42',
    place: 'New Delhi, India',
    kundali: kundali,
    mahadashas: [
      DashaPeriod(
        planet: DashaPlanet.venus,
        startDate: DateTime(1987, 12, 13),
        endDate: DateTime(2000, 6, 1),
      ),
      DashaPeriod(
        planet: DashaPlanet.rahu,
        startDate: DateTime(2020, 6, 1),
        endDate: DateTime(2038, 6, 1),
      ),
    ],
    currentMahadasha: DashaPeriod(
      planet: DashaPlanet.rahu,
      startDate: DateTime(2020, 6, 1),
      endDate: DateTime(2038, 6, 1),
    ),
    currentAntardasha: DashaPeriod(
      planet: DashaPlanet.saturn,
      startDate: DateTime(2025, 1, 1),
      endDate: DateTime(2027, 11, 1),
      level: 2,
    ),
    doshas: DoshaReport(
      kundali: kundali,
      manglik: const CheckManglikDosha()(kundali),
      kaalSarp: const CheckKaalSarpDosha()(kundali),
      sadeSati: const CalculateSadeSati()(
        moonSign: 'Leo',
        saturnPeriods: saturnPeriods,
        referenceDate: DateTime.utc(2026, 10, 16),
      ),
    ),
    transits: GocharReport(
      current: const [
        TransitReading(
          planet: TransitPlanet.saturn,
          signIndex: 11,
          houseFromMoon: 8,
          houseFromLagna: 7,
          tone: TransitTone.challenging,
        ),
      ],
      upcoming: const [],
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final code in ['en', 'hi', 'mr']) {
    test('builds a full $code report', () async {
      final bytes = await const KundliPdfService().build(
        _fullReport(),
        lookupAppLocalizations(Locale(code)),
        generatedAt: DateTime(2026, 10, 16),
      );

      expect(bytes.length, greaterThan(5000));
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    });
  }

  test('works without dosha or transit sections', () async {
    final bytes = await const KundliPdfService().build(
      KundliReportData(
        name: 'Minimal',
        dateOfBirth: DateTime(1990, 1, 1),
        birthTime: '06:00',
        place: 'Dallas, Texas',
        kundali: _kundali(),
      ),
      lookupAppLocalizations(const Locale('en')),
    );

    expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
  });
}

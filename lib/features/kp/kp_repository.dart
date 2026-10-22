import 'package:swisseph/swisseph.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/astro/swiss_eph_loader.dart';
import 'kp.dart';

/// Casts KP charts with Swiss Ephemeris (Krishnamurti ayanamsa, Placidus,
/// mean nodes).
class KpRepository {
  static const double _unixEpochJd = 2440587.5;

  static const _bodies = {
    'Sun': seSun,
    'Moon': seMoon,
    'Mars': seMars,
    'Mercury': seMercury,
    'Jupiter': seJupiter,
    'Venus': seVenus,
    'Saturn': seSaturn,
    'Rahu': seMeanNode,
  };

  Future<KpChart> cast({
    required DateTime utc,
    required double latitude,
    required double longitude,
    required String timezone,
  }) async {
    final swe = await loadSwissEph();
    try {
      swe.setSidMode(seSidmKrishnamurti);
      final jd =
          _unixEpochJd +
          utc.toUtc().millisecondsSinceEpoch / Duration.millisecondsPerDay;
      final houses = swe.housesEx(
        jd,
        seFlgSidereal,
        latitude,
        longitude,
        'P'.codeUnitAt(0),
      );
      final planets = <String, double>{
        for (final MapEntry(key: name, value: body) in _bodies.entries)
          name: _norm(
            swe.calcUt(jd, body, seFlgSwiEph | seFlgSidereal).longitude,
          ),
      };
      planets['Ketu'] = _norm(planets['Rahu']! + 180);
      final local = tz.TZDateTime.from(utc, tz.getLocation(timezone.trim()));
      return KpChart(
        cusps: [for (var i = 1; i <= 12; i++) _norm(houses.cusps[i])],
        planets: planets,
        local: DateTime(
          local.year,
          local.month,
          local.day,
          local.hour,
          local.minute,
        ),
      );
    } finally {
      swe.close();
    }
  }

  static double _norm(double v) => (v % 360 + 360) % 360;
}

/// UTC moment of a birth date and clock time ("10:30 AM", "22:05:10") in
/// an IANA zone.
DateTime birthMomentUtc(DateTime date, String time, String timezone) {
  final t = time.trim().toUpperCase();
  final pm = t.contains('PM');
  final am = t.contains('AM');
  final parts = t.replaceAll('AM', '').replaceAll('PM', '').trim().split(':');
  var hour = int.parse(parts[0]);
  final minute = parts.length > 1 ? int.parse(parts[1]) : 0;
  final second = parts.length > 2 ? int.parse(parts[2]) : 0;
  if (pm && hour < 12) hour += 12;
  if (am && hour == 12) hour = 0;
  return tz.TZDateTime(
    tz.getLocation(timezone.trim()),
    date.year,
    date.month,
    date.day,
    hour,
    minute,
    second,
  ).toUtc();
}

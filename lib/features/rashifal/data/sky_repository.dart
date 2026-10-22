import 'package:swisseph/swisseph.dart';

import '../../../core/astro/swiss_eph_loader.dart';
import '../domain/rashifal.dart';

/// Sidereal (Lahiri) signs of the nine planets at given moments.
abstract class SkyRepository {
  Future<List<SkySnapshot>> snapshots(List<DateTime> utcMoments);
}

class SwissEphemerisSkyRepository implements SkyRepository {
  static const int _flags = seFlgSwiEph | seFlgSidereal;
  static const double _unixEpochJd = 2440587.5;

  static const Map<String, int> _bodies = {
    'Sun': seSun,
    'Moon': seMoon,
    'Mars': seMars,
    'Mercury': seMercury,
    'Jupiter': seJupiter,
    'Venus': seVenus,
    'Saturn': seSaturn,
    'Rahu': seMeanNode,
  };

  @override
  Future<List<SkySnapshot>> snapshots(List<DateTime> utcMoments) async {
    final swe = await loadSwissEph();
    try {
      swe.setSidMode(seSidmLahiri);
      final result = <SkySnapshot>[];
      for (final moment in utcMoments) {
        final jd =
            _unixEpochJd +
            moment.toUtc().millisecondsSinceEpoch / Duration.millisecondsPerDay;
        final signs = <String, int>{};
        for (final MapEntry(key: name, value: body) in _bodies.entries) {
          final lon = swe.calcUt(jd, body, _flags).longitude % 360;
          signs[name] = ((lon < 0 ? lon + 360 : lon) / 30).floor() % 12;
        }
        signs['Ketu'] = (signs['Rahu']! + 6) % 12;
        result.add(SkySnapshot(moment.toUtc(), signs));
      }
      return result;
    } finally {
      swe.close();
    }
  }
}

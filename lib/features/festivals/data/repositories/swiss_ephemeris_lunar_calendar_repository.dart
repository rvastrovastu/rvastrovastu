import 'dart:io';

import 'package:swisseph/swisseph.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/lunar_calendar_data.dart';
import '../../domain/repositories/lunar_calendar_repository.dart';

/// Computes tithi intervals, new moons, sankrantis and daily rise/set times
/// with Swiss Ephemeris (Lahiri sidereal), in one library session.
///
/// Tithi and sign changes are found by stepping and bisecting to within a
/// minute. The algorithm was checked in Python with pyswisseph against
/// published 2026 festival dates before porting.
class SwissEphemerisLunarCalendarRepository implements LunarCalendarRepository {
  static const int _flags = seFlgSwiEph | seFlgSidereal;
  static const double _unixEpochJd = 2440587.5;
  static const double _precision = 1 / 1440; // one minute

  /// Extra lunar data so the months at the range edges can be named.
  static const Duration _leadIn = Duration(days: 45);
  static const Duration _leadOut = Duration(days: 40);

  @override
  Future<LunarCalendarData> calculate({
    required DateTime fromDate,
    required DateTime toDate,
    required double latitude,
    required double longitude,
    required String timezone,
  }) async {
    final location = tz.getLocation(timezone.trim());
    final swe = await _loadSwissEph();

    try {
      swe.setSidMode(seSidmLahiri);

      double longitudeOf(double jd, int body) {
        final value = swe.calcUt(jd, body, _flags).longitude % 360;
        return value < 0 ? value + 360 : value;
      }

      int tithiAt(double jd) {
        var elongation = longitudeOf(jd, seMoon) - longitudeOf(jd, seSun);
        elongation %= 360;
        if (elongation < 0) elongation += 360;
        return (elongation / 12).floor() % 30;
      }

      int sunSignAt(double jd) => (longitudeOf(jd, seSun) / 30).floor() % 12;

      final startJd = _toJd(
        _localMidnight(location, fromDate).subtract(_leadIn),
      );
      final endJd = _toJd(_localMidnight(location, toDate).add(_leadOut));

      // Tithi segments and new moons.
      final tithiChanges = _scan(tithiAt, startJd, endJd, 0.25);
      final tithis = <TithiSegment>[];
      final newMoons = <NewMoon>[];
      var segmentStart = startJd;
      var current = tithiAt(startJd);
      for (final change in tithiChanges) {
        tithis.add(
          TithiSegment(
            index: current,
            start: _fromJd(segmentStart),
            end: _fromJd(change.jd),
          ),
        );
        if (change.from == 29 && change.to == 0) {
          newMoons.add(
            NewMoon(
              time: _fromJd(change.jd),
              sunSignIndex: sunSignAt(change.jd),
            ),
          );
        }
        current = change.to;
        segmentStart = change.jd;
      }
      tithis.add(
        TithiSegment(
          index: current,
          start: _fromJd(segmentStart),
          end: _fromJd(endJd),
        ),
      );

      // Solar ingresses.
      final sankrantis = [
        for (final change in _scan(sunSignAt, startJd, endJd, 1))
          Sankranti(
            time: _fromJd(change.jd),
            localDate: _localDate(location, _fromJd(change.jd)),
            signIndex: change.to,
          ),
      ];

      // Daily sunrise, sunset and moonrise.
      double? riseOrSet(double jd, int body, int flag) {
        final result = swe.riseTrans(
          jd,
          body,
          rsmi: flag,
          geolon: longitude,
          geolat: latitude,
        );
        if (result.returnFlag < 0 || result.transitTime == 0) return null;
        return result.transitTime;
      }

      final first = DateTime(fromDate.year, fromDate.month, fromDate.day - 1);
      final last = DateTime(toDate.year, toDate.month, toDate.day + 1);
      final days = <SolarDay>[];
      double? pendingSunrise;

      for (
        var date = last;
        !date.isBefore(first);
        date = DateTime(date.year, date.month, date.day - 1)
      ) {
        final midnight = _toJd(_localMidnight(location, date));
        final nextMidnight = _toJd(
          _localMidnight(
            location,
            DateTime(date.year, date.month, date.day + 1),
          ),
        );

        final sunrise = riseOrSet(midnight, seSun, seCalcRise);
        final sunset = riseOrSet(midnight, seSun, seCalcSet);
        final moonrise = riseOrSet(midnight, seMoon, seCalcRise);
        final nextSunrise =
            pendingSunrise ??
            (sunrise == null
                ? null
                : riseOrSet(sunrise + 0.1, seSun, seCalcRise));

        days.add(
          SolarDay(
            date: date,
            sunrise: _within(sunrise, midnight, nextMidnight),
            sunset: _within(sunset, midnight, nextMidnight),
            nextSunrise: nextSunrise == null ? null : _fromJd(nextSunrise),
            moonrise: _within(moonrise, midnight, nextMidnight),
          ),
        );

        pendingSunrise = sunrise;
      }

      return LunarCalendarData(
        tithis: tithis,
        newMoons: newMoons,
        sankrantis: sankrantis,
        days: days.reversed.toList(),
      );
    } finally {
      swe.close();
    }
  }

  /// Keeps an event only if it falls on this local day.
  static DateTime? _within(double? jd, double dayStart, double dayEnd) {
    if (jd == null || jd < dayStart || jd >= dayEnd) return null;
    return _fromJd(jd);
  }

  /// Steps through [startJd, endJd] and bisects each change of [valueAt].
  /// Steps are short enough (6 h for tithis, 1 day for solar signs) that
  /// two changes can never fall inside one step.
  static List<_Change> _scan(
    int Function(double jd) valueAt,
    double startJd,
    double endJd,
    double stepDays,
  ) {
    final changes = <_Change>[];
    var jd = startJd;
    var value = valueAt(jd);

    while (jd < endJd) {
      final next = (jd + stepDays) > endJd ? endJd : jd + stepDays;
      final nextValue = valueAt(next);

      if (nextValue != value) {
        var low = jd;
        var high = next;
        while (high - low > _precision) {
          final mid = (low + high) / 2;
          if (valueAt(mid) == value) {
            low = mid;
          } else {
            high = mid;
          }
        }
        changes.add(_Change(high, value, nextValue));
        value = nextValue;
      }

      jd = next;
    }

    return changes;
  }

  static tz.TZDateTime _localMidnight(tz.Location location, DateTime date) =>
      tz.TZDateTime(location, date.year, date.month, date.day);

  static DateTime _localDate(tz.Location location, DateTime utc) {
    final local = tz.TZDateTime.from(utc, location);
    return DateTime(local.year, local.month, local.day);
  }

  static double _toJd(DateTime instant) =>
      _unixEpochJd +
      instant.toUtc().millisecondsSinceEpoch / Duration.millisecondsPerDay;

  static DateTime _fromJd(double jd) => DateTime.fromMillisecondsSinceEpoch(
    ((jd - _unixEpochJd) * Duration.millisecondsPerDay).round(),
    isUtc: true,
  );

  Future<SwissEph> _loadSwissEph() async {
    if (Platform.isIOS) {
      final appDirectory = File(Platform.resolvedExecutable).parent;
      final framework =
          '${appDirectory.path}/Frameworks/swisseph.framework/swisseph';
      if (File(framework).existsSync()) return SwissEph(framework);
      throw StateError('Swiss Ephemeris framework not found at: $framework');
    }

    if (Platform.isMacOS) {
      final contents = File(Platform.resolvedExecutable).parent.parent;
      final framework =
          '${contents.path}/Frameworks/swisseph.framework/swisseph';
      if (File(framework).existsSync()) return SwissEph(framework);
    }

    return SwissEph.load();
  }
}

class _Change {
  final double jd;
  final int from;
  final int to;

  const _Change(this.jd, this.from, this.to);
}

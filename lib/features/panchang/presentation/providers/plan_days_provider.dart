import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/time/app_clock_provider.dart';
import '../../../astrology/presentation/providers/astrology_provider.dart';
import '../../../daily_loop/domain/personal_muhurat.dart';
import '../../../your_day/domain/day_strength.dart';
import '../../../your_day/presentation/your_day_provider.dart';
import '../../domain/entities/daily_panchang_input.dart';
import '../../domain/entities/day_divisions.dart';
import 'day_divisions_provider.dart';
import 'panchang_location_provider.dart';

/// A time span in UTC.
typedef Span = ({DateTime start, DateTime end});

/// A good Choghadiya inside a day.
typedef GoodSlot = ({Span span, Choghadiya kind});

class PersonalPlanDay {
  final DateTime date;
  final List<MuhuratWindow> windows;

  const PersonalPlanDay({required this.date, required this.windows});
}

class TodayPlanDay {
  final DateTime date;
  final Span? abhijit;
  final Span? rahuKaal;
  final List<GoodSlot> good;

  const TodayPlanDay({
    required this.date,
    required this.abhijit,
    required this.rahuKaal,
    required this.good,
  });
}

DateTime _dayOn(DateTime now, tz.Location zone, int offset) {
  final local = tz.TZDateTime.from(now.toUtc(), zone);
  return DateTime(local.year, local.month, local.day + offset);
}

DailyPanchangInput _inputFor(DateTime date, PanchangPlace place) {
  final location = place.location;
  return DailyPanchangInput(
    date: date,
    latitude: location.latitude,
    longitude: location.longitude,
    timezone: location.timezone,
  );
}

/// For "For you": the best windows on each of the next [days] days for the
/// chosen purpose. Today only counts from now on.
final personalPlanProvider = FutureProvider.autoDispose
    .family<List<PersonalPlanDay>, ({int days, MuhuratPurpose purpose})>((
      ref,
      key,
    ) async {
      final kundali = await ref.watch(kundaliProvider.future);
      if (kundali == null) return const [];
      final place = ref.watch(panchangPlaceProvider).value;
      if (place == null) return const [];

      final now = ref.watch(appClockProvider);
      final zone = tz.getLocation(place.location.timezone);
      final birthNakshatra = nakshatraIndexOf(kundali.moonLongitude);

      final out = <PersonalPlanDay>[];
      for (var i = 0; i < key.days; i++) {
        final date = _dayOn(now, zone, i);
        final vedic = await ref.watch(
          dayDivisionsProvider(_inputFor(date, place)).future,
        );
        final day = vedic.today;
        if (day == null) {
          out.add(PersonalPlanDay(date: date, windows: const []));
          continue;
        }
        final moon = await ref.watch(
          moonNowProvider(moonKey(DateTime(date.year, date.month, date.day, 6)))
              .future,
        );
        final from = i == 0
            ? now
            : tz.TZDateTime(zone, date.year, date.month, date.day).toUtc();
        final windows = const FindPersonalMuhurat()(
          days: [day],
          now: from,
          birthNakshatra: birthNakshatra,
          nakshatraNow: nakshatraIndexOf(moon.longitude),
          nakshatraEndsUtc: moon.nakshatraEndsUtc,
          purpose: key.purpose,
          limit: 3,
        );
        out.add(PersonalPlanDay(date: date, windows: windows));
      }
      return out;
    });

/// For "Today": Abhijit Muhurat, Rahu Kaal and the good Choghadiya on each
/// of the next [days] days, from the Panchang.
final todayPlanProvider =
    FutureProvider.autoDispose.family<List<TodayPlanDay>, int>((ref, days) async {
      final place = ref.watch(panchangPlaceProvider).value;
      if (place == null) return const [];

      final now = ref.watch(appClockProvider);
      final zone = tz.getLocation(place.location.timezone);

      final out = <TodayPlanDay>[];
      for (var i = 0; i < days; i++) {
        final date = _dayOn(now, zone, i);
        final vedic = await ref.watch(
          dayDivisionsProvider(_inputFor(date, place)).future,
        );
        final day = vedic.today;
        if (day == null) {
          out.add(
            TodayPlanDay(date: date, abhijit: null, rahuKaal: null, good: const []),
          );
          continue;
        }
        final good = [...day.dayChoghadiya, ...day.nightChoghadiya]
            .where((p) => p.value.quality == ChoghadiyaQuality.good)
            .take(2)
            .map(
              (p) => (
                span: (start: p.start, end: p.end),
                kind: p.value,
              ),
            )
            .toList();
        out.add(
          TodayPlanDay(
            date: date,
            abhijit: (start: day.abhijit.start, end: day.abhijit.end),
            rahuKaal: (start: day.rahuKaal.start, end: day.rahuKaal.end),
            good: good,
          ),
        );
      }
      return out;
    });

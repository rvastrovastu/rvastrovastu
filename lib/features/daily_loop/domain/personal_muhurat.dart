/// Personal muhurat: the best hours left today for one kind of plan,
/// from the day's Choghadiya and Hora, checked against the user's own
/// birth star (Tara Bala) and kept clear of Rahu Kaal, Yamaganda and
/// Gulika Kaal.
library;

import '../../panchang/domain/entities/day_divisions.dart';
import '../../your_day/domain/day_strength.dart';

/// What the user wants the time for.
enum MuhuratPurpose { start, money, travel, people }

/// One recommended window, in UTC.
class MuhuratWindow {
  final DateTime start;
  final DateTime end;
  final Choghadiya choghadiya;

  /// Planet name as used across the app ('Jupiter', …).
  final String hora;
  final Tara tara;
  final int score;

  const MuhuratWindow({
    required this.start,
    required this.end,
    required this.choghadiya,
    required this.hora,
    required this.tara,
    required this.score,
  });

  Duration get length => end.difference(start);
}

class FindPersonalMuhurat {
  /// Shorter windows aren't worth showing.
  static const minimum = Duration(minutes: 20);

  /// Evening Choghadiya counted after sunset (about three hours).
  static const eveningSlots = 2;

  /// Horas traditionally favoured for each purpose.
  static const favouredHoras = <MuhuratPurpose, Set<String>>{
    MuhuratPurpose.start: {'Jupiter', 'Venus', 'Mercury', 'Sun'},
    MuhuratPurpose.money: {'Jupiter', 'Venus', 'Mercury'},
    MuhuratPurpose.travel: {'Moon', 'Mercury', 'Venus'},
    MuhuratPurpose.people: {'Venus', 'Moon', 'Jupiter'},
  };

  const FindPersonalMuhurat();

  /// Up to [limit] windows from [now] on, best first.
  ///
  /// [days] are the Vedic days to look in (yesterday's and today's, so the
  /// early hours before sunrise are covered). The Moon is in nakshatra
  /// [nakshatraNow] until [nakshatraEndsUtc], then in the next one.
  List<MuhuratWindow> call({
    required List<DayDivisions> days,
    required DateTime now,
    required int birthNakshatra,
    required int nakshatraNow,
    required DateTime nakshatraEndsUtc,
    required MuhuratPurpose purpose,
    int limit = 3,
  }) {
    final from = now.toUtc();
    final windows = <MuhuratWindow>[];

    for (final day in days) {
      final blocked = [day.rahuKaal, day.yamaganda, day.gulika];
      final slots = [
        ...day.dayChoghadiya,
        ...day.nightChoghadiya.take(eveningSlots),
      ];
      final horas = [...day.dayHoras, ...day.nightHoras];

      for (final slot in slots) {
        final base = _choghadiyaScore(slot.value, purpose);
        if (base == null) continue;

        for (final hora in horas) {
          var start = _later(slot.start, hora.start);
          final end = _earlier(slot.end, hora.end);
          if (start.isBefore(from)) start = from;
          if (end.difference(start) < minimum) continue;
          if (blocked.any((b) => _overlaps(start, end, b.start, b.end))) {
            continue;
          }

          final middle = start.add(end.difference(start) ~/ 2);
          final nakshatra = middle.isBefore(nakshatraEndsUtc)
              ? nakshatraNow
              : (nakshatraNow + 1) % 27;
          final tara = Tara.of(birthNakshatra, nakshatra);

          var score = base;
          if (favouredHoras[purpose]!.contains(hora.value)) score += 2;
          score += switch (tara.strength) {
            Strength.good => 1,
            Strength.weak => 0,
            Strength.bad => -2,
          };
          if (purpose == MuhuratPurpose.start &&
              _overlaps(start, end, day.abhijit.start, day.abhijit.end)) {
            score += 1;
          }

          windows.add(
            MuhuratWindow(
              start: start,
              end: end,
              choghadiya: slot.value,
              hora: hora.value,
              tara: tara,
              score: score,
            ),
          );
        }
      }
    }

    windows.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.start.compareTo(b.start);
    });
    return windows.take(limit).toList();
  }

  /// Null for a Choghadiya to skip for this purpose.
  static int? _choghadiyaScore(Choghadiya c, MuhuratPurpose purpose) {
    return switch (c) {
      Choghadiya.amrit => 3,
      Choghadiya.shubh => 2,
      Choghadiya.labh => purpose == MuhuratPurpose.money ? 3 : 2,
      // Chal (Char) is the traditional choice for journeys.
      Choghadiya.chal => purpose == MuhuratPurpose.travel ? 3 : null,
      Choghadiya.udveg || Choghadiya.kaal || Choghadiya.rog => null,
    };
  }

  static DateTime _later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  static DateTime _earlier(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

  static bool _overlaps(DateTime s1, DateTime e1, DateTime s2, DateTime e2) =>
      s1.isBefore(e2) && s2.isBefore(e1);
}

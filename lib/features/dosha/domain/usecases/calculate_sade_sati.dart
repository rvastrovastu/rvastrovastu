import '../entities/sade_sati.dart';
import '../entities/zodiac_signs.dart';

/// Builds a Shani Sade Sati report from the natal Moon sign and a list of
/// Saturn sign periods (see `SaturnTransitRepository`).
///
/// Sade Sati runs while Saturn transits the 12th, 1st and 2nd signs from
/// the natal Moon. Saturn often steps back into the previous sign during
/// retrograde; stretches separated by less than [maxGapWithinCycle] are
/// merged into one cycle so a brief retrograde exit does not appear as a
/// separate Sade Sati.
class CalculateSadeSati {
  static const Duration maxGapWithinCycle = Duration(days: 730);

  const CalculateSadeSati();

  SadeSatiReport call({
    required String moonSign,
    required List<SaturnSignPeriod> saturnPeriods,
    required DateTime referenceDate,
  }) {
    final moonIndex = zodiacSignIndex(moonSign);
    if (moonIndex < 0) {
      throw ArgumentError('Unknown Moon sign: "$moonSign".');
    }

    final periods = [...saturnPeriods]
      ..sort((a, b) => a.start.compareTo(b.start));

    final cycles = _buildCycles(moonIndex, periods);

    SaturnSignPeriod? current;
    for (final period in periods) {
      if (period.contains(referenceDate)) {
        current = period;
        break;
      }
    }

    SadeSatiCycle? currentCycle;
    SadeSatiCycle? nextCycle;
    for (final cycle in cycles) {
      if (cycle.contains(referenceDate)) {
        currentCycle = cycle;
      } else if (cycle.start.isAfter(referenceDate) && nextCycle == null) {
        nextCycle = cycle;
      }
    }

    SadeSatiPhase? currentPhase;
    ShaniDhaiya? dhaiya;
    if (current != null) {
      final house = houseFrom(moonIndex, current.signIndex);
      currentPhase = _phaseForHouse(house);
      if (house == 4) dhaiya = ShaniDhaiya.fourth;
      if (house == 8) dhaiya = ShaniDhaiya.eighth;
    }

    return SadeSatiReport(
      moonSign: moonSign,
      saturnSignIndex: current?.signIndex,
      cycles: cycles,
      currentCycle: currentCycle,
      currentPhase: currentCycle == null ? null : currentPhase,
      nextCycle: nextCycle,
      currentDhaiya: dhaiya,
    );
  }

  List<SadeSatiCycle> _buildCycles(
    int moonIndex,
    List<SaturnSignPeriod> periods,
  ) {
    final cycles = <SadeSatiCycle>[];
    var segments = <SadeSatiSegment>[];

    for (final period in periods) {
      final phase = _phaseForHouse(houseFrom(moonIndex, period.signIndex));
      if (phase == null) continue;

      final segment = SadeSatiSegment(
        phase: phase,
        start: period.start,
        end: period.end,
      );

      if (segments.isNotEmpty &&
          segment.start.difference(segments.last.end) > maxGapWithinCycle) {
        cycles.add(SadeSatiCycle(List.unmodifiable(segments)));
        segments = <SadeSatiSegment>[];
      }

      segments.add(segment);
    }

    if (segments.isNotEmpty) {
      cycles.add(SadeSatiCycle(List.unmodifiable(segments)));
    }

    return cycles;
  }

  SadeSatiPhase? _phaseForHouse(int house) {
    switch (house) {
      case 12:
        return SadeSatiPhase.rising;
      case 1:
        return SadeSatiPhase.peak;
      case 2:
        return SadeSatiPhase.setting;
      default:
        return null;
    }
  }
}

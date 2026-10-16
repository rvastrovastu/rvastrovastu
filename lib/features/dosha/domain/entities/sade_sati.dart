/// A continuous stretch during which sidereal Saturn stays in one sign.
class SaturnSignPeriod {
  /// Zero-based sign index (Aries = 0).
  final int signIndex;
  final DateTime start;
  final DateTime end;

  const SaturnSignPeriod({
    required this.signIndex,
    required this.start,
    required this.end,
  });

  bool contains(DateTime moment) =>
      !moment.isBefore(start) && moment.isBefore(end);

  @override
  String toString() => 'SaturnSignPeriod($signIndex, $start → $end)';
}

/// The three 2½-year phases of Shani Sade Sati.
enum SadeSatiPhase {
  /// Saturn in the 12th sign from the natal Moon.
  rising,

  /// Saturn over the natal Moon sign.
  peak,

  /// Saturn in the 2nd sign from the natal Moon.
  setting,
}

/// Shani Dhaiya (Small Panoti): Saturn in the 4th or 8th sign from the Moon.
enum ShaniDhaiya {
  /// Saturn in the 4th from the Moon (Kantaka Shani).
  fourth,

  /// Saturn in the 8th from the Moon (Ashtama Shani).
  eighth,
}

class SadeSatiSegment {
  final SadeSatiPhase phase;
  final DateTime start;
  final DateTime end;

  const SadeSatiSegment({
    required this.phase,
    required this.start,
    required this.end,
  });
}

/// One complete Sade Sati, from Saturn first entering the 12th from the
/// Moon until it finally leaves the 2nd — including any brief retrograde
/// exits and returns.
class SadeSatiCycle {
  final List<SadeSatiSegment> segments;

  const SadeSatiCycle(this.segments);

  DateTime get start => segments.first.start;
  DateTime get end => segments.last.end;

  bool contains(DateTime moment) =>
      !moment.isBefore(start) && moment.isBefore(end);

  /// Start of the first segment for [phase], if Saturn reaches it in range.
  DateTime? phaseStart(SadeSatiPhase phase) {
    for (final segment in segments) {
      if (segment.phase == phase) return segment.start;
    }
    return null;
  }
}

class SadeSatiReport {
  /// The natal Moon sign the calculation is based on.
  final String moonSign;

  /// Saturn's sidereal sign at the reference date, or `null` if the
  /// reference date falls outside the calculated transit range.
  final int? saturnSignIndex;

  /// All cycles found in the calculated range, oldest first.
  final List<SadeSatiCycle> cycles;

  final SadeSatiCycle? currentCycle;

  /// The phase Saturn occupies right now, or `null` when Saturn has briefly
  /// stepped out of the Sade Sati signs during an active cycle.
  final SadeSatiPhase? currentPhase;

  final SadeSatiCycle? nextCycle;
  final ShaniDhaiya? currentDhaiya;

  const SadeSatiReport({
    required this.moonSign,
    required this.saturnSignIndex,
    required this.cycles,
    this.currentCycle,
    this.currentPhase,
    this.nextCycle,
    this.currentDhaiya,
  });

  bool get isActive => currentCycle != null;
}

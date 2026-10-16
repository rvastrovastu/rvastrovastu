/// Slow planets whose sign changes shape the year.
enum TransitPlanet { jupiter, saturn, rahu, ketu }

extension TransitPlanetName on TransitPlanet {
  /// Name as used in `Kundali.planets` and the l10n `planetName` helper.
  String get displayKey => switch (this) {
    TransitPlanet.jupiter => 'Jupiter',
    TransitPlanet.saturn => 'Saturn',
    TransitPlanet.rahu => 'Rahu',
    TransitPlanet.ketu => 'Ketu',
  };
}

/// A continuous stretch with [planet] in one sidereal sign.
class PlanetSignPeriod {
  final TransitPlanet planet;

  /// Aries = 0.
  final int signIndex;
  final DateTime start;
  final DateTime end;

  const PlanetSignPeriod({
    required this.planet,
    required this.signIndex,
    required this.start,
    required this.end,
  });

  bool contains(DateTime moment) =>
      !moment.isBefore(start) && moment.isBefore(end);
}

/// Classical reading of a transit counted from the natal Moon.
enum TransitTone { favourable, challenging }

class TransitReading {
  final TransitPlanet planet;
  final int signIndex;
  final int houseFromMoon;
  final int houseFromLagna;
  final TransitTone tone;

  /// When the planet entered this sign (null if before the scanned range).
  final DateTime? since;

  /// When it leaves this sign (null if after the scanned range).
  final DateTime? until;

  /// The sign it moves into next, if known.
  final int? nextSignIndex;

  const TransitReading({
    required this.planet,
    required this.signIndex,
    required this.houseFromMoon,
    required this.houseFromLagna,
    required this.tone,
    this.since,
    this.until,
    this.nextSignIndex,
  });
}

class UpcomingIngress {
  final TransitPlanet planet;
  final DateTime date;
  final int signIndex;
  final int houseFromMoon;
  final TransitTone tone;

  const UpcomingIngress({
    required this.planet,
    required this.date,
    required this.signIndex,
    required this.houseFromMoon,
    required this.tone,
  });
}

class GocharReport {
  final List<TransitReading> current;
  final List<UpcomingIngress> upcoming;

  const GocharReport({required this.current, required this.upcoming});
}

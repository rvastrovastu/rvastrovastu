import '../entities/dasha_period.dart';
import '../entities/dasha_birth_data.dart';

class VimshottariStart {
  final DashaPlanet planet;
  final int nakshatraIndex;
  final double nakshatraPosition;
  final double nakshatraProgress;
  final double balance;

  const VimshottariStart({
    required this.planet,
    required this.nakshatraIndex,
    required this.nakshatraPosition,
    required this.nakshatraProgress,
    required this.balance,
  });
}

class CalculateVimshottariStart {
  static const double nakshatraSpan = 360.0 / 27.0;

  static const List<DashaPlanet> nakshatraLords = [
    DashaPlanet.ketu,
    DashaPlanet.venus,
    DashaPlanet.sun,
    DashaPlanet.moon,
    DashaPlanet.mars,
    DashaPlanet.rahu,
    DashaPlanet.jupiter,
    DashaPlanet.saturn,
    DashaPlanet.mercury,
  ];

  VimshottariStart call({required DashaBirthData birthData}) {
    if (!birthData.moonLongitude.isFinite) {
      throw ArgumentError.value(
        birthData.moonLongitude,
        'moonLongitude',
        'Moon longitude must be a finite number.',
      );
    }

    final longitude = ((birthData.moonLongitude % 360.0) + 360.0) % 360.0;

    final rawPosition = longitude / nakshatraSpan;
    final nearestBoundary = rawPosition.roundToDouble();
    final stablePosition = (rawPosition - nearestBoundary).abs() < 1e-10
        ? nearestBoundary
        : rawPosition;

    final nakshatraIndex = stablePosition.floor().clamp(0, 26);

    final progress = (stablePosition - nakshatraIndex).clamp(0.0, 1.0);
    final position = progress * nakshatraSpan;

    final balance = (1.0 - progress).clamp(0.0, 1.0);

    final planet = nakshatraLords[nakshatraIndex % 9];

    return VimshottariStart(
      planet: planet,
      nakshatraIndex: nakshatraIndex,
      nakshatraPosition: position,
      nakshatraProgress: progress,
      balance: balance,
    );
  }
}

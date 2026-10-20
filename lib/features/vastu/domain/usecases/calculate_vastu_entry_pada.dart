import '../entities/vastu_entry_segment.dart';

/// Calculates the eight equal padas on a cardinal Vastu wall.
///
/// [normalizedPosition] must be between 0.0 and 1.0 inclusive.
///
/// The wall is divided into eight equal intervals:
///
/// 0.000 ───── 0.125 ───── ... ───── 1.000
///   P1          P2                  P8
class CalculateVastuEntryPada {
  const CalculateVastuEntryPada();

  VastuEntrySegment call({
    required VastuEntrySegment wallStart,
    required double normalizedPosition,
  }) {
    if (!wallStart.isCardinal) {
      throw ArgumentError(
        'Vastu pada calculation requires a cardinal wall segment.',
      );
    }

    if (normalizedPosition < 0.0 || normalizedPosition > 1.0) {
      throw RangeError.value(
        normalizedPosition,
        'normalizedPosition',
        'must be between 0.0 and 1.0 inclusive',
      );
    }

    final pada = normalizedPosition == 1.0
        ? 8
        : (normalizedPosition * 8).floor() + 1;

    return VastuEntrySegment.values.firstWhere(
      (segment) =>
          segment.direction == wallStart.direction && segment.pada == pada,
    );
  }
}

import '../entities/vastu_entry_direction.dart';
import '../entities/vastu_entry_segment.dart';
import '../entities/vastu_entrance_input.dart';
import 'calculate_vastu_entry_pada.dart';

/// Converts raw entrance position data into the corresponding Vastu pada.
///
/// This use case intentionally keeps input modeling separate from the
/// underlying eight-pada calculation.
class CalculateVastuEntrySegment {
  const CalculateVastuEntrySegment({
    this._calculator = const CalculateVastuEntryPada(),
  });

  final CalculateVastuEntryPada _calculator;

  VastuEntrySegment call(VastuEntranceInput input) {
    final wallStart = switch (input.direction) {
      VastuEntryDirection.north => VastuEntrySegment.n1,
      VastuEntryDirection.east => VastuEntrySegment.e1,
      VastuEntryDirection.south => VastuEntrySegment.s1,
      VastuEntryDirection.west => VastuEntrySegment.w1,
      VastuEntryDirection.northeast => throw ArgumentError(
        'Vastu entrance pada calculation requires a cardinal wall.',
      ),
      VastuEntryDirection.southeast => throw ArgumentError(
        'Vastu entrance pada calculation requires a cardinal wall.',
      ),
      VastuEntryDirection.southwest => throw ArgumentError(
        'Vastu entrance pada calculation requires a cardinal wall.',
      ),
      VastuEntryDirection.northwest => throw ArgumentError(
        'Vastu entrance pada calculation requires a cardinal wall.',
      ),
    };

    return _calculator(
      wallStart: wallStart,
      normalizedPosition: input.normalizedPosition,
    );
  }
}

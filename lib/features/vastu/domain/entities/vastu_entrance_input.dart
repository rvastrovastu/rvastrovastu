import 'vastu_entry_direction.dart';

/// Raw entrance position used to calculate the corresponding Vastu pada.
///
/// [normalizedPosition] represents the entrance position along the selected
/// cardinal wall:
///
/// 0.0 = beginning of the wall
/// 1.0 = end of the wall
///
/// The wall is subsequently divided into eight equal padas by
/// CalculateVastuEntryPada.
class VastuEntranceInput {
  const VastuEntranceInput({
    required this.direction,
    required this.normalizedPosition,
  }) : assert(
         normalizedPosition >= 0.0 && normalizedPosition <= 1.0,
         'normalizedPosition must be between 0.0 and 1.0 inclusive.',
       );

  final VastuEntryDirection direction;
  final double normalizedPosition;
}

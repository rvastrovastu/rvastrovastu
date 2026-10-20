import 'vastu_entry_segment.dart';

/// Traditional deity assigned to an outer Vastu entrance pada.
///
/// RV Astro Vastu currently models 8 entrance padas on each
/// cardinal wall, for a total of 32 perimeter entrance positions.
///
/// This entity deliberately contains only the traditional mapping.
/// Assessment levels, effects, guidance, and remedies are kept
/// separate so that those interpretations can be added and tested
/// without changing the underlying pada geometry.
class VastuEntryDeity {
  const VastuEntryDeity({required this.segment, required this.deityKey});

  final VastuEntrySegment segment;

  /// Localization key for the traditional deity name.
  final String deityKey;
}

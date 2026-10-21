import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/vastu_entry_segment.dart';
import '../../domain/entities/vastu_zone.dart';
import '../../presentation/utils/vastu_localization.dart';
import '../domain/vastu_analysis.dart';
import '../domain/vastu_layout.dart';

/// Text for the plan analysis, shared by the screens and the PDF report.
extension VastuLayoutText on AppLocalizations {
  String roomName(VastuRoom room) => vastuRoomName(room.name);

  String placeName(ZonePlace place) =>
      place.isCentre ? vastuBrahmasthan : vastuZoneName(place.key);

  String zoneList(Iterable<String> keys) => [
    for (final key in keys)
      key == 'centre' ? vastuBrahmasthan : vastuZoneName(key),
  ].join(', ');

  String padaLabel(VastuEntrySegment pada) =>
      '${padaCode(pada)} · ${localizedPadaDeity(this, pada)}';

  /// "North (2°)".
  String facingLabel(double degrees) {
    final zone = vastuZoneForHeading(degrees);
    return vastuPlanFacing(
      degrees.round().toString(),
      vastuZoneName(zone.name),
    );
  }

  String doshaTitle(VastuDosha dosha) => switch (dosha.kind) {
    DoshaKind.entrance => vastuDoshaEntrance(padaLabel(dosha.pada!)),
    DoshaKind.room => vastuDoshaRoom(
      roomName(dosha.room!.room),
      placeName(dosha.room!.place),
    ),
    DoshaKind.cutCorner => vastuDoshaCorner(
      vastuCornerName(dosha.corner!.name),
    ),
  };

  /// Why it matters, or null when there's nothing more to say.
  String? doshaDetail(VastuDosha dosha) => switch (dosha.kind) {
    DoshaKind.room when !dosha.room!.place.isCentre => vastuDoshaZoneTheme(
      vastuZoneTheme(dosha.room!.place.key),
    ),
    DoshaKind.room => vastuDoshaCentre,
    DoshaKind.cutCorner => vastuDoshaZoneTheme(
      vastuZoneTheme(zoneOfCorner(dosha.corner!).name),
    ),
    DoshaKind.entrance => null,
  };

  /// Traditional remedies (dosh nivaran) for [dosha].
  String remedyFor(VastuDosha dosha) => switch (dosha.kind) {
    DoshaKind.entrance => vastuRemedyEntrance(
      dosha.pada!.name.substring(0, 1),
    ),
    DoshaKind.room => vastuRemedyRoom(dosha.room!.room.name),
    DoshaKind.cutCorner => vastuRemedyCorner(dosha.corner!.name),
  };

  /// Where a misplaced room would sit better, or null.
  String? suggestionFor(VastuDosha dosha) => dosha.kind == DoshaKind.room
      ? vastuMoveTo(zoneList(idealZonesFor(dosha.room!.room)))
      : null;
}

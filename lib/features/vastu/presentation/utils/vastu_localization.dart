import '../../../../l10n/app_localizations.dart';
import '../../data/repositories/local_vastu_entry_deity_repository.dart';
import '../../domain/entities/vastu_entry_assessment.dart';
import '../../domain/entities/vastu_entry_direction.dart';
import '../../domain/entities/vastu_entry_segment.dart';

/// Localized name of the deity ruling an entrance [segment] (pada).
String localizedPadaDeity(AppLocalizations l10n, VastuEntrySegment segment) =>
    localizedVastuDeity(
      l10n,
      const LocalVastuEntryDeityRepository().getDeity(segment).deityKey,
    );

/// Short pada label such as "N4".
String padaCode(VastuEntrySegment segment) => segment.name.toUpperCase();

String localizedVastuDirection(
  AppLocalizations l10n,
  VastuEntryDirection direction,
) {
  switch (direction) {
    case VastuEntryDirection.north:
      return l10n.vastuNorth;
    case VastuEntryDirection.east:
      return l10n.vastuEast;
    case VastuEntryDirection.south:
      return l10n.vastuSouth;
    case VastuEntryDirection.west:
      return l10n.vastuWest;
    case VastuEntryDirection.northeast:
    case VastuEntryDirection.southeast:
    case VastuEntryDirection.southwest:
    case VastuEntryDirection.northwest:
      return direction.name;
  }
}

String localizedVastuLevel(
  AppLocalizations l10n,
  VastuAssessmentLevel level,
) {
  switch (level) {
    case VastuAssessmentLevel.favorable:
      return l10n.vastuFavorable;
    case VastuAssessmentLevel.neutral:
      return l10n.vastuNeutral;
    case VastuAssessmentLevel.challenging:
      return l10n.vastuChallenging;
  }
}

String localizedVastuDeity(AppLocalizations l10n, String key) {
  switch (key) {
    case 'vastuRoga':
      return l10n.vastuRoga;
    case 'vastuNaga':
      return l10n.vastuNaga;
    case 'vastuMukhya':
      return l10n.vastuMukhya;
    case 'vastuBhallata':
      return l10n.vastuBhallata;
    case 'vastuSoma':
      return l10n.vastuSoma;
    case 'vastuBhujaga':
      return l10n.vastuBhujaga;
    case 'vastuAditi':
      return l10n.vastuAditi;
    case 'vastuDiti':
      return l10n.vastuDiti;
    case 'vastuShikhi':
      return l10n.vastuShikhi;
    case 'vastuParjanya':
      return l10n.vastuParjanya;
    case 'vastuJayanta':
      return l10n.vastuJayanta;
    case 'vastuIndra':
      return l10n.vastuIndra;
    case 'vastuSurya':
      return l10n.vastuSurya;
    case 'vastuSatya':
      return l10n.vastuSatya;
    case 'vastuBhrisha':
      return l10n.vastuBhrisha;
    case 'vastuAkasha':
      return l10n.vastuAkasha;
    case 'vastuAnila':
      return l10n.vastuAnila;
    case 'vastuPusha':
      return l10n.vastuPusha;
    case 'vastuVitatha':
      return l10n.vastuVitatha;
    case 'vastuGrihakshata':
      return l10n.vastuGrihakshata;
    case 'vastuYama':
      return l10n.vastuYama;
    case 'vastuGandharva':
      return l10n.vastuGandharva;
    case 'vastuBhringaraja':
      return l10n.vastuBhringaraja;
    case 'vastuMriga':
      return l10n.vastuMriga;
    case 'vastuPitra':
      return l10n.vastuPitra;
    case 'vastuDauvarika':
      return l10n.vastuDauvarika;
    case 'vastuSugriva':
      return l10n.vastuSugriva;
    case 'vastuPushpadanta':
      return l10n.vastuPushpadanta;
    case 'vastuVaruna':
      return l10n.vastuVaruna;
    case 'vastuAsura':
      return l10n.vastuAsura;
    case 'vastuShosha':
      return l10n.vastuShosha;
    case 'vastuPapayakshma':
      return l10n.vastuPapayakshma;
    default:
      throw ArgumentError('Unsupported Vastu deity localization key: $key');
  }
}

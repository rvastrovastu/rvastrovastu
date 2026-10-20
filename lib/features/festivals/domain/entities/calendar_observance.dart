/// Festivals and vrats the calendar can produce.
///
/// The enum name is the localization key used by `festivalName` in the ARB
/// files, so keep the two in sync.
enum ObservanceId {
  makarSankranti,
  vasantPanchami,
  mahaShivaratri,
  holi,
  ugadi,
  ramNavami,
  hanumanJayanti,
  akshayaTritiya,
  nirjalaEkadashi,
  devshayaniEkadashi,
  guruPurnima,
  rakshaBandhan,
  janmashtami,
  ganeshChaturthi,
  navratri,
  dussehra,
  karvaChauth,
  dhanteras,
  diwali,
  devUthaniEkadashi,
  // Recurring monthly vrats.
  ekadashi,
  purnima,
  amavasya,
  pradosh,
  sankashti,
  masikShivaratri,
}

enum ObservanceCategory { festival, ekadashi, fullNewMoon, vrat }

extension ObservanceIdInfo on ObservanceId {
  ObservanceCategory get category {
    switch (this) {
      case ObservanceId.ekadashi:
      case ObservanceId.nirjalaEkadashi:
      case ObservanceId.devshayaniEkadashi:
      case ObservanceId.devUthaniEkadashi:
        return ObservanceCategory.ekadashi;
      case ObservanceId.purnima:
      case ObservanceId.amavasya:
        return ObservanceCategory.fullNewMoon;
      case ObservanceId.pradosh:
      case ObservanceId.sankashti:
      case ObservanceId.masikShivaratri:
        return ObservanceCategory.vrat;
      default:
        return ObservanceCategory.festival;
    }
  }

  bool get isMajorFestival =>
      category == ObservanceCategory.festival ||
      this == ObservanceId.nirjalaEkadashi ||
      this == ObservanceId.devshayaniEkadashi ||
      this == ObservanceId.devUthaniEkadashi;
}

class CalendarObservance {
  /// Local calendar date (date-only).
  final DateTime date;
  final ObservanceId id;

  /// 0–29 tithi the observance follows, or `null` for solar events.
  final int? tithiIndex;

  const CalendarObservance({
    required this.date,
    required this.id,
    this.tithiIndex,
  });

  /// Shukla (bright) half for tithis 0–14.
  bool? get isShukla => tithiIndex == null ? null : tithiIndex! < 15;

  @override
  bool operator ==(Object other) =>
      other is CalendarObservance && other.date == date && other.id == id;

  @override
  int get hashCode => Object.hash(date, id);

  @override
  String toString() =>
      'CalendarObservance(${date.toIso8601String().substring(0, 10)}, '
      '${id.name})';
}

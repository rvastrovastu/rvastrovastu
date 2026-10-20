/// Classical yogas the app detects. The enum name is the localization key
/// used by `yogaName` / `yogaMeaning` in the ARB files.
enum YogaId {
  gajakesari,
  budhaditya,
  chandraMangal,
  ruchaka,
  bhadra,
  hamsa,
  malavya,
  shasha,
  rajYoga,
  yogakaraka,
  dhanaYoga,
  viparitaRajYoga,
  amala,
  kemadruma,
}

enum YogaNature { supportive, challenging }

extension YogaIdInfo on YogaId {
  YogaNature get nature =>
      this == YogaId.kemadruma ? YogaNature.challenging : YogaNature.supportive;

  bool get isMahapurusha =>
      this == YogaId.ruchaka ||
      this == YogaId.bhadra ||
      this == YogaId.hamsa ||
      this == YogaId.malavya ||
      this == YogaId.shasha;
}

class YogaResult {
  final YogaId id;

  /// Planets that form the yoga, in chart order, without duplicates.
  final List<String> planets;

  /// For yogas that can be cancelled (Kemadruma): whether a commonly cited
  /// cancellation applies.
  final bool cancelled;

  const YogaResult({
    required this.id,
    required this.planets,
    this.cancelled = false,
  });

  @override
  String toString() =>
      'YogaResult(${id.name}, $planets${cancelled ? ', cancelled' : ''})';
}

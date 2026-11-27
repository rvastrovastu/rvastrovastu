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
  // Moon and Sun yogas (planets around the luminaries).
  sunapha,
  anapha,
  durudhara,
  vesi,
  vasi,
  ubhayachari,
  adhi,
  vasumati,
  shakata,
  // Wealth, learning and status.
  lakshmi,
  saraswati,
  chamara,
  kahala,
  parvata,
  dharmaKarmadhipati,
  neechaBhangaRaj,
  parivartana,
  shubhaKartari,
  chatussagara,
  // Viparita Raj yogas by name.
  harsha,
  sarala,
  vimala,
  // Conjunctions.
  guruMangal,
  guruChandal,
  vish,
  angarak,
  papaKartari,
  daridra,
  // Sankhya (Nabhasa) yogas: how many signs the seven planets occupy.
  // Every chart has exactly one.
  gola,
  yuga,
  shoola,
  kedara,
  pasha,
  dama,
  veena,
}

enum YogaNature { supportive, challenging, neutral }

extension YogaIdInfo on YogaId {
  YogaNature get nature => switch (this) {
    YogaId.kemadruma ||
    YogaId.shakata ||
    YogaId.guruChandal ||
    YogaId.vish ||
    YogaId.angarak ||
    YogaId.papaKartari ||
    YogaId.daridra => YogaNature.challenging,
    _ when isSankhya => YogaNature.neutral,
    _ => YogaNature.supportive,
  };

  /// The seven Sankhya yogas, one of which every chart has.
  bool get isSankhya => index >= YogaId.gola.index;

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

/// Naming syllables (namakshar) for each nakshatra pada, from the
/// Avakahada chakra: (Devanagari, Latin), padas 1–4. Indexed like the
/// app's nakshatra list (Ashwini first).
const List<List<(String, String)>> namakshar = [
  [('चु', 'Chu'), ('चे', 'Che'), ('चो', 'Cho'), ('ला', 'La')],
  [('ली', 'Li'), ('लू', 'Lu'), ('ले', 'Le'), ('लो', 'Lo')],
  [('अ', 'A'), ('इ', 'I'), ('उ', 'U'), ('ए', 'E')],
  [('ओ', 'O'), ('वा', 'Va'), ('वी', 'Vi'), ('वू', 'Vu')],
  [('वे', 'Ve'), ('वो', 'Vo'), ('का', 'Ka'), ('की', 'Ki')],
  [('कु', 'Ku'), ('घ', 'Gha'), ('ङ', 'Nga'), ('छ', 'Chha')],
  [('के', 'Ke'), ('को', 'Ko'), ('हा', 'Ha'), ('ही', 'Hi')],
  [('हु', 'Hu'), ('हे', 'He'), ('हो', 'Ho'), ('डा', 'Da')],
  [('डी', 'Di'), ('डू', 'Du'), ('डे', 'De'), ('डो', 'Do')],
  [('मा', 'Ma'), ('मी', 'Mi'), ('मू', 'Mu'), ('मे', 'Me')],
  [('मो', 'Mo'), ('टा', 'Ta'), ('टी', 'Ti'), ('टू', 'Tu')],
  [('टे', 'Te'), ('टो', 'To'), ('पा', 'Pa'), ('पी', 'Pi')],
  [('पू', 'Pu'), ('ष', 'Sha'), ('ण', 'Na'), ('ठ', 'Tha')],
  [('पे', 'Pe'), ('पो', 'Po'), ('रा', 'Ra'), ('री', 'Ri')],
  [('रू', 'Ru'), ('रे', 'Re'), ('रो', 'Ro'), ('ता', 'Ta')],
  [('ती', 'Ti'), ('तू', 'Tu'), ('ते', 'Te'), ('तो', 'To')],
  [('ना', 'Na'), ('नी', 'Ni'), ('नू', 'Nu'), ('ने', 'Ne')],
  [('नो', 'No'), ('या', 'Ya'), ('यी', 'Yi'), ('यू', 'Yu')],
  [('ये', 'Ye'), ('यो', 'Yo'), ('भा', 'Bha'), ('भी', 'Bhi')],
  [('भू', 'Bhu'), ('धा', 'Dha'), ('फा', 'Pha'), ('ढा', 'Dha')],
  [('भे', 'Bhe'), ('भो', 'Bho'), ('जा', 'Ja'), ('जी', 'Ji')],
  [('खी', 'Khi'), ('खू', 'Khu'), ('खे', 'Khe'), ('खो', 'Kho')],
  [('गा', 'Ga'), ('गी', 'Gi'), ('गू', 'Gu'), ('गे', 'Ge')],
  [('गो', 'Go'), ('सा', 'Sa'), ('सी', 'Si'), ('सू', 'Su')],
  [('से', 'Se'), ('सो', 'So'), ('दा', 'Da'), ('दी', 'Di')],
  [('दू', 'Du'), ('थ', 'Tha'), ('झ', 'Jha'), ('ञ', 'Nya')],
  [('दे', 'De'), ('दो', 'Do'), ('चा', 'Cha'), ('ची', 'Chi')],
];

const _independentVowels = {
  'अ': 'a', 'आ': 'a', 'इ': 'i', 'ई': 'i', 'उ': 'u', 'ऊ': 'u', //
  'ए': 'e', 'ऐ': 'e', 'ओ': 'o', 'औ': 'o',
};

const _matras = {
  'ा': 'a', 'ि': 'i', 'ी': 'i', 'ु': 'u', 'ू': 'u', //
  'े': 'e', 'ै': 'e', 'ो': 'o', 'ौ': 'o',
};

/// The first sound of a Devanagari word as (consonant, vowel class), with
/// long and short vowels counted together: 'की' and 'कि' both give
/// ('क', 'i'); 'का' and a plain 'क' both give ('क', 'a'). Null when the
/// word starts with a conjunct or anything else.
(String, String)? firstSound(String word) {
  if (word.isEmpty) return null;
  final chars = word.runes.map(String.fromCharCode).toList();
  final first = chars.first;
  if (_independentVowels[first] case final v?) return ('', v);
  final next = chars.length > 1 ? chars[1] : '';
  if (next == '्') return null; // conjunct (क्ष, त्र …)
  if (_matras[next] case final v?) return (first, v);
  if (next == 'ं' || next == 'ँ' || next == '') return (first, 'a');
  // Another consonant follows: the inherent 'a'.
  return (first, 'a');
}

/// Whether [name] begins with the naming syllable [syllable].
bool startsWithSyllable(String name, String syllable) {
  final a = firstSound(name);
  final b = firstSound(syllable);
  return a != null && b != null && a == b;
}

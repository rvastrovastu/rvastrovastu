import '../../domain/entities/calendar_observance.dart';

/// A mantra in Devanagari with a Latin-letter reading. Its meaning is
/// localized in the guide content, in the same order.
class Mantra {
  final String devanagari;
  final String latin;

  const Mantra(this.devanagari, this.latin);
}

const _vasudev = Mantra(
  'ॐ नमो भगवते वासुदेवाय॥',
  'Om Namo Bhagavate Vasudevaya.',
);
const _namahShivaya = Mantra('ॐ नमः शिवाय॥', 'Om Namah Shivaya.');
const _mahamrityunjaya = Mantra(
  'ॐ त्र्यम्बकं यजामहे सुगन्धिं पुष्टिवर्धनम्।\n'
      'उर्वारुकमिव बन्धनान्मृत्योर्मुक्षीय माऽमृतात्॥',
  'Om Tryambakam Yajamahe Sugandhim Pushtivardhanam,\n'
      'Urvarukamiva Bandhanan Mrityor Mukshiya Mamritat.',
);
const _ganpati = Mantra('ॐ गं गणपतये नमः॥', 'Om Gam Ganapataye Namah.');
const _vakratunda = Mantra(
  'वक्रतुण्ड महाकाय सूर्यकोटि समप्रभ।\n'
      'निर्विघ्नं कुरु मे देव सर्वकार्येषु सर्वदा॥',
  'Vakratunda Mahakaya Suryakoti Samaprabha,\n'
      'Nirvighnam Kuru Me Deva Sarvakaryeshu Sarvada.',
);
const _lakshmi = Mantra(
  'ॐ श्रीं महालक्ष्म्यै नमः॥',
  'Om Shreem Mahalakshmyai Namah.',
);
const _ram = Mantra('ॐ श्री रामाय नमः॥', 'Om Shri Ramaya Namah.');

/// Everything about an observance's guide that doesn't depend on language.
class PujaGuideSpec {
  /// Keys into the aarti library, in the order they're sung.
  final List<String> aartis;
  final List<Mantra> mantras;

  const PujaGuideSpec({this.aartis = const [], this.mantras = const []});
}

const Map<ObservanceId, PujaGuideSpec> pujaGuideSpecs = {
  ObservanceId.makarSankranti: PujaGuideSpec(
    aartis: ['jagdish'],
    mantras: [
      Mantra('ॐ घृणि सूर्याय नमः॥', 'Om Ghrini Suryaya Namah.'),
      Mantra('ॐ आदित्याय नमः॥', 'Om Adityaya Namah.'),
    ],
  ),
  ObservanceId.vasantPanchami: PujaGuideSpec(
    aartis: ['saraswatiVandana'],
    mantras: [Mantra('ॐ ऐं सरस्वत्यै नमः॥', 'Om Aim Saraswatyai Namah.')],
  ),
  ObservanceId.mahaShivaratri: PujaGuideSpec(
    aartis: ['shiv'],
    mantras: [_namahShivaya, _mahamrityunjaya],
  ),
  ObservanceId.holi: PujaGuideSpec(
    aartis: ['jagdish'],
    mantras: [
      Mantra(
        'अहकूटा भयत्रस्तैः कृता त्वं होलि बालिशैः।\n'
            'अतस्त्वां पूजयिष्यामि भूते भूतिप्रदा भव॥',
        'Ahakuta Bhayatrastaih Krita Tvam Holi Balishaih,\n'
            'Atastvam Pujayishyami Bhute Bhutiprada Bhava.',
      ),
      _vasudev,
    ],
  ),
  ObservanceId.ugadi: PujaGuideSpec(
    aartis: ['jagdish'],
    mantras: [Mantra('ॐ ब्रह्मणे नमः॥', 'Om Brahmane Namah.'), _vasudev],
  ),
  ObservanceId.ramNavami: PujaGuideSpec(
    aartis: ['ramStuti', 'jagdish'],
    mantras: [
      _ram,
      Mantra(
        'श्री राम जय राम जय जय राम॥',
        'Shri Ram Jai Ram Jai Jai Ram.',
      ),
    ],
  ),
  ObservanceId.hanumanJayanti: PujaGuideSpec(
    aartis: ['hanuman'],
    mantras: [
      Mantra('ॐ हं हनुमते नमः॥', 'Om Ham Hanumate Namah.'),
      Mantra(
        'मनोजवं मारुततुल्यवेगं जितेन्द्रियं बुद्धिमतां वरिष्ठम्।\n'
            'वातात्मजं वानरयूथमुख्यं श्रीरामदूतं शरणं प्रपद्ये॥',
        'Manojavam Marutatulyavegam Jitendriyam Buddhimatam Varishtham,\n'
            'Vatatmajam Vanarayuthamukhyam Shriramadutam Sharanam Prapadye.',
      ),
    ],
  ),
  ObservanceId.akshayaTritiya: PujaGuideSpec(
    aartis: ['lakshmi', 'jagdish'],
    mantras: [_lakshmi, _vasudev],
  ),
  ObservanceId.nirjalaEkadashi: PujaGuideSpec(
    aartis: ['jagdish'],
    mantras: [_vasudev],
  ),
  ObservanceId.devshayaniEkadashi: PujaGuideSpec(
    aartis: ['jagdish'],
    mantras: [_vasudev],
  ),
  ObservanceId.guruPurnima: PujaGuideSpec(
    aartis: ['jagdish'],
    mantras: [
      Mantra(
        'गुरुर्ब्रह्मा गुरुर्विष्णुः गुरुर्देवो महेश्वरः।\n'
            'गुरुः साक्षात् परब्रह्म तस्मै श्री गुरवे नमः॥',
        'Gurur Brahma Gurur Vishnuh Gurur Devo Maheshvarah,\n'
            'Guruh Sakshat Parabrahma Tasmai Shri Gurave Namah.',
      ),
    ],
  ),
  ObservanceId.rakshaBandhan: PujaGuideSpec(
    mantras: [
      Mantra(
        'येन बद्धो बली राजा दानवेन्द्रो महाबलः।\n'
            'तेन त्वामपि बध्नामि रक्षे मा चल मा चल॥',
        'Yena Baddho Bali Raja Danavendro Mahabalah,\n'
            'Tena Tvamapi Badhnami Rakshe Ma Chala Ma Chala.',
      ),
    ],
  ),
  ObservanceId.janmashtami: PujaGuideSpec(
    aartis: ['kunjBihari'],
    mantras: [
      _vasudev,
      Mantra(
        'हरे कृष्ण हरे कृष्ण कृष्ण कृष्ण हरे हरे।\n'
            'हरे राम हरे राम राम राम हरे हरे॥',
        'Hare Krishna Hare Krishna Krishna Krishna Hare Hare,\n'
            'Hare Rama Hare Rama Rama Rama Hare Hare.',
      ),
    ],
  ),
  ObservanceId.ganeshChaturthi: PujaGuideSpec(
    aartis: ['ganesh'],
    mantras: [_ganpati, _vakratunda],
  ),
  ObservanceId.navratri: PujaGuideSpec(
    aartis: ['ambe'],
    mantras: [
      Mantra(
        'या देवी सर्वभूतेषु शक्तिरूपेण संस्थिता।\n'
            'नमस्तस्यै नमस्तस्यै नमस्तस्यै नमो नमः॥',
        'Ya Devi Sarvabhuteshu Shaktirupena Samsthita,\n'
            'Namastasyai Namastasyai Namastasyai Namo Namah.',
      ),
      Mantra(
        'ॐ ऐं ह्रीं क्लीं चामुण्डायै विच्चे॥',
        'Om Aim Hreem Kleem Chamundayai Vichche.',
      ),
    ],
  ),
  ObservanceId.dussehra: PujaGuideSpec(
    aartis: ['ramStuti', 'ambe'],
    mantras: [_ram, Mantra('ॐ अपराजितायै नमः॥', 'Om Aparajitayai Namah.')],
  ),
  ObservanceId.karvaChauth: PujaGuideSpec(
    aartis: ['shiv'],
    mantras: [
      Mantra(
        'नमः शिवायै शर्वाण्यै सौभाग्यं संततिं शुभाम्।\n'
            'प्रयच्छ भक्तियुक्तानां नारीणां हरवल्लभे॥',
        'Namah Shivayai Sharvanyai Saubhagyam Santatim Shubham,\n'
            'Prayachchha Bhaktiyuktanam Narinam Haravallabhe.',
      ),
      _namahShivaya,
    ],
  ),
  ObservanceId.dhanteras: PujaGuideSpec(
    aartis: ['lakshmi'],
    mantras: [
      Mantra('ॐ धन्वन्तरये नमः॥', 'Om Dhanvantaraye Namah.'),
      Mantra(
        'मृत्युना पाशदण्डाभ्यां कालेन श्यामया सह।\n'
            'त्रयोदश्यां दीपदानात् सूर्यजः प्रीयतां मम॥',
        'Mrityuna Pashadandabhyam Kalena Shyamaya Saha,\n'
            'Trayodashyam Deepadanat Suryajah Priyatam Mama.',
      ),
    ],
  ),
  ObservanceId.diwali: PujaGuideSpec(
    aartis: ['ganesh', 'lakshmi'],
    mantras: [
      _ganpati,
      Mantra(
        'ॐ श्रीं ह्रीं श्रीं कमले कमलालये प्रसीद प्रसीद।\n'
            'श्रीं ह्रीं श्रीं ॐ महालक्ष्म्यै नमः॥',
        'Om Shreem Hreem Shreem Kamale Kamalalaye Praseeda Praseeda,\n'
            'Shreem Hreem Shreem Om Mahalakshmyai Namah.',
      ),
    ],
  ),
  ObservanceId.devUthaniEkadashi: PujaGuideSpec(
    aartis: ['jagdish'],
    mantras: [
      _vasudev,
      Mantra(
        'उत्तिष्ठ गोविन्द त्यज निद्रां जगत्पते।\n'
            'त्वयि सुप्ते जगन्नाथ जगत् सुप्तं भवेदिदम्॥',
        'Uttishtha Govinda Tyaja Nidram Jagatpate,\n'
            'Tvayi Supte Jagannatha Jagat Suptam Bhavedidam.',
      ),
    ],
  ),
  ObservanceId.ekadashi: PujaGuideSpec(
    aartis: ['jagdish'],
    mantras: [_vasudev],
  ),
  ObservanceId.purnima: PujaGuideSpec(
    aartis: ['jagdish'],
    mantras: [_vasudev, Mantra('ॐ सों सोमाय नमः॥', 'Om Som Somaya Namah.')],
  ),
  ObservanceId.amavasya: PujaGuideSpec(
    mantras: [
      Mantra('ॐ पितृदेवताभ्यो नमः॥', 'Om Pitridevatabhyo Namah.'),
      _namahShivaya,
    ],
  ),
  ObservanceId.pradosh: PujaGuideSpec(
    aartis: ['shiv'],
    mantras: [_namahShivaya, _mahamrityunjaya],
  ),
  ObservanceId.sankashti: PujaGuideSpec(
    aartis: ['ganesh'],
    mantras: [_ganpati, _vakratunda],
  ),
  ObservanceId.masikShivaratri: PujaGuideSpec(
    aartis: ['shiv'],
    mantras: [_namahShivaya, _mahamrityunjaya],
  ),
};

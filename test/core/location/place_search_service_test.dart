import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/core/location/place_search_service.dart';

void main() {
  // The bundled-list tests read real assets through rootBundle.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlaceIndex', () {
    final index = PlaceIndex.parse([
      [
        'Springfield\t\t39.8017\t-89.6437\tUS\tIL',
        'Springfield\t\t37.2153\t-93.2982\tUS\tMO',
        'Bhopal\t\t23.2547\t77.4029\tIN\t35',
        'Bhopalwala\t\t32.4300\t74.3600\tPK\t04',
        'Kraków\tkrakow\t50.0614\t19.9366\tPL\t77',
        'New York City\t\t40.7143\t-74.0060\tUS\tNY',
        'West New York\t\t40.7857\t-74.0143\tUS\tNJ',
      ].join('\n'),
      'US.IL\tIllinois\nUS.MO\tMissouri\nIN.35\tMadhya Pradesh\n'
          'US.NY\tNew York\nUS.NJ\tNew Jersey',
      'US\tUSA\nIN\tIndia\nPK\tPakistan\nPL\tPoland',
    ]);

    List<String> names(String query) => [
      for (final i in index.find(query))
        '${index.names[i]}, ${index.regions[i]}',
    ];

    test('reads names, regions and countries', () {
      expect(index.names, hasLength(7));
      expect(index.regions[2], 'Madhya Pradesh');
      expect(index.countries[2], 'India');
    });

    test('prefix matches come first, India before others', () {
      expect(names('bhop'), ['Bhopal, Madhya Pradesh', 'Bhopalwala, null']);
    });

    test('a comma narrows by state or country', () {
      expect(names('Springfield, Missouri'), ['Springfield, Missouri']);
      expect(names('springfield'), hasLength(2));
    });

    test('accents are ignored both ways', () {
      expect(names('krakow'), ['Kraków, null']);
      expect(names('Kraków'), ['Kraków, null']);
    });

    test('matches words inside names, after whole-name prefixes', () {
      expect(names('new york'), [
        'New York City, New York',
        'West New York, New Jersey',
      ]);
    });

    test('one letter is not enough', () {
      expect(index.find('b'), isEmpty);
    });
  });

  test('normalizePlaceText folds case, accents and spaces', () {
    expect(normalizePlaceText('  São   Paulo '), 'sao paulo');
  });

  group('PlaceSearchService with the bundled list', () {
    final service = PlaceSearchService();

    test('finds Indian cities with state and time zone', () async {
      final results = await service.search('Bhopal');
      expect(results.first.displayName, 'Bhopal, Madhya Pradesh, India');
      expect(
        results.first.timezone,
        anyOf('Asia/Kolkata', 'Asia/Calcutta'),
      );
    });

    test('finds small towns abroad', () async {
      final results = await service.search('Prosper');
      expect(results.first.displayName, 'Prosper, Texas, USA');
      expect(results.first.timezone, 'America/Chicago');
    });

    test('knows common alternate Indian names, without diacritics', () async {
      expect(
        (await service.search('Gurgaon')).first.displayName,
        'Gurgaon, Haryana, India',
      );
      expect(
        (await service.search('Thane')).first.displayName,
        'Thane, Maharashtra, India',
      );
    });

    test('suggests while typing', () async {
      final results = await service.search('ujj');
      expect(results.first.city, 'Ujjain');
    });
  });
}

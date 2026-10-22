import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/baby_names/namakshar.dart';

void main() {
  test('long and short vowels count as the same syllable', () {
    expect(startsWithSyllable('कीर्ति', 'की'), isTrue);
    expect(startsWithSyllable('किरण', 'की'), isTrue);
    expect(startsWithSyllable('तरुण', 'ता'), isTrue);
    expect(startsWithSyllable('तारा', 'ता'), isTrue);
    expect(startsWithSyllable('तुलसी', 'ता'), isFalse);
    expect(startsWithSyllable('ईशान', 'इ'), isTrue);
    expect(startsWithSyllable('आरव', 'अ'), isTrue);
    expect(startsWithSyllable('क्षितिज', 'का'), isFalse);
  });

  test('every nakshatra has four syllables', () {
    expect(namakshar, hasLength(27));
    for (final padas in namakshar) {
      expect(padas, hasLength(4));
    }
  });

  test('the bundled names are well formed and match a syllable', () {
    final names = jsonDecode(File('assets/baby_names.json').readAsStringSync())
        as List;
    expect(names.length, greaterThan(200));
    final syllables = [for (final n in namakshar) for (final s in n) s.$1];
    for (final n in names) {
      expect(n, hasLength(5));
      expect(['m', 'f'], contains(n[2]));
      expect(
        syllables.any((s) => startsWithSyllable(n[0] as String, s)),
        isTrue,
        reason: n[0] as String,
      );
    }
  });
}

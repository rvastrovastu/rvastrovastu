import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/muhurat/domain/services/muhurat_candidate_search_service.dart';
import 'package:rv_astro_vastu/features/muhurat/presentation/pages/muhurat_wizard_page.dart';
import 'package:rv_astro_vastu/features/panchang/domain/entities/daily_panchang.dart';
import 'package:rv_astro_vastu/features/your_day/domain/day_strength.dart';

MuhuratCandidate _day(int day, String nakshatra) => MuhuratCandidate(
  date: DateTime(2026, 12, day),
  screeningReason: '',
  panchang: DailyPanchang(
    date: DateTime(2026, 12, day),
    tithi: 'Shukla Panchami',
    nakshatra: nakshatra,
    yoga: 'Shobhana',
    sunrise: '07:20 AM',
    sunset: '05:25 PM',
    moonrise: '11:00 AM',
    rahuKaal: '09:00 AM – 10:30 AM',
    muhurat: '11:58 AM – 12:40 PM',
  ),
);

void main() {
  test('nakshatra names map to their index, including spelling variants', () {
    expect(nakshatraIndexByName('Rohini'), 3);
    expect(nakshatraIndexByName('Uttara Phalguni'), 11);
    expect(nakshatraIndexByName('Dhanishta'), 22); // app list: Dhanishtha
    expect(nakshatraIndexByName('—'), isNull);
  });

  test('days good for the birth star come first, unfavourable ones last', () {
    // Born in Ashwini (0): Rohini is the 4th star → Kshema (good),
    // Mrigashira the 5th → Pratyari (bad), Punarvasu the 7th → Vadha
    // (bad), Revati the 27th → Parama Mitra (good).
    final ranked = rankMuhuratDays([
      _day(3, 'Mrigashira'),
      _day(5, 'Rohini'),
      _day(9, 'Punarvasu'),
      _day(12, 'Revati'),
    ], 0);

    expect([for (final d in ranked) d.candidate.date.day], [5, 12, 3, 9]);
    expect(ranked.first.tara, Tara.kshema);
    expect(ranked.first.goodForYou, isTrue);
    expect(ranked.last.badForYou, isTrue);
  });

  test('without a birth star the dates keep their order', () {
    final ranked = rankMuhuratDays([
      _day(3, 'Mrigashira'),
      _day(5, 'Rohini'),
    ], null);
    expect([for (final d in ranked) d.candidate.date.day], [3, 5]);
    expect(ranked.every((d) => d.tara == null), isTrue);
  });
}

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/panchang/domain/entities/daily_panchang.dart';
import 'package:rv_astro_vastu/features/panchang/domain/entities/day_divisions.dart';
import 'package:rv_astro_vastu/features/panchang/presentation/utils/panchang_localization.dart';
import 'package:rv_astro_vastu/features/panchang/presentation/utils/panchang_share.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';

String _hm(DateTime utc) =>
    '${utc.hour.toString().padLeft(2, '0')}:'
    '${utc.minute.toString().padLeft(2, '0')}';

final _panchang = DailyPanchang(
  date: DateTime(2026, 10, 18),
  tithi: 'Shukla Saptami',
  nakshatra: 'Uttara Ashadha',
  yoga: 'Dhriti',
  sunrise: '06:00 AM',
  sunset: '06:00 PM',
  moonrise: '12:40 PM',
  rahuKaal: '04:30 PM – 06:00 PM',
  muhurat: '11:36 AM – 12:24 PM',
);

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('summary with Choghadiya, Yamaganda and Gulika', () {
    final divisions = DayDivisions.calculate(
      SunTimes(
        sunrise: DateTime.utc(2026, 10, 18, 6),
        sunset: DateTime.utc(2026, 10, 18, 18),
        nextSunrise: DateTime.utc(2026, 10, 19, 6),
      ),
      DateTime.sunday,
    );

    final text = buildPanchangShareText(
      l10n: l10n,
      panchang: _panchang,
      dateLabel: 'Sunday, October 18, 2026',
      formatTime: _hm,
      place: 'New Delhi',
      divisions: divisions,
    );

    final heading = l10n.panchangShareHeading('Sunday, October 18, 2026');
    expect(text, startsWith('🪔 $heading'));
    expect(text, contains('📍 New Delhi'));
    expect(
      text,
      contains('${l10n.tithi}: ${localizedTithi(l10n, 'Shukla Saptami')}'),
    );
    expect(text, contains('${l10n.rahuKaalTitle}: 04:30 PM – 06:00 PM'));
    expect(text, contains('${l10n.yamagandaTitle}: 12:00 – 13:30'));
    expect(text, contains('${l10n.gulikaTitle}: 15:00 – 16:30'));
    // Sunday's favourable daytime Choghadiya: Labh, Amrit, Shubh.
    expect(text, contains('• ${l10n.choghadiyaName('labh')} 09:00 – 10:30'));
    expect(text, contains('• ${l10n.choghadiyaName('amrit')} 10:30 – 12:00'));
    expect(text, contains('• ${l10n.choghadiyaName('shubh')} 13:30 – 15:00'));
    expect(text, isNot(contains(l10n.choghadiyaName('udveg'))));
    expect(text, endsWith(l10n.panchangShareFooter));
    expect(text, isNot(contains('\n\n\n')));
  });

  test('skips missing values and the Choghadiya block', () {
    final text = buildPanchangShareText(
      l10n: l10n,
      panchang: DailyPanchang(
        date: DateTime(2026, 6, 21),
        tithi: '—',
        nakshatra: '—',
        yoga: '—',
        sunrise: '—',
        sunset: '—',
        moonrise: '—',
        rahuKaal: '—',
        muhurat: '—',
      ),
      dateLabel: 'Sunday, June 21, 2026',
      formatTime: _hm,
    );

    expect(text, isNot(contains(l10n.tithi)));
    expect(text, isNot(contains(l10n.rahuKaalTitle)));
    expect(text, isNot(contains(l10n.panchangShareGoodChoghadiya)));
    expect(text, isNot(contains('📍')));
    expect(text, isNot(contains('\n\n\n')));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/ai_astrologer/data/ai_astrologer_service.dart';
import 'package:rv_astro_vastu/features/ai_astrologer/domain/chart_context.dart';
import 'package:rv_astro_vastu/features/ai_astrologer/presentation/ai_chat_page.dart';
import 'package:rv_astro_vastu/features/ai_astrologer/presentation/ai_chat_provider.dart';
import 'package:rv_astro_vastu/features/astrology/domain/entities/kundali.dart';
import 'package:rv_astro_vastu/features/astrology/domain/entities/planet_position.dart';
import 'package:rv_astro_vastu/features/dasha/domain/entities/dasha_period.dart';
import 'package:rv_astro_vastu/features/gochar/domain/entities/transit.dart';
import 'package:rv_astro_vastu/features/membership/presentation/providers/membership_provider.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';

import '../membership/fake_purchases_service.dart';
import '../membership/premium_test_helper.dart';

class _FakeService implements AiAstrologerService {
  int remaining;
  final asked = <String>[];

  _FakeService(this.remaining);

  AiAllowance get _allowance =>
      AiAllowance(premium: false, limit: 3, used: 3 - remaining, remaining: remaining);

  @override
  Future<AiAllowance?> status() async => _allowance;

  @override
  Future<AiAnswer> ask({
    required String question,
    required Map<String, Object?> chart,
    required List<({bool fromUser, String text})> history,
    required String language,
  }) async {
    if (remaining <= 0) throw AiLimitReached(_allowance);
    asked.add(question);
    remaining--;
    return AiAnswer('Jupiter favours your 10th house this year.', _allowance);
  }
}

void main() {
  test('chart context carries the chart, dasha and transits, not identity', () {
    const kundali = Kundali(
      ascendant: 'Leo',
      ayanamsa: 24.1,
      ascendantDegree: 12.345,
      moonLongitude: 100,
      moonSign: 'Cancer',
      sunSign: 'Aries',
      nakshatra: 'Pushya',
      nakshatraPada: 2,
      planets: [
        PlanetPosition(
          planet: 'Jupiter',
          sign: 'Taurus',
          house: 10,
          longitude: 45,
          degree: 15.27,
          retrograde: true,
        ),
      ],
    );
    final context = buildChartContext(
      kundali: kundali,
      today: DateTime(2026, 10, 22),
      mahadasha: DashaPeriod(
        planet: DashaPlanet.saturn,
        startDate: DateTime(2020, 1, 1),
        endDate: DateTime(2039, 1, 1),
        level: 1,
      ),
      gochar: GocharReport(
        current: [
          TransitReading(
            planet: TransitPlanet.saturn,
            signIndex: 3,
            houseFromMoon: 1,
            houseFromLagna: 12,
            tone: TransitTone.challenging,
          ),
        ],
        upcoming: const [],
      ),
    );

    expect(context['today'], '2026-10-22');
    expect((context['lagna'] as Map)['degree'], 12.3);
    final jupiter = (context['planets'] as List).single as Map;
    expect(jupiter['retrograde'], true);
    expect(jupiter['degree'], 15.3);
    expect(
      ((context['vimshottari_dasha'] as Map)['mahadasha'] as Map)['planet'],
      'Saturn',
    );
    expect(context['sade_sati'], 'peak phase');
    expect(context.toString(), isNot(contains('name')));
  });

  Future<AppLocalizations> pump(
    WidgetTester tester,
    _FakeService service, {
    FakePurchasesService? store,
  }) async {
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (store == null)
            freeOverride
          else
            purchasesServiceProvider.overrideWithValue(store),
          aiAstrologerServiceProvider.overrideWithValue(service),
          aiChartContextProvider.overrideWith((ref) async => {'lagna': 'Leo'}),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: const AiChatPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.delegate.load(const Locale('en'));
  }

  testWidgets('a suggestion is asked and answered; the allowance updates', (
    tester,
  ) async {
    final service = _FakeService(3);
    final l10n = await pump(tester, service);

    expect(find.text(l10n.aiRemaining(3, 3)), findsOneWidget);
    await tester.tap(find.text(l10n.aiSuggestion('s1')));
    await tester.pumpAndSettle();

    expect(service.asked, [l10n.aiSuggestion('s1')]);
    expect(find.text('Jupiter favours your 10th house this year.'), findsOneWidget);
    expect(find.text(l10n.aiRemaining(2, 3)), findsOneWidget);
  });

  testWidgets('with no questions left, the Premium card shows', (tester) async {
    final l10n = await pump(tester, _FakeService(0));
    expect(find.text(l10n.premiumFeatureName('aiAstrologer')), findsOneWidget);
    final send = tester.widget<IconButton>(find.byKey(const ValueKey('aiSend')));
    expect(send.onPressed, isNull);
  });

  testWidgets('free users can buy a question pack when out of questions', (
    tester,
  ) async {
    final service = _FakeService(0);
    final store = FakePurchasesService();
    final l10n = await pump(tester, service, store: store);

    final buy = find.byKey(const ValueKey('aiPackBuy'));
    expect(find.text(l10n.aiPackBuy(10, r'$1.99')), findsOneWidget);

    service.remaining = 10; // the store credits the pack
    await tester.ensureVisible(buy);
    await tester.tap(buy);
    await tester.pumpAndSettle();

    expect(store.bought, ['ai10']);
    expect(find.text(l10n.aiPackAdded), findsOneWidget);
    final send = tester.widget<IconButton>(find.byKey(const ValueKey('aiSend')));
    expect(send.onPressed, isNotNull);
  });
}

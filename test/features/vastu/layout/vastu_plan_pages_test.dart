import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rv_astro_vastu/features/auth/presentation/providers/auth_provider.dart';
import 'package:rv_astro_vastu/features/membership/domain/membership.dart';
import 'package:rv_astro_vastu/features/membership/presentation/providers/membership_provider.dart';
import 'package:rv_astro_vastu/features/vastu/layout/domain/vastu_layout.dart';
import 'package:rv_astro_vastu/features/vastu/layout/presentation/pages/vastu_plan_editor_page.dart';
import 'package:rv_astro_vastu/features/vastu/layout/presentation/pages/vastu_plan_result_page.dart';
import 'package:rv_astro_vastu/features/vastu/layout/presentation/pages/vastu_plans_page.dart';
import 'package:rv_astro_vastu/features/vastu/layout/presentation/vastu_layout_providers.dart';
import 'package:rv_astro_vastu/features/vastu/layout/presentation/widgets/plan_canvas.dart';
import 'package:rv_astro_vastu/features/vastu/presentation/providers/compass_provider.dart';
import 'package:rv_astro_vastu/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../membership/fake_purchases_service.dart';

VastuLayout _home() => VastuLayout(
  id: 'home1',
  name: 'Sunrise Villa',
  updatedAt: DateTime(2026, 10, 20),
  frame: const PlanFrame(left: 0, top: 0, right: 1, bottom: 1),
  entrance: const PlanPoint(0.55, 0), // N5, favourable
  rooms: const [
    RoomMark(id: 't', room: VastuRoom.toilet, at: PlanPoint(0.9, 0.1)),
    RoomMark(id: 'k', room: VastuRoom.kitchen, at: PlanPoint(0.9, 0.9)),
  ],
);

Future<void> _seed(List<VastuLayout> layouts, {Map<String, String>? ledger}) {
  SharedPreferences.setMockInitialValues({
    'vastu_layouts': jsonEncode([for (final l in layouts) l.toJson()]),
    if (ledger != null) 'vastu_report_assignments': jsonEncode(ledger),
  });
  return SharedPreferences.getInstance();
}

/// Layout ids the test "exported" instead of building a real PDF.
final _exported = <String>[];

Future<AppLocalizations> _pump(
  WidgetTester tester, {
  required FakePurchasesService store,
  String initial = '/vastu/plans/home1',
}) async {
  _exported.clear();
  tester.view.physicalSize = const Size(430, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/vastu/plans',
        builder: (_, _) => const VastuPlansPage(),
        routes: [
          GoRoute(path: 'new', builder: (_, _) => const VastuPlanEditorPage()),
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                VastuPlanResultPage(layoutId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        purchasesServiceProvider.overrideWithValue(store),
        authUserIdProvider.overrideWithValue('user-1'),
        compassHeadingProvider.overrideWith((ref) => Stream.value(null)),
        vastuReportExporterProvider.overrideWithValue(
          (layout) async => _exported.add(layout.id),
        ),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return AppLocalizations.delegate.load(const Locale('en'));
}

void main() {
  testWidgets('free users see the score and doshas, remedies stay locked', (
    tester,
  ) async {
    await _seed([_home()]);
    final l10n = await _pump(tester, store: FakePurchasesService());

    expect(find.text('Sunrise Villa'), findsOneWidget);
    expect(find.text(l10n.vastuScoreTitle), findsOneWidget);
    expect(find.text('Toilet in Northeast'), findsOneWidget);
    expect(find.text(l10n.vastuRemedyLabel), findsNothing);
    expect(find.text(l10n.premiumFeatureName('vastuRemedies')), findsWidgets);
    // The detailed report is sold per property.
    expect(find.text(l10n.vastuReportBuy(r'$10.99')), findsOneWidget);
  });

  testWidgets('Premium shows dosh nivaran with better zones', (tester) async {
    await _seed([_home()]);
    final l10n = await _pump(
      tester,
      store: FakePurchasesService(state: const MembershipState(premium: true)),
    );

    expect(find.text(l10n.vastuRemedyLabel), findsOneWidget);
    expect(find.textContaining('Better zones:'), findsOneWidget);
    expect(find.text(l10n.vastuGeneralUpay), findsOneWidget);
    // Premium does not include the per-property report.
    expect(find.text(l10n.vastuReportBuy(r'$10.99')), findsOneWidget);
  });

  testWidgets('buying a report assigns it to this property', (tester) async {
    await _seed([_home()]);
    final store = FakePurchasesService();
    final l10n = await _pump(tester, store: store);

    await tester.tap(find.text(l10n.vastuReportBuy(r'$10.99')));
    await tester.pumpAndSettle();

    expect(store.bought, ['vastu']);
    final prefs = await SharedPreferences.getInstance();
    expect(
      jsonDecode(prefs.getString('vastu_report_assignments')!),
      {'home1': 'txn0'},
    );
    expect(find.text(l10n.vastuReportDownload), findsOneWidget);
    // The report opens straight after buying.
    expect(_exported, ['home1']);
  });

  testWidgets('an unused report can be claimed for another property', (
    tester,
  ) async {
    await _seed([_home()], ledger: {'other': 'txn0'});
    final l10n = await _pump(
      tester,
      store: FakePurchasesService(
        state: const MembershipState(vastuReports: ['txn0', 'txn1']),
      ),
    );

    expect(find.text(l10n.vastuReportUseCredit), findsOneWidget);
  });

  testWidgets('a report bought for one property does not unlock another', (
    tester,
  ) async {
    await _seed([_home()], ledger: {'other': 'txn0'});
    final l10n = await _pump(
      tester,
      store: FakePurchasesService(
        state: const MembershipState(vastuReports: ['txn0']),
      ),
    );

    expect(find.text(l10n.vastuReportDownload), findsNothing);
    expect(find.text(l10n.vastuReportBuy(r'$10.99')), findsOneWidget);
  });

  testWidgets('the list shows each property with its score', (tester) async {
    await _seed([_home()]);
    final l10n = await _pump(
      tester,
      store: FakePurchasesService(),
      initial: '/vastu/plans',
    );

    expect(find.text('Sunrise Villa'), findsOneWidget);
    expect(find.text(l10n.vastuPlansAdd), findsOneWidget);
    expect(find.text(l10n.vastuDoshaCounts(1, 0)), findsOneWidget);
  });

  testWidgets('a new property is saved with its rooms and opens', (
    tester,
  ) async {
    await _seed([]);
    final l10n = await _pump(
      tester,
      store: FakePurchasesService(),
      initial: '/vastu/plans/new',
    );

    await tester.enterText(find.byType(TextField).first, 'Lake House');
    await tester.enterText(find.byKey(const ValueKey('facingField')), '90');
    await tester.pump();
    expect(find.text('Main door faces 90° · East'), findsOneWidget);

    await tester.tap(find.text(l10n.vastuPlanStepRooms));
    await tester.pumpAndSettle();
    // Kitchen is selected by default; tap the plan once.
    final canvas = find.byType(PlanCanvas);
    await tester.tapAt(tester.getCenter(canvas) + const Offset(60, 60));
    await tester.pump();

    await tester.tap(find.text(l10n.vastuPlanSave));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(VastuPlanResultPage)),
    );
    final saved = (await container.read(vastuLayoutsProvider.future)).single;
    expect(saved.name, 'Lake House');
    expect(saved.entranceFacing, 90);
    expect(saved.rooms.single.room, VastuRoom.kitchen);
    expect(find.text('Lake House'), findsOneWidget);
  });
}

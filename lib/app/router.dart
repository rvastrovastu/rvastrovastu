import 'package:go_router/go_router.dart';
import 'app_shell.dart';
import '../features/compatibility/presentation/pages/compatibility_page.dart';
import '../features/dosha/presentation/pages/dosha_page.dart';
import '../features/festivals/domain/entities/calendar_observance.dart';
import '../features/festivals/guide/presentation/pages/puja_guide_page.dart';
import '../features/festivals/presentation/pages/festival_calendar_page.dart';
import '../features/gochar/presentation/pages/gochar_page.dart';
import '../features/muhurat/presentation/pages/muhurat_page.dart';
import '../features/numerology/presentation/numerology_page.dart';
import '../features/reminders/presentation/pages/reminder_settings_page.dart';
import '../features/ai_astrologer/presentation/ai_chat_page.dart';
import '../features/baby_names/baby_names_page.dart';
import '../features/strength/strength_page.dart';
import '../features/rashifal/presentation/rashifal_page.dart';
import '../features/remedies/presentation/remedies_page.dart';

import '../features/astrology/presentation/pages/kundali_loader_page.dart';
import '../features/auth/presentation/pages/account_page.dart';
import '../features/auth/presentation/pages/auth_page.dart';
import '../features/membership/domain/membership.dart';
import '../features/membership/presentation/pages/paywall_page.dart';
import '../features/birth_profile/presentation/pages/birth_profile_page.dart';
import '../features/birth_profile/presentation/pages/saved_profiles_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/panchang/presentation/pages/daily_timing_page.dart';
import '../features/onboarding/presentation/pages/language_preference_page.dart';
import '../features/onboarding/presentation/pages/onboarding_page.dart';
import '../features/vastu/presentation/pages/vastu_tip_page.dart';
import '../features/vastu/presentation/pages/vastu_entry_analysis_page.dart';
import '../features/vastu/presentation/pages/vastu_compass_page.dart';
import '../features/vastu/layout/presentation/pages/vastu_plan_editor_page.dart';
import '../features/vastu/layout/presentation/pages/vastu_plan_result_page.dart';
import '../features/vastu/layout/presentation/pages/vastu_plans_page.dart';
import '../features/splash/presentation/pages/splash_page.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',

    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/kundali',
                builder: (context, state) => const KundaliLoaderPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/festivals',
                builder: (context, state) => const FestivalCalendarPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/vastu',
                builder: (context, state) => const VastuTipPage(),
                routes: [
                  GoRoute(
                    path: 'entrance',
                    builder: (context, state) =>
                        const VastuEntryAnalysisPage(),
                  ),
                  GoRoute(
                    path: 'compass',
                    builder: (context, state) => const VastuCompassPage(),
                  ),
                  GoRoute(
                    path: 'plans',
                    builder: (context, state) => const VastuPlansPage(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (context, state) =>
                            const VastuPlanEditorPage(),
                      ),
                      GoRoute(
                        path: ':id',
                        builder: (context, state) => VastuPlanResultPage(
                          layoutId: state.pathParameters['id']!,
                        ),
                        routes: [
                          GoRoute(
                            path: 'edit',
                            builder: (context, state) => VastuPlanEditorPage(
                              layoutId: state.pathParameters['id'],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      GoRoute(
        path: '/splash',
        builder: (context, state) {
          return const SplashPage();
        },
      ),

      GoRoute(
        path: '/language',
        builder: (context, state) {
          return const LanguagePreferencePage();
        },
      ),

      GoRoute(
        path: '/onboarding',
        builder: (context, state) {
          return const OnboardingPage();
        },
      ),

      GoRoute(
        path: '/auth',
        builder: (context, state) {
          return const AuthPage();
        },
      ),

      GoRoute(
        path: '/birth-profile',
        builder: (context, state) {
          final isEditing = state.uri.queryParameters['edit'] == 'true';
          final profileId = state.uri.queryParameters['id'];

          return BirthProfilePage(isEditing: isEditing, profileId: profileId);
        },
      ),
      GoRoute(
        path: '/saved-profiles',
        builder: (context, state) {
          return const SavedProfilesPage();
        },
      ),

      GoRoute(
        path: '/reminders',
        builder: (context, state) => const ReminderSettingsPage(),
      ),
      GoRoute(
        path: '/puja-guide/:id',
        redirect: (context, state) =>
            ObservanceId.values.asNameMap().containsKey(
              state.pathParameters['id'],
            )
            ? null
            : '/festivals',
        builder: (context, state) => PujaGuidePage(
          id: ObservanceId.values.byName(state.pathParameters['id']!),
          date: DateTime.tryParse(state.uri.queryParameters['date'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/strength',
        builder: (context, state) => const StrengthPage(),
      ),
      GoRoute(
        path: '/baby-names',
        builder: (context, state) => const BabyNamesPage(),
      ),
      GoRoute(
        path: '/ask',
        builder: (context, state) => const AiChatPage(),
      ),
      GoRoute(
        path: '/rashifal',
        builder: (context, state) => const RashifalPage(),
      ),
      GoRoute(
        path: '/gochar',
        builder: (context, state) => const GocharPage(),
      ),
      GoRoute(
        path: '/numerology',
        builder: (context, state) => const NumerologyPage(),
      ),
      GoRoute(
        path: '/remedies',
        builder: (context, state) => const RemediesPage(),
      ),
      GoRoute(
        path: '/dosha',
        builder: (context, state) => const DoshaPage(),
      ),
      GoRoute(
        path: '/muhurat',
        builder: (context, state) => const MuhuratPage(),
      ),

      GoRoute(
        path: '/daily-timing',
        builder: (context, state) {
          return const DailyTimingPage();
        },
      ),


      GoRoute(
        path: '/compatibility',
        builder: (context, state) {
          return const CompatibilityPage();
        },
      ),
      GoRoute(
        path: '/account',
        builder: (context, state) =>
            AccountPage(next: state.uri.queryParameters['next']),
      ),
      GoRoute(
        path: '/premium',
        builder: (context, state) {
          final name = state.uri.queryParameters['feature'];
          return PaywallPage(
            highlight: PremiumFeature.values
                .where((f) => f.name == name)
                .firstOrNull,
          );
        },
      ),
    ],
  );
}

import 'package:go_router/go_router.dart';
import '../features/compatibility/presentation/pages/compatibility_page.dart';
import '../features/dosha/presentation/pages/dosha_page.dart';
import '../features/muhurat/presentation/pages/muhurat_page.dart';

import '../features/astrology/presentation/pages/kundali_loader_page.dart';
import '../features/auth/presentation/pages/auth_page.dart';
import '../features/birth_profile/presentation/pages/birth_profile_page.dart';
import '../features/birth_profile/presentation/pages/saved_profiles_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/panchang/presentation/pages/daily_timing_page.dart';
import '../features/onboarding/presentation/pages/language_preference_page.dart';
import '../features/onboarding/presentation/pages/onboarding_page.dart';
import '../features/vastu/presentation/pages/vastu_tip_page.dart';
import '../features/vastu/presentation/pages/vastu_entry_analysis_page.dart';
import '../features/splash/presentation/pages/splash_page.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',

    routes: [
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
        path: '/home',
        builder: (context, state) {
          return const HomePage();
        },
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
        path: '/vastu',
        builder: (context, state) {
          return const VastuTipPage();
        },
        routes: [
          GoRoute(
            path: 'entrance',
            builder: (context, state) {
              return const VastuEntryAnalysisPage();
            },
          ),
        ],
      ),

      GoRoute(
        path: '/kundali',
        builder: (context, state) {
          return const KundaliLoaderPage();
        },
      ),
      GoRoute(
        path: '/compatibility',
        builder: (context, state) {
          return const CompatibilityPage();
        },
      ),
    ],
  );
}

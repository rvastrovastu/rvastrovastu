import 'package:go_router/go_router.dart';

import '../features/astrology/presentation/pages/kundali_loader_page.dart';
import '../features/auth/presentation/pages/auth_page.dart';
import '../features/birth_profile/presentation/pages/birth_profile_page.dart';
import '../features/home/presentation/pages/home_page.dart';
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
        path: '/auth',
        builder: (context, state) {
          return const AuthPage();
        },
      ),

      GoRoute(
        path: '/birth-profile',
        builder: (context, state) {
          return const BirthProfilePage();
        },
      ),

      GoRoute(
        path: '/home',
        builder: (context, state) {
          return const HomePage();
        },
      ),

      GoRoute(
        path: '/kundali',
        builder: (context, state) {
          return const KundaliLoaderPage();
        },
      ),
    ],
  );
}

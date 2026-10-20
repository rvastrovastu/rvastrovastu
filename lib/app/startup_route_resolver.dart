/// Pure routing decisions for app startup.
///
/// Keep navigation policy separate from storage and authentication services
/// so the decision logic can be covered by unit tests.
class StartupRouteResolver {
  const StartupRouteResolver._();

  static String routeAfterSplash({
    required bool hasSavedLanguage,
    required bool hasProfile,
    required bool supabaseConfigured,
    required bool authenticated,
  }) {
    if (!hasSavedLanguage) return '/language';
    if (!hasProfile) return '/onboarding';

    if (supabaseConfigured && !authenticated) {
      return '/auth';
    }

    return '/home';
  }

  static String routeAfterOnboarding({required bool supabaseConfigured}) {
    return supabaseConfigured ? '/auth' : '/home';
  }
}

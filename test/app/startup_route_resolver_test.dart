import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/app/startup_route_resolver.dart';

void main() {
  group('StartupRouteResolver.routeAfterSplash', () {
    test('first launch selects language before other decisions', () {
      expect(
        StartupRouteResolver.routeAfterSplash(
          hasSavedLanguage: false,
          hasProfile: false,
          supabaseConfigured: true,
          authenticated: false,
        ),
        '/language',
      );
    });

    test('saved language without a profile continues to onboarding', () {
      expect(
        StartupRouteResolver.routeAfterSplash(
          hasSavedLanguage: true,
          hasProfile: false,
          supabaseConfigured: true,
          authenticated: false,
        ),
        '/onboarding',
      );
    });

    test('returning user without a Supabase session goes to auth', () {
      expect(
        StartupRouteResolver.routeAfterSplash(
          hasSavedLanguage: true,
          hasProfile: true,
          supabaseConfigured: true,
          authenticated: false,
        ),
        '/auth',
      );
    });

    test('authenticated returning user goes to Home', () {
      expect(
        StartupRouteResolver.routeAfterSplash(
          hasSavedLanguage: true,
          hasProfile: true,
          supabaseConfigured: true,
          authenticated: true,
        ),
        '/home',
      );
    });

    test('local-only returning user goes to Home without authentication', () {
      expect(
        StartupRouteResolver.routeAfterSplash(
          hasSavedLanguage: true,
          hasProfile: true,
          supabaseConfigured: false,
          authenticated: false,
        ),
        '/home',
      );
    });
  });

  group('StartupRouteResolver.routeAfterOnboarding', () {
    test('requires the auth step when Supabase is configured', () {
      expect(
        StartupRouteResolver.routeAfterOnboarding(supabaseConfigured: true),
        '/auth',
      );
    });

    test('preserves local-only operation', () {
      expect(
        StartupRouteResolver.routeAfterOnboarding(supabaseConfigured: false),
        '/home',
      );
    });
  });
}

# RV Astro Vastu

Your family's honest astrologer: daily horoscope, Kundali, Panchang, festivals
and Vastu from your own chart, plus fixed-price consultations. Flutter app for
Android and iOS, with a Supabase backend.

- Astrology is calculated on the phone (Swiss Ephemeris, Lahiri ayanamsa).
- Supabase holds accounts, synced birth profiles, bookings and Ask AI usage.
- RevenueCat handles Premium and add-ons; Stripe handles consultations.
- Website and legal pages: `index.html` and `legal/`, served by GitHub Pages.

## Run it

```bash
flutter pub get
flutter gen-l10n
flutter run --dart-define-from-file=release.json
```

`release.json` holds the build settings (Supabase URL and publishable key,
RevenueCat public keys). It is git-ignored; ask the owner for a copy.

## Test

```bash
flutter analyze
flutter test
```

If the Swiss Ephemeris tests fail on a Mac with "slice is not valid mach-o
file", an Android build left its library in the cache: run `flutter clean`.

CI (`.github/workflows/ci.yml`) runs the app tests, applies every database
migration to Postgres with permission checks (`supabase/tests/`), and type
checks the edge functions.

## Release (Android)

1. Bump `version:` in `pubspec.yaml` (the number after `+` must go up).
2. `flutter build appbundle --release --dart-define-from-file=release.json`
3. Upload `build/app/outputs/bundle/release/app-release.aab` in Play Console.

Signing uses `android/key.properties` and the upload keystore, both
git-ignored and backed up outside this repository.

## Backend

```bash
supabase db push --remote                 # apply new migrations
supabase functions deploy ask-astrologer
supabase functions deploy create-consultation-checkout
supabase functions deploy stripe-webhook --no-verify-jwt
supabase functions deploy notify-consultation-paid --no-verify-jwt
```

Function secrets (AI keys, Stripe, RevenueCat, WhatsApp) live in the
Supabase dashboard, never in this repository.

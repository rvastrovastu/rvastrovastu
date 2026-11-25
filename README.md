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

## Website and web app

rvastrovastu.com serves the landing page (`index.html`, `cities/`, `legal/`)
at the root and the full app, built with Flutter web, under `/app/`.

```bash
tools/build_web.sh                 # → build/site, ready to upload
python3 -m http.server -d build/site 8080   # try it: localhost:8080/app/
DEPLOY=vercel tools/build_web.sh   # build and deploy with the Vercel CLI
```

The script copies the Swiss Ephemeris WebAssembly files from the `swisseph`
package into `web/`, builds with `--base-href /app/`, and assembles the
site with hosting headers for Vercel (`vercel.json`) and Netlify or
Cloudflare Pages (`_headers`). CI builds it on every push (artifact
`website`).

On the web: charts use the same Moshier ephemeris as the phones; Vastu plan
pictures are kept in the browser's IndexedDB; reminders and the home-screen
widget are phone-only; the compass falls back to the manual dial.

Premium on the web uses RevenueCat Web Billing (Stripe). One-time setup:

1. RevenueCat → Project → Apps → add a **Web Billing** app connected to
   your Stripe account; copy its public key (`rcb_…`) into `release.json`
   as `REVENUECAT_WEB_KEY` (and into the `RELEASE_JSON` CI secret).
2. Create web products with the **same identifiers** as the stores:
   `rv_premium_monthly`, `rv_premium_yearly` (7-day trial), `rv_kundli_pdf`,
   `rv_compatibility_pdf`, `rv_varshphal_pdf`, `rv_vastu_report`,
   `rv_ai_questions_10`; attach each to the same entitlement as on mobile.
3. Add the monthly and yearly packages to the **current** offering, and put
   the one-time products in packages of an offering named `web_addons`
   (the web SDK sells packages only).

Purchases follow the Supabase account, so Premium bought on the web shows
on the phone and the other way round.

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

Two Supabase projects: **staging** for trying changes, **production** for
users. Their refs are in `tools/supabase_projects.env`. Deploy migrations and
all functions to one of them, always staging first:

```bash
tools/deploy_backend.sh staging
tools/deploy_backend.sh production      # asks you to type "production"
```

### Staging

One-time setup:

1. Create a second project in the Supabase dashboard (free plan is fine),
   same region as production. Put its ref in `tools/supabase_projects.env`.
2. `tools/deploy_backend.sh staging` creates every table, rule and function.
3. In the staging project's Edge Function secrets, add the same names as
   production but with test values: Stripe **test** keys and a test webhook,
   one AI key, RevenueCat key. Leave WhatsApp unset to send no messages.
4. Copy `staging.example.json` to `staging.json` (git-ignored) and fill the
   staging URL and publishable key.

Run the app against staging:

```bash
flutter run --dart-define-from-file=staging.json
```

A staging build shows a STAGING ribbon and sends nothing to Firebase
Analytics or Crashlytics.

Function secrets (AI keys, Stripe, RevenueCat, WhatsApp) live in the
Supabase dashboard, never in this repository.

### Booking audit trail

Every change to a consultation booking is written to `audit_log` (who:
user, `service_role` for edge functions and the Stripe webhook, or
`database` for the dashboard and scheduled jobs; what changed, with old and
new values, contact details shown only as `changed`). App users cannot read
it. History of one booking, in the SQL editor:

```sql
select at, action, actor_role, changes
from audit_log
where table_name = 'consultation_requests' and row_id = '<booking id>'
order by at;
```

Rows are deleted after 7 years by `apply_retention()`.

## City pages

`cities/*.html` list a year of Purnima and Amavasya times per city. They
are generated; refresh them every year:

```bash
pip install pyswisseph
python3 tools/city_pages.py
```


#!/usr/bin/env bash
# Builds the whole website into build/site, ready to deploy:
#
#   build/site/               landing page (index.html), city pages, legal
#   build/site/app/           the full RV Astro Vastu app (Flutter web)
#
# Usage:
#   tools/build_web.sh                      # uses release.json
#   tools/build_web.sh staging.json         # any --dart-define file
#   DEPLOY=vercel tools/build_web.sh        # build, then `vercel deploy --prod`
#
# release.json needs REVENUECAT_WEB_KEY (the rcb_… Web Billing key) for
# Premium to sell on the web; without it the web app runs as free.
set -euo pipefail
cd "$(dirname "$0")/.."

DEFINES="${1:-release.json}"
OUT=build/site

echo "== Packages"
flutter pub get
flutter gen-l10n

echo "== Swiss Ephemeris WebAssembly"
SWISSEPH=$(python3 - <<'PY'
import json
cfg = json.load(open('.dart_tool/package_config.json'))
uri = next(p['rootUri'] for p in cfg['packages'] if p['name'] == 'swisseph')
print(uri.removeprefix('file://'))
PY
)
cp "$SWISSEPH/assets/swisseph.js" "$SWISSEPH/assets/swisseph.wasm" web/

echo "== Flutter web build (served at /app/)"
DEFINE_ARGS=()
if [[ -f "$DEFINES" ]]; then
  DEFINE_ARGS=(--dart-define-from-file="$DEFINES")
else
  echo "   ($DEFINES not found: building without backend or payments)"
fi
# --no-web-resources-cdn: serve CanvasKit from our own site rather than
# Google's CDN, so the app has no third-party dependency to load.
flutter build web --release --base-href /app/ --no-web-resources-cdn \
  --dart-define=APP_SHARE_URL=https://www.rvastrovastu.com/ \
  "${DEFINE_ARGS[@]}"

echo "== Assemble $OUT"
rm -rf "$OUT"
mkdir -p "$OUT"
cp index.html consult-success.html robots.txt sitemap.xml "$OUT/"
cp -r legal cities "$OUT/"
mkdir -p "$OUT/assets"
cp -r assets/site assets/images "$OUT/assets/"
cp -r build/web "$OUT/app"
# Keep only the CanvasKit files a JavaScript build loads (canvaskit and
# its chromium variant). skwasm/wimp are for --wasm builds, the
# webparagraph build is experimental, and .symbols are debug data: 37 MB
# down to about 12 MB, well inside Vercel's upload limit.
find "$OUT/app/canvaskit" -type f \
  ! -path '*/canvaskit/canvaskit.js' ! -path '*/canvaskit/canvaskit.wasm' \
  ! -path '*/canvaskit/chromium/canvaskit.js' \
  ! -path '*/canvaskit/chromium/canvaskit.wasm' -delete
find "$OUT/app/canvaskit" -type d -empty -delete
cp tools/web_hosting/vercel.json "$OUT/vercel.json"
cp tools/web_hosting/_headers "$OUT/_headers"

du -sh "$OUT" "$OUT/app"
echo "Done: open $OUT/index.html via a web server, e.g."
echo "   python3 -m http.server -d $OUT 8080   →   http://localhost:8080/app/"

if [[ "${DEPLOY:-}" == "vercel" ]]; then
  # Deploy a copy of the built site from outside the repo: inside a git
  # repo the Vercel CLI may upload from the repo root (SDK, caches: far over
  # its 100 MB file limit). vercel.json in the site turns off the old
  # project's install and build steps. The project link is kept in
  # tools/web_hosting/.vercel so it survives rebuilds.
  STAGE="$(mktemp -d)/rv_site"
  cp -R "$OUT" "$STAGE"
  if [[ -d tools/web_hosting/.vercel ]]; then
    cp -R tools/web_hosting/.vercel "$STAGE/"
  fi
  echo "   uploading $(du -sh "$STAGE" | cut -f1) from $STAGE"
  (cd "$STAGE" && vercel deploy --prod)
  if [[ -d "$STAGE/.vercel" ]]; then
    rm -rf tools/web_hosting/.vercel
    cp -R "$STAGE/.vercel" tools/web_hosting/
  fi
fi

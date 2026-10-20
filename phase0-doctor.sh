#!/usr/bin/env bash
#
# PlanBhai Phase 0 doctor. Read-only: inspects your setup and tells you what's
# left to do. Changes nothing.
#
# Usage:
#   bash ~/Downloads/phase0-doctor.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }

PASS=0; FAIL=0; WARN=0
ok()   { echo "  [ok]   $1"; PASS=$((PASS+1)); }
bad()  { echo "  [FIX]  $1"; FAIL=$((FAIL+1)); }
warn() { echo "  [warn] $1"; WARN=$((WARN+1)); }

echo "PlanBhai Phase 0 doctor"
echo "root: $ROOT"
echo

# --------------------------------------------------------------------------
echo "1. Repo layout"
[ -d backend ] && ok "backend/ found" || bad "no backend/ directory"
[ -f backend/server.js ] && ok "backend/server.js found" \
  || warn "backend/server.js not found - note your entry point"
if [ -d server ]; then
  if [ -z "$(find server -type f 2>/dev/null)" ]; then
    warn "empty server/ still present - rm -rf server"
  else
    warn "server/ has files in it - inspect before deleting"
  fi
fi
echo

# --------------------------------------------------------------------------
echo "2. Phase 0 files"
for f in \
  backend/models/DayBrief.js \
  backend/models/ExternalEvent.js \
  backend/models/SuggestionDismissal.js \
  backend/services/daybrief/tz.util.js \
  backend/services/daybrief/readiness.service.js \
  backend/services/daybrief/builders.service.js \
  backend/services/daybrief/context.adapter.js \
  backend/services/daybrief/daybrief.service.js \
  backend/routes/dashboard.routes.js \
  backend/routes/calendar.routes.js
do
  [ -f "$f" ] && ok "$f" || bad "missing $f - run install-phase0.sh"
done
[ -f PlanBhai/Services/CalendarSyncManager.swift ] \
  && ok "PlanBhai/Services/CalendarSyncManager.swift" \
  || bad "missing CalendarSyncManager.swift"
echo

# --------------------------------------------------------------------------
echo "3. Your existing middleware (the routes need these names)"
if [ -d backend/middleware ]; then
  found=$(ls backend/middleware 2>/dev/null | tr '\n' ' ')
  [ -n "$found" ] && ok "backend/middleware: $found" || warn "backend/middleware is empty"
else
  warn "no backend/middleware directory"
fi
echo "  --- auth-ish middleware referenced by your existing routes ---"
grep -rhoE "require\('\.\./middleware/[A-Za-z0-9_.-]+'\)" backend/routes 2>/dev/null \
  | sort -u | sed 's/^/       /' || echo "       (none found)"
echo "  --- what guards your AI endpoints ---"
grep -rlE "anthropic|claude|/ai/" backend/routes 2>/dev/null | head -5 | while read -r f; do
  echo "       $f:"
  grep -oE "router\.(get|post)\([^,]+,[^)]*" "$f" 2>/dev/null | head -3 | sed 's/^/         /'
done
echo "  NOTE: dashboard.routes.js and calendar.routes.js import"
echo "        requireAuth and requireHouseholdMember. Rename those imports to"
echo "        match whatever appears above."
echo

# --------------------------------------------------------------------------
echo "4. Household model shape (needed for requireHouseholdMember)"
HH=$(ls backend/models 2>/dev/null | grep -iE "household|family|group" | head -1)
if [ -n "$HH" ]; then
  ok "backend/models/$HH"
  echo "  --- members field ---"
  grep -nA4 -iE "members\s*:" "backend/models/$HH" 2>/dev/null | head -12 | sed 's/^/       /'
else
  warn "no household-like model found - check what you call it"
fi
echo

# --------------------------------------------------------------------------
echo "5. Node dependencies"
if [ -d backend/node_modules/mongoose ]; then
  ok "mongoose installed in backend/"
else
  bad "mongoose not in backend/node_modules - run: cd backend && npm install"
fi
[ -f backend/.env ] && ok "backend/.env present" || warn "no backend/.env"
echo

# --------------------------------------------------------------------------
echo "6. MongoDB"
URI="${MONGODB_URI:-}"
if [ -z "$URI" ] && [ -f backend/.env ]; then
  URI=$(grep -E "^MONGODB_URI=" backend/.env | head -1 | cut -d= -f2- | tr -d '"'"'"'')
  [ -n "$URI" ] && warn "MONGODB_URI not exported; read from backend/.env"
fi

if [ -z "$URI" ]; then
  bad "MONGODB_URI is unset. Your earlier mongosh hit the default 'test' db,"
  echo "         which is why 'ns does not exist' appeared."
  echo "         Fix:  export MONGODB_URI=\"\$(grep MONGODB_URI backend/.env | cut -d= -f2-)\""
else
  ok "MONGODB_URI resolved (${URI:0:28}...)"
  SETNAME=$(mongosh "$URI" --quiet --eval "try { db.hello().setName || 'STANDALONE' } catch(e) { 'UNREACHABLE' }" 2>/dev/null | tail -1)
  case "$SETNAME" in
    STANDALONE)
      bad "Mongo is STANDALONE - calendar.routes.js transactions will throw"
      echo "         Production on Render must be a replica set."
      ;;
    UNREACHABLE|"")
      bad "cannot reach Mongo at that URI"
      ;;
    *)
      ok "replica set '$SETNAME' - transactions supported"
      ;;
  esac
fi

echo "  --- what is holding port 27017 ---"
lsof -nP -iTCP:27017 -sTCP:LISTEN 2>/dev/null | tail -n +2 | sed 's/^/       /' \
  || echo "       nothing listening"
echo "  --- brew services ---"
brew services list 2>/dev/null | grep -i mongo | sed 's/^/       /' || echo "       (brew not present)"
echo

# --------------------------------------------------------------------------
echo "7. Pure-logic smoke test"
if [ -f backend/services/daybrief/readiness.service.js ]; then
  RESULT=$(node -e "
    const { computeReadiness } = require('./backend/services/daybrief/readiness.service.js');
    const r = computeReadiness({
      nowUtc: new Date('2026-07-30T12:00:00Z'), localDate: '2026-07-30',
      calendar: { connected: true, events: [] },
      meals: { used: true, primarySlot: 'dinner', planned: { title: 'X', haveRatio: 1, missing: [] } },
      groceries: { listExists: true, missingCount: 0 },
      family: { memberCount: 1, obligations: [] },
      habits: { active: [] }, finance: { tracked: false, bills: [] },
    });
    console.log(r ? r.score : 'null');
  " 2>&1 | tail -1)
  [ "$RESULT" = "100" ] && ok "readiness engine returns 100 on a perfect day" \
    || bad "readiness engine returned '$RESULT' (expected 100)"
else
  warn "skipped - readiness.service.js not installed"
fi
echo

# --------------------------------------------------------------------------
echo "8. Route registration"
ENTRY="backend/server.js"
[ -f "$ENTRY" ] || ENTRY=$(ls backend/app.js backend/index.js 2>/dev/null | head -1)
if [ -n "$ENTRY" ] && [ -f "$ENTRY" ]; then
  grep -q "dashboard.routes" "$ENTRY" && ok "dashboard route mounted in $ENTRY" \
    || bad "not mounted - add to $ENTRY (see section 9)"
  grep -q "calendar.routes" "$ENTRY" && ok "calendar route mounted in $ENTRY" \
    || bad "not mounted - add to $ENTRY (see section 9)"
fi
echo

# --------------------------------------------------------------------------
echo "=========================================="
echo "  $PASS ok / $WARN warnings / $FAIL to fix"
echo "=========================================="
echo
echo "9. If Mongo is STANDALONE, do this (one time):"
cat <<'HOWTO'
       brew services stop mongodb-community
       CONF="$(brew --prefix)/etc/mongod.conf"
       printf '\nreplication:\n  replSetName: rs0\n' >> "$CONF"
       brew services start mongodb-community
       sleep 3
       mongosh --quiet --eval 'rs.initiate()'

   Your earlier attempt failed with "Address already in use" because a mongod
   was already running on 27017 -- it never got as far as replication. Stopping
   the brew service first is the missing piece. Editing mongod.conf rather than
   passing --replSet also means it survives reboots.

10. Route registration snippet for backend/server.js:

       app.use('/api/dashboard', require('./routes/dashboard.routes'));
       app.use('/api/calendar',  require('./routes/calendar.routes'));

    Put these beside your existing app.use lines. Do NOT paste them into the
    terminal -- they go inside the file.
HOWTO

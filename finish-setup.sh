#!/usr/bin/env bash
#
# PlanBhai Phase 0 — finish wiring.
#
# Detects your existing auth middleware, creates requireHouseholdMember matching
# your real Household schema, fixes the imports in the two new route files, and
# mounts the routes in server.js.
#
# Everything it modifies is backed up to <file>.bak2 first. It refuses to guess
# about authentication: if it can't positively identify your auth middleware it
# stops and tells you, rather than mounting endpoints with no protection.
#
# Usage:
#   bash ~/Downloads/finish-setup.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
[ -d backend ] || { echo "ERROR: no backend/ under $ROOT"; exit 1; }

echo "PlanBhai Phase 0 — finish wiring"
echo "root: $ROOT"
echo

backup() { [ -f "$1" ] && cp "$1" "$1.bak2" && echo "    backed up $1 -> $1.bak2"; }

# ===========================================================================
echo "1. Looking for your auth middleware"
echo

echo "  --- how server.js mounts routes ---"
grep -n "app\.use(" backend/server.js | sed 's/^/     /'
echo
echo "  --- files that look like auth ---"
CANDIDATES=$(grep -rlE "jwt\.verify|jsonwebtoken|Bearer" backend --include="*.js" \
  2>/dev/null | grep -v node_modules | grep -v "/routes/dashboard\|/routes/calendar" | head -10)
if [ -n "$CANDIDATES" ]; then
  echo "$CANDIDATES" | sed 's/^/     /'
else
  echo "     (none found)"
fi
echo

# Try to identify the auth middleware module.
AUTH_PATH=""
AUTH_NAME=""
for f in $CANDIDATES; do
  case "$f" in
    *middleware*|*auth*|*Auth*)
      if grep -qE "module\.exports|exports\." "$f" 2>/dev/null; then
        AUTH_PATH="$f"
        break
      fi
      ;;
  esac
done

if [ -z "$AUTH_PATH" ]; then
  echo "  COULD NOT identify your auth middleware."
  echo
  echo "  Nothing has been changed. Please paste the output above into the chat,"
  echo "  plus the result of:"
  echo "     grep -rn \"jwt.verify\" backend --include=\"*.js\" | grep -v node_modules"
  echo
  exit 1
fi

echo "  Using: $AUTH_PATH"
echo "  --- what it exports ---"
grep -nE "module\.exports|exports\.[A-Za-z]+ *=" "$AUTH_PATH" | head -5 | sed 's/^/     /'
echo "  --- what it attaches to the request ---"
grep -noE "req\.(user|userId|auth)[A-Za-z._]*" "$AUTH_PATH" | sort -u -t: -k2 | head -8 | sed 's/^/     /'
echo

# Path that the route files (in backend/routes/) use to require it.
AUTH_REQUIRE="../$(echo "$AUTH_PATH" | sed 's|^backend/||' | sed 's|\.js$||')"

# Detect the export style: `module.exports = fn` vs `module.exports = { name }`
if grep -qE "module\.exports *= *(async *)?(function|\()" "$AUTH_PATH" \
   || grep -qE "module\.exports *= *[a-zA-Z_][a-zA-Z0-9_]* *;" "$AUTH_PATH"; then
  AUTH_IMPORT="const requireAuth = require('$AUTH_REQUIRE');"
else
  NAMED=$(grep -oE "exports\.[A-Za-z]+" "$AUTH_PATH" | head -1 | cut -d. -f2)
  [ -z "$NAMED" ] && NAMED=$(grep -oE "module\.exports *= *\{ *[A-Za-z]+" "$AUTH_PATH" \
    | grep -oE "[A-Za-z]+$" | head -1)
  if [ -n "$NAMED" ]; then
    AUTH_IMPORT="const { $NAMED: requireAuth } = require('$AUTH_REQUIRE');"
  else
    AUTH_IMPORT="const requireAuth = require('$AUTH_REQUIRE');"
  fi
fi
echo "  Import line to be used in the route files:"
echo "     $AUTH_IMPORT"
echo

# ===========================================================================
echo "2. Writing backend/middleware/requireHouseholdMember.js"
mkdir -p backend/middleware
backup backend/middleware/requireHouseholdMember.js

cat > backend/middleware/requireHouseholdMember.js << 'MW_EOF'
const mongoose = require('mongoose');
const Household = require('../models/Household');

/**
 * Confirms the caller actually belongs to the household they're asking about,
 * then attaches the validated id as req.scopeId.
 *
 * Downstream code reads ONLY req.scopeId, never req.query.scopeId. That's what
 * stops an unsubstituted ":scopeId" string from reaching a cache key.
 *
 * Household.members is a flat array of user ObjectIds:
 *   members: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }]
 * so membership is a direct match, not a nested `members.userId` lookup.
 */
module.exports = async function requireHouseholdMember(req, res, next) {
  try {
    // Different auth middlewares attach the user differently; accept the common shapes.
    const userId =
      (req.user && (req.user._id || req.user.id)) || req.userId || (req.auth && req.auth.userId);

    if (!userId) {
      return res.status(401).json({ error: 'Not authenticated' });
    }

    const raw = req.query.scopeId || req.body.scopeId || req.params.scopeId;

    if (!raw || !mongoose.Types.ObjectId.isValid(raw)) {
      return res.status(400).json({ error: 'A valid scopeId is required' });
    }

    const household = await Household.findOne({ _id: raw, members: userId }).select('_id');

    if (!household) {
      return res.status(403).json({ error: 'Not a member of this household' });
    }

    req.scopeId = household._id;
    if (!req.user) req.user = { _id: userId };
    next();
  } catch (err) {
    console.error('[requireHouseholdMember]', err);
    res.status(500).json({ error: 'Authorization check failed' });
  }
};
MW_EOF
echo "    wrote backend/middleware/requireHouseholdMember.js"
echo

# ===========================================================================
echo "3. Fixing imports in the new route files"
for f in backend/routes/dashboard.routes.js backend/routes/calendar.routes.js; do
  if [ ! -f "$f" ]; then
    echo "    MISSING $f — run install-phase0.sh first"
    continue
  fi
  backup "$f"
  python3 - "$f" "$AUTH_IMPORT" << 'PY_EOF'
import sys, re
path, auth_import = sys.argv[1], sys.argv[2]
src = open(path).read()
src = src.replace(
    "// Replace these two with your existing middleware.\n"
    "const requireAuth = require('../middleware/requireAuth');",
    auth_import)
src = src.replace(
    "// >>> EDIT: swap for the middleware already guarding your 10 AI endpoints.\n"
    "const requireAuth = require('../middleware/requireAuth');",
    auth_import)
src = re.sub(r"^const requireAuth = require\('\.\./middleware/requireAuth'\);$",
             auth_import, src, flags=re.M)
open(path, "w").write(src)
PY_EOF
  node --check "$f" && echo "    patched + parses: $f"
done
echo

# ===========================================================================
echo "4. Mounting the routes in backend/server.js"
if grep -q "dashboard.routes" backend/server.js; then
  echo "    already mounted, skipping"
else
  backup backend/server.js
  python3 - backend/server.js << 'PY_EOF'
import sys, re
path = sys.argv[1]
lines = open(path).read().split("\n")

# Insert right after the last existing app.use('/api...') mount so the new routes
# sit with their siblings and land before any 404 handler.
idx = max((i for i, l in enumerate(lines)
           if re.search(r"app\.use\(\s*[\"']/api", l)), default=None)

block = [
    "app.use('/api/dashboard', require('./routes/dashboard.routes'));",
    "app.use('/api/calendar',  require('./routes/calendar.routes'));",
]

if idx is None:
    idx = max((i for i, l in enumerate(lines) if "app.use(" in l), default=len(lines) - 1)

lines[idx + 1:idx + 1] = block
open(path, "w").write("\n".join(lines))
print(f"    inserted after line {idx + 1}")
PY_EOF
  node --check backend/server.js && echo "    server.js parses"
fi
echo

# ===========================================================================
echo "5. Verifying every new file loads"
cd backend
FAILED=0
for m in models/DayBrief models/ExternalEvent models/SuggestionDismissal \
         services/mongo.util services/daybrief/tz.util \
         services/daybrief/readiness.service services/daybrief/builders.service \
         services/daybrief/context.adapter services/daybrief/daybrief.service \
         middleware/requireHouseholdMember; do
  if node -e "require('./$m')" 2>/dev/null; then
    echo "    ok   $m"
  else
    ERR=$(node -e "require('./$m')" 2>&1 | grep -E "^(Error|[A-Za-z]*Error):" | head -1)
    echo "    FAIL $m"
    echo "         ${ERR:-unknown error}"
    FAILED=1
  fi
done
cd ..
echo

echo "=========================================="
if [ "$FAILED" = "0" ]; then
  echo "  Wiring complete."
  echo
  echo "  Next: start your backend and watch for errors."
  echo "     cd backend && npm start"
else
  echo "  Some modules failed to load — see above."
fi
echo "=========================================="

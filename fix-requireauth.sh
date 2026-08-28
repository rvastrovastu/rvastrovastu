#!/usr/bin/env bash
#
# Fixes the 401 properly.
#
# Two problems:
#   1. dashboard.routes.js and calendar.routes.js import '../routes/authRoutes'
#      as middleware. That's your login ROUTER — requests pass straight through
#      it and req.user is never set.
#   2. You have no shared auth middleware. The same jwt.verify block is
#      duplicated inline across six route files.
#
# This creates backend/middleware/requireAuth.js using the exact same logic as
# your aiRoutes.js requireUser(), and points the two new routes at it.
#
# Your six existing route files are NOT touched. Nothing that works today can
# break as a result of this.
#
# Usage:
#   bash ~/Downloads/fix-requireauth.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
[ -d backend ] || { echo "ERROR: no backend/ under $ROOT"; exit 1; }

echo "PlanBhai — fixing requireAuth"
echo

# ---------------------------------------------------------------------------
echo "1. Sanity checks"
[ -f backend/config/jwt.js ] \
  && echo "   ok   backend/config/jwt.js found" \
  || { echo "   FAIL backend/config/jwt.js missing — stopping"; exit 1; }
[ -f backend/models/User.js ] \
  && echo "   ok   backend/models/User.js found" \
  || { echo "   FAIL backend/models/User.js missing — stopping"; exit 1; }
echo

# ---------------------------------------------------------------------------
echo "2. Creating backend/middleware/requireAuth.js"
F=backend/middleware/requireAuth.js
[ -f "$F" ] && cp "$F" "$F.bak" && echo "   backed up -> $F.bak"

cat > "$F" << 'MW_EOF'
const jwt = require("jsonwebtoken");
const JWT_SECRET = require("../config/jwt");
const User = require("../models/User");

/**
 * Express middleware version of the requireUser() helper that is currently
 * duplicated inline across aiRoutes, householdRoutes, appDataRoutes, pushRoutes,
 * billingRoutes and authRoutes.
 *
 * Same logic, same JWT_SECRET, same response shape — the only difference is that
 * this one is composable, so routes can list it alongside other guards instead of
 * copying the block again.
 *
 * On success it attaches the full User document as req.user, so downstream code
 * can read req.user._id.
 *
 * Worth doing eventually: switch the six existing files to import this too. Six
 * independent copies of a token check is how signing/verification mismatches
 * creep in — one copy drifts and the failure shows up somewhere unrelated.
 */
module.exports = async function requireAuth(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res.status(401).json({ success: false, message: "No token provided" });
  }

  try {
    const token = authHeader.split(" ")[1];
    const decoded = jwt.verify(token, JWT_SECRET);
    const user = await User.findById(decoded.id);

    if (!user) {
      return res.status(404).json({ success: false, message: "User not found" });
    }

    req.user = user;
    next();
  } catch (error) {
    return res.status(401).json({ success: false, message: "Invalid or expired token" });
  }
};
MW_EOF

node --check "$F" && echo "   wrote + parses: $F"
echo

# ---------------------------------------------------------------------------
echo "3. Repointing the two new route files"
for f in backend/routes/dashboard.routes.js backend/routes/calendar.routes.js; do
  [ -f "$f" ] || { echo "   MISSING $f"; continue; }
  cp "$f" "$f.bak4"

  python3 - "$f" << 'PY_EOF'
import sys, re
path = sys.argv[1]
src = open(path).read()
good = "const requireAuth = require('../middleware/requireAuth');"
# Replace whatever requireAuth currently points at — authRoutes was wrong.
src = re.sub(r"const requireAuth = require\('[^']*'\);", good, src)
src = re.sub(r'const requireAuth = require\("[^"]*"\);', good, src)
open(path, "w").write(src)
PY_EOF

  LINE=$(grep -n "requireAuth = require" "$f" | head -1)
  node --check "$f" && echo "   $f"
  echo "        $LINE"
done
echo

# ---------------------------------------------------------------------------
echo "4. Verifying the modules load"
cd backend
OK=1
for m in middleware/requireAuth middleware/requireHouseholdMember \
         routes/dashboard.routes routes/calendar.routes; do
  if node -e "require('./$m')" 2>/dev/null; then
    echo "   ok   $m"
  else
    ERR=$(node -e "require('./$m')" 2>&1 | grep -E "^[A-Za-z]*Error:" | head -1)
    echo "   FAIL $m"
    echo "        ${ERR:-unknown error}"
    OK=0
  fi
done
cd ..
echo

echo "=========================================="
if [ "$OK" = "1" ]; then
  echo "  Fixed. Now RESTART the server — Node only reads"
  echo "  files at startup, so nothing changes until you do:"
  echo
  echo "    kill \$(lsof -ti tcp:5001) 2>/dev/null; sleep 2"
  echo "    cd backend && npm start"
  echo
  echo "  Then in a second window:"
  echo "    bash ~/Downloads/test-dashboard.sh $ROOT"
else
  echo "  Something failed to load — see above."
fi
echo "=========================================="

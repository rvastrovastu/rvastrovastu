#!/usr/bin/env bash
#
# Fixes the 401 from requireHouseholdMember.
#
# Your auth middleware attaches the logged-in user in a shape the first version
# didn't recognise. This replaces it with one that accepts every common shape and,
# if it still can't find an id, prints exactly what IS on the request so we can
# stop guessing.
#
# Usage:
#   bash ~/Downloads/fix-auth-shape.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
[ -d backend ] || { echo "ERROR: no backend/ under $ROOT"; exit 1; }

echo "1. What your auth middleware attaches"
echo
grep -rln "jwt\.verify" --include="*.js" backend 2>/dev/null | grep -v node_modules | while read -r f; do
  echo "   --- $f ---"
  grep -nE "req\.[a-zA-Z_]+ *=|req\.[a-zA-Z_]+\.[a-zA-Z_]+ *=" "$f" | sed 's/^/     /'
done
echo

echo "2. Which file the routes import as requireAuth"
grep -n "requireAuth = require\|requireAuth }" backend/routes/dashboard.routes.js | sed 's/^/   /'
echo

echo "3. Replacing requireHouseholdMember"
F=backend/middleware/requireHouseholdMember.js
[ -f "$F" ] && cp "$F" "$F.bak3" && echo "   backed up -> $F.bak3"

cat > "$F" << 'MW_EOF'
const mongoose = require('mongoose');
const Household = require('../models/Household');

/**
 * Confirms the caller belongs to the household they're asking about, then
 * attaches the validated id as req.scopeId. Downstream code reads only
 * req.scopeId, never req.query.scopeId — that's what keeps an unsubstituted
 * ":scopeId" string from reaching a cache key.
 *
 * Household.members is a flat array of user ObjectIds, so membership is a
 * direct match rather than a nested `members.userId` lookup.
 */

/**
 * Auth middlewares vary in where they put the logged-in user. Rather than
 * assuming one shape, check all the common ones. If none match we log the actual
 * request keys, because a silent 401 with no clue is the worst possible failure.
 */
function extractUserId(req) {
  const candidates = [
    req.user && req.user._id,
    req.user && req.user.id,
    req.user && req.user.userId,
    req.user && req.user.userID,
    req.user && req.user.sub,
    req.userId,
    req.userID,
    req.user_id,
    req.auth && req.auth.userId,
    req.auth && req.auth.id,
    req.auth && req.auth._id,
    req.auth && req.auth.sub,
    req.userData && req.userData.userId,
    req.userData && req.userData.id,
    req.currentUser && req.currentUser._id,
    req.currentUser && req.currentUser.id,
    typeof req.user === 'string' ? req.user : null,
  ];

  for (const c of candidates) {
    if (c && mongoose.Types.ObjectId.isValid(String(c))) return String(c);
  }
  return null;
}

module.exports = async function requireHouseholdMember(req, res, next) {
  try {
    const userId = extractUserId(req);

    if (!userId) {
      // Diagnostic: this prints once to the server console and tells us exactly
      // which property to read, instead of leaving a bare 401.
      console.error(
        '[requireHouseholdMember] no user id found on the request.\n' +
          '  req.user     = ' + JSON.stringify(req.user) + '\n' +
          '  req.userId   = ' + JSON.stringify(req.userId) + '\n' +
          '  req.auth     = ' + JSON.stringify(req.auth) + '\n' +
          '  req.userData = ' + JSON.stringify(req.userData) + '\n' +
          '  custom keys  = ' +
          JSON.stringify(
            Object.keys(req).filter(
              (k) => !k.startsWith('_') && typeof req[k] !== 'function' && k.length < 20
            )
          )
      );
      return res.status(401).json({ error: 'Not authenticated' });
    }

    const raw = req.query.scopeId || req.body.scopeId || req.params.scopeId;

    if (!raw || !mongoose.Types.ObjectId.isValid(raw)) {
      return res.status(400).json({ error: 'A valid scopeId is required' });
    }

    const household = await Household.findOne({ _id: raw, members: userId }).select('_id');

    if (!household) {
      console.warn(
        `[requireHouseholdMember] user ${userId} is not a member of household ${raw}`
      );
      return res.status(403).json({ error: 'Not a member of this household' });
    }

    req.scopeId = household._id;
    if (!req.user || typeof req.user !== 'object') req.user = {};
    if (!req.user._id) req.user._id = userId;
    next();
  } catch (err) {
    console.error('[requireHouseholdMember]', err);
    res.status(500).json({ error: 'Authorization check failed' });
  }
};
MW_EOF

node --check "$F" && echo "   wrote + parses: $F"
echo
echo "=========================================="
echo "  Restart the server, then run the test again:"
echo
echo "    kill \$(lsof -ti tcp:5001) 2>/dev/null; sleep 2; cd backend && npm start"
echo
echo "  If it still returns 401, the server window will now print"
echo "  exactly what is on the request. Paste that."
echo "=========================================="

#!/usr/bin/env bash
#
# Wires dashboard cache invalidation, and removes the .bak files that got
# committed by mistake.
#
# Without this, saving a meal or ticking off a chore leaves the dashboard showing
# the cached brief UNTIL MIDNIGHT. To a user that reads as "the app is broken",
# and because they can't tell which parts are stale it undermines trust in the
# whole screen.
#
# Usage:
#   bash ~/Downloads/wire-cache-bust.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
[ -d backend ] || { echo "ERROR: no backend/ under $ROOT"; exit 1; }

echo "PlanBhai — cache invalidation"
echo

# ---------------------------------------------------------------------------
echo "1. Removing committed .bak files"
COUNT=$(git ls-files | grep -cE "\.bak[0-9a-z]*$" || true)
if [ "$COUNT" = "0" ]; then
  echo "   none tracked — nothing to do"
else
  git ls-files | grep -E "\.bak[0-9a-z]*$" | while read -r f; do
    git rm --cached --quiet "$f" 2>/dev/null && echo "   untracked $f"
  done
fi

if ! grep -q "^\*\.bak" .gitignore 2>/dev/null; then
  printf '\n# backups written by setup scripts\n*.bak\n*.bak[0-9]\n*.bakfinal\n' >> .gitignore
  echo "   added *.bak patterns to .gitignore"
fi
echo

# ---------------------------------------------------------------------------
echo "2. Adding bustBriefsForOwner to daybrief.service.js"
F=backend/services/daybrief/daybrief.service.js
[ -f "$F" ] || { echo "   ERROR: $F not found"; exit 1; }

if grep -q "bustBriefsForOwner" "$F"; then
  echo "   already present, skipping"
else
  cp "$F" "$F.bakbust"
  python3 - "$F" << 'PY_EOF'
import sys, re
p = sys.argv[1]
s = open(p).read()

if "const mongoose = require('mongoose');" not in s:
    s = s.replace("const DayBrief = require('../../models/DayBrief');",
                  "const mongoose = require('mongoose');\nconst DayBrief = require('../../models/DayBrief');", 1)
if "models/Household" not in s:
    s = s.replace("const DayBrief = require('../../models/DayBrief');",
                  "const DayBrief = require('../../models/DayBrief');\nconst Household = require('../../models/Household');", 1)

fn = '''
/**
 * Busts briefs for an AppData owner id.
 *
 * AppData.userId is overloaded — it holds a household id for shared types
 * (groceries, events, calendar_events, party_events, household_notes) and a user
 * id for personal ones (habits, chores, meal_plan, family_members). So:
 *
 *   household id -> bust that household
 *   user id      -> bust EVERY household they belong to, because their chores,
 *                   habits and meal_plan feed each of those dashboards
 */
async function bustBriefsForOwner(ownerId) {
  if (!ownerId || !mongoose.Types.ObjectId.isValid(String(ownerId))) {
    return { deletedCount: 0 };
  }

  const oid = new mongoose.Types.ObjectId(String(ownerId));
  const scopeIds = new Set();

  const [asHousehold, memberOf] = await Promise.all([
    Household.exists({ _id: oid }),
    Household.find({ members: oid }).select('_id').lean(),
  ]);

  if (asHousehold) scopeIds.add(String(oid));
  for (const h of memberOf) scopeIds.add(String(h._id));

  if (scopeIds.size === 0) return { deletedCount: 0 };

  const today = new Date().toISOString().slice(0, 10);
  return DayBrief.deleteMany({
    scopeId: { $in: [...scopeIds].map((s) => new mongoose.Types.ObjectId(s)) },
    localDate: { $gte: today },
  });
}

module.exports = {'''

s = re.sub(r"module\.exports = \{", fn, s, count=1)
s = s.replace("module.exports = { getTodayBrief, bustDayBrief, buildBrief, decorateForRead };",
              "module.exports = {\n  getTodayBrief,\n  bustDayBrief,\n  bustBriefsForOwner,\n  buildBrief,\n  decorateForRead,\n};")
if "bustBriefsForOwner," not in s.split("module.exports")[-1]:
    s = re.sub(r"(module\.exports = \{\s*\n\s*getTodayBrief,)",
               r"\1\n  bustBriefsForOwner,", s, count=1)

open(p, "w").write(s)
PY_EOF
  node --check "$F" && echo "   patched + parses"
fi
echo

# ---------------------------------------------------------------------------
echo "3. Hooking appDataRoutes.js"
R=backend/routes/appDataRoutes.js
[ -f "$R" ] || { echo "   ERROR: $R not found"; exit 1; }

if grep -q "bustBriefsForOwner" "$R"; then
  echo "   already hooked, skipping"
else
  cp "$R" "$R.bakbust"
  python3 - "$R" << 'PY_EOF'
import sys, re
p = sys.argv[1]
s = open(p).read()

anchor = re.search(r"const router = express\.Router\(\);", s)
if not anchor:
    print("   ERROR: could not find 'const router = express.Router();'")
    sys.exit(1)

hook = '''

// --- dashboard cache invalidation -------------------------------------------
// Every AppData mutation goes through /:userId/:type, so one hook here covers
// meals, chores, groceries, events and habits — no per-handler edits, so nothing
// that currently works can break.
//
// The bust runs BEFORE the response is sent. A client that saves and immediately
// reloads its dashboard would otherwise race the cache and see stale data, which
// is exactly the confusing case this is meant to prevent.
const { bustBriefsForOwner } = require("../services/daybrief/daybrief.service");

router.use((req, res, next) => {
  if (!["POST", "PUT", "DELETE"].includes(req.method)) return next();

  // req.params isn't populated yet at router level, so read the path directly:
  // "/<userId>/<type>[/<itemId>]"
  const owner = String(req.path || "").split("/").filter(Boolean)[0];
  if (!owner) return next();

  let busted = false;
  const bust = async () => {
    if (busted) return;
    busted = true;
    try {
      await bustBriefsForOwner(owner);
    } catch (e) {
      // Never let cache cleanup fail a save the user already made.
      console.error("[daybrief] cache bust failed:", e.message);
    }
  };

  const sendJson = res.json.bind(res);
  res.json = (body) => {
    if (res.statusCode >= 400 || (body && body.success === false)) return sendJson(body);
    bust().finally(() => sendJson(body));
    return res;
  };

  // Safety net for any handler that responds via send/end instead of json.
  res.on("finish", () => {
    if (res.statusCode < 400) bust();
  });

  next();
});
'''

i = anchor.end()
s = s[:i] + hook + s[i:]
open(p, "w").write(s)
PY_EOF
  node --check "$R" && echo "   patched + parses"
fi
echo

# ---------------------------------------------------------------------------
echo "4. Verifying modules load"
cd backend
for m in services/daybrief/daybrief.service routes/appDataRoutes; do
  if node -e "require('dotenv').config(); require('./$m')" 2>/dev/null; then
    echo "   ok   $m"
  else
    echo "   FAIL $m"
    node -e "require('dotenv').config(); require('./$m')" 2>&1 | grep -E "^[A-Za-z]*Error:" | head -1 | sed 's/^/        /'
  fi
done
cd ..
echo

echo "=========================================="
echo "  Restart, then test that a save clears the cache:"
echo "     bash ~/Downloads/phase0-final.sh $ROOT"
echo "=========================================="

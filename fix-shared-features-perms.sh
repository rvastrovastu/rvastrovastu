#!/usr/bin/env bash
#
# Closes a live permissions hole.
#
# POST /api/households/update-shared-features checked that the caller was a
# MEMBER, and nothing more. So any member could turn Meals, Grocery or Calendar
# off for the entire household.
#
# Hiding the toggle in the app would not have fixed it — the endpoint is
# reachable directly with any member's token. This is the server-side half, and
# it is the half that matters.
#
# household.isAdmin() already exists on the model and covers the creator plus
# any co-admins they have appointed. Nothing new to store.
#
# THE UI STILL SHOWS THE TOGGLE to everyone; non-owners will now get a clear
# error instead of a silent change. Greying it out for non-owners is a separate,
# smaller change worth doing next.
#
# Only householdRoutes.js changes.
#
# Usage:
#   bash ~/Downloads/fix-shared-features-perms.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
R="backend/routes/householdRoutes.js"
[ -f "$R" ] || { echo "ERROR: $R not found"; exit 1; }

echo "PlanBhai — owner-only shared features"
echo

echo "1. Confirming the model has what we need"
grep -q "isAdmin = function" backend/models/Household.js \
  && echo "   ok   Household.isAdmin exists" \
  || { echo "   MISSING isAdmin on the model"; exit 1; }
grep -q "createdBy" backend/models/Household.js \
  && echo "   ok   createdBy recorded" \
  || { echo "   MISSING createdBy"; exit 1; }
echo

echo "2. Patching"
cp "$R" "$R.bakperms"
cat > /tmp/pb_perms.py << 'PLANBHAI_EOF'
import sys
p = sys.argv[1]
s = open(p).read()

old = """        if (!household.members.some(id => id.toString() === user._id.toString())) {
            return res.status(403).json({ success: false, message: "You're not a member of this household" });
        }

        household.sharedFeatures = sharedFeatures || [];"""

new = """        if (!household.members.some(id => id.toString() === user._id.toString())) {
            return res.status(403).json({ success: false, message: "You're not a member of this household" });
        }

        // Membership alone was enough here, so ANY member could turn Meals or
        // Grocery off for everyone. Hiding the toggle in the app would not have
        // helped — the endpoint is reachable directly.
        //
        // isAdmin covers the creator and any co-admins they have appointed.
        if (!household.isAdmin(user._id)) {
            return res.status(403).json({
                success: false,
                message: "Only the household owner can change shared features",
            });
        }

        household.sharedFeatures = sharedFeatures || [];"""

if 'isAdmin(user._id)' in s and 'shared features' in s:
    print("   already protected"); sys.exit(3)
if old not in s:
    print("   ERROR: the handler is not in the expected shape"); sys.exit(2)

s = s.replace(old, new, 1)
open(p, "w").write(s)
print("   owner check added")
PLANBHAI_EOF
python3 /tmp/pb_perms.py "$R"
RC=$?
rm -f /tmp/pb_perms.py
if [ "$RC" = "3" ]; then
  echo "   nothing to do"
elif [ "$RC" != "0" ]; then
  cp "$R.bakperms" "$R"
  echo "   reverted"
  exit 1
fi
node --check "$R" || { echo "   PARSE FAILED — reverting"; cp "$R.bakperms" "$R"; exit 1; }
echo "   parses"
echo

echo "3. Who owns what"
cd backend
node -e '
require("dotenv").config();
const m = require("mongoose");
(async () => {
  await m.connect(process.env.MONGODB_URI);
  const H = require("./models/Household"), U = require("./models/User");
  for (const h of await H.find({}).lean()) {
    const owner = await U.findById(h.createdBy).select("name email").lean();
    console.log("   " + h.name.padEnd(16) + "owner: " + (owner ? owner.email : "unknown") +
                "   admins: " + (h.admins || []).length);
  }
  await m.disconnect();
})().catch(e => console.log("   " + e.message));
' 2>/dev/null
cd ..
echo

echo "=========================================="
echo "  Deploy:"
echo "     git add -A && git commit -m 'Only household owners can change shared features' && git push"
echo "  then Manual Deploy on Render."
echo
echo "  Verify — this should now be rejected for a non-owner:"
echo "     curl -X POST .../api/households/update-shared-features \\"
echo "       -H \"Authorization: Bearer \$TOK\" -H 'Content-Type: application/json' \\"
echo "       -d '{\"householdId\":\"...\",\"sharedFeatures\":[]}'"
echo
echo "  Revert:  cp $R.bakperms $R"
echo "=========================================="

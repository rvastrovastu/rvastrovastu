#!/usr/bin/env bash
#
# The durable fix: web writes UUIDs.
#
# THE ROOT CAUSE, traced at last
#   Web generated ids like "mse37xjyqb9hzh" — Date.now() in base 36 plus some
#   randomness. iOS structs declare `let id: UUID`. One web-written row makes
#   the WHOLE list fail to decode, so 30 party guests and 9 menu items were
#   invisible on the phone while sitting in the database.
#
#   Six Swift structs had to be made tolerant before this was traced to its
#   source: Challenge, GroupMember, PlanGroup, Habit, PartyGuest, PartyMenuItem.
#   Eight more were exposed and simply had not been written from web yet —
#   Chore, FamilyMember, PantryItem, GroceryItem, BudgetItem, FamilyPhoto,
#   LocationShare, SettlementEntry, Vendor.
#
# WHY FIX WEB RATHER THAN THE NINE STRUCTS
#   iOS has always written UUIDs. Web is the side producing incompatible ids.
#   One helper fixes every type at once — including ones neither of us has
#   enumerated — instead of nine Swift edits with regression risk across screens
#   that currently work.
#
# WHAT THIS DOES
#   Adds newId() to api.js, removes the two local copies, and replaces nine
#   inline uses across Calendar, HouseholdDetail, Meals and Party.
#
# WHAT IT DOES NOT DO
#   Existing JS ids stay in the database, which is why the tolerant decoders
#   already shipped still matter. And the eight iOS structs still declare
#   `let id: UUID` — they simply stop being hit. Migrating those to String is a
#   separate, unhurried job.
#
# Usage:
#   bash ~/Downloads/fix-web-ids.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
[ -d web/src ] || { echo "ERROR: no web/src under $ROOT"; exit 1; }

echo "PlanBhai — web writes UUIDs"
echo

echo "1. Before"
grep -rc "Date.now().toString(36)" web/src/pages/*.jsx 2>/dev/null | grep -v ":0" | grep -v "\.bak" | sed 's/^/   /'
echo

echo "2. Backing up"
for f in web/src/api.js web/src/pages/Calendar.jsx web/src/pages/HouseholdDetail.jsx \
         web/src/pages/Meals.jsx web/src/pages/Party.jsx; do
  [ -f "$f" ] && cp "$f" "$f.bakids"
done
echo "   done"
echo

echo "3. Patching"
cat > /tmp/pb_newid.py << 'PLANBHAI_EOF'
import sys, re, os

web = sys.argv[1]
JS_ID = "Date.now().toString(36) + Math.random().toString(36).slice(2, 8)"

# 1. The helper, in api.js so every page can reach it.
api = os.path.join(web, 'src/api.js')
s = open(api).read()
if 'export function newId' not in s:
    helper = '''/**
 * A UUID, uppercase — the same shape iOS writes.
 *
 * Web previously generated JavaScript ids like "mse37xjyqb9hzh". iOS structs
 * declare `let id: UUID`, so a single web-written row made the WHOLE list fail
 * to decode: 30 party guests and 9 menu items were invisible on the phone while
 * sitting in the database.
 *
 * Six structs had to be made tolerant before this was traced to its source.
 * Generating compatible ids here fixes every type at once, including ones
 * nobody has enumerated.
 */
export function newId() {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) {
    return crypto.randomUUID().toUpperCase();
  }
  // Older browsers. Same shape, weaker randomness — acceptable for a local id.
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    return (c === 'x' ? r : (r & 0x3) | 0x8).toString(16);
  }).toUpperCase();
}

'''
    anchor = "const BASE_URL"
    if anchor not in s:
        print("ERROR: could not find BASE_URL in api.js"); sys.exit(2)
    s = s.replace(anchor, helper + anchor, 1)
    open(api, 'w').write(s)
    print("  api.js: added newId()")
else:
    print("  api.js: newId() already present")

# 2. Every page.
pages = ['Calendar.jsx', 'HouseholdDetail.jsx', 'Meals.jsx', 'Party.jsx']
total = 0
for name in pages:
    p = os.path.join(web, 'src/pages', name)
    if not os.path.exists(p):
        print(f"  {name}: not found"); continue
    s = open(p).read()
    before = s

    # Drop the local definitions.
    s = re.sub(r"function newId\(\) \{\n  return " + re.escape(JS_ID) + r";\n\}\n\n?", "", s)

    # Replace inline uses.
    n = s.count(JS_ID)
    s = s.replace(JS_ID, "newId()")

    # Import it if the file now uses it.
    if 'newId()' in s and 'newId' not in s.split('\n')[0:20][0:0] :
        pass
    if 'newId()' in s and not re.search(r"import \{[^}]*\bnewId\b[^}]*\} from '\.\./api'", s):
        m = re.search(r"import \{ api \} from '\.\./api';", s)
        if m:
            s = s[:m.start()] + "import { api, newId } from '../api';" + s[m.end():]
        else:
            m2 = re.search(r"^import .*\n", s, re.M)
            s = s[:m2.end()] + "import { newId } from '../api';\n" + s[m2.end():]

    if s != before:
        open(p, 'w').write(s)
        total += n
        print(f"  {name}: {n} replaced")

print(f"total inline ids replaced: {total}")
PLANBHAI_EOF
python3 /tmp/pb_newid.py web
RC=$?
rm -f /tmp/pb_newid.py
if [ "$RC" != "0" ]; then
  for f in web/src/api.js web/src/pages/Calendar.jsx web/src/pages/HouseholdDetail.jsx \
           web/src/pages/Meals.jsx web/src/pages/Party.jsx; do
    [ -f "$f.bakids" ] && cp "$f.bakids" "$f"
  done
  echo "   reverted everything"
  exit 1
fi
echo

echo "4. After"
n=$(grep -rl "Date.now().toString(36)" web/src/pages/*.jsx 2>/dev/null | grep -v "\.bak" | wc -l | tr -d ' ')
[ "$n" = "0" ] && echo "   ok   no JS ids left in live pages" \
              || { echo "   $n file(s) still generating JS ids:"; grep -rl "Date.now().toString(36)" web/src/pages/*.jsx | grep -v "\.bak" | sed 's/^/      /'; }
grep -q "export function newId" web/src/api.js && echo "   ok   newId() exported"
echo

echo "5. Building"
(cd web && npm run build 2>&1 | grep -E "ERROR|error during|✓ built" | head -8)
echo

echo "=========================================="
echo "  Deploy:  git add -A && git commit -m 'Web writes UUIDs' && git push"
echo "           then cd web && vercel --prod"
echo
echo "  Test it: add a chore or family member from web, then open iOS. It should"
echo "  appear rather than making the whole list vanish."
echo
echo "  Revert:  for f in web/src/api.js web/src/pages/{Calendar,HouseholdDetail,Meals,Party}.jsx; do cp \$f.bakids \$f; done"
echo "=========================================="

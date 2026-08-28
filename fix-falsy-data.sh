#!/usr/bin/env bash
#
# Fixes falsy AppData values being returned as [].
#
#   record?.data || []   ->   record ? record.data : []
#
# `0`, `""` and `false` are falsy, so `||` replaced them with an empty array.
# ai_import_count is 0 right now, and water_glasses is 0 every morning after the
# daily reset — iOS then fails to decode an array as an Int.
#
# Shows a diff and verifies. Reverts on any failure.
#
# Usage:
#   bash ~/Downloads/fix-falsy-data.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
F="backend/routes/appDataRoutes.js"
[ -f "$F" ] || { echo "ERROR: $F not found"; exit 1; }

echo "PlanBhai — fixing falsy AppData values"
echo

echo "1. Lines that will change"
grep -n "data ||" "$F" | sed 's/^/   /'
COUNT=$(grep -c "data ||" "$F")
echo
if [ "$COUNT" = "0" ]; then
  echo "   No matches — already fixed, or the pattern differs."
  echo "   Anything referencing .data in a response:"
  grep -n "\.data" "$F" | grep -i "res\|return\|data:" | sed 's/^/      /' | head
  exit 0
fi
echo "   $COUNT occurrence(s)"
echo

echo "2. Patching"
cp "$F" "$F.bakfalsy"

python3 - "$F" << 'PY_EOF'
import sys, re
p = sys.argv[1]
s = open(p).read()
orig = s

# Known variants. `record ? record.data : []` preserves 0, "" and false while
# still returning [] when there is genuinely no record.
subs = [
    (r"record\?\.data \|\| \[\]", "record ? record.data : []"),
    (r"record\.data \|\| \[\]",   "record ? record.data : []"),
    (r"updated\?\.data \|\| \[\]", "updated ? updated.data : []"),
    (r"updated\.data \|\| \[\]",   "updated ? updated.data : []"),
]

total = 0
for pat, rep in subs:
    s, n = re.subn(pat, rep, s)
    total += n

if total == 0:
    print("   nothing matched the known patterns — no changes made")
    sys.exit(2)

open(p, "w").write(s)
print(f"   replaced {total} occurrence(s)")
PY_EOF
RC=$?

if [ "$RC" = "2" ]; then
  rm -f "$F.bakfalsy"
  echo
  echo "   Showing every '.data ||' line so it can be fixed by hand:"
  grep -n "data ||" "$F" | sed 's/^/      /'
  exit 1
elif [ "$RC" != "0" ]; then
  cp "$F.bakfalsy" "$F"
  echo "   FAILED — reverted"
  exit 1
fi
echo

echo "3. Diff"
diff "$F.bakfalsy" "$F" | sed 's/^/   /'
echo

echo "4. Verifying"
node --check "$F" || { echo "   PARSE FAILED — reverting"; cp "$F.bakfalsy" "$F"; exit 1; }
echo "   parses"

LEFT=$(grep -c "data ||" "$F")
if [ "$LEFT" = "0" ]; then
  echo "   no 'data ||' patterns remain"
else
  echo "   WARNING: $LEFT still remain:"
  grep -n "data ||" "$F" | sed 's/^/      /'
fi
echo

echo "=========================================="
echo "  Deploy all pending fixes:"
echo "     git add -A"
echo "     git commit -m 'Fix falsy AppData values returning []'"
echo "     git push"
echo "  then Manual Deploy on Render."
echo
echo "  Revert if needed:  cp $F.bakfalsy $F"
echo "=========================================="

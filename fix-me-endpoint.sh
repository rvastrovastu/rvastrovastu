#!/usr/bin/env bash
#
# Fixes GET /api/auth/me.
#
#   jwt.verify() returns a payload keyed `id`, but /me reads `decoded.userId`,
#   which is undefined. findById(undefined) returns null, so /me has ALWAYS
#   responded 404. That's why currentUser was never populated, which is why
#   userId fell through to "guest-<jwt>" — the source of the 57 orphaned records.
#
# Verifies the token really is signed with `id` before changing anything.
#
# Usage:
#   bash ~/Downloads/fix-me-endpoint.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
F="backend/routes/authRoutes.js"
[ -f "$F" ] || { echo "ERROR: $F not found"; exit 1; }

echo "PlanBhai — fixing /api/auth/me"
echo

echo "1. What the token is signed with"
grep -n "jwt.sign" -A 3 "$F" | sed 's/^/   /'
echo

if grep -q "jwt.sign(\s*{\s*id:" "$F" || grep -A2 "jwt.sign" "$F" | grep -q "id:"; then
  echo "   -> payload uses 'id'"
else
  echo "   Could not confirm the payload key. Not changing anything."
  echo "   Paste the jwt.sign block above into the chat."
  exit 1
fi
echo

echo "2. How other routes read it (these all work)"
grep -rn "decoded\.id\|decoded\.userId" --include="*.js" backend/routes backend/middleware 2>/dev/null \
  | sed 's|^|   |'
echo

echo "3. Patching"
if ! grep -q "findById(decoded.userId)" "$F"; then
  echo "   'findById(decoded.userId)' not found — already fixed?"
  grep -n "findById(decoded" "$F" | sed 's/^/      /'
  exit 0
fi

cp "$F" "$F.bakme"
python3 - "$F" << 'PY_EOF'
import sys
p = sys.argv[1]
s = open(p).read()
old = "findById(decoded.userId)"
n = s.count(old)
if n == 0:
    print("   nothing to replace"); sys.exit(2)
s = s.replace(old, "findById(decoded.id)")
open(p, "w").write(s)
print(f"   replaced {n} occurrence(s)")
PY_EOF
[ $? -ne 0 ] && { cp "$F.bakme" "$F"; echo "   reverted"; exit 1; }
echo

echo "4. Diff"
diff "$F.bakme" "$F" | sed 's/^/   /'
echo

echo "5. Verifying"
node --check "$F" || { echo "   PARSE FAILED — reverting"; cp "$F.bakme" "$F"; exit 1; }
echo "   parses"
echo

echo "=========================================="
echo "  Deploy:"
echo "     git add -A"
echo "     git commit -m 'Fix /me reading decoded.userId instead of decoded.id'"
echo "     git push"
echo "  then Manual Deploy on Render."
echo
echo "  Revert:  cp $F.bakme $F"
echo "=========================================="

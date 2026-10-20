#!/usr/bin/env bash
#
# Makes GET /api/auth/me return the same user shape as login.
#
# Swift's User model maps `id` to the JSON key "_id":
#     case id = "_id"
# but /me hand-builds { id: user._id, name, email } — so "_id" is absent and
# decoding fails on a non-optional field. Login works because it returns the raw
# Mongoose document, which serializes with "_id".
#
# Fix: return `user` directly. It was already fetched with .select("-password"),
# so this gives one user shape instead of two, and also sends trialEndsAt and the
# referral fields the model already expects but never receives.
#
# Usage:
#   bash ~/Downloads/fix-me-shape.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
F="backend/routes/authRoutes.js"
[ -f "$F" ] || { echo "ERROR: $F not found"; exit 1; }

echo "PlanBhai — aligning /me with the User model"
echo

echo "1. What Swift expects"
sed -n '/enum CodingKeys/,/}/p' PlanBhai/ios/PlanBhai/Models/User.swift | sed 's/^/   /'
echo

echo "2. What /me currently sends"
grep -n 'res.json({ user: {' "$F" | sed 's/^/   /'
echo

if ! grep -q 'res.json({ user: { id: user._id' "$F"; then
  echo "   Pattern not found — already fixed, or the line differs."
  grep -n "res.json({ user" "$F" | sed 's/^/      /'
  exit 0
fi

echo "3. Patching"
cp "$F" "$F.bakshape"
python3 - "$F" << 'PY_EOF'
import sys
p = sys.argv[1]
s = open(p).read()
old = "res.json({ user: { id: user._id, name: user.name, email: user.email } });"
if old not in s:
    print("   exact line not found — no changes made"); sys.exit(2)
s = s.replace(old, "res.json({ user });", 1)
open(p, "w").write(s)
print("   replaced 1 line")
PY_EOF
if [ $? -ne 0 ]; then
  cp "$F.bakshape" "$F"
  echo "   reverted — no changes made"
  exit 1
fi
echo

echo "4. Diff"
diff "$F.bakshape" "$F" | sed 's/^/   /'
echo

echo "5. Verifying"
node --check "$F" || { echo "   PARSE FAILED — reverting"; cp "$F.bakshape" "$F"; exit 1; }
echo "   parses"
grep -q 'select("-password")' "$F" \
  && echo "   password still excluded from the response" \
  || echo "   WARNING: could not confirm .select(\"-password\") — check line 206 by hand"
echo

echo "=========================================="
echo "  Next:"
echo "     git add -A"
echo "     git commit -m 'Return full user object from /me to match login shape'"
echo "     git push"
echo "  then Manual Deploy on Render."
echo
echo "  Revert:  cp $F.bakshape $F"
echo "=========================================="

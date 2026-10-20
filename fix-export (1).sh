#!/usr/bin/env bash
#
# Fixes "bustBriefsForOwner is not a function".
#
# The earlier patcher added the function body but failed to add it to
# module.exports, so the destructured import in appDataRoutes.js was undefined.
# Non-fatal — the try/catch swallowed it — but cache invalidation has been dead
# since that deploy.
#
# Also prints verifyScopeAccess so the separate 403 issue can be diagnosed.
#
# Usage:
#   bash ~/Downloads/fix-export.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
F="backend/services/daybrief/daybrief.service.js"
[ -f "$F" ] || { echo "ERROR: $F not found"; exit 1; }

echo "PlanBhai — fixing the export"
echo

echo "1. Current state"
grep -q "^async function bustBriefsForOwner" "$F" \
  && echo "   function defined:  yes" \
  || echo "   function defined:  NO"
grep -A8 "module.exports" "$F" | grep -q "bustBriefsForOwner" \
  && echo "   exported:          yes" \
  || echo "   exported:          NO  <- this is the bug"
echo

echo "2. Patching module.exports"
cp "$F" "$F.bakexport"
python3 - "$F" << 'PY_EOF'
import sys, re
p = sys.argv[1]
s = open(p).read()

if "async function bustBriefsForOwner" not in s:
    print("   ERROR: the function itself is missing — re-run wire-cache-bust.sh")
    sys.exit(1)

m = re.search(r"module\.exports\s*=\s*\{[^}]*\};", s)
if not m:
    print("   ERROR: could not find module.exports")
    sys.exit(1)

block = m.group(0)
if "bustBriefsForOwner" in block:
    print("   already exported, nothing to do")
    sys.exit(0)

new_block = (
    "module.exports = {\n"
    "  getTodayBrief,\n"
    "  bustDayBrief,\n"
    "  bustBriefsForOwner,\n"
    "  buildBrief,\n"
    "  decorateForRead,\n"
    "};"
)
s = s[:m.start()] + new_block + s[m.end():]
open(p, "w").write(s)
print("   exports rewritten")
PY_EOF
[ $? -ne 0 ] && { cp "$F.bakexport" "$F"; echo "   reverted"; exit 1; }

node --check "$F" && echo "   parses"
echo

echo "3. Proving the import resolves"
cd backend
node -e "
require('dotenv').config();
const svc = require('./services/daybrief/daybrief.service');
const t = typeof svc.bustBriefsForOwner;
console.log('   typeof bustBriefsForOwner: ' + t + (t === 'function' ? '  <- fixed' : '  <- STILL BROKEN'));
" 2>&1 | tail -2
cd ..
echo

echo "4. verifyScopeAccess — the source of the 403s (separate issue)"
sed -n '/verifyScopeAccess/,/^}/p' backend/routes/appDataRoutes.js | head -35 | sed 's/^/   /'
echo

echo "=========================================="
echo "  Commit and redeploy:"
echo "     git add -A && git commit -m 'Export bustBriefsForOwner' && git push"
echo "  then Manual Deploy on Render."
echo "=========================================="

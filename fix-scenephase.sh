#!/usr/bin/env bash
#
# Moves the .task(id: scenePhase) block from PlanBhaiApp to RootView.
#
# The previous patcher anchored on a tail pattern that matched the end of
# PlanBhaiApp, because RootView sits AFTER NotificationManager in this file.
# scenePhase is declared on RootView, so the modifier landed out of scope.
#
# Usage:
#   bash ~/Downloads/fix-scenephase.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
APP="PlanBhai/ios/PlanBhai/PlanBhaiApp.swift"
[ -f "$APP" ] || { echo "ERROR: $APP not found"; exit 1; }

echo "PlanBhai — fixing scenePhase placement"
echo

cp "$APP" "$APP.bakscene"

python3 - "$APP" << 'PY_EOF'
import sys
p = sys.argv[1]
s = open(p).read()

BLOCK = """        .task(id: scenePhase) {
            if scenePhase == .active {
                await appState.syncCalendarIfPossible()
            }
        }
"""

# 1. Remove it from wherever it currently is (PlanBhaiApp's WindowGroup).
removed = s.count(BLOCK)
s = s.replace(BLOCK, "")
print(f"   removed {removed} misplaced block(s)")

# 2. Confirm scenePhase is declared on RootView.
if "@Environment(\\.scenePhase) private var scenePhase" not in s:
    print("   ERROR: scenePhase declaration missing from RootView")
    sys.exit(1)
print("   scenePhase declaration present on RootView")

# 3. Append to RootView, which is the last struct in the file. Its body ends with
#    the onAppear close, the body close, then the struct close.
s = s.rstrip() + "\n"
TAIL = "\n        }\n    }\n}\n"
i = s.rfind(TAIL)
if i == -1:
    print("   ERROR: could not locate the end of RootView")
    sys.exit(1)

# Sanity check: the sync call must be nearby, i.e. we're really in RootView.
if "syncCalendarIfPossible" not in s[max(0, i-1200):i]:
    print("   ERROR: end of RootView doesn't contain the sync call — not patching blind")
    sys.exit(1)

NEW = ("\n        }\n"
       "        .task(id: scenePhase) {\n"
       "            if scenePhase == .active {\n"
       "                await appState.syncCalendarIfPossible()\n"
       "            }\n"
       "        }\n"
       "    }\n}\n")

s = s[:i] + NEW + s[i + len(TAIL):]
open(p, "w").write(s)
print("   appended to RootView")
PY_EOF

if [ $? -ne 0 ]; then
  cp "$APP.bakscene" "$APP"
  echo "   reverted — no changes made"
  exit 1
fi

echo
echo "Result — last 22 lines:"
tail -22 "$APP" | sed 's/^/   /'
echo

echo "Building..."
xcodebuild -scheme PlanBhai -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head -15
echo
echo "=========================================="
echo "  Restore if needed:  cp $APP.bakscene $APP"
echo "=========================================="

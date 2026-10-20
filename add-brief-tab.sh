#!/usr/bin/env bash
#
# Adds DayBriefView as a temporary 7th tab so it can be compared against
# DashboardView on device.
#
# Two coordinated edits — the switch case index must match the tabs array index:
#   1. `case 6: DayBriefView()` before `default:`
#   2. a 7th entry appended to ForestTabBar.tabs
#
# Appended at index 6 rather than inserted, so existing indices are untouched.
# That matters: pendingInviteCode sets `selected = 4`, which must stay
# FamilyTabRootView.
#
# NOTE: 7 tabs is cramped (~50pt each). Fine for comparison, not for shipping.
# Once you've decided, replace `case 0: DashboardView()` instead and drop this.
#
# Usage:
#   bash ~/Downloads/add-brief-tab.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
F="PlanBhai/ios/PlanBhai/Views/MainTabView.swift"
[ -f "$F" ] || { echo "ERROR: $F not found"; exit 1; }

echo "PlanBhai — adding the Brief tab"
echo

if grep -q "DayBriefView()" "$F"; then
  echo "   already added, nothing to do"
  exit 0
fi

echo "1. Checking DayBriefView exists"
if [ -f "PlanBhai/ios/PlanBhai/Views/DayBriefView.swift" ]; then
  echo "   ok   DayBriefView.swift found"
else
  echo "   MISSING — run install-phase1.sh first"
  exit 1
fi
echo

echo "2. Patching"
cp "$F" "$F.baktab"

python3 - "$F" << 'PY_EOF'
import sys
p = sys.argv[1]
s = open(p).read()

# --- 1. switch case ------------------------------------------------------
old_case = """                case 5: SettingsView()
                default: DashboardView()"""
new_case = """                case 5: SettingsView()
                case 6: DayBriefView()
                default: DashboardView()"""
if old_case not in s:
    print("   ERROR: switch block not in the expected shape"); sys.exit(2)
s = s.replace(old_case, new_case, 1)

# --- 2. tabs array -------------------------------------------------------
old_tabs = """        ("person.circle", "person.circle.fill",     "Me",        PB.sky),
    ]"""
new_tabs = """        ("person.circle", "person.circle.fill",     "Me",        PB.sky),
        ("sun.max",       "sun.max.fill",           "Brief",     PB.amber),
    ]"""
if old_tabs not in s:
    print("   ERROR: tabs array not in the expected shape"); sys.exit(2)
s = s.replace(old_tabs, new_tabs, 1)

open(p, "w").write(s)
print("   added case 6 and the tabs entry")
PY_EOF

if [ $? -ne 0 ]; then
  cp "$F.baktab" "$F"
  echo "   reverted — no changes made"
  exit 1
fi
echo

echo "3. Diff"
diff "$F.baktab" "$F" | sed 's/^/   /'
echo

echo "4. Checking the indices line up"
CASES=$(grep -cE "^ +case [0-9]+:" "$F")
ENTRIES=$(grep -cE '^ +\("[a-z]' "$F")
echo "   switch cases: $CASES"
echo "   tab entries : $ENTRIES"
if [ "$CASES" = "$ENTRIES" ]; then
  echo "   they match — every tab maps to a view"
else
  echo "   MISMATCH — a tab would open the wrong screen. Reverting."
  cp "$F.baktab" "$F"
  exit 1
fi
echo

echo "5. Building"
SIM=$(xcrun simctl list devices available 2>/dev/null \
  | grep -E "^ +iPhone" | sed 's/ (.*//' | sed 's/^ *//' | head -1)
[ -z "$SIM" ] && SIM="iPhone 17"
echo "   simulator: $SIM"
xcodebuild -scheme PlanBhai -destination "platform=iOS Simulator,name=$SIM" build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head -15
echo

echo "=========================================="
echo "  Run the app and tap the last tab (sun icon, \"Brief\")."
echo
echo "  Revert:  cp $F.baktab $F"
echo "=========================================="

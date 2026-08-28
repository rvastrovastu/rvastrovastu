#!/usr/bin/env bash
#
# Inserts CalendarSyncSection() into SettingsView, and builds against a simulator
# that actually exists on this machine.
#
# The anchor is the PageHeader(...).padding(.top, 8) at the top of the VStack —
# unique in the file, so the insert is safe.
#
# Usage:
#   bash ~/Downloads/add-calendar-section.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
SET="PlanBhai/ios/PlanBhai/Views/SettingsView.swift"
[ -f "$SET" ] || { echo "ERROR: $SET not found"; exit 1; }

echo "PlanBhai — add calendar section"
echo

echo "1. Inserting CalendarSyncSection()"
if grep -q "CalendarSyncSection()" "$SET"; then
  echo "   already present, skipping"
else
  cp "$SET" "$SET.bakcal"
  python3 - "$SET" << 'PY_EOF'
import sys
p = sys.argv[1]
s = open(p).read()

anchor = ".padding(.top, 8)"
i = s.find(anchor)
if i == -1:
    print("   ERROR: anchor '.padding(.top, 8)' not found")
    sys.exit(1)

# Match the anchor's own indentation so the insert looks native.
line_start = s.rfind("\n", 0, i) + 1
indent = s[line_start:i]

end = i + len(anchor)
insert = "\n\n" + indent + "CalendarSyncSection()"
s = s[:end] + insert + s[end:]
open(p, "w").write(s)
print("   inserted after PageHeader")
PY_EOF
  if [ $? -ne 0 ]; then
    cp "$SET.bakcal" "$SET"
    echo "   reverted — no changes made"
    exit 1
  fi
fi
echo

echo "2. Picking a simulator that exists"
SIM=$(xcrun simctl list devices available 2>/dev/null \
  | grep -E "^ +iPhone" \
  | sed 's/ (.*//' \
  | sed 's/^ *//' \
  | head -1)
if [ -z "$SIM" ]; then
  echo "   no iPhone simulator found. Available devices:"
  xcrun simctl list devices available | head -20
  exit 1
fi
echo "   using: $SIM"
echo

echo "3. Building"
xcodebuild -scheme PlanBhai -destination "platform=iOS Simulator,name=$SIM" build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head -20
echo

echo "=========================================="
echo "  If the build failed, restore with:"
echo "     cp $SET.bakcal $SET"
echo "=========================================="

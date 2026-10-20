#!/usr/bin/env bash
#
# Jump to moves to the bottom, on both household screens.
#
#   before   header · switcher · JUMP TO · memories · wall
#   after    header · switcher · memories · wall · JUMP TO
#
# Jump to is a grid of navigation, and it sat above the two things people
# actually open these pages to see. Shortcuts belong under the content they
# shortcut past.
#
# BOTH SCREENS, because there are two and they had drifted:
#   HouseholdHubView    the Household tab
#   HouseholdView       the detail page, opened from the household list
#
# HOW IT MOVES
#   Braces are walked to find where the block closes, rather than counting
#   lines — a nested LazyVGrid makes any fixed offset a guess, and the block is
#   a different length in each file.
#
#   It lands after the wall, or after the activity feed where one exists.
#
# The script verifies the ORDER afterwards, not just that the file compiles. A
# block moved to the wrong place still builds.
#
# Usage:
#   bash ~/Downloads/move-jump-to.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
D="PlanBhai/ios/PlanBhai/Views"
for f in "$D/HouseholdHubView.swift" "$D/HouseholdView.swift"; do
  [ -f "$f" ] || { echo "ERROR: $f not found"; exit 1; }
done

echo "PlanBhai — Jump to goes last"
echo

echo "1. Before"
for f in HouseholdHubView HouseholdView; do
  j=$(grep -n "JUMP TO" "$D/$f.swift" | head -1 | cut -d: -f1)
  w=$(grep -n "HouseholdWallSection(household" "$D/$f.swift" | head -1 | cut -d: -f1)
  echo "   $f: Jump to at ${j:-none}, wall at ${w:-none}"
done
echo

echo "2. Moving"
cp "$D/HouseholdHubView.swift" "$D/HouseholdHubView.swift.bakjump"
cp "$D/HouseholdView.swift" "$D/HouseholdView.swift.bakjump"
cat > /tmp/pb_mj.py << 'PLANBHAI_EOF'
import sys, re

def move_jump(path, label):
    lines = open(path).read().split('\n')

    # The block starts at the sharedFeatureSet guard.
    start = None
    for i, l in enumerate(lines):
        if 'if !household.sharedFeatureSet.isEmpty {' in l:
            start = i
            break
    if start is None:
        print(f"   {label}: no Jump to block found"); return False

    # Walk braces to its close, rather than counting lines — a nested
    # LazyVGrid makes any fixed offset a guess.
    depth = 0
    end = None
    for i in range(start, len(lines)):
        depth += lines[i].count('{') - lines[i].count('}')
        if depth == 0 and i > start:
            end = i
            break
    if end is None:
        print(f"   {label}: could not find where the block closes"); return False

    block = lines[start:end + 1]
    if not any('JUMP TO' in l for l in block):
        print(f"   {label}: that block is not Jump to"); return False

    rest = lines[:start] + lines[end + 1:]

    # After the wall — shortcuts belong under the content they shortcut past.
    wall = None
    for i, l in enumerate(rest):
        if 'HouseholdWallSection(household: household)' in l:
            wall = i
            break
    if wall is None:
        print(f"   {label}: no wall section to place it after"); return False

    # Activity, where present, sits between the wall and Jump to.
    after = wall
    for i in range(wall + 1, min(wall + 4, len(rest))):
        if 'HouseholdActivitySection' in rest[i]:
            after = i
            break

    comment = [
        '',
        '                            // Jump to sits LAST. It is a grid of navigation, and it was',
        '                            // above the things people open this page to see — the',
        '                            // memories and the wall. Shortcuts belong under the content',
        '                            // they shortcut past.',
    ]
    out = rest[:after + 1] + comment + block + rest[after + 1:]
    open(path, 'w').write('\n'.join(out))
    print(f"   {label}: moved {len(block)} lines below the wall")
    return True

ok1 = move_jump('PlanBhai/ios/PlanBhai/Views/HouseholdHubView.swift', 'hub')
ok2 = move_jump('PlanBhai/ios/PlanBhai/Views/HouseholdView.swift', 'detail')
sys.exit(0 if (ok1 and ok2) else 2)
PLANBHAI_EOF
python3 /tmp/pb_mj.py
RC=$?
rm -f /tmp/pb_mj.py
if [ "$RC" != "0" ]; then
  cp "$D/HouseholdHubView.swift.bakjump" "$D/HouseholdHubView.swift"
  cp "$D/HouseholdView.swift.bakjump" "$D/HouseholdView.swift"
  echo "   reverted both"; exit 1
fi
echo

echo "3. After — the order, not just the build"
fail=0
for f in HouseholdHubView HouseholdView; do
  j=$(grep -n "JUMP TO" "$D/$f.swift" | head -1 | cut -d: -f1)
  w=$(grep -n "HouseholdWallSection(household" "$D/$f.swift" | head -1 | cut -d: -f1)
  if [ -n "$j" ] && [ -n "$w" ] && [ "$j" -gt "$w" ]; then
    echo "   ok   $f: Jump to ($j) is below the wall ($w)"
  else
    echo "   WRONG $f: Jump to at ${j:-none}, wall at ${w:-none}"
    fail=1
  fi
done
if [ "$fail" = "1" ]; then
  cp "$D/HouseholdHubView.swift.bakjump" "$D/HouseholdHubView.swift"
  cp "$D/HouseholdView.swift.bakjump" "$D/HouseholdView.swift"
  echo "   reverted both — the order is wrong even if it would compile"
  exit 1
fi
echo

echo "4. Building"
SIM=$(xcodebuild -scheme PlanBhai -showdestinations 2>/dev/null \
  | grep -oE "name:iPhone [^}]*" | sed 's/name://' | sed 's/ *$//' | head -1)
[ -z "$SIM" ] && SIM="iPhone 17"
echo "   simulator: $SIM"
xcodebuild -scheme PlanBhai -destination "platform=iOS Simulator,name=$SIM" build 2>&1 \
  | grep -E "error:|failures\)|BUILD (SUCCEEDED|FAILED)" | head -12
echo

echo "=========================================="
echo "  Household tab, and a household opened from the list — memories and"
echo "  wall first, Jump to at the bottom of both."
echo
echo "  Revert:"
echo "     cp $D/HouseholdHubView.swift.bakjump $D/HouseholdHubView.swift"
echo "     cp $D/HouseholdView.swift.bakjump $D/HouseholdView.swift"
echo "=========================================="

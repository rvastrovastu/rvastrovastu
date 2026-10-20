#!/usr/bin/env bash
#
# Each household shows its own wall.
#
# THE BUG
#   1. Open Family Friend  -> fetchHouseholdNotes(bfb01c) -> 1 post
#   2. Switch to JulyTrip   -> loadAllLocalData() only
#   3. householdNotes still holds Family Friend's post
#   4. The wall renders it under JulyTrip
#
#   The server was never wrong. Both branches of its query filter by
#   householdId, membership is checked, and admin-only visibility is handled.
#   JulyTrip genuinely has no notes at all — only one household_notes record
#   exists in the database.
#
#   The client simply never asked again. householdNotes is ONE shared array on
#   AppState, replaced wholesale on fetch, and switching households did not
#   trigger a fetch.
#
# THE FIX
#   The switcher clears householdNotes immediately, then refetches for the newly
#   selected household. Clearing first matters: without it the old posts stay on
#   screen during the round trip, which is the same wrong answer for a shorter
#   time.
#
# Only HouseholdHubView.swift changes.
#
# Usage:
#   bash ~/Downloads/fix-wall-scoping.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
H="PlanBhai/ios/PlanBhai/Views/HouseholdHubView.swift"
[ -f "$H" ] || { echo "ERROR: $H not found"; exit 1; }

echo "PlanBhai — per-household wall"
echo

echo "1. Confirming the pieces"
grep -q "func fetchHouseholdNotes" PlanBhai/ios/PlanBhai/AppState.swift \
  && echo "   ok   fetchHouseholdNotes exists" \
  || { echo "   MISSING fetchHouseholdNotes"; exit 1; }
grep -q "struct HouseholdSwitcher" "$H" \
  && echo "   ok   HouseholdSwitcher present" \
  || { echo "   MISSING HouseholdSwitcher — add it first"; exit 1; }
echo

echo "2. Patching"
cp "$H" "$H.bakwall"
cat > /tmp/pb_wall.py << 'PLANBHAI_EOF'
import sys
p = sys.argv[1]
s = open(p).read()

old = """                        Button {
                            appState.activeHouseholdId = h.id
                            Task { await appState.loadAllLocalData() }
                        } label: {"""

new = """                        Button {
                            appState.activeHouseholdId = h.id
                            // Clear first. householdNotes is ONE shared array, so
                            // without this the previous household's wall stays on
                            // screen until the fetch returns — and if the fetch is
                            // never made, permanently. That is why both households
                            // showed the same posts.
                            appState.householdNotes = []
                            Task {
                                await appState.loadAllLocalData()
                                await appState.fetchHouseholdNotes(householdId: h.id)
                            }
                        } label: {"""

if 'appState.householdNotes = []' in s:
    print("   already fixed"); sys.exit(3)
if old not in s:
    print("   ERROR: switcher button not in the expected shape"); sys.exit(2)

s = s.replace(old, new, 1)
open(p, "w").write(s)
print("   switcher clears and refetches the wall")
PLANBHAI_EOF
python3 /tmp/pb_wall.py "$H"
RC=$?
rm -f /tmp/pb_wall.py
if [ "$RC" = "3" ]; then
  echo "   nothing to do"
elif [ "$RC" != "0" ]; then
  cp "$H.bakwall" "$H"
  echo "   reverted"
  exit 1
fi
echo

echo "3. Building"
SIM=$(xcodebuild -scheme PlanBhai -showdestinations 2>/dev/null \
  | grep -oE "name:iPhone [^}]*" | sed 's/name://' | sed 's/ *$//' | head -1)
[ -z "$SIM" ] && SIM="iPhone 17"
echo "   simulator: $SIM"
xcodebuild -scheme PlanBhai -destination "platform=iOS Simulator,name=$SIM" build 2>&1 \
  | grep -E "error:|failures\)|BUILD (SUCCEEDED|FAILED)" | head -10
echo

echo "=========================================="
echo "  Switch between Family Friend and JulyTrip. JulyTrip's wall should be"
echo "  EMPTY — it has no notes in the database. Family Friend keeps its post."
echo
echo "  NOTE: the wall is also rendered elsewhere (HouseholdDetailView). If it"
echo "  still shows stale posts when reached another way, that screen needs the"
echo "  same refetch on appear."
echo
echo "  Revert:  cp $H.bakwall $H"
echo "=========================================="

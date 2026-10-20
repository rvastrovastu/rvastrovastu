#!/usr/bin/env bash
#
# Fixes water_glasses failing to load for accounts holding the legacy shape.
#
# THE BUG
#   Current code stores water_glasses as a plain Int. One production record
#   holds {"count":4,"date":"Sat Jul 25 2026"} — an older shape. Decoding as
#   Int fails, the `if let` never fires, and waterGlasses keeps its previous
#   value. Visible as "Load water_glasses failed: The data couldn't be read".
#
#   Worse, the load happens BEFORE resetTrackersIfNeeded(). On a failed load
#   the stale in-memory count survives while trackerLastResetDate is fresh, so
#   the reset does not fire and yesterday's number shows as today's.
#
# THE FIX
#   Try Int first, then {count,date}. The `date` field is ignored on purpose:
#   resetTrackersIfNeeded() already owns the daily reset via
#   trackerLastResetDate, and honouring a second date field would give two
#   mechanisms conflicting ideas about "today".
#
#   saveAllLocalData already writes an Int, so each affected account self-heals
#   on its next save. No migration script needed.
#
# Only AppState.swift changes.
#
# Usage:
#   bash ~/Downloads/fix-water-shape.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
F="PlanBhai/ios/PlanBhai/AppState.swift"
[ -f "$F" ] || { echo "ERROR: $F not found"; exit 1; }

echo "PlanBhai — water_glasses shape fix"
echo

if grep -q "loadWaterGlasses" "$F"; then
  echo "   already applied"
  exit 0
fi

echo "1. Patching"
cp "$F" "$F.bakwater"

cat > /tmp/pb_water.txt << 'PLANBHAI_EOF'
    /// Reads water_glasses tolerantly.
    ///
    /// The current codebase stores this as a plain Int, but at least one record
    /// in production holds `{"count":4,"date":"Sat Jul 25 2026"}` — a shape from
    /// an older build or the web app. `loadData(as: Int.self)` fails on it, the
    /// `if let` never fires, and that user's count silently stays at whatever it
    /// was. That is the "Load water_glasses failed" line in the console.
    ///
    /// Reading both shapes fixes it for existing records; saveAllLocalData then
    /// rewrites it as an Int, so each account self-heals on its next save.
    private struct WaterRecord: Decodable {
        let count: Int
        // `date` is deliberately ignored. resetTrackersIfNeeded() already owns
        // the daily reset via trackerLastResetDate; honouring a second, older
        // date field would mean two mechanisms disagreeing about "today".
    }

    private func loadWaterGlasses() async -> Int? {
        if let n: Int = await loadData("water_glasses", as: Int.self) { return n }
        if let rec: WaterRecord = await loadData("water_glasses", as: WaterRecord.self) {
            print("[water] migrated legacy {count,date} record -> \(rec.count)")
            return rec.count
        }
        return nil
    }
PLANBHAI_EOF

python3 - "$F" /tmp/pb_water.txt << 'PY_EOF'
import sys
path, snipfile = sys.argv[1], sys.argv[2]
s = open(path).read()
snip = open(snipfile).read()

old_call = """        if let backendWater: Int = await loadData("water_glasses", as: Int.self) {
            self.waterGlasses = backendWater
        }"""
new_call = """        if let backendWater = await loadWaterGlasses() {
            self.waterGlasses = backendWater
        }"""
if old_call not in s:
    print("   ERROR: the water load block is not in the expected shape")
    sys.exit(2)
s = s.replace(old_call, new_call, 1)

# Place the helper beside the other tracker functions.
anchor = "    func addWaterGlass()"
i = s.find(anchor)
if i == -1:
    print("   ERROR: addWaterGlass not found"); sys.exit(2)
s = s[:i] + snip + "\n" + s[i:]

open(path, "w").write(s)
print("   tolerant loader added and wired")
PY_EOF
if [ $? -ne 0 ]; then
  cp "$F.bakwater" "$F"
  echo "   reverted — no changes made"
  exit 1
fi
rm -f /tmp/pb_water.txt
echo

echo "2. Diff"
diff "$F.bakwater" "$F" | head -40 | sed 's/^/   /'
echo

echo "3. Building"
SIM=$(xcodebuild -scheme PlanBhai -showdestinations 2>/dev/null \
  | grep -oE "name:iPhone [^}]*" | sed 's/name://' | sed 's/ *$//' | head -1)
[ -z "$SIM" ] && SIM="iPhone 17"
echo "   simulator: $SIM"
xcodebuild -scheme PlanBhai -destination "platform=iOS Simulator,name=$SIM" build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head -15
echo

echo "=========================================="
echo "  Revert:  cp $F.bakwater $F"
echo "=========================================="

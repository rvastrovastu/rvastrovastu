#!/usr/bin/env bash
#
# Fixes "Load habits failed: The data couldn't be read because it is missing."
#
# THE BUG, and it is mine
#   Stored habits look like this:
#       {"name":"Drink 8 glass of water","streak":2,"completedToday":false}
#   No `id`. The Habit struct declares `let id: String` as non-optional, so
#   decoding throws keyNotFound and takes the WHOLE array with it — which is
#   why habits kept disappearing from iOS.
#
#   I made Challenge, GroupMember and PlanGroup tolerant of the web shape
#   earlier today and never did the same for Habit, which has exactly the same
#   split: the tracker writes {id, title}, web writes {name}.
#
# THE FIX
#   Habit reads both shapes and writes both spellings. The id is derived from
#   the name when absent — "web:<name>" — so the same habit keeps the same
#   identity across loads instead of getting a fresh UUID each time, which
#   would make every load look like a different set of habits.
#
#   Existing call sites are unaffected: the memberwise init keeps its old
#   argument names and every field except title has a default.
#
# Only Models.swift changes.
#
# Usage:
#   bash ~/Downloads/fix-habit-decode.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
M="PlanBhai/ios/PlanBhai/Models.swift"
[ -f "$M" ] || { echo "ERROR: $M not found"; exit 1; }

echo "PlanBhai — habit decoding"
echo

if grep -q 'forKey: .name' "$M" && grep -q "struct Habit" "$M"; then
  if grep -A 40 "^struct Habit" "$M" | grep -q "forKey: .name"; then
    echo "   already tolerant"
    exit 0
  fi
fi

echo "1. Patching Habit"
cp "$M" "$M.bakhabitdec"
cat > /tmp/pb_habit.txt << 'PLANBHAI_EOF'
struct Habit: Identifiable, Codable {
    let id: String
    var title: String
    var streak: Int
    var completedToday: Bool
    var streakShields: Int = 1          // Tier 2: forgiving streaks — grace days that protect a streak from a missed day
    var lastMissedDate: String? = nil   // ISO date string of the most recent day a shield was used, for UI messaging

    /// The day this habit was last completed, as "yyyy-MM-dd".
    ///
    /// WITHOUT THIS FIELD, SAVING FROM iOS SILENTLY DELETES IT. The server
    /// writes lastCompletedDate so completion can be derived rather than
    /// trusted — nothing clears `completedToday` at midnight, so a habit ticked
    /// yesterday would otherwise read as done today, forever on web.
    var lastCompletedDate: String? = nil

    init(id: String = UUID().uuidString, title: String, streak: Int = 0,
         completedToday: Bool = false, streakShields: Int = 1,
         lastMissedDate: String? = nil, lastCompletedDate: String? = nil) {
        self.id = id; self.title = title; self.streak = streak
        self.completedToday = completedToday; self.streakShields = streakShields
        self.lastMissedDate = lastMissedDate; self.lastCompletedDate = lastCompletedDate
    }

    /// Reads BOTH shapes.
    ///
    /// The habit tracker writes {id, title, streak, streakShields}. The web app
    /// and older records write {name, streak, completedToday} with NO id at all
    /// — and `let id: String` being non-optional made the whole array fail to
    /// decode, which is why habits kept vanishing from iOS.
    ///
    /// The id is derived from the name when absent, so the same habit keeps the
    /// same identity across loads rather than getting a fresh UUID each time.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = (try? c.decode(String.self, forKey: .title))
             ?? (try? c.decode(String.self, forKey: .name)) ?? "Habit"
        id = (try? c.decode(String.self, forKey: .id)) ?? "web:\(title)"
        streak = (try? c.decode(Int.self, forKey: .streak)) ?? 0
        completedToday = (try? c.decode(Bool.self, forKey: .completedToday)) ?? false
        streakShields = (try? c.decode(Int.self, forKey: .streakShields)) ?? 1
        lastMissedDate = try? c.decode(String.self, forKey: .lastMissedDate)
        lastCompletedDate = try? c.decode(String.self, forKey: .lastCompletedDate)
    }

    /// Writes BOTH spellings so neither client loses the record.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(title, forKey: .name)
        try c.encode(streak, forKey: .streak)
        try c.encode(completedToday, forKey: .completedToday)
        try c.encode(streakShields, forKey: .streakShields)
        try c.encodeIfPresent(lastMissedDate, forKey: .lastMissedDate)
        try c.encodeIfPresent(lastCompletedDate, forKey: .lastCompletedDate)
    }

    enum CodingKeys: String, CodingKey {
        case id, title, streak, completedToday, streakShields, lastMissedDate, lastCompletedDate
        case name
    }

    /// Whether this counts as done *today*. Prefers the date; falls back to the
    /// boolean for records written before the date existed.
    func isCompleteToday(_ today: String) -> Bool {
        if let d = lastCompletedDate { return d == today }
        return completedToday
    }
}
PLANBHAI_EOF

python3 - "$M" /tmp/pb_habit.txt << 'PY_EOF'
import sys, re
path, newfile = sys.argv[1], sys.argv[2]
s = open(path).read()
new = open(newfile).read()

m = re.search(r"struct Habit: Identifiable, Codable \{.*?\n\}", s, re.S)
if not m:
    print("   ERROR: Habit struct is not in the expected shape"); sys.exit(2)
s = s[:m.start()] + new.rstrip() + s[m.end():]
open(path, "w").write(s)
print("   replaced with the tolerant version")
PY_EOF
if [ $? -ne 0 ]; then
  cp "$M.bakhabitdec" "$M"
  echo "   reverted"; exit 1
fi
rm -f /tmp/pb_habit.txt
echo

echo "2. Verifying"
n=$(grep -c "^struct Habit: Identifiable, Codable" "$M")
[ "$n" = "1" ] && echo "   ok   one Habit struct" \
  || { echo "   $n copies — reverting"; cp "$M.bakhabitdec" "$M"; exit 1; }
grep -A 45 "^struct Habit" "$M" | grep -q "forKey: .name" && echo "   ok   reads the web shape"
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
echo "  Run as Test1@test.com — 5 habits should appear, and the console"
echo "  should be free of \"Load habits failed\"."
echo
echo "  Revert:  cp $M.bakhabitdec $M"
echo "=========================================="

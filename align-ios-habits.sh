#!/usr/bin/env bash
#
# Aligns iOS's habit tracker with the server's streak rule.
#
# TWO CHANGES
#   Models.swift   Habit gains `lastCompletedDate`.
#   AppState.swift completeHabit() uses the date, and syncs to the server.
#
# WHY THE MODEL CHANGE IS THE IMPORTANT ONE
#   The server writes lastCompletedDate so completion can be DERIVED rather
#   than trusted — nothing clears `completedToday` at midnight, so on web a
#   ticked habit would read as done forever.
#
#   Habit is Codable and gets written back wholesale by saveAllLocalData. A
#   struct without that property DROPS IT on the next save — the server writes
#   the date, iOS quietly deletes it, and the bug returns a day later looking
#   unrelated to anything.
#
# THE RULE
#   Only TODAY's completion is reversible. Un-checking tomorrow no longer
#   removes a day that was legitimately earned. Previously any un-complete
#   decremented, which was right for a mis-tap and wrong the next morning.
#
# WHY IT STAYS OPTIMISTIC
#   The original completeHabit carried "No save here — avoid storm", so someone
#   already hit a save-loop here. The local flip stays for instant feedback and
#   offline use; the server call follows in the background and owns the
#   arithmetic. On failure the local state stands and the next load reconciles.
#
# Call sites are unchanged — completeHabit stays synchronous, so
# HabitTrackerView and DashboardView need no edits.
#
# Usage:
#   bash ~/Downloads/align-ios-habits.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
D="PlanBhai/ios/PlanBhai"
[ -f "$D/Models.swift" ] || { echo "ERROR: $D/Models.swift not found"; exit 1; }
[ -f "$D/AppState.swift" ] || { echo "ERROR: $D/AppState.swift not found"; exit 1; }

echo "PlanBhai — aligning iOS habits"
echo

echo "1. Prerequisite"
grep -q "func completeHabit(name:" "$D/DayBriefModels.swift" 2>/dev/null \
  && echo "   ok   DayBriefService.completeHabit exists" \
  || { echo "   MISSING DayBriefService.completeHabit — run install-habit-tap.sh first"; exit 1; }
echo

echo "2. Habit model"
if grep -q "lastCompletedDate" "$D/Models.swift"; then
  echo "   already present"
else
  cp "$D/Models.swift" "$D/Models.swift.bakalign"
  cat > /tmp/pb_habit_model.txt << 'PLANBHAI_EOF'
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
    ///
    /// Decoding into a struct without this property drops it on the next
    /// saveAllLocalData, which would reintroduce that bug a day later.
    var lastCompletedDate: String? = nil

    /// Whether this habit counts as done *today*, in the given calendar.
    /// Prefers the date; falls back to the boolean for records written before
    /// the date existed.
    func isCompleteToday(_ today: String) -> Bool {
        if let d = lastCompletedDate { return d == today }
        return completedToday
    }
}
PLANBHAI_EOF
  python3 - "$D/Models.swift" /tmp/pb_habit_model.txt << 'PY_EOF'
import sys, re
path, newfile = sys.argv[1], sys.argv[2]
s = open(path).read()
new = open(newfile).read()

m = re.search(r"struct Habit: Identifiable, Codable \{.*?\n\}", s, re.S)
if not m:
    print("   ERROR: Habit struct not in the expected shape"); sys.exit(2)
s = s[:m.start()] + new.rstrip() + s[m.end():]
open(path, "w").write(s)
print("   added lastCompletedDate + isCompleteToday()")
PY_EOF
  if [ $? -ne 0 ]; then
    cp "$D/Models.swift.bakalign" "$D/Models.swift"
    echo "   reverted"; exit 1
  fi
  rm -f /tmp/pb_habit_model.txt
fi
echo

echo "3. completeHabit"
if grep -q "localDayString" "$D/AppState.swift"; then
  echo "   already aligned"
else
  cp "$D/AppState.swift" "$D/AppState.swift.bakalign"
  cat > /tmp/pb_complete.txt << 'PLANBHAI_EOF'
    /// Local ISO day, matching what the server calls "today".
    static func localDayString(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f.string(from: date)
    }

    /// Toggles a habit.
    ///
    /// Optimistic, then synced. The local flip keeps the tap instant — the
    /// original comment here warned about a save storm, and routing every tap
    /// through the network would also break offline use. The server call
    /// follows in the background and owns the streak arithmetic, so the habit
    /// tracker and the Brief can no longer disagree about what a streak is.
    ///
    /// THE RULE: only TODAY's completion is reversible. Un-checking tomorrow no
    /// longer removes a day that was legitimately earned — which the old purely
    /// local version did.
    func completeHabit(_ habit: Habit) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }

        let today = Self.localDayString()
        let wasCompleteToday = habits[index].isCompleteToday(today)
        let next = !wasCompleteToday

        habits[index].completedToday = next
        if next {
            habits[index].streak += 1
            habits[index].lastCompletedDate = today
        } else {
            habits[index].streak = max(habits[index].streak - 1, 0)
            habits[index].lastCompletedDate = nil
        }

        // Background sync. On failure the local state stands — the next load
        // reconciles from the server, and losing a tap is worse than briefly
        // disagreeing with it.
        let name = habits[index].title
        Task { [weak self] in
            guard let self, let token = self.authToken else { return }
            do {
                _ = try await DayBriefService.shared.completeHabit(
                    name: name, done: next, token: token)
            } catch {
                self.handleError("Habit sync failed", error)
            }
        }
    }
PLANBHAI_EOF
  python3 - "$D/AppState.swift" /tmp/pb_complete.txt << 'PY_EOF'
import sys, re
path, newfile = sys.argv[1], sys.argv[2]
s = open(path).read()
new = open(newfile).read()

m = re.search(r"    func completeHabit\(_ habit: Habit\) \{.*?\n    \}\n", s, re.S)
if not m:
    print("   ERROR: completeHabit not in the expected shape"); sys.exit(2)
s = s[:m.start()] + new + s[m.end():]
open(path, "w").write(s)
print("   replaced with the date-aware version")
PY_EOF
  if [ $? -ne 0 ]; then
    cp "$D/AppState.swift.bakalign" "$D/AppState.swift"
    echo "   reverted"; exit 1
  fi
  rm -f /tmp/pb_complete.txt
fi
echo

echo "4. Call sites (should need no changes)"
grep -rn "completeHabit(habit)" "$D/Views/" 2>/dev/null | sed 's/^/   /'
echo "   completeHabit is still synchronous, so these are untouched."
echo

echo "5. Building"
SIM=$(xcodebuild -scheme PlanBhai -showdestinations 2>/dev/null \
  | grep -oE "name:iPhone [^}]*" | sed 's/name://' | sed 's/ *$//' | head -1)
[ -z "$SIM" ] && SIM="iPhone 17"
echo "   simulator: $SIM"
xcodebuild -scheme PlanBhai -destination "platform=iOS Simulator,name=$SIM" build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head -15
echo

echo "=========================================="
echo "  Revert:"
echo "     cp $D/Models.swift.bakalign $D/Models.swift"
echo "     cp $D/AppState.swift.bakalign $D/AppState.swift"
echo "=========================================="

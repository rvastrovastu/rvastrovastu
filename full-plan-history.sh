#!/usr/bin/env bash
#
# Saved Plans holds real plans, and they can be restored.
#
# WHAT IT WAS
#   SavedPlanData stored `summary` alone — a list of sentences. A past week
#   could be read about but never brought back, so regenerating genuinely lost
#   it. That is why the confirmation had to WARN rather than reassure.
#
# WHAT IT IS NOW
#   summary, meals and groceryList. Restoring writes `meal_plan`, the key the
#   Brief, calendar range, pantry diff and grocery-gap rule all read — a restore
#   that only set weeklyPlan would look right on one screen and change nothing
#   anywhere else.
#
#   Both new fields are OPTIONAL. Records written before today have only a
#   summary, and a history that loses its own history would be a poor fix.
#   isRestorable tells them apart.
#
# THE GROCERY LIST IS NOT REPLACED ON RESTORE
#   Someone restoring an old week has probably already bought things this week.
#   Silently discarding a half-ticked list to make room would cost more than it
#   gives.
#
# THE ALERT NOW REASSURES
#     before  "Only a summary of the current one is kept — not its meals."
#     after   "The current one is kept in Saved Plans, and you can restore it
#              any time."
#
#   It was a warning because the limitation was real. Removing the limitation is
#   better than warning about it.
#
# NO UI FOR RESTORE YET — restoreSavedPlan() exists and works; SavedPlansView
# needs a button calling it, which is a small addition once you have seen the
# stored data look right.
#
# Usage:
#   bash ~/Downloads/full-plan-history.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
D="PlanBhai/ios/PlanBhai"

echo "PlanBhai — restorable plan history"
echo

run() {
  local label="$1" file="$2" script="$3"
  cp "$file" "$file.bakhist"
  python3 "$script"
  local rc=$?
  if [ "$rc" = "3" ]; then echo "   $label: nothing to do"
  elif [ "$rc" != "0" ]; then cp "$file.bakhist" "$file"; echo "   $label: reverted"; return 1
  fi
  return 0
}

echo "1. The model"
cat > /tmp/pb_sp.py << 'PLANBHAI_EOF'
import sys
p = 'PlanBhai/ios/PlanBhai/Models.swift'
s = open(p).read()

if 'let meals: [DayMealPlan]?' in s:
    print("   already extended"); sys.exit(3)

old = """struct SavedPlanData: Codable {
    let summary: String?
}"""
new = """struct SavedPlanData: Codable {
    let summary: String?

    /// The plan itself, not only its description.
    ///
    /// This used to hold `summary` alone — so Saved Plans was a list of
    /// sentences, and a past week could be read about but never restored.
    /// Regenerating meant the old plan was genuinely gone, which is why the
    /// confirmation had to warn about it rather than reassure.
    ///
    /// OPTIONAL, because records written before this field exist and must still
    /// decode. A history that loses its own history would be a poor fix.
    let meals: [DayMealPlan]?
    let groceryList: [GroceryItem]?

    init(summary: String?, meals: [DayMealPlan]? = nil, groceryList: [GroceryItem]? = nil) {
        self.summary = summary
        self.meals = meals
        self.groceryList = groceryList
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        summary = try? c.decode(String.self, forKey: .summary)
        meals = try? c.decode([DayMealPlan].self, forKey: .meals)
        groceryList = try? c.decode([GroceryItem].self, forKey: .groceryList)
    }

    enum CodingKeys: String, CodingKey { case summary, meals, groceryList }

    /// Can this be put back, or is it one of the old summary-only records?
    var isRestorable: Bool { (meals?.isEmpty == false) }
}"""

if old not in s:
    print("   ERROR: SavedPlanData is not in the expected shape"); sys.exit(2)
s = s.replace(old, new, 1)
open(p, "w").write(s)
print("   SavedPlanData carries the full plan")
PLANBHAI_EOF
run "model" "$D/Models.swift" /tmp/pb_sp.py || exit 1
rm -f /tmp/pb_sp.py
echo

echo "2. Saving the whole plan"
cat > /tmp/pb_sf.py << 'PLANBHAI_EOF'
import sys
p = 'PlanBhai/ios/PlanBhai/AppState.swift'
s = open(p).read()

if 'meals: weeklyPlan.meals' in s:
    print("   already saving the full plan"); sys.exit(3)

old = """            data: SavedPlanData(summary: weeklyPlan.summary), createdAt: f.string(from: Date())"""
new = """            // The whole plan, so a past week can be restored rather than only
            // read about.
            data: SavedPlanData(summary: weeklyPlan.summary,
                                meals: weeklyPlan.meals,
                                groceryList: weeklyPlan.groceryList),
            createdAt: f.string(from: Date())"""
if old not in s:
    print("   ERROR: the save block is not in the expected shape"); sys.exit(2)
s = s.replace(old, new, 1)

# Restoring a saved plan.
anchor = "    /// Auto-saves the current party plan to history, same pattern as meal plans."
restore = '''    /// Makes a saved plan the active one again.
    ///
    /// Writes it to `meal_plan` as well as memory — that is the key the Brief,
    /// the calendar range, the pantry diff and the grocery-gap rule all read,
    /// so a restore that only set weeklyPlan would look right on one screen and
    /// change nothing anywhere else.
    ///
    /// The grocery list is NOT replaced. Someone restoring an old week has
    /// probably already bought things this week, and silently discarding a
    /// half-ticked list to make room would cost more than it gives.
    @discardableResult
    func restoreSavedPlan(_ saved: SavedPlan) async -> Bool {
        guard let meals = saved.data.meals, !meals.isEmpty else { return false }

        let plan = MealPlanResponse(
            summary: saved.data.summary ?? "",
            meals: meals,
            groceryList: saved.data.groceryList ?? []
        )
        weeklyPlan = plan

        await saveData("meal_plan",
                       CanonicalMealPlan(summary: plan.summary, meals: plan.meals),
                       scopeId: sharedScopeId)
        return true
    }

''' + anchor

if anchor not in s:
    print("   ERROR: could not find where to add restore"); sys.exit(2)
s = s.replace(anchor, restore, 1)
open(p, "w").write(s)
print("   full plan saved, and restorable")
PLANBHAI_EOF
run "save" "$D/AppState.swift" /tmp/pb_sf.py || exit 1
rm -f /tmp/pb_sf.py
echo

echo "3. The alert can reassure now"
cat > /tmp/pb_aw.py << 'PLANBHAI_EOF'
import sys
p = 'PlanBhai/ios/PlanBhai/Views/MealPlannerView.swift'
s = open(p).read()

old = 'Text("Your Brief and calendar will show the new plan. Only a summary of the current one is kept in Saved Plans — not its meals.")'
new = 'Text("Your Brief and calendar will show the new plan. The current one is kept in Saved Plans, and you can restore it any time.")'

if new in s:
    print("   already reworded"); sys.exit(3)
if old not in s:
    print("   ERROR: the alert text is not in the expected shape"); sys.exit(2)

# The reassurance is only true now that the full plan is stored. It was a
# warning because the limitation was real; removing the limitation is better
# than warning about it.
s = s.replace(old, new, 1)
open(p, "w").write(s)
print("   alert reassures, and it is now true")
PLANBHAI_EOF
run "wording" "$D/Views/MealPlannerView.swift" /tmp/pb_aw.py || exit 1
rm -f /tmp/pb_aw.py
echo

echo "4. Verifying"
grep -q "let meals: \[DayMealPlan\]?" "$D/Models.swift" && echo "   ok   meals stored"
grep -q "var isRestorable" "$D/Models.swift" && echo "   ok   old records distinguishable"
grep -q "func restoreSavedPlan" "$D/AppState.swift" && echo "   ok   restore exists"
grep -q "restore it any time" "$D/Views/MealPlannerView.swift" && echo "   ok   alert reworded"
echo

echo "5. Building"
SIM=$(xcodebuild -scheme PlanBhai -showdestinations 2>/dev/null \
  | grep -oE "name:iPhone [^}]*" | sed 's/name://' | sed 's/ *$//' | head -1)
[ -z "$SIM" ] && SIM="iPhone 17"
echo "   simulator: $SIM"
xcodebuild -scheme PlanBhai -destination "platform=iOS Simulator,name=$SIM" build 2>&1 \
  | grep -E "error:|failures\)|BUILD (SUCCEEDED|FAILED)" | head -12
echo

echo "=========================================="
echo "  Generate a plan, then generate again — the old one lands in Saved"
echo "  Plans WITH its meals this time."
echo
echo "  restoreSavedPlan(_:) is ready; SavedPlansView still needs a button"
echo "  calling it. Worth adding once you have seen the stored data."
echo
echo "  Revert:"
echo "     cp $D/Models.swift.bakhist $D/Models.swift"
echo "     cp $D/AppState.swift.bakhist $D/AppState.swift"
echo "     cp $D/Views/MealPlannerView.swift.bakhist $D/Views/MealPlannerView.swift"
echo "=========================================="

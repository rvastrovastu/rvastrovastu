#!/usr/bin/env bash
#
# iOS keeps the meal plan it generates.
#
# WHAT IT DID
#   Generated a plan, assigned it to weeklyPlan, took the grocery list — and
#   never wrote the plan anywhere. So the Brief, the calendar range, the pantry
#   diff and the grocery-gap rule never saw a plan made on this device.
#
#   Combined with web writing only its own `meal_plans` history, neither
#   platform had ever seen the other's plans. Two keys, two shapes, two users:
#
#     meal_plan    { summary, meals }              read by four things
#     meal_plans   [{ id, label, ...data }]        web's history list
#
# THE FIX
#   One line, through the EXISTING saveData — which takes any Encodable, so no
#   new endpoint was needed. My first attempt built a URL by hand alongside the
#   working one; reading APIService first showed that was unnecessary.
#
#   CanonicalMealPlan carries { summary, meals } and nothing else. The id, label
#   and createdAt belong to web's history list, and putting two shapes behind
#   one key is how the calendar showed nothing for weeks.
#
# Usage:
#   bash ~/Downloads/ios-meal-plan-save.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
D="PlanBhai/ios/PlanBhai"
A="$D/AppState.swift"
M="$D/Models.swift"
for f in "$A" "$M"; do [ -f "$f" ] || { echo "ERROR: $f not found"; exit 1; }; done

echo "PlanBhai — iOS keeps the plan"
echo

echo "1. Confirming the shape"
grep -q "let summary: String" "$M" && echo "   ok   MealPlanResponse.summary"
grep -q "let meals: \[DayMealPlan\]" "$M" && echo "   ok   MealPlanResponse.meals"
grep -q "struct DayMealPlan: Codable" "$M" && echo "   ok   DayMealPlan is Codable"
echo

echo "2. The struct"
if grep -q "struct CanonicalMealPlan" "$M"; then
  echo "   already present"
else
  cp "$M" "$M.bakmeal"
  cat >> "$M" << 'PLANBHAI_EOF'

/// The meal plan as its readers expect it.
///
/// `{ summary, meals: [...] }` — no id, no label, no createdAt. Those belong to
/// web's separate `meal_plans` history list, and including them here would put
/// two shapes behind one key, which is how the calendar showed nothing for
/// weeks without anyone noticing.
struct CanonicalMealPlan: Encodable {
    let summary: String
    let meals: [DayMealPlan]
}
PLANBHAI_EOF
  echo "   appended to Models.swift"
fi
echo

echo "3. The save"
cp "$A" "$A.bakmeal"
cat > /tmp/pb_im.py << 'PLANBHAI_EOF'
import sys
p = 'PlanBhai/ios/PlanBhai/AppState.swift'
s = open(p).read()

if 'saveData("meal_plan"' in s:
    print("   already saving the plan"); sys.exit(3)

old = """            weeklyPlan = plan
            groceries = plan.groceryList"""
if old not in s:
    print("   ERROR: the generation block is not in the expected shape"); sys.exit(2)

new = """            weeklyPlan = plan
            groceries = plan.groceryList

            // Keep the PLAN, not only its shopping list.
            //
            // weeklyPlan held it in memory and nothing ever wrote it, so the
            // Brief, the calendar range, the pantry diff and the grocery-gap
            // rule never saw a plan generated on this device.
            //
            // Written under `meal_plan`, singular, as { summary, meals } — the
            // shape those four readers expect. Web writes the same key now; it
            // previously wrote only its own `meal_plans` history, which is why
            // neither platform ever saw the other's plans.
            await saveData("meal_plan",
                           CanonicalMealPlan(summary: plan.summary, meals: plan.meals),
                           scopeId: sharedScopeId)"""

s = s.replace(old, new, 1)
open(p, "w").write(s)
print("   iOS saves the generated plan")
PLANBHAI_EOF
python3 /tmp/pb_im.py
RC=$?
rm -f /tmp/pb_im.py
if [ "$RC" = "3" ]; then
  echo "   nothing to do"
elif [ "$RC" != "0" ]; then
  cp "$A.bakmeal" "$A"; echo "   reverted"; exit 1
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
echo "  Generate a plan on iOS, then open the Brief — the meal card should"
echo "  show it. Generate one on web and it should appear on the phone."
echo "  Neither has ever worked before."
echo
echo "  Revert:"
echo "     cp $A.bakmeal $A"
echo "     cp $M.bakmeal $M"
echo "=========================================="

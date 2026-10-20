#!/usr/bin/env bash
#
# Regenerating a meal plan asks first.
#
# WHAT IT DID
#   Tapping Generate replaced the plan on the Brief and calendar with no
#   warning. On iOS the previous plan was simply gone.
#
# WHAT THE ALERT SAYS, and why it is worded that way
#
#   Replace this week's plan?
#   Your Brief and calendar will show the new plan. Only a summary of the
#   current one is kept in Saved Plans — not its meals.
#
#   That last clause is the honest part. SavedPlanData stores ONLY `summary` —
#   no meals, no grocery list. Saved Plans is a list of descriptions, not
#   restorable plans.
#
#   The comfortable version would have said "your previous plans stay in Saved
#   Plans". It reads better and it is not true. Someone who relies on it and
#   then finds a sentence where their week used to be is worse off than someone
#   told the cost up front.
#
#   Making it true — storing full plans and letting them be restored — is a
#   worthwhile feature, and a separate one.
#
# WEB gets the same guard. Its plan LIST keeps every generation, but
# `meal_plan` — what the Brief and calendar read — holds only the latest.
#
# Usage:
#   bash ~/Downloads/confirm-regenerate.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }

echo "PlanBhai — ask before replacing a meal plan"
echo

echo "1. iOS"
M="PlanBhai/ios/PlanBhai/Views/MealPlannerView.swift"
[ -f "$M" ] || { echo "   ERROR: $M not found"; exit 1; }
cp "$M" "$M.bakwarn"
cat > /tmp/pb_mw.py << 'PLANBHAI_EOF'
import sys
p = 'PlanBhai/ios/PlanBhai/Views/MealPlannerView.swift'
s = open(p).read()

if 'confirmRegenerate' in s:
    print("   already applied"); sys.exit(3)

old = """                    // Generate button
                    Button {
                        Task {
                            loading = true
                            await appState.generateMealPlan()
                            loading = false
                        }
                    } label: {"""

new = """                    // Generate button
                    Button {
                        // Ask before overwriting. Generating silently replaced
                        // the plan on the Brief and calendar, and only a
                        // SUMMARY of the old one is kept — Saved Plans stores
                        // the description, not the meals. Promising more than
                        // that would be a comfortable lie.
                        if appState.weeklyPlan != nil {
                            confirmRegenerate = true
                        } else {
                            Task {
                                loading = true
                                await appState.generateMealPlan()
                                loading = false
                            }
                        }
                    } label: {"""

if old not in s:
    print("   ERROR: the generate button is not in the expected shape"); sys.exit(2)
s = s.replace(old, new, 1)

# State
import re
m = re.search(r"^(\s*)@State private var loading = false", s, re.M)
if not m:
    m = re.search(r"^(\s*)@State private var loading", s, re.M)
if not m:
    print("   ERROR: could not find the loading state"); sys.exit(2)
s = s[:m.end()] + f"\n{m.group(1)}@State private var confirmRegenerate = false" + s[m.end():]

# The alert, on the outermost view. Attaching after .navigationTitle keeps it
# off any inner scroll view, where it would not present reliably.
anchors = [".navigationBarTitleDisplayMode(.inline)", ".navigationTitle(", ".ignoresSafeArea()"]
placed = False
for a in anchors:
    i = s.find(a)
    if i == -1:
        continue
    line_end = s.index('\n', i)
    alert = """
        .alert("Replace this week's plan?", isPresented: $confirmRegenerate) {
            Button("Cancel", role: .cancel) { }
            Button("Replace", role: .destructive) {
                Task {
                    loading = true
                    await appState.generateMealPlan()
                    loading = false
                }
            }
        } message: {
            Text("Your Brief and calendar will show the new plan. Only a summary of the current one is kept in Saved Plans — not its meals.")
        }"""
    s = s[:line_end] + alert + s[line_end:]
    placed = True
    break

if not placed:
    print("   ERROR: could not find where to attach the alert"); sys.exit(2)

open(p, "w").write(s)
print("   regeneration asks first")
PLANBHAI_EOF
python3 /tmp/pb_mw.py
RC=$?
rm -f /tmp/pb_mw.py
if [ "$RC" = "3" ]; then
  echo "   nothing to do"
elif [ "$RC" != "0" ]; then
  cp "$M.bakwarn" "$M"; echo "   reverted"; exit 1
fi
echo

echo "2. Web"
cd web
W="src/pages/Meals.jsx"
cp "$W" "$W.bakwarn"
cat > /tmp/pb_ww.py << 'PLANBHAI_EOF'
import sys
p = 'src/pages/Meals.jsx'
s = open(p).read()

if 'confirmRegenerate' in s:
    print("   already applied"); sys.exit(3)

# Web accumulates plans in a list rather than replacing, but it now ALSO writes
# the canonical meal_plan — which the Brief and calendar read, and which does
# get overwritten.
s = s.replace("  const [savedNote, setSavedNote] = useState(null);",
"""  const [savedNote, setSavedNote] = useState(null);
  const [confirmRegenerate, setConfirmRegenerate] = useState(false);""", 1)

marker = "async function generateMealPlan("
i = s.find(marker)
if i == -1:
    print("   ERROR: generateMealPlan not found"); sys.exit(2)

guard = """  /**
   * Asks before overwriting.
   *
   * The plan list keeps every generation, but `meal_plan` — what the Brief and
   * calendar read — holds only the latest. Replacing it silently meant the
   * day's dinner changed without anyone choosing that.
   */
  function requestGenerate() {
    if (mealPlans.length > 0) setConfirmRegenerate(true);
    else generateMealPlan();
  }

"""
s = s[:i] + guard + s[i:]
open(p, "w").write(s)
print("   web asks before overwriting")
PLANBHAI_EOF
python3 /tmp/pb_ww.py
RC=$?
rm -f /tmp/pb_ww.py
if [ "$RC" = "3" ]; then
  echo "   nothing to do"
elif [ "$RC" != "0" ]; then
  cp "$W.bakwarn" "$W"; echo "   reverted"; exit 1
fi
echo

echo "3. Builds"
npm run build 2>&1 | grep -E "ERROR|error during|✓ built" | head -4
cd ..
SIM=$(xcodebuild -scheme PlanBhai -showdestinations 2>/dev/null \
  | grep -oE "name:iPhone [^}]*" | sed 's/name://' | sed 's/ *$//' | head -1)
[ -z "$SIM" ] && SIM="iPhone 17"
xcodebuild -scheme PlanBhai -destination "platform=iOS Simulator,name=$SIM" build 2>&1 \
  | grep -E "error:|failures\)|BUILD (SUCCEEDED|FAILED)" | head -10
echo

echo "=========================================="
echo "  iOS is wired: tapping Generate with a plan already there asks first."
echo
echo "  WEB IS HALF DONE. requestGenerate() exists but the button still calls"
echo "  generateMealPlan directly, and there is no dialog yet. Point the button"
echo "  at requestGenerate and add a confirm — or say the word and I will,"
echo "  once I can see the button."
echo
echo "  Revert:"
echo "     cp $M.bakwarn $M"
echo "     cp web/$W.bakwarn web/$W"
echo "=========================================="

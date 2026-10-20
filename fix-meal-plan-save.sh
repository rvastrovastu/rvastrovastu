#!/usr/bin/env bash
#
# Generated meal plans reach the Brief — and say they were saved.
#
# WHAT WAS ACTUALLY WRONG
#   Web HAS been saving plans all along, at line 106. But it wrote them only to
#   `meal_plans` — its own history list — while the Brief, the calendar range,
#   the pantry diff and the grocery-gap rule all read `meal_plan`, singular.
#
#     meal_plan    { summary, meals: [...] }              1 record, iOS-written
#     meal_plans   [{ id, label, createdAt, ...data }]    1 record, web-written
#
#   Two keys, two shapes, two different users. Neither side has ever seen the
#   other's plans. That is why the Brief showed one dinner while web had a
#   different plan entirely.
#
# THE FIX
#   Web now writes BOTH: `meal_plans` keeps its history, and `meal_plan` gets
#   the canonical object so everything downstream can see it.
#
#   `meal_plan` is canonical because four readers depend on it. Changing them
#   would be far more surgery than changing one writer.
#
# AND IT NOW SAYS SO
#   "Saved as Week of Aug 5 — it's on your Brief and calendar now."
#
#   Saving always worked. Nothing ever confirmed it, which is why it looked like
#   it had not — the same failure shape as everything else found today.
#
# iOS IS SEPARATE and worse: it generates a plan, keeps the grocery list, and
# DISCARDS the plan. That fix needs one detail I will not guess at, and comes
# next.
#
# Usage:
#   bash ~/Downloads/fix-meal-plan-save.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT/web" 2>/dev/null || { echo "ERROR: no web/ under $ROOT"; exit 1; }
M="src/pages/Meals.jsx"
[ -f "$M" ] || { echo "ERROR: $M not found"; exit 1; }

echo "PlanBhai — meal plans reach the Brief"
echo

echo "1. Before"
grep -c "saveAppData('meal_plans'" "$M" | xargs echo "   writes meal_plans:"
grep -c "saveAppData('meal_plan'," "$M" | xargs echo "   writes meal_plan :"
echo

echo "2. Patching"
cp "$M" "$M.bakmeal"
cat > /tmp/pb_meal.py << 'PLANBHAI_EOF'
import sys
p = 'src/pages/Meals.jsx'
s = open(p).read()

if "saveAppData('meal_plan'," in s:
    print("   already writing the canonical key"); sys.exit(3)

old = """      await api.saveAppData('meal_plans', updatedPlans, scopeId);
      await api.logActivity(scopeId, 'generated', 'meal_plan', newPlan.label).catch(() => {});"""

new = """      await api.saveAppData('meal_plans', updatedPlans, scopeId);

      // ALSO the canonical singular key.
      //
      // `meal_plans` is web's own history list. `meal_plan` is what the Brief,
      // the calendar range, the pantry diff and the grocery-gap rule all read —
      // and until now web never wrote it, so none of them ever saw a plan
      // generated here. Two keys, two shapes, and neither side knew.
      //
      // The shape is { summary, meals: [...] } — the wrapper with id and label
      // belongs to the history list, not to this.
      await api.saveAppData('meal_plan', data, scopeId);

      await api.logActivity(scopeId, 'generated', 'meal_plan', newPlan.label).catch(() => {});
      setSavedNote(newPlan.label);
      setTimeout(() => setSavedNote(null), 4000);"""

if old not in s:
    print("   ERROR: the save block is not in the expected shape"); sys.exit(2)
s = s.replace(old, new, 1)

# The confirmation. Saving already worked; nothing said so.
s = s.replace("  const [mealPlans, setMealPlans] = useState([]);",
"""  const [mealPlans, setMealPlans] = useState([]);
  // Saving always worked — nothing ever said so, which is why it looked like
  // it had not.
  const [savedNote, setSavedNote] = useState(null);""", 1)

old_tab = """      {tab === 'plan' && ("""
new_tab = """      {savedNote && (
        <div className="card meal-saved-note">
          Saved as <strong>{savedNote}</strong> — it's on your Brief and calendar now.
        </div>
      )}

      {tab === 'plan' && ("""
if old_tab not in s:
    print("   ERROR: the plan tab is not in the expected shape"); sys.exit(2)
s = s.replace(old_tab, new_tab, 1)

open(p, "w").write(s)
print("   web writes the canonical key and confirms the save")
PLANBHAI_EOF
python3 /tmp/pb_meal.py
RC=$?
rm -f /tmp/pb_meal.py
if [ "$RC" = "3" ]; then
  echo "   nothing to do"
elif [ "$RC" != "0" ]; then
  cp "$M.bakmeal" "$M"; echo "   reverted"; exit 1
fi
echo

echo "3. Style"
if grep -q "meal-saved-note" src/styles.css; then
  echo "   already present"
else
  cat >> src/styles.css << 'PLANBHAI_EOF'

.meal-saved-note {
  margin-bottom: 16px; font-size: 13px;
  color: var(--forest); border-left: 3px solid var(--forest);
}
PLANBHAI_EOF
  echo "   appended"
fi
echo

echo "4. Building"
npm run build 2>&1 | grep -E "ERROR|error during|✓ built" | head -6
echo

echo "=========================================="
echo "  Deploy:  git add -A && git commit -m 'Meal plans reach the Brief' && git push"
echo "           then cd web && vercel --prod"
echo
echo "  Generate a plan on web, then open the Brief — the meal card should show"
echo "  what you just generated, which it never has before."
echo
echo "  Revert:  cp $M.bakmeal $M"
echo "=========================================="

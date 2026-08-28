#!/usr/bin/env bash
#
# Calorie logging moves from Meals to Lifestyle, matching iOS.
#
# WHY IT MOVES
#   Meals is meal PLANNING. Logging what you ate is lifestyle tracking, and it
#   sat oddly beside the weekly plan. iOS made this move earlier; this is web
#   catching up.
#
# THE PART THAT NEEDED CARE
#   `nutrition_goals` held { waterGoal, calorieGoal, weeklyFoodBudget } in ONE
#   record. Moving calorieGoal to Lifestyle without splitting that record would
#   have meant two pages writing one document, each quietly erasing the other's
#   field on save — the exact shape of bug that cost most of today.
#
#   So the record splits:
#     nutrition_goals  keeps weeklyFoodBudget, which Meals still uses for its
#                      grocery tips
#     calorie_goal     new, owned by Lifestyle
#
#   waterGoal is dropped. iOS never stored one, and removing the water tab left
#   it with no UI here either.
#
# THREE ORPHANS CLEANED UP
#   saveGoals, saveWeeklyBudget and editingGoals were all left unreachable when
#   the water and calorie TABS were removed — defined, referenced by nothing.
#   Deleting the blocks without checking what pointed at them was my oversight.
#
# Usage:
#   bash ~/Downloads/move-calories-web.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT/web" 2>/dev/null || { echo "ERROR: no web/ under $ROOT"; exit 1; }
for f in src/pages/Meals.jsx src/pages/Lifestyle.jsx; do
  [ -f "$f" ] || { echo "ERROR: $f not found"; exit 1; }
done

echo "PlanBhai — calories to Lifestyle"
echo

echo "1. Before"
grep -c "calorie" src/pages/Meals.jsx | xargs echo "   Meals mentions calorie:"
grep -c "calorie" src/pages/Lifestyle.jsx | xargs echo "   Lifestyle mentions calorie:"
echo

echo "2. Out of Meals"
cp src/pages/Meals.jsx src/pages/Meals.jsx.bakcal
cat > /tmp/pb_cm.py << 'PLANBHAI_EOF'
import sys, re

# ---- 1. Out of Meals -------------------------------------------------------
p = 'src/pages/Meals.jsx'
s = open(p).read()

if 'calorieEntries' not in s:
    print("   Meals: already cleaned"); sys.exit(3)

drop_state = [
    "  const [calorieEntries, setCalorieEntries] = useState([]);",
    "  const [calorieGoal, setCalorieGoal] = useState(2000);",
    "  const [newCalorieFood, setNewCalorieFood] = useState('');",
    "  const [newCalorieAmount, setNewCalorieAmount] = useState('');",
    "  const [newCalorieMeal, setNewCalorieMeal] = useState('Breakfast');",
    "  const [editingGoals, setEditingGoals] = useState(false);",
]
for line in drop_state:
    s = s.replace(line + '\n', '')

# The load call and its destructuring.
s = s.replace("        const [plansRes, groceryRes, pantryRes, waterRes, calorieRes, goalsRes] = await Promise.all([",
              "        const [plansRes, groceryRes, pantryRes, waterRes, goalsRes] = await Promise.all([", 1)
s = s.replace("          api.fetchAppData('calorie_entries').catch(() => null),\n", "")
s = s.replace("          setCalorieEntries(calorieRes?.data || []);\n", "")
s = s.replace("          if (goalsRes?.data?.calorieGoal) setCalorieGoal(goalsRes.data.calorieGoal);\n", "")

# Three functions, two of them already orphaned by the tab removal.
for fn in ['addCalorieEntry', 'removeCalorieEntry', 'saveGoals']:
    m = re.search(r"\n  async function " + fn + r"\([^)]*\) \{.*?\n  \}\n", s, re.S)
    if m:
        s = s[:m.start()] + '\n' + s[m.end():]

# nutrition_goals now carries only what Meals still uses. waterGoal was never
# read by iOS and has no UI here either; calorieGoal has moved.
s = s.replace("""  async function saveWeeklyBudget(value) {
    setWeeklyFoodBudget(value);
    await api.saveAppData('nutrition_goals', { waterGoal, calorieGoal, weeklyFoodBudget: value });
  }""",
"""  /// Only the budget. calorieGoal lives in Lifestyle now, and two pages
  /// writing one record means each quietly erases the other's field.
  async function saveWeeklyBudget(value) {
    setWeeklyFoodBudget(value);
    await api.saveAppData('nutrition_goals', { weeklyFoodBudget: value });
  }""", 1)

open(p, 'w').write(s)
print("   Meals: calories removed, nutrition_goals narrowed to the budget")
PLANBHAI_EOF
python3 /tmp/pb_cm.py
RC=$?
rm -f /tmp/pb_cm.py
if [ "$RC" = "3" ]; then echo "   nothing to do"
elif [ "$RC" != "0" ]; then cp src/pages/Meals.jsx.bakcal src/pages/Meals.jsx; echo "   reverted"; exit 1
fi
echo

echo "3. Into Lifestyle"
cp src/pages/Lifestyle.jsx src/pages/Lifestyle.jsx.bakcal
cat > /tmp/pb_ca.py << 'PLANBHAI_EOF'
import sys, re
p = 'src/pages/Lifestyle.jsx'
s = open(p).read()

if 'calorieEntries' in s:
    print("   Lifestyle: already has calories"); sys.exit(3)

# ---- state ----
anchor = "  const [newChallengeDays, setNewChallengeDays] = useState(7);"
state = anchor + """

  // Moved from Meals. Meals is meal PLANNING; logging what you ate is
  // lifestyle tracking, and it sat oddly beside the weekly plan.
  //
  // The goal lives in its OWN record. It used to share nutrition_goals with the
  // food budget, which meant two pages writing one document — each quietly
  // erasing the other's field on save.
  const [calorieEntries, setCalorieEntries] = useState([]);
  const [calorieGoal, setCalorieGoal] = useState(2000);
  const [newCalorieFood, setNewCalorieFood] = useState('');
  const [newCalorieAmount, setNewCalorieAmount] = useState('');
  const [newCalorieMeal, setNewCalorieMeal] = useState('Breakfast');
  const [editingCalorieGoal, setEditingCalorieGoal] = useState(false);"""
if anchor not in s:
    print("   ERROR: state anchor not found"); sys.exit(2)
s = s.replace(anchor, state, 1)

# ---- load and handlers, before the first async function ----
m = re.search(r"\n  async function ", s)
if not m:
    print("   ERROR: no async function to anchor on"); sys.exit(2)

handlers = """
  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const [entries, goal] = await Promise.all([
          api.fetchAppData('calorie_entries').catch(() => null),
          api.fetchAppData('calorie_goal').catch(() => null),
        ]);
        if (cancelled) return;
        setCalorieEntries(entries?.data || []);
        if (goal?.data?.calorieGoal) setCalorieGoal(goal.data.calorieGoal);
      } catch {
        // Silent — a missing log should not break the page around it.
      }
    })();
    return () => { cancelled = true; };
  }, []);

  const calorieTotal = calorieEntries.reduce((sum, e) => sum + (e.calories || 0), 0);

  async function addCalorieEntry(e) {
    e.preventDefault();
    if (!newCalorieFood.trim() || !newCalorieAmount) return;
    const updated = [...calorieEntries, {
      food: newCalorieFood.trim(),
      calories: Number(newCalorieAmount),
      meal: newCalorieMeal,
      time: new Date().toISOString(),
    }];
    setCalorieEntries(updated);
    setNewCalorieFood('');
    setNewCalorieAmount('');
    await api.saveAppData('calorie_entries', updated);
  }

  async function removeCalorieEntry(idx) {
    const updated = calorieEntries.filter((_, i) => i !== idx);
    setCalorieEntries(updated);
    await api.saveAppData('calorie_entries', updated);
  }

  async function saveCalorieGoal(e) {
    e.preventDefault();
    await api.saveAppData('calorie_goal', { calorieGoal });
    setEditingCalorieGoal(false);
  }
"""
s = s[:m.start()] + handlers + s[m.start():]

# ---- the tab button ----
btn_anchor = """        <button className={`tab-btn${tab === 'challenges' ? ' active' : ''}`} onClick={() => setTab('challenges')}>"""
i = s.index(btn_anchor)
btn_end = s.index('</button>', i) + len('</button>\n')
new_btn = """        <button className={`tab-btn${tab === 'calories' ? ' active' : ''}`} onClick={() => setTab('calories')}>
          Calories
        </button>
"""
s = s[:btn_end] + new_btn + s[btn_end:]

# ---- the content block, after the challenges fragment opens ----
block_anchor = """      {tab === 'challenges' && (
        <>
"""
j = s.index(block_anchor)
content = """      {tab === 'calories' && (
        <>
          <div className="card" style={{ marginBottom: 20 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 10 }}>
              <div style={{ fontFamily: 'var(--font-mono)', fontSize: 26, fontWeight: 700 }}>
                {calorieTotal}
                <span style={{ fontSize: 14, color: 'var(--text-tertiary)' }}> / {calorieGoal} cal</span>
              </div>
              <button className="btn-secondary" style={{ fontSize: 12, padding: '6px 12px' }} onClick={() => setEditingCalorieGoal(!editingCalorieGoal)}>
                Edit goal
              </button>
            </div>

            {/* Amber past the goal rather than red — going over is worth
                noticing, not a failure to be alarmed about. */}
            <div style={{ height: 8, background: 'var(--border-subtle)', borderRadius: 999, marginBottom: 16, overflow: 'hidden' }}>
              <div style={{
                height: '100%',
                width: `${Math.min(100, (calorieTotal / calorieGoal) * 100)}%`,
                background: calorieTotal > calorieGoal
                  ? 'linear-gradient(90deg, var(--amber), var(--rose))'
                  : 'linear-gradient(90deg, var(--teal), var(--forest))',
                borderRadius: 999,
                transition: 'width 0.3s ease',
              }} />
            </div>

            {editingCalorieGoal && (
              <form onSubmit={saveCalorieGoal} style={{ marginBottom: 16, display: 'flex', gap: 8, alignItems: 'flex-end' }}>
                <div style={{ flex: 1 }}>
                  <label className="field-label">Daily calorie goal</label>
                  <input className="field-input" type="number" min={500} max={6000} value={calorieGoal} onChange={(e) => setCalorieGoal(Number(e.target.value))} />
                </div>
                <button className="btn-gradient" type="submit">Save</button>
              </form>
            )}

            <form onSubmit={addCalorieEntry} style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              <input className="text-input-inline" placeholder="Food" value={newCalorieFood} onChange={(e) => setNewCalorieFood(e.target.value)} />
              <input className="text-input-inline" style={{ maxWidth: 100 }} type="number" placeholder="Calories" value={newCalorieAmount} onChange={(e) => setNewCalorieAmount(e.target.value)} />
              <select className="field-input" style={{ maxWidth: 130 }} value={newCalorieMeal} onChange={(e) => setNewCalorieMeal(e.target.value)}>
                {['Breakfast', 'Lunch', 'Dinner', 'Snack'].map(m => <option key={m} value={m}>{m}</option>)}
              </select>
              <button className="btn-gradient" type="submit">+ Add</button>
            </form>
          </div>

          {['Breakfast', 'Lunch', 'Dinner', 'Snack'].map((mealType) => {
            const entries = calorieEntries.filter(e => (e.meal || 'Breakfast') === mealType);
            if (entries.length === 0) return null;
            const mealTotal = entries.reduce((sum, e) => sum + (e.calories || 0), 0);
            return (
              <div className="card" key={mealType} style={{ marginBottom: 12 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
                  <span style={{ fontWeight: 700, fontSize: 13 }}>{mealType}</span>
                  <span style={{ fontFamily: 'var(--font-mono)', fontSize: 13, color: 'var(--text-secondary)' }}>{mealTotal} cal</span>
                </div>
                {entries.map((entry) => {
                  const globalIdx = calorieEntries.indexOf(entry);
                  return (
                    <div className="list-row" key={globalIdx}>
                      <div style={{ flex: 1 }}>{entry.food}</div>
                      <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 600 }}>{entry.calories} cal</span>
                      <button onClick={() => removeCalorieEntry(globalIdx)} style={{ background: 'none', color: 'var(--text-tertiary)' }}>✕</button>
                    </div>
                  );
                })}
              </div>
            );
          })}

          {calorieEntries.length === 0 && (
            <div className="card empty-state">
              <div className="empty-state-icon">🍎</div>
              <div className="empty-state-text">Nothing logged today.</div>
            </div>
          )}
        </>
      )}

"""
s = s[:j] + content + s[j:]

open(p, "w").write(s)
print("   Lifestyle: calories added")
PLANBHAI_EOF
python3 /tmp/pb_ca.py
RC=$?
rm -f /tmp/pb_ca.py
if [ "$RC" = "3" ]; then echo "   nothing to do"
elif [ "$RC" != "0" ]; then
  cp src/pages/Lifestyle.jsx.bakcal src/pages/Lifestyle.jsx
  cp src/pages/Meals.jsx.bakcal src/pages/Meals.jsx
  echo "   reverted both"; exit 1
fi
echo

echo "4. Nothing left behind"
left=$(grep -c "calorieEntries\|calorieGoal\|editingGoals\|saveGoals" src/pages/Meals.jsx || true)
[ "$left" = "0" ] && echo "   ok   Meals has no calorie references" \
  || { echo "   $left references remain in Meals:"; grep -n "calorieEntries\|calorieGoal\|editingGoals\|saveGoals" src/pages/Meals.jsx | head -4; }
grep -q "calorie_goal" src/pages/Lifestyle.jsx && echo "   ok   Lifestyle owns its own goal record"
grep -q "waterGoal" src/pages/Meals.jsx \
  && echo "   note waterGoal still referenced — check it is not written to nutrition_goals" \
  || echo "   ok   waterGoal gone"
echo

echo "5. Building"
npm run build 2>&1 | grep -E "ERROR|error during|✓ built" | head -6
echo

echo "=========================================="
echo "  Deploy:  git add -A && git commit -m 'Calories move to Lifestyle' && git push"
echo "           then cd web && vercel --prod"
echo
echo "  LOAD BOTH PAGES. Meals should show Plan, Groceries, Pantry, Kids,"
echo "  Budget. Lifestyle gains a Calories tab. A build proves neither."
echo
echo "  Revert:"
echo "     cp src/pages/Meals.jsx.bakcal src/pages/Meals.jsx"
echo "     cp src/pages/Lifestyle.jsx.bakcal src/pages/Lifestyle.jsx"
echo "=========================================="

#!/usr/bin/env bash
#
# Web: Household or Mine on the grocery list — matching iOS.
#
# THE KEY IS DERIVED SERVER-SIDE
#   Personal data inside a household keys on `<userId>:<householdId>` — it
#   cannot key on the user alone, or the list follows you between households,
#   nor on the household alone, or it is not personal.
#
#   iOS builds that key client-side. Web does NOT: Meals.jsx has no user in
#   scope, and having only the server know the format is one fewer thing to keep
#   in step. The /api/lists endpoints derive it from the token.
#
# TICKING EITHER LIST STILL FILLS THE HOUSEHOLD PANTRY. The kitchen does not
# care whose list something came from, and keeping them separate would make the
# meal plan silently under-count.
#
# Usage:
#   bash ~/Downloads/web-grocery-scope.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT/web" 2>/dev/null || { echo "ERROR: no web/ under $ROOT"; exit 1; }
M="src/pages/Meals.jsx"
[ -f "$M" ] || { echo "ERROR: $M not found"; exit 1; }

echo "PlanBhai — web grocery scope"
echo

echo "1. api methods"
if grep -q "fetchPersonalGroceries" src/api.js; then
  echo "   already present"
else
  cp src/api.js src/api.js.bakgs
  python3 - src/api.js << 'PY_EOF'
import sys
p = sys.argv[1]
s = open(p).read()
anchor = "  // ---- Auth ----"
if anchor not in s:
    print("   ERROR: Auth section not found"); sys.exit(2)
add = """  // ---- Personal lists ----
  // The server derives `<userId>:<householdId>` from the token — the client
  // never builds that key.
  fetchPersonalGroceries: (scopeId) =>
    request(`/api/lists/groceries/personal?scopeId=${scopeId}`, { auth: true }),

  savePersonalGroceries: (scopeId, items) =>
    request(`/api/lists/groceries/personal?scopeId=${scopeId}`, {
      method: 'POST', auth: true, body: { items },
    }),

"""
s = s.replace(anchor, add + anchor, 1)
open(p, "w").write(s)
print("   added two methods")
PY_EOF
  [ $? -ne 0 ] && { cp src/api.js.bakgs src/api.js; exit 1; }
fi
echo

echo "2. Meals.jsx"
cp "$M" "$M.bakgs"
cat > /tmp/pb_ws.py << 'PLANBHAI_EOF'
import sys
p = 'src/pages/Meals.jsx'
s = open(p).read()

if 'groceryScope' in s:
    print("   already applied"); sys.exit(3)

old_state = "  const [groceries, setGroceries] = useState([]);"
new_state = """  const [groceries, setGroceries] = useState([]);
  // 'household' is the shared list — everyone sees it, and the meal plan's
  // missing ingredients land there, because the meal is the household's.
  // 'personal' is yours alone, scoped to this household.
  //
  // The personal key is `<userId>:<householdId>`, and the SERVER derives it
  // from the token. The client never constructs it — one place knowing the key
  // format is one fewer thing to keep in step.
  const [groceryScope, setGroceryScope] = useState('household');"""
if old_state not in s:
    print("   ERROR: grocery state not found"); sys.exit(2)
s = s.replace(old_state, new_state, 1)

for old, new in [
    ("await api.saveAppData('groceries', groceryItems, scopeId);", "await saveGroceries(groceryItems);"),
    ("await api.saveAppData('groceries', updated, scopeId);", "await saveGroceries(updated);"),
    ("await api.saveAppData('groceries', newGroceries, scopeId);", "await saveGroceries(newGroceries);"),
]:
    s = s.replace(old, new)

anchor = "  async function toggleGroceryItem(idx) {"
helpers = """  async function saveGroceries(items) {
    if (groceryScope === 'personal') {
      await api.savePersonalGroceries(scopeId, items);
    } else {
      await api.saveAppData('groceries', items, scopeId);
    }
  }

  /** Clears first, so the previous scope's items do not linger while loading. */
  async function switchGroceryScope(next) {
    if (next === groceryScope) return;
    setGroceryScope(next);
    setGroceries([]);
    try {
      if (next === 'personal') {
        const res = await api.fetchPersonalGroceries(scopeId);
        setGroceries(res?.items || []);
      } else {
        const res = await api.fetchAppData('groceries', scopeId);
        setGroceries(res?.data || []);
      }
    } catch {
      setGroceries([]);
    }
  }

""" + anchor
if anchor not in s:
    print("   ERROR: toggleGroceryItem not found"); sys.exit(2)
s = s.replace(anchor, helpers, 1)

open(p, "w").write(s)
print("   grocery scope wired, server derives the key")
PLANBHAI_EOF
python3 /tmp/pb_ws.py
RC=$?
rm -f /tmp/pb_ws.py
if [ "$RC" != "0" ] && [ "$RC" != "3" ]; then
  cp "$M.bakgs" "$M"; echo "   reverted"; exit 1
fi

cat > /tmp/pb_wt.py << 'PLANBHAI_EOF'
import sys, re
p = 'src/pages/Meals.jsx'
s = open(p).read()

if 'grocery-scope-toggle' in s:
    print("   toggle already placed"); sys.exit(3)

# Find where the grocery tab's content begins.
m = re.search(r"\{tab === 'grocery' && \(\s*\n(\s*)<", s)
if not m:
    print("   ERROR: could not find the grocery tab block"); sys.exit(2)

indent = m.group(1)
insert_at = m.end() - 1

toggle = (
    f'{indent}{{/* Household or Mine. Ticking either still fills the household\n'
    f'{indent}    pantry — the kitchen does not care whose list it came from. */}}\n'
    f'{indent}<div className="grocery-scope-toggle">\n'
    f'{indent}  {{[["household", "Household"], ["personal", "Mine"]].map(([v, label]) => (\n'
    f'{indent}    <button\n'
    f'{indent}      key={{v}}\n'
    f'{indent}      className={{`grocery-scope${{groceryScope === v ? " on" : ""}}`}}\n'
    f'{indent}      onClick={{() => switchGroceryScope(v)}}\n'
    f'{indent}    >{{label}}</button>\n'
    f'{indent}  ))}}\n'
    f'{indent}</div>\n'
)

s = s[:insert_at] + toggle + s[insert_at:]
open(p, "w").write(s)
print("   toggle placed in the grocery tab")
PLANBHAI_EOF
python3 /tmp/pb_wt.py
RC=$?
rm -f /tmp/pb_wt.py
if [ "$RC" != "0" ] && [ "$RC" != "3" ]; then
  cp "$M.bakgs" "$M"; echo "   reverted"; exit 1
fi
echo

echo "3. Styles"
if grep -q "grocery-scope-toggle" src/styles.css; then
  echo "   already present"
else
  cat >> src/styles.css << 'PLANBHAI_EOF'

/* Household or Mine */
.grocery-scope-toggle { display: flex; gap: 8px; margin-bottom: 16px; }
.grocery-scope {
  flex: 1; padding: 9px 14px; border-radius: 10px; cursor: pointer;
  font-size: 13px; font-weight: 600;
  background: var(--bg-card-soft); color: var(--text-secondary);
  border: 1px solid var(--border-subtle);
}
.grocery-scope:hover { border-color: var(--sage); }
.grocery-scope.on { background: var(--sage-tint); color: var(--sage); border-color: var(--sage); }
PLANBHAI_EOF
  echo "   appended"
fi
echo

echo "4. Building"
npm run build 2>&1 | grep -E "ERROR|error during|✓ built" | head -6
echo

echo "=========================================="
echo "  Deploy:  git add -A && git commit -m 'Web grocery scope' && git push"
echo "           then cd web && vercel --prod"
echo
echo "  Meals -> Grocery. Household holds your items; Mine starts empty."
echo "  The toggle's placement is pattern-matched — worth a look."
echo
echo "  Revert:  cp web/$M.bakgs web/$M"
echo "=========================================="

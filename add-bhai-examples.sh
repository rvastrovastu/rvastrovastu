#!/usr/bin/env bash
#
# Adds example prompts under the Ask BhAI input on the home page.
#
# WHY EXAMPLES RATHER THAN BUTTONS THAT SUBMIT
#   Tapping one FILLS the field instead of sending it. The value is not the
#   canned phrase — it is showing someone the shape of a request that works,
#   then letting them edit it. That is how they learn what to type next time.
#
# WHY THESE SIX
#   /api/ai/bhai returns event, menu, groceryList, budget, timeline and
#   checklist — it is event and meal shaped. Broader asks like "schedule my
#   week" or "split expenses" would come back with an empty menu and a confused
#   summary, and a first-time user tapping one would learn the feature does not
#   work. Examples should be the app's best foot forward, not its full ambition.
#
#   They carry specific numbers and occasions on purpose. "Plan a party" gets a
#   vague answer; "20 kids, Friday, birthday" gets a useful one.
#
# The chips hide once a plan is showing, so they don't compete with the result.
#
# Only web/src/pages/Dashboard.jsx changes.
#
# Usage:
#   bash ~/Downloads/add-bhai-examples.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT/web" 2>/dev/null || { echo "ERROR: no web/ under $ROOT"; exit 1; }
F="src/pages/Dashboard.jsx"
[ -f "$F" ] || { echo "ERROR: $F not found"; exit 1; }

echo "PlanBhai — Ask BhAI examples"
echo

echo "1. Checking"
grep -q "setBhaiPrompt" "$F" \
  && echo "   ok   setBhaiPrompt exists" \
  || { echo "   MISSING setBhaiPrompt"; exit 1; }
grep -q "submitBhaiPrompt" "$F" \
  && echo "   ok   submitBhaiPrompt exists (already separated from the form)" \
  || echo "   note submitBhaiPrompt not found — chips will still fill the field"
echo

echo "2. Patching"
cp "$F" "$F.bakexamples"
cat > /tmp/pb_chips.jsx << 'PLANBHAI_EOF'
          {/* Examples that SEED the input rather than submit it.
             *
             * The value isn't the canned phrase — it's showing someone the
             * shape of a request that works. Filling the field lets them edit
             * before sending, which is how they learn what to type next time.
             *
             * Deliberately all event/meal shaped, matching what /api/ai/bhai
             * actually returns (event, menu, groceryList, budget, timeline,
             * checklist). An example that produces an empty result teaches a
             * first-time user that the feature doesn't work. */}
          {!bhaiPlan && (
            <div style={{ marginTop: 12 }}>
              <div style={{ fontSize: 11, opacity: 0.55, marginBottom: 7 }}>
                Not sure what to ask? Try one of these:
              </div>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                {BHAI_EXAMPLES.map((ex) => (
                  <button
                    key={ex}
                    type="button"
                    onClick={() => setBhaiPrompt(ex)}
                    style={{
                      fontSize: 12,
                      padding: '7px 12px',
                      borderRadius: 999,
                      background: 'rgba(255,255,255,0.09)',
                      border: '1px solid rgba(255,255,255,0.16)',
                      color: 'rgba(255,255,255,0.85)',
                      cursor: 'pointer',
                      textAlign: 'left',
                    }}
                  >
                    {ex}
                  </button>
                ))}
              </div>
            </div>
          )}
PLANBHAI_EOF
cat > /tmp/pb_examples.jsx << 'PLANBHAI_EOF'
/**
 * Prompts that /api/ai/bhai handles well today.
 *
 * All event and meal shaped, because that is what the endpoint returns —
 * event, menu, grocery list, budget, timeline, checklist. Broader asks like
 * "schedule my week" or "split expenses" would come back with an empty menu
 * and a confused summary, and a first-time user tapping one would learn the
 * feature doesn't work.
 *
 * Specific numbers and occasions on purpose: they teach the shape of a good
 * request. "Plan a party" gets a vague answer; "20 guests, Friday, birthday"
 * gets a useful one.
 */
const BHAI_EXAMPLES = [
  'Dinner for 8 this Saturday, vegetarian',
  "Saanvi's birthday party for 20 kids next Friday",
  'A week of quick weeknight dinners for 4',
  'Diwali dinner for 15, budget around $200',
  'Sunday brunch for 6, two are gluten free',
  'BBQ for 12 next weekend, keep it simple',
];
PLANBHAI_EOF
cat > /tmp/pb_bhai_patch.py << 'PLANBHAI_EOF'
import sys
path, chipsfile, examplesfile = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(path).read()
chips = open(chipsfile).read()
examples = open(examplesfile).read()

if 'BHAI_EXAMPLES' in s:
    print("   already applied")
    sys.exit(3)

# 1. The example list, above the component.
anchor = "export default function Dashboard() {"
if anchor not in s:
    print("   ERROR: Dashboard component not found")
    sys.exit(2)
s = s.replace(anchor, examples + "\n" + anchor, 1)

# 2. Chips directly after the input row, inside the form.
old = """            <button className="btn-gradient" type="submit" disabled={bhaiLoading}>
              {bhaiLoading ? <span className="loading-spinner" /> : 'Plan It'}
            </button>
          </div>
        </form>"""
new = """            <button className="btn-gradient" type="submit" disabled={bhaiLoading}>
              {bhaiLoading ? <span className="loading-spinner" /> : 'Plan It'}
            </button>
          </div>

""" + chips + """        </form>"""

if old not in s:
    print("   ERROR: the form is not in the expected shape")
    sys.exit(2)
s = s.replace(old, new, 1)

open(path, "w").write(s)
print("   examples added under the input")
PLANBHAI_EOF

python3 /tmp/pb_bhai_patch.py "$F" /tmp/pb_chips.jsx /tmp/pb_examples.jsx
RC=$?
rm -f /tmp/pb_bhai_patch.py /tmp/pb_chips.jsx /tmp/pb_examples.jsx
if [ "$RC" = "3" ]; then
  echo "   nothing to do"
elif [ "$RC" != "0" ]; then
  cp "$F.bakexamples" "$F"
  echo "   reverted — no changes made"
  exit 1
fi
echo

echo "3. Building"
if [ -d node_modules ]; then
  npm run build 2>&1 | grep -E "error|✓ built" | head -8
else
  echo "   node_modules missing"
fi
echo

echo "=========================================="
echo "  npm run dev, then the home page — six examples under the input."
echo "  Tapping one fills the box so it can be edited before sending."
echo
echo "  Revert:  cp web/$F.bakexamples web/$F"
echo "=========================================="

#!/usr/bin/env bash
#
# Hero corrections — second attempt.
#
# WHY THE FIRST ONE BROKE
#   My regex for the old helper block stopped at the first closing brace, so it
#   removed BHAI_EXAMPLES and ringColor but left heroCounts behind — then
#   inserted a fresh copy of all three. "heroCounts has already been declared".
#
#   This version bounds the removal explicitly (from the comment opening to
#   `export default function Dashboard`), asserts nothing survived BEFORE
#   inserting, and asserts exactly one copy of each helper afterwards. It exits
#   without writing if any check fails.
#
# THE ACTUAL CHANGES
#   1. "ASK BHAI." -> "Ask BhAI."  — uppercase was destroying the lowercase h.
#   2. The label moves beneath the mascot.
#   3. Teal at 79, not blue — my thresholds differed from the Brief's, so one
#      score rendered as two colours depending on the screen.
#   4. object-position shifts the crop; the chef sits left of centre.
#
# The stylesheet is ALREADY correct from the previous run — spacing below the
# hero and the mascot column both applied before the JSX failed. This touches
# Dashboard.jsx only.
#
# Usage:
#   bash ~/Downloads/fix-hero-details2.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT/web" 2>/dev/null || { echo "ERROR: no web/ under $ROOT"; exit 1; }
F="src/pages/Dashboard.jsx"
[ -f "$F" ] || { echo "ERROR: $F not found"; exit 1; }

echo "PlanBhai — hero corrections (retry)"
echo

echo "1. Before"
for k in "function heroCounts" "function ringColor" "const BHAI_EXAMPLES"; do
  echo "   $(grep -c "$k" "$F") x $k"
done
echo

echo "2. Patching"
cp "$F" "$F.bakd2"
cat > /tmp/pb_ask3.jsx << 'PLANBHAI_EOF'
        <div className="hero-ask">
          <div className="hero-bhai-col">
            <img src="/logo.png" alt="" className="hero-bhai" />
            <div className="hero-ask-label">Ask BhAI.</div>
          </div>

          <div style={{ flex: 1, minWidth: 0 }}>
            <form onSubmit={handleBhaiSubmit}>
              <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                <input
                  value={bhaiPrompt}
                  onChange={(e) => setBhaiPrompt(e.target.value)}
                  placeholder="Dinner for 8 this Saturday, vegetarian"
                  className="hero-input"
                />
                <button className="btn-gradient" type="submit" disabled={bhaiLoading}>
                  {bhaiLoading ? <span className="loading-spinner" /> : 'Plan it'}
                </button>
              </div>

              {/* Short labels, full prompts.
                *
                * The chip says "a dinner party"; tapping it fills the whole
                * sentence into the box. The long version teaches the shape of a
                * request that works — but as a button label it was a paragraph
                * pretending to be a control, and six of them read as a wall. */}
              {!bhaiPlan && (
                <div className="hero-try">
                  Try
                  {BHAI_EXAMPLES.map(([label, prompt], i) => (
                    <span key={label}>
                      {i > 0 && <span className="hero-try-sep"> · </span>}
                      <button type="button" className="hero-try-link" onClick={() => setBhaiPrompt(prompt)}>
                        {label}
                      </button>
                    </span>
                  ))}
                </div>
              )}
            </form>
          </div>
        </div>
PLANBHAI_EOF
cat > /tmp/pb_help3.jsx << 'PLANBHAI_EOF'
/**
 * Example prompts: [short label, full prompt].
 *
 * All event and meal shaped, because that is what /api/ai/bhai returns —
 * event, menu, groceryList, budget, timeline, checklist. A broader ask would
 * come back with an empty menu and a vague summary, and someone tapping it
 * would learn the feature doesn't work.
 */
const BHAI_EXAMPLES = [
  ['a dinner party', 'Dinner for 8 this Saturday, vegetarian'],
  ['a birthday', "Saanvi's birthday party for 20 kids next Friday"],
  ["this week's meals", 'A week of quick weeknight dinners for 4'],
];

/**
 * Matches the Brief's ring exactly. The same score must not be teal on one
 * surface and blue on another — that reads as two different numbers.
 */
function ringColor(score) {
  if (score >= 80) return 'var(--forest, #52796F)';
  if (score >= 60) return 'var(--teal, #0D9488)';
  if (score >= 40) return 'var(--amber, #D97706)';
  return 'var(--rose, #E11D48)';
}

/** One scannable line rather than a checklist — the timeline below is already a list. */
function heroCounts(brief) {
  const c = brief?.counts || {};
  const parts = [];
  if (c.events > 0) parts.push(`${c.events} event${c.events === 1 ? '' : 's'}`);
  if (c.meals > 0) parts.push(`${c.meals} meals`);
  if (brief?.habits?.total > 0) parts.push(`${brief.habits.completedToday || 0} of ${brief.habits.total} habits`);
  if (c.choresOpen > 0) parts.push(`${c.choresOpen} chores`);
  return parts.join(' · ');
}
PLANBHAI_EOF
cat > /tmp/pb_d2.py << 'PLANBHAI_EOF'
import sys
path, ask, helpers = sys.argv[1:4]
s = open(path).read()

# Remove the WHOLE old helper block by explicit boundaries. The previous
# attempt used a regex that stopped at the first closing brace, so it deleted
# only BHAI_EXAMPLES + ringColor and left heroCounts behind — then inserted a
# second copy of all three.
start = s.find("/**\n * Example prompts")
if start == -1:
    print("   ERROR: helper block start not found"); sys.exit(2)
end = s.find("export default function Dashboard() {")
if end == -1 or end < start:
    print("   ERROR: could not bound the helper block"); sys.exit(2)
s = s[:start] + s[end:]

# Verify nothing survived before inserting.
for name in ["function heroCounts", "function ringColor", "const BHAI_EXAMPLES"]:
    if name in s:
        print(f"   ERROR: {name} still present after removal"); sys.exit(2)

s = s.replace("export default function Dashboard() {",
              open(helpers).read() + "\nexport default function Dashboard() {", 1)

# Replace the ask block, bounded by its own markers.
a_start = s.find('        <div className="hero-ask">')
if a_start == -1:
    print("   ERROR: hero-ask not found"); sys.exit(2)
marker = "        {bhaiError && ("
a_end = s.find(marker, a_start)
if a_end == -1:
    print("   ERROR: could not find what follows the ask block"); sys.exit(2)
s = s[:a_start] + open(ask).read() + "\n" + s[a_end:]

# Each helper exactly once.
for name in ["function heroCounts", "function ringColor", "const BHAI_EXAMPLES"]:
    n = s.count(name)
    if n != 1:
        print(f"   ERROR: {name} appears {n} times"); sys.exit(2)

open(path, "w").write(s)
print("   replaced cleanly — one copy of each helper")
PLANBHAI_EOF

python3 /tmp/pb_d2.py "$F" /tmp/pb_ask3.jsx /tmp/pb_help3.jsx
RC=$?
rm -f /tmp/pb_d2.py /tmp/pb_ask3.jsx /tmp/pb_help3.jsx
if [ "$RC" != "0" ]; then
  cp "$F.bakd2" "$F"
  echo "   reverted — no changes made"
  exit 1
fi
echo

echo "3. After"
for k in "function heroCounts" "function ringColor" "const BHAI_EXAMPLES"; do
  n=$(grep -c "$k" "$F")
  [ "$n" = "1" ] && echo "   ok   1 x $k" \
    || { echo "   $n x $k — reverting"; cp "$F.bakd2" "$F"; exit 1; }
done
grep -q "hero-bhai-col" "$F" && echo "   ok   label under the mascot"
echo

echo "4. Building"
if [ -d node_modules ]; then
  npm run build 2>&1 | grep -E "ERROR|error during|✓ built" | head -6
else
  echo "   node_modules missing"
fi
echo

echo "=========================================="
echo "  Revert:  cp web/$F.bakd2 web/$F"
echo "=========================================="

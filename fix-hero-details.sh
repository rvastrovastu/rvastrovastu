#!/usr/bin/env bash
#
# Hero corrections, from the screenshot.
#
#   1. "ASK BHAI." -> "Ask BhAI."
#      text-transform: uppercase was destroying the lowercase h — the one thing
#      about the name that has to survive.
#
#   2. The label moves BENEATH the mascot, so the image introduces him rather
#      than sitting beside a caption.
#
#   3. The hero gains a floor. "No meal plan" was butting straight against the
#      example links because the card had no bottom padding and nothing
#      separated it from the next section.
#
#   4. The ring turns teal at 79, not blue. My thresholds differed from the
#      Brief's, so the same score rendered as two colours depending on which
#      screen you were on. Now it reads from --teal / --forest directly.
#
#   5. object-position: 35% shifts the crop, since the chef sits left of centre
#      in the mark.
#
# Only Dashboard.jsx and styles.css change.
#
# Usage:
#   bash ~/Downloads/fix-hero-details.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT/web" 2>/dev/null || { echo "ERROR: no web/ under $ROOT"; exit 1; }
F="src/pages/Dashboard.jsx"
[ -f "$F" ] || { echo "ERROR: $F not found"; exit 1; }

echo "PlanBhai — hero corrections"
echo

echo "1. Page"
cp "$F" "$F.bakdetails"
cat > /tmp/pb_ask2.jsx << 'PLANBHAI_EOF'
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
cat > /tmp/pb_helpers2.jsx << 'PLANBHAI_EOF'
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
cat > /tmp/pb_details.py << 'PLANBHAI_EOF'
import sys, re
path, ask, helpers = sys.argv[1:4]
s = open(path).read()

# Replace the helper block (ring colours changed).
m = re.search(r"/\*\*\n \* Example prompts.*?\n\}\n", s, re.S)
if not m:
    print("   ERROR: helper block not found"); sys.exit(2)
s = s[:m.start()] + open(helpers).read() + s[m.end():]

# Replace the Ask block — mascot column, label beneath.
start = s.find('        <div className="hero-ask">')
if start == -1:
    print("   ERROR: hero-ask not found"); sys.exit(2)
end = s.find('        </div>\n\n        {bhaiError', start)
if end == -1:
    end = s.find('        {bhaiError', start)
    if end == -1:
        print("   ERROR: could not find the end of the ask block"); sys.exit(2)
else:
    end += len('        </div>\n')
s = s[:start] + open(ask).read() + s[end:]

open(path, "w").write(s)
print("   ask block and helpers replaced")
PLANBHAI_EOF

python3 /tmp/pb_details.py "$F" /tmp/pb_ask2.jsx /tmp/pb_helpers2.jsx
RC=$?
rm -f /tmp/pb_details.py /tmp/pb_ask2.jsx /tmp/pb_helpers2.jsx
if [ "$RC" != "0" ]; then
  cp "$F.bakdetails" "$F"
  echo "   reverted — no changes made"
  exit 1
fi
echo

echo "2. Styles"
cp src/styles.css src/styles.css.bakdetails
python3 - src/styles.css << 'PY_EOF'
import sys
p = sys.argv[1]
s = open(p).read()
i = s.find("\n/* ---------- Home hero ---------- */")
if i == -1:
    print("   ERROR: hero style block not found"); sys.exit(2)
open(p, "w").write(s[:i])
PY_EOF
[ $? -ne 0 ] && { cp src/styles.css.bakdetails src/styles.css; exit 1; }
cat >> src/styles.css << 'PLANBHAI_EOF'

/* ---------- Home hero ---------- */

.hero-date {
  font-size: 11px; font-weight: 500; letter-spacing: 0.09em;
  text-transform: uppercase; opacity: 0.6;
}
.hero-name { font-size: 24px; font-weight: 500; margin-top: 4px; }

.hero-status { display: flex; align-items: center; gap: 16px; margin-top: 18px; }

/* conic-gradient, so no SVG and no dependency */
.hero-ring {
  width: 56px; height: 56px; border-radius: 50%; flex-shrink: 0;
  display: flex; align-items: center; justify-content: center;
}
.hero-ring-inner {
  width: 42px; height: 42px; border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  font-size: 15px; font-weight: 500;
  /* Matches the hero card, so the ring reads as a ring rather than a disc. */
  background: var(--hero-bg, #141527);
}
.hero-verdict { font-size: 15px; font-weight: 500; line-height: 1.35; }
.hero-counts { font-size: 12px; opacity: 0.6; margin-top: 3px; }

.hero-divider {
  height: 1px; background: rgba(255,255,255,0.12); margin: 18px 0;
}

.hero-ask { display: flex; align-items: flex-start; gap: 16px; }
/* Image above the name, so the mascot is introduced rather than labelled. */
.hero-bhai-col {
  display: flex; flex-direction: column; align-items: center;
  gap: 6px; flex-shrink: 0; width: 64px;
}
/* Bhai sits beside the input so he reads as the person you are asking,
   rather than a logo in the corner you stopped noticing. */
.hero-bhai {
  width: 56px; height: 56px; border-radius: 50%;
  object-fit: cover; object-position: 35% center;
  background: rgba(255,255,255,0.08);
}
.hero-ask-label {
  font-size: 13px; font-weight: 600; opacity: 0.75;
  /* NOT uppercase. text-transform destroyed the lowercase h in "BhAI", which
     is the one thing about the name that has to survive. */
}
.hero-input {
  flex: 1; min-width: 220px; padding: 11px 14px; border-radius: 8px;
  border: none; background: rgba(255,255,255,0.10);
  color: white; font-size: 13px;
}
.hero-input::placeholder { color: rgba(255,255,255,0.40); }

.hero-try { margin-top: 12px; font-size: 12px; opacity: 0.6; }
/* The hero needs a floor. Without it the next section butts straight up
   against the example links. */
.hero-card { padding-bottom: 26px; }
.hero-card + * { margin-top: 20px; }
.hero-try-sep { opacity: 0.5; }
.hero-try-link {
  background: none; border: none; padding: 0 0 0 4px;
  font-size: 12px; color: #5DCAA5; cursor: pointer; text-decoration: none;
}
.hero-try-link:hover { text-decoration: underline; }

@media (max-width: 560px) {
  .hero-ask { flex-direction: column; gap: 12px; }
  .hero-bhai { width: 44px; height: 44px; }
}
PLANBHAI_EOF
echo "   styles replaced"
grep -q "hero-bhai-col" src/styles.css && echo "   ok   mascot column"
grep -q "hero-card + \*" src/styles.css && echo "   ok   spacing below the hero"
echo

echo "3. Building"
if [ -d node_modules ]; then
  npm run build 2>&1 | grep -E "error|✓ built" | head -8
else
  echo "   node_modules missing"
fi
echo

echo "=========================================="
echo "  Revert:"
echo "     cp web/$F.bakdetails web/$F"
echo "     cp web/src/styles.css.bakdetails web/src/styles.css"
echo "=========================================="

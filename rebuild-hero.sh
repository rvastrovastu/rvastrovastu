#!/usr/bin/env bash
#
# Rebuilds the home hero.
#
# WHAT CHANGES
#   - Logo drops from 90px and MOVES beside the Ask BhAI input, where the chef
#     reads as the person you are asking rather than branding in the corner.
#   - The readiness ring, verdict and day counts move INTO the hero. Nothing on
#     the home page previously answered "is my day under control" — the score,
#     the sentence and the counts are the five-second read the product is built
#     around, and it belongs above the fold.
#   - Counts become one scannable line, not a checklist. The timeline below is
#     already a list.
#   - Six sentence-long example chips become three short links. "A dinner party"
#     scans; "Saanvi's birthday party for 20 kids next Friday" was a paragraph
#     pretending to be a button. Tapping still fills the FULL prompt.
#   - Label reads "Ask BhAI." to match the brand.
#
# The Dashboard now also fetches the Brief, because the ring and counts come
# from it. Wrapped in .catch so a Brief failure cannot take down the home page.
#
# Only web/src/pages/Dashboard.jsx and styles.css change.
#
# Usage:
#   bash ~/Downloads/rebuild-hero.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT/web" 2>/dev/null || { echo "ERROR: no web/ under $ROOT"; exit 1; }
F="src/pages/Dashboard.jsx"
[ -f "$F" ] || { echo "ERROR: $F not found"; exit 1; }

echo "PlanBhai — home hero"
echo

echo "1. Checking"
grep -q "fetchDayBrief" src/api.js \
  && echo "   ok   api.fetchDayBrief exists" \
  || { echo "   MISSING api.fetchDayBrief — run install-web-brief.sh first"; exit 1; }
[ -f public/logo.png ] && echo "   ok   public/logo.png" \
  || echo "   warn public/logo.png not found — Bhai will render blank"
echo

echo "2. Patching"
cp "$F" "$F.bakhero"
cat > /tmp/pb_top.jsx << 'PLANBHAI_EOF'
      <div className="hero-card">
        <div className="hero-date">{today}</div>
        <div className="hero-name">{greeting}, {user?.name?.split(' ')[0] || 'there'}</div>

        {brief?.readiness && (
          <div className="hero-status">
            <div
              className="hero-ring"
              style={{
                background: `conic-gradient(${ringColor(brief.readiness.score)} ${brief.readiness.score * 3.6}deg, rgba(255,255,255,0.12) 0deg)`,
              }}
            >
              <div className="hero-ring-inner">{brief.readiness.score}</div>
            </div>
            <div style={{ minWidth: 0 }}>
              <div className="hero-verdict">
                {brief.readiness.score >= 80 ? 'Everything fits.' : brief.greeting?.line || brief.readiness.label}
              </div>
              {heroCounts(brief) && <div className="hero-counts">{heroCounts(brief)}</div>}
            </div>
          </div>
        )}

        <div className="hero-divider" />
PLANBHAI_EOF
cat > /tmp/pb_ask.jsx << 'PLANBHAI_EOF'
        <div className="hero-ask">
          <img src="/logo.png" alt="" className="hero-bhai" />

          <div style={{ flex: 1, minWidth: 0 }}>
            <div className="hero-ask-label">Ask BhAI.</div>

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
cat > /tmp/pb_helpers.jsx << 'PLANBHAI_EOF'
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

/** Matches the ring on the Brief, so the same score reads the same everywhere. */
function ringColor(score) {
  if (score >= 80) return '#1D9E75';
  if (score >= 60) return '#38BDF8';
  if (score >= 40) return '#D97706';
  return '#E11D48';
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
cat > /tmp/pb_hero_patch.py << 'PLANBHAI_EOF'
import sys
path, top, ask, helpers = sys.argv[1:5]
s = open(path).read()

if 'hero-status' in s:
    print("   already applied"); sys.exit(3)

# 1. helpers above the component
anchor = "export default function Dashboard() {"
if anchor not in s:
    print("   ERROR: Dashboard component not found"); sys.exit(2)

# The old flat example list is superseded by [label, prompt] pairs.
import re
s = re.sub(r"const BHAI_EXAMPLES = \[[^\]]*\];\n", "", s)
s = s.replace(anchor, open(helpers).read() + "\n" + anchor, 1)

# 2. brief state + fetch
old_state = "  const [bhaiPrompt, setBhaiPrompt] = useState('');"
if old_state not in s:
    print("   ERROR: bhaiPrompt state not found"); sys.exit(2)
s = s.replace(old_state,
    "  const [brief, setBrief] = useState(null);\n" + old_state, 1)

# Fetch the brief alongside everything else — the ring and counts come from it.
old_fetch = "          api.fetchAppData('habits').catch(() => null),"
if old_fetch not in s:
    print("   ERROR: habits fetch not found"); sys.exit(2)
s = s.replace(old_fetch,
    old_fetch + "\n          scopeId ? api.fetchDayBrief(scopeId, Intl.DateTimeFormat().resolvedOptions().timeZone).catch(() => null) : Promise.resolve(null),", 1)

old_dest = "        const [habitsRes, choresRes, mealRes, morningRes, eveningRes, eventsRes, menuRes] = await Promise.all(["
if old_dest not in s:
    print("   ERROR: destructure not found"); sys.exit(2)
s = s.replace(old_dest,
    "        const [habitsRes, briefRes, choresRes, mealRes, morningRes, eveningRes, eventsRes, menuRes] = await Promise.all([", 1)

old_set = "          setHabits(habitsRes?.data || []);"
s = s.replace(old_set, old_set + "\n          setBrief(briefRes || null);", 1)

# 3. hero top
old_top = """      <div className="hero-card">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
          <div>
            <div className="hero-greeting">{greeting} · {today}</div>
            <div className="hero-name" style={{ marginBottom: 20 }}>Welcome, {user?.name || 'there'}</div>
          </div>
          <img src="/logo.png" alt="" style={{ width: 90, height: 90, borderRadius: 18, flexShrink: 0 }} />
        </div>
"""
if old_top not in s:
    print("   ERROR: hero top is not in the expected shape"); sys.exit(2)
s = s.replace(old_top, open(top).read(), 1)

# 4. the Ask block — from the form open to its close
start = s.find('        <form onSubmit={handleBhaiSubmit}')
if start == -1:
    print("   ERROR: form not found"); sys.exit(2)
end = s.find('        </form>', start)
if end == -1:
    print("   ERROR: form close not found"); sys.exit(2)
s = s[:start] + open(ask).read() + s[end + len('        </form>\n'):]

open(path, "w").write(s)
print("   hero rebuilt")
PLANBHAI_EOF

python3 /tmp/pb_hero_patch.py "$F" /tmp/pb_top.jsx /tmp/pb_ask.jsx /tmp/pb_helpers.jsx
RC=$?
rm -f /tmp/pb_hero_patch.py /tmp/pb_top.jsx /tmp/pb_ask.jsx /tmp/pb_helpers.jsx
if [ "$RC" = "3" ]; then
  echo "   nothing to do"
elif [ "$RC" != "0" ]; then
  cp "$F.bakhero" "$F"
  echo "   reverted — no changes made"
  exit 1
fi
echo

echo "3. Styles"
if grep -q "^.hero-status" src/styles.css; then
  echo "   already appended"
else
  cp src/styles.css src/styles.css.bakhero
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
.hero-verdict { font-size: 15px; font-weight: 500; }
.hero-counts { font-size: 12px; opacity: 0.6; margin-top: 3px; }

.hero-divider {
  height: 1px; background: rgba(255,255,255,0.12); margin: 18px 0;
}

.hero-ask { display: flex; align-items: flex-start; gap: 14px; }
/* Bhai sits beside the input so he reads as the person you are asking,
   rather than a logo in the corner you stopped noticing. */
.hero-bhai {
  width: 56px; height: 56px; border-radius: 50%; flex-shrink: 0;
  object-fit: cover; background: rgba(255,255,255,0.08);
}
.hero-ask-label {
  font-size: 11px; font-weight: 500; letter-spacing: 0.09em;
  text-transform: uppercase; opacity: 0.6; margin-bottom: 8px;
}
.hero-input {
  flex: 1; min-width: 220px; padding: 11px 14px; border-radius: 8px;
  border: none; background: rgba(255,255,255,0.10);
  color: white; font-size: 13px;
}
.hero-input::placeholder { color: rgba(255,255,255,0.40); }

.hero-try { margin-top: 10px; font-size: 12px; opacity: 0.6; }
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
  echo "   appended"
fi
echo

echo "4. Building"
if [ -d node_modules ]; then
  npm run build 2>&1 | grep -E "error|✓ built" | head -8
else
  echo "   node_modules missing"
fi
echo

echo "=========================================="
echo "  npm run dev, then the home page."
echo
echo "  If Bhai looks oddly cropped, the circle is centring on the middle of a"
echo "  square image. Add object-position to .hero-bhai in styles.css to shift"
echo "  it — the chef sits left of centre in the mark."
echo
echo "  Revert:"
echo "     cp web/$F.bakhero web/$F"
echo "     cp web/src/styles.css.bakhero web/src/styles.css"
echo "=========================================="

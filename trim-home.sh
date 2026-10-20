#!/usr/bin/env bash
#
# Hero alignment, and trimming the home page.
#
# ALIGNMENT
#   The two columns are now bottom-aligned, so "Ask BhAI." and the "Try …" line
#   sit on one baseline. Doing it this way rather than with hand-tuned offsets
#   means it survives the Try line wrapping on a narrow screen.
#
#   The ask row also gains space under the divider — the input was sitting
#   directly on it.
#
# REMOVED
#   Quick Add. Every destination those emoji buttons reach is already in the
#   Brief's sections below, and a grid of shortcuts above a real day summary is
#   noise competing with it.
#
#   Your Households. Switching scope belongs on the household screen, not on a
#   page about today. It is still reachable from the nav.
#
# Only Dashboard.jsx and styles.css change.
#
# Usage:
#   bash ~/Downloads/trim-home.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT/web" 2>/dev/null || { echo "ERROR: no web/ under $ROOT"; exit 1; }
D="src/pages/Dashboard.jsx"
[ -f "$D" ] || { echo "ERROR: $D not found"; exit 1; }

echo "PlanBhai — hero alignment + trim"
echo

echo "1. Dashboard"
cp "$D" "$D.baktrim"
cat > /tmp/pb_trim.py << 'PLANBHAI_EOF'
import sys
path = sys.argv[1]
s = open(path).read()
orig = s

# Quick Add — the Brief's sections already carry every destination these
# shortcut to, and a grid of emoji buttons above a real day summary is noise.
qa = s.find("          <h2 style={{ fontSize: 13, marginBottom: 12, textTransform: 'uppercase', letterSpacing: '0.06em', color: 'var(--text-secondary)' }}>Quick Add</h2>")
if qa != -1:
    nxt = s.find("          {/* The Brief replaces", qa)
    if nxt == -1:
        nxt = s.find("          <Brief embedded />", qa)
    if nxt == -1:
        print("   ERROR: could not bound Quick Add"); sys.exit(2)
    s = s[:qa] + s[nxt:]
    print("   removed Quick Add")

# Your Households — switching scope belongs in the household screen, not on a
# page about today.
yh = s.find("          <h2 style={{ fontSize: 13, marginBottom: 12, textTransform: 'uppercase', letterSpacing: '0.06em', color: 'var(--text-secondary)' }}>Your Households</h2>")
if yh != -1:
    end = s.find("        </>", yh)
    if end == -1:
        print("   ERROR: could not bound Your Households"); sys.exit(2)
    s = s[:yh] + s[end:]
    print("   removed Your Households")

if s == orig:
    print("   nothing matched — already trimmed?"); sys.exit(3)

open(path, "w").write(s)
PLANBHAI_EOF
python3 /tmp/pb_trim.py "$D"
RC=$?
rm -f /tmp/pb_trim.py
if [ "$RC" = "3" ]; then
  echo "   nothing to remove"
elif [ "$RC" != "0" ]; then
  cp "$D.baktrim" "$D"
  echo "   reverted — no changes made"
  exit 1
fi
echo

echo "2. Styles"
cp src/styles.css src/styles.css.baktrim
python3 - src/styles.css << 'PY_EOF'
import sys
p = sys.argv[1]
s = open(p).read()
i = s.find("\n/* ---------- Home hero ---------- */")
if i == -1:
    print("   ERROR: hero style block not found"); sys.exit(2)
open(p, "w").write(s[:i])
PY_EOF
[ $? -ne 0 ] && { cp src/styles.css.baktrim src/styles.css; exit 1; }
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

.hero-ask {
  display: flex; align-items: flex-end; gap: 16px;
  /* Breathing room under the divider — the input was sitting on it. */
  margin-top: 8px;
}
/* Image above the name, so the mascot is introduced rather than labelled. */
.hero-bhai-col {
  display: flex; flex-direction: column; align-items: center;
  gap: 8px; flex-shrink: 0; width: 72px;
}
/* Bhai sits beside the input so he reads as the person you are asking,
   rather than a logo in the corner you stopped noticing. */
.hero-bhai {
  width: 56px; height: 56px; border-radius: 50%;
  object-fit: cover; object-position: 35% center;
  background: rgba(255,255,255,0.08);
}
.hero-ask-label {
  font-size: 13px; font-weight: 600; opacity: 0.85; white-space: nowrap;
  /* NOT uppercase. text-transform destroyed the lowercase h in "BhAI", which
     is the one thing about the name that has to survive. */
}
.hero-input {
  flex: 1; min-width: 220px; padding: 11px 14px; border-radius: 8px;
  border: none; background: rgba(255,255,255,0.10);
  color: white; font-size: 13px;
}
.hero-input::placeholder { color: rgba(255,255,255,0.40); }

.hero-try { margin-top: 8px; font-size: 13px; opacity: 0.6; }
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

/* My Day row, on the Brief */
.brief-myday {
  display: flex; align-items: center; gap: 13px;
  padding: 14px 16px; text-decoration: none; color: inherit;
}
.brief-myday:hover { border-color: var(--sage); }
.brief-myday-icon { font-size: 20px; }
.brief-myday-text { display: flex; flex-direction: column; flex: 1; min-width: 0; }
.brief-myday-text strong { font-size: 14px; color: var(--text-primary); }
.brief-myday-text small { font-size: 12px; color: var(--text-tertiary); margin-top: 2px; }
.brief-myday-chev { font-size: 20px; color: var(--text-tertiary); }
PLANBHAI_EOF
grep -q "align-items: flex-end" src/styles.css && echo "   ok   columns bottom-aligned"
echo

echo "3. Checking for orphans"
for name in quickAdds timeline suggestion summaryText households; do
  n=$(grep -c "\b$name\b" "$D" || true)
  echo "   $name: $n reference(s)"
done
echo "   (a lone declaration is harmless; the build will flag a real problem)"
echo

echo "4. Building"
if [ -d node_modules ]; then
  npm run build 2>&1 | grep -E "ERROR|error during|✓ built" | head -8
else
  echo "   node_modules missing"
fi
echo

echo "=========================================="
echo "  Revert:"
echo "     cp web/$D.baktrim web/$D"
echo "     cp web/src/styles.css.baktrim web/src/styles.css"
echo "=========================================="

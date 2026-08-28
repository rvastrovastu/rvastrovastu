#!/usr/bin/env bash
#
# Two corrections.
#
#   1. THE SCORE APPEARED TWICE
#      The hero showed a 79 ring, and Today's Focus directly below showed the
#      same 79 with its breakdown. One page stating a number twice reads as two
#      numbers that happen to agree. The ring goes; the verdict sentence and the
#      counts line stay, because those are the five-second read.
#
#   2. THE EM-DASH
#      "…dinner's planned — one thing left to sort." becomes "…dinner's
#      planned, one thing left to sort."
#
#      This is SERVER-SIDE — the phrasing is built in builders.service.js, not
#      formatted on the client, so it needs a Render deploy to take effect on
#      both platforms.
#
# NOTE: ringColor() is now unused in Dashboard.jsx. Harmless, and left in place
# in case the ring returns somewhere.
#
# Usage:
#   bash ~/Downloads/fix-hero-dupes.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }

echo "PlanBhai — de-duplicating the score"
echo

echo "1. Backend greeting"
B=backend/services/daybrief/builders.service.js
[ -f "$B" ] || { echo "   ERROR: $B not found"; exit 1; }
cp "$B" "$B.bakdupe"
cat > "$B" << 'PLANBHAI_EOF'
const { localTimeIn, localHourIn, relativeDayLabel } = require('./tz.util');

const capitalize = (s) => (s ? s.charAt(0).toUpperCase() + s.slice(1) : s);



/**
 * Merges every time-anchored thing in the day into one sorted list. Pure.
 * Calendar events, habits, meals and tasks all land in the same visual river —
 * that's what makes it read as "your day" rather than four separate widgets.
 */
function buildTimeline(ctx) {
  const { tz } = ctx;
  const rows = [];

  for (const e of ctx.calendar?.events || []) {
    if (e.allDay) continue;
    rows.push({
      start: localTimeIn(new Date(e.startUtc), tz),
      end: e.endUtc ? localTimeIn(new Date(e.endUtc), tz) : null,
      title: e.title,
      kind: 'event',
      source: 'calendar',
      sourceId: String(e.externalId || e._id || ''),
      icon: '📅',
      _sortUtc: new Date(e.startUtc).getTime(),
    });
  }

  for (const h of ctx.habits?.active || []) {
    if (!h.windowStartUtc) continue;
    rows.push({
      start: localTimeIn(new Date(h.windowStartUtc), tz),
      end: h.windowEndUtc ? localTimeIn(new Date(h.windowEndUtc), tz) : null,
      title: h.title,
      kind: 'habit',
      source: 'planbhai',
      sourceId: String(h.id || h._id || ''),
      icon: h.icon || '🔁',
      _sortUtc: new Date(h.windowStartUtc).getTime(),
    });
  }

  for (const m of ctx.meals?.slots || []) {
    if (!m.timeUtc) continue;
    rows.push({
      start: localTimeIn(new Date(m.timeUtc), tz),
      end: null,
      title: m.title,
      kind: 'meal',
      source: 'planbhai',
      sourceId: String(m.id || ''),
      icon: '🍽',
      _sortUtc: new Date(m.timeUtc).getTime(),
    });
  }

  for (const t of ctx.tasks?.scheduled || []) {
    if (!t.dueUtc) continue;
    rows.push({
      start: localTimeIn(new Date(t.dueUtc), tz),
      end: null,
      title: t.title,
      kind: 'task',
      source: 'planbhai',
      sourceId: String(t.id || t._id || ''),
      icon: '✓',
      _sortUtc: new Date(t.dueUtc).getTime(),
    });
  }

  return rows.sort((a, b) => a._sortUtc - b._sortUtc).map(({ _sortUtc, ...r }) => r);
}

// ---------------------------------------------------------------------------

/**
 * Greeting. NO PERSONAL NAMES — this document is shared across the household, so
 * the client composes `Good ${timeOfDay}, ${session.firstName}` locally.
 *
 * The line leads with what IS handled. The whole premise is "your Bhai already
 * planned your day", so opening with a raw diagnostic ("4 things with nobody
 * assigned") undercuts the product before the user has read anything else. Same
 * data, framed as reassurance, with a gentle nudge only when the day genuinely
 * needs attention.
 */

/**
 * Short positive clause per domain, with the score it must reach to be claimed.
 *
 * Thresholds are per-domain because the scales mean different things. Meals score
 * 60 when a dinner is planned but pantry coverage is unknown — that IS good news
 * and worth saying. Family at 70 means chores are still open and unassigned, so
 * claiming "everyone knows their part" there would be a cheerful lie, and a
 * summary people catch lying once stops getting read.
 */
const POSITIVE = {
  calendar: { at: 90, say: "your schedule's clear" },
  meals: { at: 60, say: "dinner's planned" },
  groceries: { at: 85, say: 'groceries are covered' },
  family: { at: 95, say: 'everyone knows their part' },
  habits: { at: 85, say: 'habits are on track' },
  finance: { at: 90, say: 'no bills need you' },
};

function buildGreeting(ctx, readiness) {
  const hour = localHourIn(new Date(ctx.nowUtc), ctx.tz);
  const timeOfDay =
    hour < 12 ? 'morning' : hour < 17 ? 'afternoon' : hour < 21 ? 'evening' : 'night';

  if (!readiness) {
    return { timeOfDay, line: "Let's get your day set up.", generatedBy: 'rule' };
  }

  const good = readiness.breakdown
    .filter((b) => b.applicable && POSITIVE[b.domain] && b.score >= POSITIVE[b.domain].at)
    .sort((a, b) => b.score - a.score)
    .slice(0, 2)
    .map((b) => POSITIVE[b.domain].say);

  const s = readiness.score;
  let line;

  if (s >= 95) {
    line = "Everything's handled. Nothing needs you right now.";
  } else if (good.length) {
    const praise = good.length === 2 ? `${good[0]} and ${good[1]}` : good[0];
    line = s >= 80 ? `${praise}.` : `${praise}, one thing left to sort.`;
  } else if (s >= 60) {
    line = 'Your day is mostly set.';
  } else {
    line = "Let's get today sorted.";
  }

  return { timeOfDay, line: capitalize(line).slice(0, 90), generatedBy: 'rule' };
}

// ---------------------------------------------------------------------------

/** The 5-second scan chips. Client renders the top N by priority. */
function buildSignals(ctx) {
  const signals = [];

  // Chop on a word boundary, not mid-word: "Homemade Pizza with Mozzarella,
  // Pepperon" reads like a bug rather than a summary.
  const fit = (text, max = 40) => {
    const s = String(text).trim();
    if (s.length <= max) return s;
    const cut = s.slice(0, max - 1);
    const sp = cut.lastIndexOf(' ');
    return (sp > max * 0.5 ? cut.slice(0, sp) : cut).replace(/[,;:]$/, '') + '…';
  };

  const push = (icon, text, kind, priority) =>
    text && signals.push({ icon, text: fit(text), kind, priority });

  if (ctx.weather?.summary) {
    push(ctx.weather.icon || '☀️', ctx.weather.summary, 'weather', 30);
  }

  const nextEvent = (ctx.calendar?.events || [])
    .filter((e) => !e.allDay && new Date(e.startUtc) > new Date(ctx.nowUtc))
    .sort((a, b) => new Date(a.startUtc) - new Date(b.startUtc))[0];
  if (nextEvent) {
    push('📅', `${nextEvent.title} at ${localTimeIn(new Date(nextEvent.startUtc), ctx.tz)}`, 'event', 90);
  }

  for (const b of ctx.birthdays || []) {
    const nm = String(b.name || '').trim();
    // "Mom's Birthday" already carries the possessive — don't produce "Mom's's".
    const label = !nm
      ? `Birthday ${b.relative}`
      : /['\u2019]s$/.test(nm)
        ? `${nm} birthday ${b.relative}`
        : `${nm}'s birthday ${b.relative}`;
    push('🎂', label, 'birthday', 70);
  }

  if (ctx.habits?.total > 0) {
    push(
      '🔁',
      `${ctx.habits.completedToday}/${ctx.habits.total} habits done`,
      'habit',
      45
    );
  }

  if (ctx.habits?.longestStreak > 2) {
    push('🔥', `Habit streak ${ctx.habits.longestStreak} days`, 'streak', 40);
  }

  const openChores = (ctx.family?.obligations || []).length;
  if (openChores > 0) {
    push('🧹', `${openChores} chore${openChores > 1 ? 's' : ''} open`, 'chore', 65);
  }

  const dueSoon = (ctx.finance?.bills || []).filter((b) => !b.paid);
  if (dueSoon.length) {
    push('💰', `${dueSoon.length} bill${dueSoon.length > 1 ? 's' : ''} due soon`, 'bill', 60);
  }

  // Grocery items are a shopping list, not a shortage — there is no `checked`
  // field and pantry is empty, so this is "to buy", not "missing".
  if (ctx.groceries?.itemCount > 0) {
    push('🛒', `${ctx.groceries.itemCount} items to buy`, 'grocery', 50);
  }

  const notes = (ctx.notes || []).length;
  if (notes > 0) {
    push('📝', `${notes} household note${notes > 1 ? 's' : ''}`, 'note', 35);
  }

  if (ctx.meals?.planned?.title) {
    push('🍽', `${ctx.meals.planned.title} tonight`, 'meal', 55);
  }

  return signals.sort((a, b) => b.priority - a.priority);
}

// ---------------------------------------------------------------------------

/**
 * empty / sparse / rich.
 *
 * Weather is excluded deliberately: it's available for every household on earth,
 * so counting it would make a brand-new user look "sparse" when we actually know
 * nothing about them. Faking richness is worse than asking for setup.
 *
 * A null readiness means no domain applies — nothing plannable is known — so the
 * state is empty no matter how many chips we scraped together. Otherwise the
 * client is told to render a score ring with no score in it, which is how you get
 * a blank circle on the most important screen in the app.
 */
function deriveState(signals, ctx, readiness) {
  if (!readiness) return 'empty';

  const real = signals.filter((s) => s.kind !== 'weather').length;
  const hasTimeline =
    (ctx.calendar?.events?.length || 0) +
      (ctx.habits?.active?.length || 0) +
      (ctx.meals?.slots?.length || 0) >
    0;

  if (real === 0 && !hasTimeline) return 'empty';
  if (real <= 3) return 'sparse';
  return 'rich';
}

// ---------------------------------------------------------------------------

/** 'Tomorrow — Dentist' rows for the Upcoming section. */
function buildUpcoming(ctx) {
  return (ctx.upcoming || [])
    .slice(0, 6)
    .map((u) => ({
      day: relativeDayLabel(ctx.localDate, u.date, ctx.tz),
      date: u.date,
      title: u.title,
      kind: u.kind || 'event',
      icon: u.icon || '📌',
    }));
}

module.exports = { buildTimeline, buildGreeting, buildSignals, deriveState, buildUpcoming };
PLANBHAI_EOF
node --check "$B" || { echo "   PARSE FAILED — reverting"; cp "$B.bakdupe" "$B"; exit 1; }
grep -q ", one thing left to sort" "$B" && echo "   ok   comma, not em-dash"
echo

echo "2. Web hero"
D=web/src/pages/Dashboard.jsx
[ -f "$D" ] || { echo "   ERROR: $D not found"; exit 1; }
cp "$D" "$D.bakdupe"
cat > /tmp/pb_top2.jsx << 'PLANBHAI_EOF'
      <div className="hero-card">
        <div className="hero-date">{today}</div>
        <div className="hero-name">{greeting}, {user?.name?.split(' ')[0] || 'there'}</div>

        {/* No ring here. Today's Focus below shows the same score with its
            breakdown, and one page saying 79% twice reads as two numbers that
            happen to agree. The verdict and counts stay, because those are the
            five-second read. */}
        {brief?.readiness && (
          <div className="hero-status">
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
cat > /tmp/pb_dupe.py << 'PLANBHAI_EOF'
import sys
path, top = sys.argv[1:3]
s = open(path).read()

start = s.find('      <div className="hero-card">')
if start == -1:
    print("   ERROR: hero-card not found"); sys.exit(2)
end = s.find('        <div className="hero-divider" />', start)
if end == -1:
    print("   ERROR: hero-divider not found"); sys.exit(2)
end += len('        <div className="hero-divider" />\n')

s = s[:start] + open(top).read() + s[end:]
open(path, "w").write(s)

if 'hero-ring' in s:
    print("   WARNING: hero-ring still referenced")
else:
    print("   ring removed from the hero")
PLANBHAI_EOF
python3 /tmp/pb_dupe.py "$D" /tmp/pb_top2.jsx
RC=$?
rm -f /tmp/pb_dupe.py /tmp/pb_top2.jsx
if [ "$RC" != "0" ]; then
  cp "$D.bakdupe" "$D"
  cp "$B.bakdupe" "$B"
  echo "   reverted both — no changes made"
  exit 1
fi
echo

echo "3. Styles"
cp web/src/styles.css web/src/styles.css.bakdupe
python3 - web/src/styles.css << 'PY_EOF'
import sys
p = sys.argv[1]
s = open(p).read()
i = s.find("\n/* ---------- Home hero ---------- */")
if i == -1:
    print("   ERROR: hero style block not found"); sys.exit(2)
open(p, "w").write(s[:i])
PY_EOF
[ $? -ne 0 ] && { cp web/src/styles.css.bakdupe web/src/styles.css; exit 1; }
cat >> web/src/styles.css << 'PLANBHAI_EOF'

/* ---------- Home hero ---------- */

.hero-date {
  font-size: 11px; font-weight: 500; letter-spacing: 0.09em;
  text-transform: uppercase; opacity: 0.6;
}
.hero-name { font-size: 24px; font-weight: 500; margin-top: 4px; }

.hero-status { margin-top: 16px; }

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

/* Embedded in the Dashboard, the Brief drops its own width cap and padding so
   its cards align exactly with the hero above. Standalone it keeps the cap,
   because 780px is a comfortable reading width when nothing else is on the
   page to line up with. */
.brief-embedded {
  max-width: none;
  margin: 0;
  padding: 0;
}

/* A CTA that performs an action is a button, not a label on a link. */
.brief-cta-btn {
  border: none; cursor: pointer; font-family: inherit;
}
.brief-cta-btn:hover { background: var(--sage); color: var(--bg-card); }
.brief-cta-btn:disabled { opacity: 0.6; cursor: default; }
PLANBHAI_EOF
echo "   styles updated"
echo

echo "4. Clearing the cached brief"
cd backend
cat > ./.pb_bust.js << 'BUST_EOF'
require("dotenv").config();
const m = require("mongoose");
(async () => {
  await m.connect(process.env.MONGODB_URI);
  const r = await require("./models/DayBrief").deleteMany({});
  console.log("   cleared " + r.deletedCount + " — the old wording was cached");
  await m.disconnect();
})().catch(e => { console.error("   " + e.message); process.exit(0); });
BUST_EOF
node ./.pb_bust.js
rm -f ./.pb_bust.js
cd ..
echo

echo "5. Building web"
(cd web && npm run build 2>&1 | grep -E "ERROR|error during|✓ built" | head -6)
echo

echo "=========================================="
echo "  The greeting change is BACKEND, so it needs Render:"
echo "     git add -A && git commit -m 'One score per page; comma not em-dash' && git push"
echo "     (Render: Manual Deploy)   then   cd web && vercel --prod"
echo
echo "  Revert:"
echo "     cp $B.bakdupe $B"
echo "     cp $D.bakdupe $D"
echo "     cp web/src/styles.css.bakdupe web/src/styles.css"
echo "=========================================="

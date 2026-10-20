#!/usr/bin/env bash
#
# Softens the calendar overlap penalty from 25 to 10.
#
# Two events at the same hour is a normal Friday — a soccer run and a birthday
# both at 6 PM is a real day, not a broken one. At 25 the score read 69% on a
# day that was genuinely fine, and a score that punishes ordinary life stops
# being believed.
#
# On your current data: calendar 75 -> 90, overall 69% -> 75%.
#
# Only readiness.service.js changes.
#
# Usage:
#   bash ~/Downloads/soften-overlap.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
F="backend/services/daybrief/readiness.service.js"
[ -f "$F" ] || { echo "ERROR: $F not found"; exit 1; }

echo "PlanBhai — softening the overlap penalty"
echo

cp "$F" "$F.bakoverlap"
cat > "$F" << 'PLANBHAI_EOF'
/**
 * Readiness scoring.
 *
 * Readiness measures how much of today is PLANNED AND COVERED — not how much is
 * done. That distinction is the whole point: a completion score reads ~0% at 7 AM,
 * which is the exact anxiety the dashboard exists to remove. Readiness legitimately
 * reads 92% before the user has done anything, because the day is handled.
 *
 * Every function here is pure. No mongoose, no I/O, no Date.now() except what is
 * passed in. That is what makes the formula testable without Mongo fixtures.
 *
 * Expected context shape (built by loadContext, see daybrief.service.js):
 * {
 *   nowUtc: Date,
 *   calendar: { connected, events: [{ startUtc, endUtc, title, allDay,
 *                                     requiresEscort, assigneeId }] },
 *   meals:    { used, primarySlot, planned: { title, haveRatio|null, missing[] }|null },
 *   groceries:{ listExists, missingCount },
 *   family:   { memberCount, obligations: [{ title, assigneeId|null }] },
 *   habits:   { active: [{ id, title, windowEndUtc, completedAt|null }] },
 *   finance:  { tracked, bills: [{ title, dueDate:'YYYY-MM-DD', paid }] },
 *   localDate: 'YYYY-MM-DD'
 * }
 */

const BASE_WEIGHTS = {
  calendar: 0.25,
  meals: 0.2,
  groceries: 0.15,
  family: 0.15,
  habits: 0.15,
  finance: 0.1,
};

const clamp = (n, lo = 0, hi = 100) => Math.max(lo, Math.min(hi, n));

// ---------------------------------------------------------------------------
// Domain scorers. Each returns { applicable, score, reason }.
// ---------------------------------------------------------------------------

function scoreCalendar(cal = {}) {
  const events = (cal.events || []).filter((e) => !e.allDay);
  const applicable = Boolean(cal.connected) || events.length > 0;
  if (!applicable) return { applicable: false, score: 0, reason: '' };

  let score = 100;
  const reasons = [];

  const sorted = [...events].sort((a, b) => new Date(a.startUtc) - new Date(b.startUtc));

  // Overlaps
  let hasOverlap = false;
  for (let i = 1; i < sorted.length; i++) {
    if (new Date(sorted[i].startUtc) < new Date(sorted[i - 1].endUtc)) {
      hasOverlap = true;
      break;
    }
  }
  if (hasOverlap) {
    // 10, not 25. A genuine double-booking is worth flagging, but people
    // deliberately overlap things all the time — a soccer run and a birthday at
    // the same hour is a normal Friday, not a broken day. Penalising it heavily
    // made the score read low on days that were actually fine.
    score -= 10;
    reasons.push('two events overlap');
  }

  // Tight transitions (<15 min between back-to-back events), capped at -30
  let tight = 0;
  for (let i = 1; i < sorted.length; i++) {
    const gapMin = (new Date(sorted[i].startUtc) - new Date(sorted[i - 1].endUtc)) / 60000;
    if (gapMin >= 0 && gapMin < 15) tight++;
  }
  if (tight > 0) {
    score -= Math.min(30, tight * 15);
    reasons.push(`${tight} tight transition${tight > 1 ? 's' : ''}`);
  }

  // Escort-requiring events with nobody assigned
  const unassigned = events.filter((e) => e.requiresEscort && !e.assigneeId).length;
  if (unassigned > 0) {
    score -= 20;
    reasons.push(`${unassigned} pickup${unassigned > 1 ? 's' : ''} unassigned`);
  }

  // Overloaded day
  if (events.length > 5) {
    score -= 10;
    reasons.push(`${events.length} events today`);
  }

  return {
    applicable: true,
    score: clamp(score),
    reason: reasons.length ? capitalize(reasons.join(', ')) : 'Your schedule has room to breathe',
  };
}

function scoreMeals(meals = {}) {
  if (!meals.used) return { applicable: false, score: 0, reason: '' };

  const slot = meals.primarySlot || 'dinner';
  if (!meals.planned) {
    return { applicable: true, score: 0, reason: `No ${slot} planned yet` };
  }

  const { title, haveRatio } = meals.planned;

  if (haveRatio == null) {
    return { applicable: true, score: 60, reason: `${title} planned for ${slot}` };
  }

  const score = clamp(Math.round(60 + 40 * clamp(haveRatio, 0, 1)));
  const reason =
    haveRatio >= 1
      ? `${title} planned, everything on hand`
      : `${title} planned, ${Math.round((1 - haveRatio) * 100)}% of ingredients missing`;

  return { applicable: true, score, reason };
}

function scoreGroceries(groceries = {}) {
  if (!groceries.listExists) return { applicable: false, score: 0, reason: '' };

  const missing = groceries.missingCount || 0;
  if (missing === 0) {
    return { applicable: true, score: 100, reason: 'Nothing missing for today or tomorrow' };
  }

  return {
    applicable: true,
    score: clamp(100 - 12 * missing, 30, 100),
    reason: `${missing} item${missing > 1 ? 's' : ''} short for upcoming meals`,
  };
}

function scoreFamily(family = {}) {
  if ((family.memberCount || 0) <= 1) return { applicable: false, score: 0, reason: '' };

  const obligations = family.obligations || [];
  if (obligations.length === 0) {
    return { applicable: true, score: 100, reason: 'No handoffs needed today' };
  }

  const assigned = obligations.filter((o) => o.assigneeId).length;
  const ratio = assigned / obligations.length;

  // Only judge assignment if the household actually assigns things. Many
  // households keep a shared chore list nobody is individually named on — that's
  // a normal way to use the app, not a gap. Penalising it would peg the score
  // low forever, and a number that never moves stops meaning anything.
  const USES_ASSIGNMENT = ratio >= 0.5;

  if (!USES_ASSIGNMENT) {
    const done = family.choresDone || 0;
    const total = family.choresTotal || obligations.length;
    const doneRatio = total > 0 ? done / total : 1;
    return {
      applicable: true,
      // Never below 70: an open shared chore list is an ordinary state of
      // affairs, not something wrong with the day.
      score: clamp(Math.round(70 + 30 * doneRatio)),
      reason:
        obligations.length === 1
          ? '1 chore still open'
          : `${obligations.length} chores still open`,
    };
  }

  const score = clamp(Math.round(100 * ratio));
  const gap = obligations.length - assigned;

  return {
    applicable: true,
    score,
    reason:
      gap === 0
        ? 'Everyone knows their part today'
        : `${gap} thing${gap > 1 ? 's' : ''} with nobody assigned`,
  };
}

function scoreHabits(habits = {}, nowUtc) {
  const active = habits.active || [];
  if (active.length === 0) return { applicable: false, score: 0, reason: '' };

  const now = new Date(nowUtc);
  const missed = active.filter(
    (h) => !h.completedAt && h.windowEndUtc && new Date(h.windowEndUtc) < now
  ).length;

  const score = clamp(100 - 20 * missed);
  return {
    applicable: true,
    score,
    reason:
      missed === 0
        ? 'Habits on track'
        : `${missed} habit${missed > 1 ? 's' : ''} past its window`,
  };
}

function scoreFinance(finance = {}, localDate) {
  if (!finance.tracked) return { applicable: false, score: 0, reason: '' };

  const unpaid = (finance.bills || []).filter((b) => !b.paid);
  if (unpaid.length === 0) return { applicable: true, score: 100, reason: 'No bills pending' };

  // daysUntil is a plain date diff — bills are date-granular, not time-granular
  const daysUntil = (d) => Math.round((Date.parse(d) - Date.parse(localDate)) / 86400000);
  const soonest = Math.min(...unpaid.map((b) => daysUntil(b.dueDate)));

  if (soonest < 0) return { applicable: true, score: 0, reason: 'A bill is overdue' };
  if (soonest === 0) return { applicable: true, score: 20, reason: 'A bill is due today' };
  if (soonest === 1) return { applicable: true, score: 40, reason: 'A bill is due tomorrow' };
  if (soonest <= 3) return { applicable: true, score: 70, reason: `A bill is due in ${soonest} days` };
  return { applicable: true, score: 100, reason: 'Nothing due this week' };
}

// ---------------------------------------------------------------------------
// Composite
// ---------------------------------------------------------------------------

const LABELS = [
  [95, 'Everything is under control.'],
  [80, "You're in good shape today."],
  [60, 'A few things need you.'],
  [40, 'Today needs some attention.'],
  [0, "Let's get today sorted."],
];

function labelFor(score) {
  return LABELS.find(([floor]) => score >= floor)[1];
}

/**
 * @returns {{ score, label, breakdown, weakest }} or null when no domain applies
 *          (a brand-new household — callers should render the empty state, not a 0%).
 */
function computeReadiness(ctx) {
  const raw = {
    calendar: scoreCalendar(ctx.calendar),
    meals: scoreMeals(ctx.meals),
    groceries: scoreGroceries(ctx.groceries),
    family: scoreFamily(ctx.family),
    habits: scoreHabits(ctx.habits, ctx.nowUtc),
    finance: scoreFinance(ctx.finance, ctx.localDate),
  };

  const applicable = Object.entries(raw).filter(([, v]) => v.applicable);

  // No applicable domains means we know nothing about this household yet. Returning
  // 0% here would be a lie dressed as data — the empty state is the honest answer.
  if (applicable.length === 0) return null;

  const totalWeight = applicable.reduce((s, [d]) => s + BASE_WEIGHTS[d], 0);

  // Re-normalizing over applicable domains only is what stops a new user from being
  // punished for simply not tracking bills.
  const breakdown = Object.entries(raw).map(([domain, v]) => ({
    domain,
    score: v.score,
    weight: v.applicable ? BASE_WEIGHTS[domain] / totalWeight : 0,
    applicable: v.applicable,
    reason: v.reason,
  }));

  const score = Math.round(
    breakdown.filter((b) => b.applicable).reduce((s, b) => s + b.score * b.weight, 0)
  );

  const weakest = breakdown
    .filter((b) => b.applicable)
    .sort((a, b) => a.score - b.score)[0];

  return { score, label: labelFor(score), breakdown, weakest };
}

function capitalize(s) {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

module.exports = {
  computeReadiness,
  labelFor,
  BASE_WEIGHTS,
  // exported for unit tests
  _scorers: { scoreCalendar, scoreMeals, scoreGroceries, scoreFamily, scoreHabits, scoreFinance },
};
PLANBHAI_EOF
node --check "$F" || { echo "   PARSE FAILED — reverting"; cp "$F.bakoverlap" "$F"; exit 1; }
echo "   wrote + parses"
grep -q "score -= 10;" "$F" && echo "   penalty is now 10"
echo

echo "Clearing the cached brief"
cd backend
cat > ./.pb_bust.js << 'BUST_EOF'
require("dotenv").config();
const m = require("mongoose");
(async () => {
  await m.connect(process.env.MONGODB_URI);
  const r = await require("./models/DayBrief").deleteMany({});
  console.log("   cleared " + r.deletedCount + " cached brief(s)");
  await m.disconnect();
})().catch(e => { console.error("   " + e.message); process.exit(0); });
BUST_EOF
node ./.pb_bust.js
rm -f ./.pb_bust.js
cd ..
echo

echo "=========================================="
echo "  Deploy:"
echo "     git add -A && git commit -m 'Soften calendar overlap penalty to 10' && git push"
echo "  then Manual Deploy on Render."
echo "=========================================="

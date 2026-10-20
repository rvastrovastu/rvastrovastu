#!/usr/bin/env bash
#
# One calendar endpoint for both platforms.
#
# WHAT IT FIXES
#   web/src/pages/Calendar.jsx fetches `meal_plans` — a key with ZERO documents
#   in your database. The real key is `meal_plan`. So the meals loop iterates
#   nothing and meals have NEVER appeared on that calendar. No error, no
#   warning; the array was simply always empty.
#
#   It also ignores `events` (3 docs, Swift-epoch dates from iOS) and EventKit
#   entirely — so the device calendar you built the whole sync for has never
#   reached the web calendar.
#
#   And it dated meals as createdAt + index, which puts Monday's dinner on
#   whatever weekday the plan was generated. meal_plan is a RECURRING WEEKLY
#   TEMPLATE keyed "Monday".."Sunday"; mapping by weekday is what it means.
#
# THE ENDPOINT
#   GET /api/schedule/range?scopeId=&from=&to=&tz=
#
#   Merges server-side: schedule blocks (personal), EventKit events, PlanBhai
#   events, calendar_events, party_events, and meals mapped by weekday.
#   Returns the flat { id, title, date, time, type, source, sourceId } shape the
#   existing web grid already consumes.
#
#   Capped at 62 days so nobody can request a decade in one call.
#
# WHY ONE ENDPOINT MATTERS MORE THAN A NEW PAGE
#   The calendar read AppData directly while the Brief read the DayBrief
#   contract. Two paths to the same information drift — and had, in three
#   separate ways. Now there is one answer to "what is on Tuesday".
#
# Usage:
#   bash ~/Downloads/install-calendar-range.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
[ -d backend/services ] || { echo "ERROR: backend/services not found"; exit 1; }

echo "PlanBhai — calendar range endpoint"
echo

echo "1. Prerequisite"
[ -f backend/services/schedule.service.js ] \
  && echo "   ok   schedule.service.js" \
  || { echo "   MISSING — run install-schedule-phase-a.sh first"; exit 1; }
echo

write() {
  local dest="$1"
  [ -f "$dest" ] && cp "$dest" "$dest.bakrange"
  cat > "$dest"
  echo "   wrote $dest"
}

echo "2. Backend"
write 'backend/services/scheduleRange.service.js' << 'PLANBHAI_EOF'
const AppData = require('../models/AppData');
const Household = require('../models/Household');
const ExternalEvent = require('../models/ExternalEvent');
const ScheduleBlock = require('../models/ScheduleBlock');
const ScheduleInstance = require('../models/ScheduleInstance');
const { occursOn, applyInstances } = require('./schedule.service');
const { localDateIn, localTimeIn, startOfLocalDayUtc } = require('./daybrief/tz.util');

/**
 * Everything on a household's calendar across a date range.
 *
 * WHY THIS EXISTS
 *   The Brief answers "what about today" and is cached per day. Drawing a month
 *   through it would mean 31 cache lookups, 31 pantry diffs and 31 readiness
 *   computations for data a grid mostly discards.
 *
 *   More importantly, web's calendar was reading AppData directly and had
 *   drifted: it fetched `meal_plans` (0 documents — the real key is
 *   `meal_plan`), so meals never appeared, and it ignored `events` and EventKit
 *   entirely. Two paths to the same information disagree; this makes one.
 *
 * Returns the flat shape the existing web grid already consumes:
 *   { id, title, date, time, type, source, sourceId }
 */

const SWIFT_EPOCH_OFFSET = 978307200;
const MAX_DAYS = 62;

const swiftToUtc = (n) =>
  typeof n === 'number' && isFinite(n) ? new Date((n + SWIFT_EPOCH_OFFSET) * 1000) : null;

function eachDate(from, to) {
  const out = [];
  let t = Date.parse(`${from}T00:00:00Z`);
  const end = Date.parse(`${to}T00:00:00Z`);
  while (t <= end && out.length < MAX_DAYS) {
    out.push(new Date(t).toISOString().slice(0, 10));
    t += 86400000;
  }
  return out;
}

const weekdayOf = (localDate, tz) =>
  new Intl.DateTimeFormat('en-US', { timeZone: tz, weekday: 'long' })
    .format(startOfLocalDayUtc(localDate, tz));

/** Meal slots have no stored time; these are conventional, flagged as such. */
const MEAL_TIMES = { breakfast: '08:00', lunch: '12:30', dinner: '19:00' };

async function rangeForHousehold({ scopeId, userId, from, to, tz }) {
  const dates = eachDate(from, to);
  if (dates.length === 0) return { days: [] };

  const household = await Household.findById(scopeId).select('members').lean();
  const memberIds = ((household && household.members) || []).map(String);
  const ids = [String(scopeId), ...memberIds];

  const [appRows, external, blocks, instances] = await Promise.all([
    AppData.find({ userId: { $in: ids } }).lean(),
    ExternalEvent.find({
      scopeId,
      startUtc: {
        $gte: startOfLocalDayUtc(dates[0], tz),
        $lt: new Date(startOfLocalDayUtc(dates[dates.length - 1], tz).getTime() + 86400000),
      },
    }).lean(),
    // Schedule blocks are PERSONAL — only the caller's.
    ScheduleBlock.find({ userId, active: true }).lean(),
    ScheduleInstance.find({ userId, localDate: { $in: dates } }).lean(),
  ]);

  const shared = (type) => {
    const row = appRows.find((r) => r.userId === String(scopeId) && r.type === type);
    return row ? row.data : null;
  };
  const bestOf = (type) => {
    const rows = appRows
      .filter((r) => r.userId !== String(scopeId) && r.type === type)
      .sort((a, b) => new Date(b.updatedAt) - new Date(a.updatedAt));
    for (const r of rows) {
      const d = r.data;
      const has = Array.isArray(d) ? d.length : d && typeof d === 'object' ? Object.keys(d).length : false;
      if (has) return d;
    }
    return null;
  };

  const byDate = {};
  const add = (date, row) => {
    if (!date || !byDate[date]) return;
    byDate[date].push(row);
  };
  for (const d of dates) byDate[d] = [];

  // ---- PlanBhai calendar_events (date + time strings) ---------------------
  for (const e of shared('calendar_events') || []) {
    add(e.date, {
      id: `cal-${e.id}`, title: e.title || e.type || 'Event',
      date: e.date, time: e.time || '', type: e.type || 'Event',
      source: 'custom', sourceId: e.id,
    });
  }

  // ---- party_events -------------------------------------------------------
  for (const p of shared('party_events') || []) {
    add(p.date, {
      id: `party-${p.id}`, title: p.name || 'Untitled event',
      date: p.date, time: '', type: 'Party',
      source: 'party', sourceId: p.id,
    });
  }

  // ---- events (Swift epoch — 2001, not 1970) ------------------------------
  for (const e of shared('events') || []) {
    const d = swiftToUtc(e.date);
    if (!d) continue;
    const date = localDateIn(d, tz);
    add(date, {
      id: `evt-${e.id}`, title: e.name || 'Event',
      date, time: localTimeIn(d, tz), type: 'Event',
      source: 'event', sourceId: e.id,
    });
  }

  // ---- EventKit — the device calendar web could never see ------------------
  for (const e of external) {
    const date = localDateIn(new Date(e.startUtc), tz);
    add(date, {
      id: `ext-${e.externalId}-${e.occurrenceDate}`, title: e.title,
      date, time: e.allDay ? '' : localTimeIn(new Date(e.startUtc), tz),
      type: 'Calendar', source: 'device', sourceId: e.externalId,
    });
  }

  // ---- meals ---------------------------------------------------------------
  // meal_plan is a RECURRING WEEKLY TEMPLATE keyed "Monday".."Sunday". The old
  // web calendar derived dates from createdAt + index, which put Monday's meal
  // on whatever day the plan happened to be generated. Mapping by weekday is
  // what the data actually means.
  const plan = bestOf('meal_plan');
  if (plan && Array.isArray(plan.meals)) {
    for (const date of dates) {
      const day = weekdayOf(date, tz);
      const row = plan.meals.find((m) => m.day === day);
      if (!row) continue;
      for (const slot of ['breakfast', 'lunch', 'dinner']) {
        const meal = row[slot];
        if (!meal || !meal.name) continue;
        add(date, {
          id: `meal-${date}-${slot}`, title: meal.name,
          date, time: MEAL_TIMES[slot], type: 'Meal',
          source: 'meal', sourceId: slot, isDefaultTime: true,
        });
      }
    }
  }

  // ---- schedule blocks (personal) ------------------------------------------
  for (const date of dates) {
    const dayInstances = instances.filter((i) => i.localDate === date);
    for (const b of applyInstances(blocks, dayInstances, date)) {
      add(date, {
        id: `blk-${b.blockId}-${date}`, title: b.title,
        date, time: b.start, type: 'Block',
        source: 'schedule', sourceId: b.blockId,
        kind: b.kind, done: b.done, end: b.end,
      });
    }
  }

  return {
    days: dates.map((date) => ({
      localDate: date,
      rows: byDate[date].sort((a, b) => String(a.time || '99').localeCompare(String(b.time || '99'))),
    })),
  };
}

module.exports = { rangeForHousehold, eachDate, MAX_DAYS };
PLANBHAI_EOF
write 'backend/routes/schedule.routes.js' << 'PLANBHAI_EOF'
const express = require('express');
const ScheduleBlock = require('../models/ScheduleBlock');
const { blocksForDate, setInstance, clearInstance } = require('../services/schedule.service');
const { rangeForHousehold, MAX_DAYS } = require('../services/scheduleRange.service');
const { bustBriefsForOwner } = require('../services/daybrief/daybrief.service');
const { isValidTz, todayIn } = require('../services/daybrief/tz.util');

const router = express.Router();

// >>> EDIT if your middleware is named differently.
const requireAuth = require('../middleware/requireAuth');
const requireHouseholdMember = require('../middleware/requireHouseholdMember');

/**
 * Schedules are PERSONAL. Every route reads req.user._id and never a userId
 * from the request, so one household member cannot read or edit another's day.
 * scopeId is still required, because a block belongs to the household context
 * it was created in.
 */

/** GET /api/schedule/day?scopeId=...&tz=...&date=YYYY-MM-DD */
router.get('/day', requireAuth, requireHouseholdMember, async (req, res) => {
  const userId = String(req.user._id);
  const tz = isValidTz(req.query.tz) ? req.query.tz : 'UTC';
  const localDate = req.query.date || todayIn(tz);

  if (!/^\d{4}-\d{2}-\d{2}$/.test(localDate)) {
    return res.status(422).json({ success: false, message: 'date must be YYYY-MM-DD' });
  }

  try {
    res.json({ success: true, localDate, blocks: await blocksForDate({ userId, localDate }) });
  } catch (err) {
    console.error('[schedule/day]', err);
    res.status(500).json({ success: false, message: 'Could not load your schedule' });
  }
});

/**
 * GET /api/schedule/range?scopeId=&from=&to=&tz=
 *
 * Everything on the calendar across a range: schedule blocks, EventKit events,
 * PlanBhai events, parties, and meals — merged server-side so the calendar and
 * the Brief can no longer disagree about what is on a given Tuesday.
 *
 * Capped at MAX_DAYS so nobody can request a decade in one call.
 */
router.get('/range', requireAuth, requireHouseholdMember, async (req, res) => {
  const tz = isValidTz(req.query.tz) ? req.query.tz : 'UTC';
  const { from, to } = req.query;
  const iso = /^\d{4}-\d{2}-\d{2}$/;

  if (!iso.test(String(from || '')) || !iso.test(String(to || ''))) {
    return res.status(422).json({ success: false, message: 'from and to must be YYYY-MM-DD' });
  }
  if (Date.parse(`${to}T00:00:00Z`) < Date.parse(`${from}T00:00:00Z`)) {
    return res.status(422).json({ success: false, message: 'to must not precede from' });
  }

  const span = Math.round(
    (Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86400000
  ) + 1;
  if (span > MAX_DAYS) {
    return res.status(422).json({ success: false, message: `range may not exceed ${MAX_DAYS} days` });
  }

  try {
    const result = await rangeForHousehold({
      scopeId: req.scopeId,
      userId: String(req.user._id),
      from, to, tz,
    });
    res.set('Cache-Control', 'private, max-age=30');
    res.json({ success: true, ...result });
  } catch (err) {
    console.error('[schedule/range]', err);
    res.status(500).json({ success: false, message: 'Could not load your calendar' });
  }
});

/** GET /api/schedule/blocks — the templates, for an edit screen. */
router.get('/blocks', requireAuth, requireHouseholdMember, async (req, res) => {
  try {
    const blocks = await ScheduleBlock.find({ userId: String(req.user._id) })
      .sort({ startTime: 1 })
      .lean();
    res.json({ success: true, blocks });
  } catch (err) {
    console.error('[schedule/blocks]', err);
    res.status(500).json({ success: false, message: 'Could not load your blocks' });
  }
});

/** POST /api/schedule/blocks */
router.post('/blocks', requireAuth, requireHouseholdMember, async (req, res) => {
  const userId = String(req.user._id);
  const { title, kind, startTime, durationMin, recurrence, tags, goalId, source } = req.body || {};

  if (!title || !String(title).trim()) {
    return res.status(400).json({ success: false, message: 'title is required' });
  }
  if (!/^\d{2}:\d{2}$/.test(String(startTime || ''))) {
    return res.status(400).json({ success: false, message: 'startTime must be HH:mm' });
  }
  const mins = Number(durationMin);
  if (!Number.isFinite(mins) || mins < 5 || mins > 600) {
    return res.status(400).json({ success: false, message: 'durationMin must be 5–600' });
  }

  try {
    const block = await ScheduleBlock.create({
      scopeId: req.scopeId,
      userId,
      title: String(title).trim(),
      kind: kind || 'admin',
      startTime,
      durationMin: mins,
      recurrence: recurrence || undefined,
      tags: Array.isArray(tags) ? tags.slice(0, 8) : [],
      goalId: goalId || null,
      source: source || 'manual',
    });
    await bustBriefsForOwner(userId).catch(() => {});
    res.json({ success: true, block });
  } catch (err) {
    console.error('[schedule/blocks POST]', err);
    res.status(500).json({ success: false, message: 'Could not save that block' });
  }
});

/** PUT /api/schedule/blocks/:id */
router.put('/blocks/:id', requireAuth, requireHouseholdMember, async (req, res) => {
  const userId = String(req.user._id);
  const allowed = ['title', 'kind', 'startTime', 'durationMin', 'recurrence', 'tags', 'goalId', 'active'];
  const update = {};
  for (const k of allowed) if (req.body[k] !== undefined) update[k] = req.body[k];

  try {
    // Scoped by userId as well as id — an id alone would let one member edit
    // another's block.
    const block = await ScheduleBlock.findOneAndUpdate(
      { _id: req.params.id, userId },
      update,
      { new: true }
    );
    if (!block) return res.status(404).json({ success: false, message: 'Block not found' });
    await bustBriefsForOwner(userId).catch(() => {});
    res.json({ success: true, block });
  } catch (err) {
    console.error('[schedule/blocks PUT]', err);
    res.status(500).json({ success: false, message: 'Could not update that block' });
  }
});

/** DELETE /api/schedule/blocks/:id */
router.delete('/blocks/:id', requireAuth, requireHouseholdMember, async (req, res) => {
  const userId = String(req.user._id);
  try {
    const r = await ScheduleBlock.deleteOne({ _id: req.params.id, userId });
    if (!r.deletedCount) return res.status(404).json({ success: false, message: 'Block not found' });
    await bustBriefsForOwner(userId).catch(() => {});
    res.json({ success: true });
  } catch (err) {
    console.error('[schedule/blocks DELETE]', err);
    res.status(500).json({ success: false, message: 'Could not delete that block' });
  }
});

/**
 * POST /api/schedule/instance   { blockId, localDate, state, startTime, durationMin }
 *
 * state: done | skipped | moved | clear
 *
 * `clear` removes the deviation, which is how un-completing and undoing a move
 * both work — a mis-tap should always be reversible.
 */
router.post('/instance', requireAuth, requireHouseholdMember, async (req, res) => {
  const userId = String(req.user._id);
  const { blockId, localDate, state, startTime, durationMin } = req.body || {};

  if (!blockId) return res.status(400).json({ success: false, message: 'blockId is required' });
  if (!/^\d{4}-\d{2}-\d{2}$/.test(String(localDate || ''))) {
    return res.status(400).json({ success: false, message: 'localDate must be YYYY-MM-DD' });
  }
  if (!['done', 'skipped', 'moved', 'clear'].includes(state)) {
    return res.status(400).json({ success: false, message: 'invalid state' });
  }

  try {
    // Confirm the block belongs to the caller before recording anything against it.
    const owns = await ScheduleBlock.exists({ _id: blockId, userId });
    if (!owns) return res.status(404).json({ success: false, message: 'Block not found' });

    if (state === 'clear') {
      await clearInstance({ userId, blockId, localDate });
    } else {
      await setInstance({
        scopeId: req.scopeId, userId, blockId, localDate, state, startTime, durationMin,
      });
    }

    await bustBriefsForOwner(userId).catch(() => {});
    res.json({ success: true, blocks: await blocksForDate({ userId, localDate }) });
  } catch (err) {
    console.error('[schedule/instance]', err);
    res.status(500).json({ success: false, message: 'Could not update that' });
  }
});

module.exports = router;
PLANBHAI_EOF

for f in backend/services/scheduleRange.service.js backend/routes/schedule.routes.js; do
  node --check "$f" || { echo "   PARSE FAILED: $f"; exit 1; }
done
echo "   both parse"
echo

echo "3. Web api method"
if grep -q "fetchScheduleRange" web/src/api.js; then
  echo "   already present"
else
  cp web/src/api.js web/src/api.js.bakrange
  python3 - web/src/api.js << 'PY_EOF'
import sys
p = sys.argv[1]
s = open(p).read()
anchor = "  // ---- Auth ----"
if anchor not in s:
    print("   ERROR: Auth section not found"); sys.exit(2)
add = """  // ---- Calendar ----
  fetchScheduleRange: (scopeId, from, to, tz) =>
    request(
      `/api/schedule/range?scopeId=${scopeId}&from=${from}&to=${to}&tz=${encodeURIComponent(tz)}`,
      { auth: true }
    ),

"""
s = s.replace(anchor, add + anchor, 1)
open(p, "w").write(s)
print("   added api.fetchScheduleRange")
PY_EOF
  [ $? -ne 0 ] && { cp web/src/api.js.bakrange web/src/api.js; echo "   reverted"; exit 1; }
fi
echo

echo "4. Verifying against real data"
cd backend
cat > ./.pb_range.js << 'RANGE_EOF'
require("dotenv").config();
const m = require("mongoose");
(async () => {
  await m.connect(process.env.MONGODB_URI);
  const A = require("./models/AppData");
  const counts = {};
  for (const t of ["meal_plans", "meal_plan", "calendar_events", "party_events", "events"]) {
    counts[t] = await A.countDocuments({ type: t });
  }
  console.log("   meal_plans  " + counts.meal_plans + " doc(s)  <- what web fetched");
  console.log("   meal_plan   " + counts.meal_plan + " doc(s)  <- what actually exists");
  console.log("   events      " + counts.events + " doc(s)  <- web ignored these");
  const E = require("./models/ExternalEvent");
  console.log("   EventKit    " + (await E.countDocuments({})) + " row(s)  <- web ignored these");
  await m.disconnect();
})().catch(e => { console.error("   " + e.message); process.exit(0); });
RANGE_EOF
node ./.pb_range.js
rm -f ./.pb_range.js
cd ..
echo

echo "=========================================="
echo "  Deploy:"
echo "     git add -A && git commit -m 'One calendar range endpoint' && git push"
echo "  then Manual Deploy on Render."
echo
echo "  The web Calendar page still fetches AppData directly — swapping it to"
echo "  this endpoint is the next step, and needs its load function. Send:"
echo "     sed -n '45,95p' web/src/pages/Calendar.jsx"
echo "=========================================="

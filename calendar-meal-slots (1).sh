#!/usr/bin/env bash
#
# Meal rows on the calendar: slot labels, at slot times.
#
#   8 AM   Breakfast
#   1 PM   Lunch
#   8 PM   Dinner
#
# WAS
#   8 AM   Scrambled Eggs with Toast and Orange Juice
#   1 PM   Tomato Soup with Grilled Cheese Sandwiches
#   8 PM   Spaghetti Bolognese with Garlic Bread and Side Salad
#
# The times stay so meals sort sensibly among real events and clashes are
# visible. The DISH NAMES go, because a full title per slot pushed actual
# appointments off the screen — and the Brief already shows tonight's dinner in
# full, with its ingredient coverage.
#
# The dish is still carried on the row as `dish`, so a tap can reveal it without
# another request.
#
# Each row is flagged isDefaultTime, because the meal plan stores NO times —
# these are conventions. A client can render them as approximate; a meal at
# 8 AM is a guess, a dentist at 8 AM is not.
#
# Only scheduleRange.service.js changes. Both platforms read this endpoint, so
# one deploy fixes both calendars.
#
# Usage:
#   bash ~/Downloads/calendar-meal-slots.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
F="backend/services/scheduleRange.service.js"
[ -f "$F" ] || { echo "ERROR: $F not found"; exit 1; }

echo "PlanBhai — calendar meal slots"
echo

echo "1. Writing"
cp "$F" "$F.bakslots"
cat > "$F" << 'PLANBHAI_EOF'
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

/**
 * Conventional slot times. The meal plan stores no times at all — these exist
 * so meals sort sensibly among real events, and are flagged isDefaultTime so a
 * client can show them as approximate.
 */
const MEAL_TIMES = { breakfast: '08:00', lunch: '13:00', dinner: '20:00' };

const weekdayOf = (localDate, tz) =>
  new Intl.DateTimeFormat('en-US', { timeZone: tz, weekday: 'long' })
    .format(startOfLocalDayUtc(localDate, tz));

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

      // One row per slot, at its conventional time — but labelled by SLOT, not
      // by dish. "Spaghetti Bolognese with Garlic Bread and Side Salad" took a
      // whole line and pushed real events off the screen; "Dinner" says what
      // the row is for. The dish name lives on the Brief, which has room for it
      // and shows tonight's with its ingredient coverage.
      for (const slot of ['breakfast', 'lunch', 'dinner']) {
        const meal = row[slot];
        if (!meal || !meal.name) continue;
        add(date, {
          id: `meal-${date}-${slot}`,
          title: slot.charAt(0).toUpperCase() + slot.slice(1),
          date,
          time: MEAL_TIMES[slot],
          type: 'Meal',
          source: 'meal',
          sourceId: slot,
          // These times are conventions, not stored data. Flagged so a client
          // can render them differently from a real appointment — a meal at
          // 8 AM is a guess; a dentist at 8 AM is not.
          isDefaultTime: true,
          // Carried so a tap can show what is actually planned without another
          // request.
          dish: meal.name,
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
node --check "$F" || { echo "   PARSE FAILED — reverting"; cp "$F.bakslots" "$F"; exit 1; }
echo "   wrote + parses"
grep -q "lunch: '13:00'" "$F" && echo "   ok   1 PM lunch"
grep -q "dinner: '20:00'" "$F" && echo "   ok   8 PM dinner"
grep -q "isDefaultTime" "$F" && echo "   ok   times flagged as approximate"
echo

echo "2. After deploying, check:"
echo
echo "   TOK=\$(curl -s -X POST https://planbhai.onrender.com/api/auth/login \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"email\":\"ritesh@test.com\",\"password\":\"Test@1234\"}' \\"
echo "     | node -pe 'JSON.parse(require(\"fs\").readFileSync(0)).token')"
echo
echo "   curl -s \"https://planbhai.onrender.com/api/schedule/range?scopeId=6a5186af77659b8762bfb01c&from=2026-08-03&to=2026-08-03&tz=America/Chicago\" \\"
echo "     -H \"Authorization: Bearer \$TOK\" | node -pe 'JSON.parse(require(\"fs\").readFileSync(0)).days[0].rows.filter(r=>r.source===\"meal\").map(r=>r.time+\"  \"+r.title).join(\"\\n\")'"
echo

echo "=========================================="
echo "  Deploy:"
echo "     git add -A && git commit -m 'Calendar meals: slot labels at slot times' && git push"
echo "  then Manual Deploy on Render. One deploy fixes both calendars."
echo
echo "  Revert:  cp $F.bakslots $F"
echo "=========================================="

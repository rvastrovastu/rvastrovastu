#!/usr/bin/env bash
#
# Fixes habits coming back with name: null.
#
# Two shapes exist in AppData:
#   older records   { name, streak, completedToday }
#   habit tracker   { id, title, streak, streakShields, completedToday }
#
# The adapter only read `name`, so every tracker-written habit became null —
# four blank sprouts in the garden, and a total inflated from 5 to 9.
#
# Also collapses genuine duplicates: "Morning Hydration" and "10k Steps Daily"
# are each stored twice under different ids. Counting them twice makes the
# garden and the "N of M done" line wrong.
#
# Only context.adapter.js changes.
#
# Usage:
#   bash ~/Downloads/fix-habit-shapes.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
F="backend/services/daybrief/context.adapter.js"
[ -f "$F" ] || { echo "ERROR: $F not found"; exit 1; }

echo "PlanBhai — fixing habit shapes"
echo

echo "1. Writing the adapter"
cp "$F" "$F.bakhabits"
cat > "$F" << 'PLANBHAI_EOF'
/**
 * Turns PlanBhai's actual data into the normalized `ctx` the dashboard consumes.
 *
 * ---------------------------------------------------------------------------
 * KEY FACT: AppData.userId is overloaded.
 *
 * It holds EITHER a household id OR a user id, depending on the type:
 *
 *   household-keyed  groceries, events, calendar_events, party_events,
 *                    household_notes
 *   user-keyed       habits, chores, meal_plan, family_members, pantry,
 *                    water_glasses, nutrition_goals, calorie_entries
 *
 * Household-keyed types need no merging — they're already shared. User-keyed
 * types must be merged across members, because the data is NOT concentrated in
 * the owner's account: this household's only meal_plan belongs to a non-owner.
 * Reading just the owner would show "no dinner planned" while a full 7-day plan
 * sits right there.
 * ---------------------------------------------------------------------------
 *
 * DATES: events[].date is a Swift TimeInterval — seconds since 2001-01-01, not
 * 1970. Verified: 805523400 -> 2026-07-12. The unix epoch would silently place
 * every event in 1995.
 */

const AppData = require('../../models/AppData');
const Household = require('../../models/Household');
const ExternalEvent = require('../../models/ExternalEvent');
const { startOfLocalDayUtc, endOfLocalDayUtc, localDateIn } = require('./tz.util');

/** Apple's reference date (2001-01-01) as unix seconds. */
const SWIFT_EPOCH_OFFSET = 978307200;

const swiftDateToUtc = (n) =>
  typeof n === 'number' && isFinite(n) ? new Date((n + SWIFT_EPOCH_OFFSET) * 1000) : null;

/** Weekday name for a local date, matching meal_plan's "Monday".."Sunday" keys. */
function weekdayName(localDate, tz) {
  const d = startOfLocalDayUtc(localDate, tz);
  return new Intl.DateTimeFormat('en-US', { timeZone: tz, weekday: 'long' }).format(d);
}

/** 'YYYY-MM-DD' + 'HH:mm' in `tz` -> a UTC instant. */
function localDateTimeToUtc(dateStr, timeStr, tz) {
  if (!dateStr) return null;
  const base = startOfLocalDayUtc(dateStr, tz);
  if (!base || isNaN(base)) return null;
  const [h, m] = String(timeStr || '00:00').split(':').map(Number);
  return new Date(base.getTime() + ((h || 0) * 60 + (m || 0)) * 60000);
}

async function soft(name, fn, fallback) {
  try {
    return await fn();
  } catch (err) {
    console.error(`[daybrief] loader "${name}" failed:`, err.message);
    return fallback;
  }
}

// ---------------------------------------------------------------------------

/**
 * Fetches every AppData row belonging to the household or any member in ONE
 * round trip. The dashboard is the most-hit screen in the app; thirty separate
 * queries here would be felt immediately.
 */
async function loadAppBundle(scopeId, memberIds) {
  const scope = String(scopeId);
  const ids = [scope, ...memberIds.map(String)];
  const rows = await AppData.find({ userId: { $in: ids } }).lean();

  const byType = new Map();
  for (const r of rows) {
    if (!byType.has(r.type)) byType.set(r.type, []);
    byType.get(r.type).push(r);
  }

  return {
    /** Household-keyed value: groceries, events, calendar_events, party_events. */
    shared(type) {
      const row = (byType.get(type) || []).find((r) => r.userId === scope);
      return row ? row.data : null;
    },

    /** Member rows for a user-keyed type, newest first. */
    memberRows(type) {
      return (byType.get(type) || [])
        .filter((r) => r.userId !== scope)
        .sort((a, b) => new Date(b.updatedAt) - new Date(a.updatedAt));
    },

    /** Concatenate an array type across members, tagging each item's owner. */
    mergedArray(type) {
      const out = [];
      for (const r of this.memberRows(type)) {
        if (Array.isArray(r.data)) {
          for (const item of r.data) out.push({ ...item, _ownerUserId: r.userId });
        }
      }
      return out;
    },

    /**
     * Most recently updated non-empty value. Used where one shared answer is
     * wanted (meal_plan, family_members) but the data lives in an arbitrary
     * member's account.
     */
    bestOf(type) {
      for (const r of this.memberRows(type)) {
        const d = r.data;
        const has = Array.isArray(d)
          ? d.length > 0
          : d && typeof d === 'object'
            ? Object.keys(d).length > 0
            : d != null;
        if (has) return { data: d, userId: r.userId, updatedAt: r.updatedAt };
      }
      return null;
    },
  };
}

// ---------------------------------------------------------------------------

/**
 * Three event sources merge into one timeline:
 *   ExternalEvent    synced from EventKit (may be empty until iOS syncs)
 *   events           Swift-epoch numeric dates
 *   calendar_events  'YYYY-MM-DD' + 'HH:mm' strings
 */
async function loadCalendar(bundle, scopeId, tz, localDate, dayStart, dayEnd) {
  const events = [];

  const external = await ExternalEvent.find({
    scopeId,
    startUtc: { $lt: dayEnd },
    endUtc: { $gt: dayStart },
  }).lean();

  for (const e of external) {
    events.push({
      externalId: e.externalId,
      title: e.title,
      startUtc: e.startUtc,
      endUtc: e.endUtc,
      allDay: e.allDay,
      requiresEscort: false,
      assigneeId: null,
      source: 'eventkit',
    });
  }

  for (const e of bundle.shared('events') || []) {
    const start = swiftDateToUtc(e.date);
    if (!start || start < dayStart || start >= dayEnd) continue;
    events.push({
      externalId: e.id,
      title: e.name || 'Event',
      startUtc: start,
      endUtc: new Date(start.getTime() + 3600000), // no duration stored
      allDay: false,
      // invitedMemberIDs point at family_members ids, not User accounts.
      requiresEscort: Array.isArray(e.invitedMemberIDs) && e.invitedMemberIDs.length > 0,
      assigneeId: null,
      source: 'planbhai_events',
    });
  }

  for (const e of bundle.shared('calendar_events') || []) {
    const start = localDateTimeToUtc(e.date, e.time, tz);
    if (!start || start < dayStart || start >= dayEnd) continue;
    events.push({
      externalId: e.id,
      title: e.title || e.type || 'Event',
      startUtc: start,
      endUtc: new Date(start.getTime() + 3600000),
      allDay: !e.time,
      requiresEscort: false,
      assigneeId: null,
      source: 'calendar_events',
    });
  }

  events.sort((a, b) => new Date(a.startUtc) - new Date(b.startUtc));

  const latestSync = await ExternalEvent.findOne({ scopeId }).sort({ updatedAt: -1 }).lean();

  return {
    connected: events.length > 0 || Boolean(latestSync),
    syncedAt: latestSync ? latestSync.updatedAt : null,
    events,
  };
}

/**
 * meal_plan is a RECURRING WEEKLY TEMPLATE keyed "Monday".."Sunday". There's no
 * anchor date, so today's meal is just today's weekday name — a nicer design
 * than a dated plan, since it never goes stale.
 *
 * Meal times aren't stored. Conventional defaults let meals appear on the
 * timeline, flagged isDefaultTime so the UI can render them softer than a real
 * appointment rather than implying a commitment nobody made.
 */
const DEFAULT_MEAL_TIMES = { breakfast: '08:00', lunch: '12:30', dinner: '19:00' };

async function loadMeals(bundle, tz, localDate) {
  const best = bundle.bestOf('meal_plan');
  if (!best || !Array.isArray(best.data.meals)) {
    return { used: false, primarySlot: 'dinner', planned: null, slots: [] };
  }

  const today = weekdayName(localDate, tz);
  const row = best.data.meals.find((m) => m.day === today);

  if (!row) return { used: true, primarySlot: 'dinner', planned: null, slots: [] };

  const slots = [];
  for (const slot of ['breakfast', 'lunch', 'dinner']) {
    const meal = row[slot];
    if (!meal || !meal.name) continue;
    slots.push({
      id: `${slot}:${localDate}`,
      slot,
      title: meal.name,
      calories: meal.calories == null ? null : meal.calories,
      timeUtc: localDateTimeToUtc(localDate, DEFAULT_MEAL_TIMES[slot], tz),
      isDefaultTime: true,
    });
  }

  const dinner = row.dinner;

  return {
    used: true,
    primarySlot: 'dinner',
    planned:
      dinner && dinner.name
        ? {
            title: dinner.name,
            recipeId: null,
            // pantry is empty in every account, so coverage is genuinely unknown.
            // null (not 0) keeps the score honest — readiness scores 60 for
            // "planned, coverage unknown" rather than penalising a real plan.
            haveRatio: null,
            missing: [],
            calories: dinner.calories == null ? null : dinner.calories,
          }
        : null,
    slots,
    weekPlanSummary: best.data.summary || null,
  };
}

/**
 * Grocery items are {quantity, id, item, category} — no `checked` or `purchased`
 * field, and pantry is empty everywhere. A 29-item list means "29 things to buy",
 * NOT "29 things missing".
 *
 * listExists:false keeps this OUT of the readiness score deliberately. Scoring it
 * as missing items would floor an ordinary shopping list at 30 and drag the whole
 * day down for no reason. It still surfaces as a signal. Flip this on once pantry
 * data exists and real coverage can be computed.
 */
async function loadGroceries(bundle) {
  const items = bundle.shared('groceries') || [];
  const list = Array.isArray(items) ? items : [];
  return {
    listExists: false,
    missingCount: 0,
    itemCount: list.length,
    items: list.slice(0, 50),
  };
}

/**
 * family_members are app-local people (Jim, Joy) with their own ids — NOT User
 * accounts. chores.assignedToID references those ids, which is what lets us spot
 * an obligation nobody has picked up.
 */
async function loadFamily(bundle, scopeId) {
  const household = await Household.findById(scopeId).select('members').lean();
  const memberCount = ((household && household.members) || []).length || 1;

  const bestFam = bundle.bestOf('family_members');
  const people = bestFam && Array.isArray(bestFam.data) ? bestFam.data : [];

  const chores = bundle.mergedArray('chores');
  const open = chores.filter((c) => !c.isDone);

  return {
    memberCount: Math.max(memberCount, people.length || 1),
    members: people.map((p) => ({
      id: p.id,
      name: p.name,
      role: p.role || null,
      status: p.status || null,
      colorIndex: p.colorIndex == null ? null : p.colorIndex,
    })),
    obligations: open.map((c) => ({
      id: c.id,
      title: c.title,
      assigneeId: c.assignedToID || null,
      done: false,
      points: c.points == null ? null : c.points,
      recurring: Boolean(c.isRecurringDaily),
    })),
    choresTotal: chores.length,
    choresDone: chores.length - open.length,
  };
}

/**
 * habits are {name, streak, completedToday} — no scheduled time, no id.
 *
 * Since nothing is scheduled, there is nothing PLANNED to measure, so habits stay
 * out of the readiness score. Scoring them on completion would read 0% every
 * morning — precisely the anxiety this dashboard exists to remove. They surface
 * as a signal and their own section instead.
 */
async function loadHabits(bundle) {
  const raw = bundle.mergedArray('habits');

  // Two shapes exist in the wild. Older records use `name` with no id; newer
  // ones written by the habit tracker use `title` plus an id and streakShields.
  // Reading only one of them silently turns the other into nulls.
  const normalized = raw
    .map((h) => ({
      name: h.title || h.name || null,
      streak: h.streak || 0,
      completedToday: Boolean(h.completedToday),
      ownerUserId: h._ownerUserId,
    }))
    .filter((h) => h.name);

  // Genuine duplicates exist — the same habit saved twice under different ids.
  // Counting them twice would inflate the total and make the garden look wrong,
  // so collapse per owner + name, keeping the completed one where they differ.
  const seen = new Map();
  for (const h of normalized) {
    const key = `${h.ownerUserId}::${h.name.trim().toLowerCase()}`;
    const prev = seen.get(key);
    if (!prev) {
      seen.set(key, h);
    } else {
      seen.set(key, {
        ...prev,
        streak: Math.max(prev.streak, h.streak),
        completedToday: prev.completedToday || h.completedToday,
      });
    }
  }

  const habits = [...seen.values()];

  return {
    active: [], // no times -> nothing to place on the timeline
    all: habits,
    total: habits.length,
    completedToday: habits.filter((h) => h.completedToday).length,
    longestStreak: habits.reduce((m, h) => Math.max(m, h.streak || 0), 0),
  };
}

/** budget_items and settlements are empty in every account, so finance stays off. */
async function loadFinance() {
  return { tracked: false, bills: [] };
}

async function loadUpcoming(bundle, scopeId, tz, localDate, dayEnd) {
  const out = [];

  for (const p of bundle.shared('party_events') || []) {
    if (!p.date || p.date <= localDate) continue;
    out.push({ date: p.date, title: p.name || 'Party', kind: 'party', icon: '🎉' });
  }

  for (const e of bundle.shared('calendar_events') || []) {
    if (!e.date || e.date <= localDate) continue;
    out.push({ date: e.date, title: e.title || e.type || 'Event', kind: 'event', icon: '📅' });
  }

  for (const e of bundle.shared('events') || []) {
    const d = swiftDateToUtc(e.date);
    if (!d || d < dayEnd) continue;
    out.push({ date: localDateIn(d, tz), title: e.name || 'Event', kind: 'event', icon: '📅' });
  }

  const ext = await ExternalEvent.find({ scopeId, startUtc: { $gte: dayEnd } })
    .sort({ startUtc: 1 })
    .limit(10)
    .lean();
  for (const e of ext) {
    out.push({ date: e.occurrenceDate, title: e.title, kind: 'event', icon: '📅' });
  }

  return out.sort((a, b) => String(a.date).localeCompare(String(b.date))).slice(0, 8);
}

/** Birthdays surface from party/calendar entries whose name says so. */
async function loadBirthdays(bundle, localDate) {
  const out = [];
  const isBirthday = (s) => /b-?day|birthday/i.test(s || '');

  const consider = [
    ...(bundle.shared('party_events') || []).map((p) => ({ date: p.date, name: p.name })),
    ...(bundle.shared('calendar_events') || []).map((e) => ({ date: e.date, name: e.title })),
  ];

  for (const c of consider) {
    if (!c.date || !isBirthday(c.name)) continue;
    const diff = Math.round(
      (Date.parse(`${c.date}T00:00:00Z`) - Date.parse(`${localDate}T00:00:00Z`)) / 86400000
    );
    if (diff < 0 || diff > 14) continue;
    // "Saarth Bday" -> "Saarth"; a bare "Birthday" -> "" so the caller can render
    // "Birthday today" instead of "Birthday's birthday today".
    const name = String(c.name || '')
      .replace(/\s*(birthday|b-?day)\s*/gi, ' ')
      .replace(/\s+/g, ' ')
      .trim();
    out.push({
      name,
      relative: diff === 0 ? 'today' : diff === 1 ? 'tomorrow' : `in ${diff} days`,
      date: c.date,
    });
  }
  return out;
}

async function loadWeather() {
  // Not implemented yet. When added: cache by rounded lat/lon + hour, 2s hard
  // timeout, degrade silently. Weather must never slow the dashboard.
  return null;
}

// ---------------------------------------------------------------------------

async function loadContext({ scopeId, tz, localDate, nowUtc = new Date() }) {
  const dayStart = startOfLocalDayUtc(localDate, tz);
  const dayEnd = endOfLocalDayUtc(localDate, tz);

  const household = await Household.findById(scopeId).select('members').lean();
  const memberIds = ((household && household.members) || []).map(String);

  const bundle = await loadAppBundle(scopeId, memberIds);

  const [calendar, meals, groceries, family, habits, finance, upcoming, birthdays, weather] =
    await Promise.all([
      soft('calendar', () => loadCalendar(bundle, scopeId, tz, localDate, dayStart, dayEnd), {
        connected: false,
        events: [],
      }),
      soft('meals', () => loadMeals(bundle, tz, localDate), {
        used: false,
        primarySlot: 'dinner',
        planned: null,
        slots: [],
      }),
      soft('groceries', () => loadGroceries(bundle), {
        listExists: false,
        missingCount: 0,
        itemCount: 0,
        items: [],
      }),
      soft('family', () => loadFamily(bundle, scopeId), {
        memberCount: 1,
        members: [],
        obligations: [],
      }),
      soft('habits', () => loadHabits(bundle), {
        active: [],
        all: [],
        total: 0,
        completedToday: 0,
        longestStreak: 0,
      }),
      soft('finance', () => loadFinance(), { tracked: false, bills: [] }),
      soft('upcoming', () => loadUpcoming(bundle, scopeId, tz, localDate, dayEnd), []),
      soft('birthdays', () => loadBirthdays(bundle, localDate), []),
      soft('weather', () => loadWeather(), null),
    ]);

  return {
    scopeId,
    tz,
    localDate,
    nowUtc,
    dayStart,
    dayEnd,
    calendar,
    meals,
    groceries,
    family,
    habits,
    finance,
    upcoming,
    birthdays,
    weather,
    notes: bundle.shared('household_notes') || [],
    tasks: { scheduled: [] },
  };
}

module.exports = { loadContext, swiftDateToUtc, weekdayName, SWIFT_EPOCH_OFFSET };
PLANBHAI_EOF
node --check "$F" || { echo "   PARSE FAILED — reverting"; cp "$F.bakhabits" "$F"; exit 1; }
echo "   wrote + parses"
echo

echo "2. Clearing the cached brief"
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
echo "  Deploy, then re-check:"
echo "     git add -A && git commit -m 'Normalize habit title/name and dedupe' && git push"
echo "  then Manual Deploy on Render."
echo "=========================================="

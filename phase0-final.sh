#!/usr/bin/env bash
#
# PlanBhai Phase 0 — everything in one script.
#
# Installs the four dashboard files, clears cached briefs, restarts the server,
# and runs the end-to-end test. Replaces install-adapter.sh, rebuild-and-test.sh
# and test-dashboard.sh, which kept colliding with older downloads.
#
# Usage:
#   bash ~/Downloads/phase0-final.sh /Users/riteshvyas/PlanBhai/PlanBhai
#   bash ~/Downloads/phase0-final.sh /Users/riteshvyas/PlanBhai/PlanBhai <householdId>
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
SCOPE_ARG="${2:-}"
[ -d "$ROOT/backend" ] || { echo "ERROR: no backend/ under $ROOT"; exit 1; }
cd "$ROOT"

PORT=$(grep -E "^PORT=" backend/.env 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"'"'"'')
[ -z "$PORT" ] && PORT=5001
BASE="http://localhost:$PORT"
TZ_ARG="America/Chicago"
LOG=/tmp/planbhai-server.log

envval() { grep -E "^$1=" backend/.env | head -1 | cut -d= -f2- | tr -d '"'"'"'' | tr -d '\r'; }
MONGODB_URI="$(envval MONGODB_URI)"

echo "PlanBhai Phase 0 — install, restart, test"
echo "  root: $ROOT"
echo

echo "1. Writing files"
mkdir -p backend/services/daybrief
write() {
  local dest="$1"
  [ -f "$dest" ] && cp "$dest" "$dest.bakfinal"
  cat > "$dest"
  echo "   wrote $dest"
}

write 'backend/services/daybrief/context.adapter.js' << 'PLANBHAI_EOF'
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
  const habits = bundle.mergedArray('habits');
  return {
    active: [], // no times -> nothing to place on the timeline
    all: habits.map((h) => ({
      name: h.name,
      streak: h.streak || 0,
      completedToday: Boolean(h.completedToday),
      ownerUserId: h._ownerUserId,
    })),
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

write 'backend/services/daybrief/builders.service.js' << 'PLANBHAI_EOF'
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
    line = s >= 80 ? `${praise}.` : `${praise} — one thing left to sort.`;
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

write 'backend/services/daybrief/readiness.service.js' << 'PLANBHAI_EOF'
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
    score -= 25;
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

write 'backend/services/daybrief/daybrief.service.js' << 'PLANBHAI_EOF'
const DayBrief = require('../../models/DayBrief');
const SuggestionDismissal = require('../../models/SuggestionDismissal');
const { loadContext } = require('./context.adapter');
const { computeReadiness } = require('./readiness.service');
const {
  buildTimeline,
  buildGreeting,
  buildSignals,
  deriveState,
  buildUpcoming,
} = require('./builders.service');
const { todayIn, endOfLocalDayUtc, localTimeIn, relativeDayLabel } = require('./tz.util');

const CURRENT_SCHEMA_VERSION = 1;

// >>> EDIT: your existing entitlement check.
// const { hasFeature } = require('../entitlements.service');
const hasFeature = () => true;

/**
 * Pure. Takes context, returns a persistable brief. No I/O — this is what makes the
 * whole pipeline unit-testable without Mongo fixtures.
 */
function buildBrief(ctx) {
  const readiness = computeReadiness(ctx);
  const signals = buildSignals(ctx);
  const timeline = buildTimeline(ctx);
  const state = deriveState(signals, ctx, readiness);

  return {
    scopeId: ctx.scopeId,
    localDate: ctx.localDate,
    tz: ctx.tz,
    state,
    schemaVersion: CURRENT_SCHEMA_VERSION,

    greeting: buildGreeting(ctx, readiness),

    readiness: readiness
      ? { score: readiness.score, label: readiness.label, breakdown: readiness.breakdown }
      : null,

    signals,
    suggestions: [], // Phase 2
    timeline,
    contextCards: [], // Phase 3

    meal: ctx.meals?.planned
      ? {
          slot: ctx.meals.primarySlot || 'dinner',
          title: ctx.meals.planned.title,
          recipeId: ctx.meals.planned.recipeId || null,
          haveRatio: ctx.meals.planned.haveRatio,
          missing: ctx.meals.planned.missing || [],
          imageUrl: ctx.meals.planned.imageUrl || null,
        }
      : null,

    family: (ctx.family?.members || []).map((m) => {
      const mine = (ctx.family.obligations || []).filter(
        (o) => String(o.assigneeId) === String(m.id)
      );
      const pending = mine.filter((o) => !o.done);
      return {
        memberId: m.id,
        name: m.name,
        status: pending.length ? pending[0].title : mine.length ? 'All done' : 'Nothing scheduled',
        state: pending.length ? 'pending' : mine.length ? 'done' : 'upcoming',
        icon: pending.length ? '⏳' : mine.length ? '✓' : '·',
      };
    }),

    upcoming: buildUpcoming(ctx),

    calendarSyncedAt: ctx.calendar?.syncedAt || null,
    generatedAt: new Date(),
    expiresAt: new Date(endOfLocalDayUtc(ctx.localDate, ctx.tz).getTime() + 6 * 3600000),
  };
}

/**
 * Applies everything that is per-user rather than per-household. Never persisted.
 *   - dismissals hide suggestions for one member only
 *   - `locked` depends on that member's entitlements, which can differ
 *   - `isNow` depends on the clock, so caching it would go stale within minutes
 */
async function decorateForRead(brief, user) {
  const doc = brief.toObject ? brief.toObject() : { ...brief };

  const dismissed = await SuggestionDismissal.find({
    userId: user._id,
    scopeId: doc.scopeId,
  })
    .select('suggestionId')
    .lean();
  const dismissedIds = new Set(dismissed.map((d) => d.suggestionId));

  doc.suggestions = (doc.suggestions || [])
    .filter((s) => !dismissedIds.has(s.id))
    .map((s) => ({ ...s, locked: s.feature ? !hasFeature(user, s.feature) : false }));

  const nowHM = localTimeIn(new Date(), doc.tz);
  doc.timeline = (doc.timeline || []).map((r) => ({
    ...r,
    isNow: Boolean(r.end ? r.start <= nowHM && nowHM < r.end : r.start === nowHM),
  }));

  doc.upcoming = (doc.upcoming || []).map((u) => ({
    ...u,
    day: relativeDayLabel(todayIn(doc.tz), u.date, doc.tz),
  }));

  delete doc.buildMs;
  return doc;
}

/**
 * Cache-check → build → persist → decorate.
 * Cache key is (scopeId, localDate, tz): the brief is shared across the household,
 * but a member travelling to another timezone genuinely needs different wall-clock
 * times, so tz belongs in the key. Rare, and an extra document is cheap.
 */
async function getTodayBrief({ user, scopeId, tz, date }) {
  const localDate = date || todayIn(tz);
  const key = { scopeId, localDate, tz };

  const cached = await DayBrief.findOne(key);
  if (cached && cached.schemaVersion === CURRENT_SCHEMA_VERSION) {
    return decorateForRead(cached, user);
  }

  const t0 = Date.now();
  const ctx = await loadContext({ scopeId, tz, localDate });
  const brief = buildBrief(ctx);
  brief.buildMs = Date.now() - t0;

  const saved = await DayBrief.findOneAndUpdate(key, brief, {
    upsert: true,
    new: true,
    setDefaultsOnInsert: true,
  });

  return decorateForRead(saved, user);
}

/** Call from every mutation that changes the day: meals, groceries, habits, tasks. */
async function bustDayBrief(scopeId) {
  const today = new Date().toISOString().slice(0, 10);
  return DayBrief.deleteMany({ scopeId, localDate: { $gte: today } });
}

module.exports = { getTodayBrief, bustDayBrief, buildBrief, decorateForRead };

PLANBHAI_EOF


echo
echo "2. Checking they parse"
for f in context.adapter builders.service readiness.service daybrief.service; do
  node --check "backend/services/daybrief/$f.js" || { echo "   FAILED: $f.js"; exit 1; }
  echo "   ok   $f.js"
done
echo

echo "3. Clearing cached briefs"
cd backend
node -e "
require('dotenv').config();
const m = require('mongoose');
(async () => {
  await m.connect(process.env.MONGODB_URI);
  const r = await require('./models/DayBrief').deleteMany({});
  console.log('   cleared ' + r.deletedCount + ' cached brief(s)');
  await m.disconnect();
})().catch(e => { console.error('   FAILED: ' + e.message); process.exit(1); });
" || exit 1
cd ..
echo

echo "4. Restarting the server"
if lsof -ti tcp:$PORT >/dev/null 2>&1; then
  kill $(lsof -ti tcp:$PORT) 2>/dev/null
  echo "   stopped the old one"
  sleep 2
fi
cd backend && nohup npm start > "$LOG" 2>&1 & 
cd "$ROOT"
UP=0
for i in $(seq 1 20); do
  sleep 1
  CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 2 "$BASE/api/dashboard/today?tz=$TZ_ARG" 2>/dev/null)
  [ "$CODE" != "000" ] && { UP=1; break; }
done
[ "$UP" = "0" ] && { echo "   did not start. Last 25 log lines:"; tail -25 "$LOG" | sed 's/^/      /'; exit 1; }
echo "   up on port $PORT"
echo

echo "5. Sign in"
read -r -p "   Email: " EMAIL
read -r -s -p "   Password: " PASSWORD
echo
RESP=$(curl -s --max-time 10 -X POST "$BASE/api/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
TOKEN=$(node -e "
  let d; try { d = JSON.parse(process.argv[1]); } catch { process.exit(0); }
  const t = d.token || d.accessToken || d.jwt || (d.data && (d.data.token || d.data.accessToken));
  if (t) console.log(t);
" "$RESP" 2>/dev/null)
[ -z "$TOKEN" ] && { echo "   login failed:"; echo "$RESP" | head -c 300 | sed 's/^/     /'; exit 1; }
echo "   signed in"

USER_ID=$(node -e "
  const p = process.argv[1].split('.')[1]; if (!p) process.exit(0);
  try { const d = JSON.parse(Buffer.from(p,'base64').toString()); console.log(d.id||d._id||d.userId||d.sub||''); } catch {}
" "$TOKEN" 2>/dev/null)
echo

echo "6. Dashboard"
if [ -n "$SCOPE_ARG" ]; then
  SCOPE="$SCOPE_ARG"
else
  SCOPE=$(mongosh "$MONGODB_URI" --quiet --eval "
    const h = db.households.findOne({ members: ObjectId('$USER_ID') }, { _id: 1 });
    print(h ? h._id.toString() : '');
  " 2>/dev/null | tail -1 | tr -d '[:space:]')
fi
[ -z "$SCOPE" ] && { echo "   no household id"; exit 1; }
echo "   scopeId: $SCOPE"
echo

BODY=$(curl -s --max-time 20 "$BASE/api/dashboard/today?scopeId=$SCOPE&tz=$TZ_ARG" -H "Authorization: Bearer $TOKEN")
STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 20 "$BASE/api/dashboard/today?scopeId=$SCOPE&tz=$TZ_ARG" -H "Authorization: Bearer $TOKEN")
echo "   HTTP $STATUS"
echo
[ "$STATUS" != "200" ] && { echo "$BODY" | head -c 500 | sed 's/^/   /'; exit 1; }

node -e "
  const d = JSON.parse(process.argv[1]);
  const line = (k,v) => console.log('   ' + (k+':').padEnd(13) + v);
  line('state', d.state);
  line('greeting', (d.greeting && d.greeting.line) || '-');
  line('readiness', d.readiness ? d.readiness.score + '%  ' + d.readiness.label : 'null (empty state)');
  line('signals', (d.signals||[]).length);
  (d.signals||[]).slice(0,7).forEach(s => console.log('                 ' + s.icon + ' ' + s.text));
  line('timeline', (d.timeline||[]).length);
  (d.timeline||[]).slice(0,6).forEach(t => console.log('                 ' + t.start + '  ' + t.title));
  line('meal', d.meal ? d.meal.title : 'none planned');
  line('upcoming', (d.upcoming||[]).length);
  if (d.readiness) {
    console.log();
    d.readiness.breakdown.filter(b=>b.applicable).forEach(b =>
      console.log('   ' + b.domain.padEnd(10) + String(b.score).padStart(4) + '  ' + (b.reason||'')));
    const off = d.readiness.breakdown.filter(b=>!b.applicable).map(b=>b.domain);
    if (off.length) console.log('   not applicable: ' + off.join(', '));
  }
  console.log();
  const bad = (d.state !== 'empty') && !d.readiness;
  console.log(bad ? '   *** state/readiness disagree — the fix did not apply ***'
                  : '   state and readiness agree');
" "$BODY"

echo
echo "=========================================="
echo "  Server running in background."
echo "  Watch:  tail -f $LOG"
echo "  Stop:   kill \$(lsof -ti tcp:$PORT)"
echo "=========================================="

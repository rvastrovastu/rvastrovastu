#!/usr/bin/env bash
#
# Ports the old dashboard's aiAndRemindersCard intelligence into the rules
# engine, rather than moving the card.
#
# That card was genuinely data-driven and knew three things the engine did not:
#
#   streak_shield          a habit about to break that has a shield. Only the
#                          habit tracker writes streakShields, so this stays
#                          quiet for habits saved in the older shape rather
#                          than implying everyone has one.
#   party_menu_unplanned   a NAMED party within 5 days with no menu.
#   rsvp_pending           guests who have not replied, within 10 days.
#
# Two views computing the same advice on different data is how they drift apart
# and start contradicting each other — which is why this is a port, not a move.
# The engine also reads the whole household; the card only saw one device's
# AppState.
#
# THREE GUARDS, each for a way this could mislead:
#
#   contested   party_event is USER-keyed and several members can hold their
#               own. When more than one names a party, the rules stay silent —
#               saying "the menu isn't planned" when another member already
#               planned it is worse than saying nothing.
#   unnamed     an event with no name is a half-started form, not a party.
#   shields     a shielded habit no longer also fires "streak at risk", which
#               would tell the user their streak is both safe and in danger.
#
# party_event.date is a Swift TimeInterval (2001 epoch), same as events[].date.
#
# Usage:
#   bash ~/Downloads/port-reminders.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
[ -d backend/services/daybrief ] || { echo "ERROR: backend/services/daybrief not found"; exit 1; }

echo "PlanBhai — porting reminder intelligence"
echo

write() {
  local dest="$1"
  [ -f "$dest" ] && cp "$dest" "$dest.bakport"
  cat > "$dest"
  echo "   wrote $dest"
}

echo "1. Backend"
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
  const raw = bundle.mergedArray('habits');

  // Two shapes exist in the wild. Older records use `name` with no id; newer
  // ones written by the habit tracker use `title` plus an id and streakShields.
  // Reading only one of them silently turns the other into nulls.
  const normalized = raw
    .map((h) => ({
      name: h.title || h.name || null,
      streak: h.streak || 0,
      completedToday: Boolean(h.completedToday),
      // Only the habit tracker writes shields; older records have none. Kept as
      // a number so a rule can tell "no shield" from "feature not in use".
      streakShields: Number(h.streakShields || 0),
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
        streakShields: Math.max(prev.streakShields, h.streakShields),
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

/**
 * Party state: the in-progress event, its guests, and its menu.
 *
 * party_event is USER-keyed, and several members can each hold one — so
 * "is the menu planned" has more than one possible answer. bestOf takes the
 * most recently updated, which is a guess, so `contested` is exposed and rules
 * stay quiet when it's true. Telling someone their menu isn't ready when
 * another member already planned it is worse than saying nothing.
 */
async function loadParty(bundle) {
  const best = bundle.bestOf('party_event');
  const event = (best && best.data) || null;

  const rows = bundle.memberRows('party_event').filter((r) => {
    const d = r.data;
    return d && typeof d === 'object' && String(d.name || '').trim();
  });

  const guests = bundle.mergedArray('party_guests');
  const menuItems = bundle.mergedArray('party_menu_items');

  const name = String((event && event.name) || '').trim();

  return {
    // An unnamed event is a half-started form, not a party worth nudging about.
    active: Boolean(name),
    contested: rows.length > 1,
    name,
    dateUtc: event ? swiftDateToUtc(event.date) : null,
    menuPlanned: Boolean(event && event.menuPlanned),
    guestListStarted: Boolean(event && event.guestListStarted),
    shoppingDone: Boolean(event && event.shoppingDone),
    guests: guests.map((g) => ({
      name: g.name,
      rsvpStatus: g.rsvpStatus || 'Pending',
      dietaryRestrictions: g.dietaryRestrictions || '',
    })),
    confirmedCount: guests.filter((g) => g.rsvpStatus === 'Yes').length,
    pendingCount: guests.filter((g) => g.rsvpStatus === 'Pending').length,
    menuItemCount: menuItems.length,
  };
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

  const household = await Household.findById(scopeId)
    .select('members isPremium')
    .lean();
  const memberIds = ((household && household.members) || []).map(String);

  const bundle = await loadAppBundle(scopeId, memberIds);

  const [calendar, meals, groceries, family, habits, finance, party, upcoming, birthdays, weather] =
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
      soft('party', () => loadParty(bundle), {
        active: false, contested: false, guests: [],
        confirmedCount: 0, pendingCount: 0, menuItemCount: 0,
      }),
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
    // Drives the AI ranking tier — premium households get a daily judgement
    // call, everyone else gets score order.
    isPremium: Boolean(household && household.isPremium),
    calendar,
    meals,
    groceries,
    family,
    habits,
    finance,
    party,
    upcoming,
    birthdays,
    weather,
    notes: bundle.shared('household_notes') || [],
    tasks: { scheduled: [] },
  };
}

module.exports = { loadContext, swiftDateToUtc, weekdayName, SWIFT_EPOCH_OFFSET };
PLANBHAI_EOF
write 'backend/services/daybrief/suggestions.service.js' << 'PLANBHAI_EOF'
/**
 * Suggestion rules engine.
 *
 * Every suggestion here is DETERMINISTIC. "You're missing tomatoes" is a pantry
 * diff; "Mom's birthday in 12 days" is date arithmetic; "streak at risk" is a
 * clock comparison. None of it needs a model, none of it can hallucinate, and
 * it costs nothing to run on every request.
 *
 * Phrasing lives in DEFAULT_TEMPLATES below — edit those to change the voice.
 * Placeholders are filled with today's facts at build time.
 *
 * Each rule returns null when it doesn't apply. Ranking happens at the end.
 */

const { localTimeIn, localHourIn, daysBetween } = require('./tz.util');

/** "17:03" -> "5:03 PM". The rest of the app shows 12-hour; so should these. */
function display(hhmm) {
  const [h, m] = String(hhmm).split(':').map(Number);
  if (isNaN(h)) return hhmm;
  const suffix = h < 12 ? 'AM' : 'PM';
  const h12 = h % 12 === 0 ? 12 : h % 12;
  return m === 0 ? `${h12} ${suffix}` : `${h12}:${String(m).padStart(2, '0')} ${suffix}`;
}

/** Phrasing. Edit freely — placeholders in braces are filled from today's facts. */
const DEFAULT_TEMPLATES = {
  calendar_conflict: 'Two things clash at {time}',
  calendar_overload: '{count} events today — want them rearranged?',
  birthday_upcoming: "{name}'s birthday {relative}",
  birthday_upcoming_unnamed: 'A birthday {relative}',
  party_approaching: '{name} is {relative}',
  chores_unassigned: '{count} chores have nobody assigned',
  meal_unplanned: 'No {slot} planned yet',
  grocery_gap: 'Missing {items} for {meal}',
  streak_at_risk: '{name} streak is at {streak} days',
  grocery_ready: '{count} items on your grocery list',
  next_event: '{name} at {time}',
  streak_shield: '{name} streak is safe — you have a shield',
  party_menu_unplanned: "{name} is {relative} and the menu isn't planned",
  rsvp_pending: '{count} guests have not replied to {name}',
};

const fill = (template, vars) =>
  String(template).replace(/\{(\w+)\}/g, (_, k) => (vars[k] == null ? '' : String(vars[k])));

function make({ kind, entityId, localDate, icon, vars, cta, deeplink, webPath, feature, score }) {
  const template = DEFAULT_TEMPLATES[kind];
  return {
    id: `${kind}:${entityId}:${localDate}`,
    kind,
    icon,
    title: fill(template, vars),
    cta,
    deeplink,
    webPath,
    feature,
    score,
  };
}

// ---------------------------------------------------------------------------
// Rules
// ---------------------------------------------------------------------------

/** Two events at the same time — the user probably knows, but confirming helps. */
function ruleCalendarConflict(ctx) {
  const events = (ctx.calendar?.events || [])
    .filter((e) => !e.allDay)
    .sort((a, b) => new Date(a.startUtc) - new Date(b.startUtc));

  for (let i = 1; i < events.length; i++) {
    if (new Date(events[i].startUtc) < new Date(events[i - 1].endUtc)) {
      return make({
        kind: 'calendar_conflict',
        entityId: String(events[i].externalId || i),
        localDate: ctx.localDate,
        icon: '⚠️',
        vars: { time: display(localTimeIn(new Date(events[i].startUtc), ctx.tz)) },
        cta: 'View day',
        deeplink: 'planbhai://planner',
        webPath: '/planner',
        feature: 'planner',
        score: 85,
      });
    }
  }
  return null;
}

function ruleCalendarOverload(ctx) {
  const count = (ctx.calendar?.events || []).filter((e) => !e.allDay).length;
  if (count < 5) return null;
  return make({
    kind: 'calendar_overload',
    entityId: 'today',
    localDate: ctx.localDate,
    icon: '🧠',
    vars: { count },
    cta: 'Rearrange',
    deeplink: 'planbhai://planner',
    webPath: '/planner',
    feature: 'planner',
    score: 70,
  });
}

function ruleBirthday(ctx) {
  const b = (ctx.birthdays || [])[0];
  if (!b) return null;

  // The calendar entry may just be titled "Birthday" with no name attached.
  // "Someone's birthday today" reads like the app lost the name; "A birthday
  // today" is simply what we know.
  const named = Boolean(String(b.name || '').trim());

  return make({
    kind: named ? 'birthday_upcoming' : 'birthday_upcoming_unnamed',
    entityId: b.date || 'bday',
    localDate: ctx.localDate,
    icon: '🎂',
    vars: { name: b.name, relative: b.relative },
    cta: 'Plan something',
    deeplink: 'planbhai://party',
    webPath: '/party',
    feature: 'party',
    score: b.relative === 'today' ? 95 : 75,
  });
}

/** A party within 10 days with nothing prepared yet. */
function ruleParty(ctx) {
  const soon = (ctx.upcoming || []).find((u) => {
    if (u.kind !== 'party') return false;
    const d = daysBetween(ctx.localDate, u.date);
    return d >= 0 && d <= 10;
  });
  if (!soon) return null;

  const d = daysBetween(ctx.localDate, soon.date);
  return make({
    kind: 'party_approaching',
    entityId: soon.date,
    localDate: ctx.localDate,
    icon: '🎉',
    vars: {
      name: soon.title,
      relative: d === 0 ? 'today' : d === 1 ? 'tomorrow' : `in ${d} days`,
    },
    cta: 'Open planner',
    deeplink: 'planbhai://party',
    webPath: '/party',
    feature: 'party',
    score: d <= 2 ? 88 : 60,
  });
}

/**
 * Chores nobody has picked up. Only fires when the household actually uses
 * assignment — a shared list nobody is named on is a normal way to work, and
 * nagging about it would be noise.
 */
function ruleChoresUnassigned(ctx) {
  const obligations = ctx.family?.obligations || [];
  if (obligations.length === 0) return null;

  const assigned = obligations.filter((o) => o.assigneeId).length;
  if (assigned / obligations.length < 0.5) return null;

  const gap = obligations.length - assigned;
  if (gap === 0) return null;

  return make({
    kind: 'chores_unassigned',
    entityId: 'chores',
    localDate: ctx.localDate,
    icon: '🧹',
    vars: { count: gap },
    cta: 'Assign',
    deeplink: 'planbhai://household',
    webPath: '/household',
    feature: 'household',
    score: 65,
  });
}

/** No dinner planned, and it's late enough that it matters. */
function ruleMealUnplanned(ctx) {
  if (!ctx.meals?.used) return null;
  if (ctx.meals.planned) return null;
  if (localHourIn(new Date(ctx.nowUtc), ctx.tz) < 15) return null;

  return make({
    kind: 'meal_unplanned',
    entityId: ctx.meals.primarySlot || 'dinner',
    localDate: ctx.localDate,
    icon: '🍽',
    vars: { slot: ctx.meals.primarySlot || 'dinner' },
    cta: 'Plan it',
    deeplink: 'planbhai://meals',
    webPath: '/meals',
    feature: 'meals',
    score: 90,
  });
}

/**
 * Ingredients the meal needs that aren't on hand.
 *
 * Requires pantry data. Every account currently has an empty pantry, so this
 * never fires today — but it's the single highest-value suggestion in the
 * product, so the rule is here and ready rather than waiting on a rewrite.
 */
function ruleGroceryGap(ctx) {
  const missing = ctx.meals?.planned?.missing || [];
  if (missing.length === 0) return null;

  return make({
    kind: 'grocery_gap',
    entityId: 'dinner',
    localDate: ctx.localDate,
    icon: '🛒',
    vars: {
      items: missing.slice(0, 3).join(', '),
      meal: ctx.meals.planned.title,
    },
    cta: 'Add to list',
    deeplink: 'planbhai://grocery',
    webPath: '/grocery',
    feature: 'grocery',
    score: 92,
  });
}

/** A streak worth protecting, not yet done today. */
function ruleStreakAtRisk(ctx) {
  const at = (ctx.habits?.all || [])
    // Shielded habits are handled by ruleStreakShield. Firing both would tell
    // the user their streak is safe AND at risk about the same habit.
    .filter((h) => !h.completedToday && (h.streak || 0) >= 3 && (h.streakShields || 0) === 0)
    .sort((a, b) => (b.streak || 0) - (a.streak || 0))[0];
  if (!at) return null;

  // Only nudge in the evening. Reminding someone at 8 AM that they haven't done
  // a habit yet is nagging, not helping.
  if (localHourIn(new Date(ctx.nowUtc), ctx.tz) < 17) return null;

  return make({
    kind: 'streak_at_risk',
    entityId: at.name,
    localDate: ctx.localDate,
    icon: '🔥',
    vars: { name: at.name, streak: at.streak },
    cta: 'Mark done',
    deeplink: 'planbhai://habits',
    webPath: '/habits',
    feature: 'habits',
    score: 80,
  });
}

/** The next thing happening, when it's close. */
function ruleNextEvent(ctx) {
  const now = new Date(ctx.nowUtc);
  const next = (ctx.calendar?.events || [])
    .filter((e) => !e.allDay && new Date(e.startUtc) > now)
    .sort((a, b) => new Date(a.startUtc) - new Date(b.startUtc))[0];
  if (!next) return null;

  const minsAway = (new Date(next.startUtc) - now) / 60000;
  if (minsAway > 120) return null;

  return make({
    kind: 'next_event',
    entityId: String(next.externalId || 'next'),
    localDate: ctx.localDate,
    icon: '⏰',
    vars: { name: next.title, time: display(localTimeIn(new Date(next.startUtc), ctx.tz)) },
    cta: 'View',
    deeplink: 'planbhai://planner',
    webPath: '/planner',
    feature: 'planner',
    score: 98,
  });
}

/**
 * A streak that would break today, protected by a shield.
 *
 * Ported from the old dashboard's aiAndRemindersCard — the rules engine had no
 * idea shields existed. Only the habit tracker writes streakShields, so this
 * stays quiet for habits saved in the older shape rather than implying everyone
 * has one.
 */
function ruleStreakShield(ctx) {
  const shielded = (ctx.habits?.all || [])
    .filter((h) => !h.completedToday && (h.streakShields || 0) > 0 && (h.streak || 0) >= 1)
    .sort((a, b) => (b.streak || 0) - (a.streak || 0))[0];
  if (!shielded) return null;

  // Same evening-only guard as the plain streak nudge.
  if (localHourIn(new Date(ctx.nowUtc), ctx.tz) < 17) return null;

  return make({
    kind: 'streak_shield',
    entityId: shielded.name,
    localDate: ctx.localDate,
    icon: '🛡',
    vars: { name: shielded.name },
    cta: 'Mark done',
    deeplink: 'planbhai://habits',
    webPath: '/habits',
    feature: 'habits',
    score: 82,
  });
}

/**
 * A named party within 5 days whose menu isn't planned.
 *
 * Silent when the party state is contested — party_event is user-keyed and
 * several members can hold their own. Telling someone the menu isn't ready when
 * another member already planned it is worse than saying nothing.
 */
function rulePartyMenuUnplanned(ctx) {
  const p = ctx.party;
  if (!p || !p.active || p.contested) return null;
  if (p.menuPlanned || p.menuItemCount > 0) return null;
  if (!p.dateUtc) return null;

  const days = Math.floor((new Date(p.dateUtc) - new Date(ctx.nowUtc)) / 86400000);
  if (days < 0 || days > 5) return null;

  return make({
    kind: 'party_menu_unplanned',
    entityId: p.name,
    localDate: ctx.localDate,
    icon: '🍲',
    vars: {
      name: p.name,
      relative: days === 0 ? 'today' : days === 1 ? 'tomorrow' : `in ${days} days`,
    },
    cta: 'Plan menu',
    deeplink: 'planbhai://party',
    webPath: '/party',
    feature: 'party',
    score: days <= 1 ? 94 : 86,
  });
}

/** Guests who haven't replied, while there's still time to chase them. */
function ruleRsvpPending(ctx) {
  const p = ctx.party;
  if (!p || !p.active || p.contested) return null;
  if (p.pendingCount === 0) return null;
  if (!p.dateUtc) return null;

  const days = Math.floor((new Date(p.dateUtc) - new Date(ctx.nowUtc)) / 86400000);
  if (days < 0 || days > 10) return null;

  return make({
    kind: 'rsvp_pending',
    entityId: `${p.name}:rsvp`,
    localDate: ctx.localDate,
    icon: '👥',
    vars: { count: p.pendingCount, name: p.name },
    cta: 'Chase',
    deeplink: 'planbhai://party',
    webPath: '/party',
    feature: 'party',
    score: days <= 3 ? 84 : 62,
  });
}

// ---------------------------------------------------------------------------

const RULES = [
  ruleNextEvent,
  rulePartyMenuUnplanned,
  ruleGroceryGap,
  ruleBirthday,
  ruleMealIfUnplanned,
  ruleRsvpPending,
  ruleStreakShield,
  ruleCalendarConflict,
  ruleParty,
  ruleStreakAtRisk,
  ruleCalendarOverload,
  ruleChoresUnassigned,
];

// Named separately so the array above reads in priority order.
function ruleMealIfUnplanned(ctx) {
  return ruleMealUnplanned(ctx);
}

/** Every suggestion that applies today, unranked. */
function buildCandidates(ctx) {
  const out = [];
  for (const rule of RULES) {
    try {
      const s = rule(ctx);
      if (s) out.push(s);
    } catch (err) {
      console.error(`[suggestions] rule failed:`, err.message);
    }
  }
  return out;
}

/**
 * Picks the top 3.
 *
 * @param {Array}  candidates
 * @param {Array}  rankOrder  optional list of suggestion ids, best first
 *
 * Three is a deliberate cap. A wall of suggestions is a task list wearing a
 * different hat, and the whole point is that the app already handled things.
 *
 * rankOrder is unused today — scores decide. It exists so an ordering can be
 * supplied later without touching the rules, and it ignores any id that isn't
 * in today's candidates.
 */
function selectTop(candidates, rankOrder = null, limit = 3) {
  if (!Array.isArray(rankOrder) || rankOrder.length === 0) {
    return [...candidates].sort((a, b) => b.score - a.score).slice(0, limit);
  }

  const byId = new Map(candidates.map((c) => [c.id, c]));
  const picked = [];
  const seen = new Set();

  for (const id of rankOrder) {
    const c = byId.get(id);
    if (c && !seen.has(id)) {
      picked.push(c);
      seen.add(id);
    }
    if (picked.length >= limit) break;
  }

  if (picked.length < limit) {
    const rest = candidates
      .filter((c) => !seen.has(c.id))
      .sort((a, b) => b.score - a.score);
    picked.push(...rest.slice(0, limit - picked.length));
  }

  return picked;
}

/** Convenience wrapper: build then select. */
function buildSuggestions(ctx, rankOrder = null) {
  return selectTop(buildCandidates(ctx), rankOrder);
}

module.exports = { buildSuggestions, buildCandidates, selectTop, DEFAULT_TEMPLATES, fill };
PLANBHAI_EOF

for f in context.adapter suggestions.service; do
  node --check "backend/services/daybrief/$f.js" || { echo "   PARSE FAILED: $f"; exit 1; }
done
echo "   both parse"
echo

echo "2. Exercising all twelve rules"
cd backend
cat > ./.pb_rules.js << 'RULES_EOF'
const { buildCandidates } = require("./services/daybrief/suggestions.service");
const iso = (h) => new Date(`2026-07-31T${String(h).padStart(2, "0")}:00:00Z`);

const ctx = {
  tz: "America/Chicago", localDate: "2026-07-31", nowUtc: iso(23),
  calendar: { connected: true, events: [
    { externalId: "a", title: "One",   startUtc: iso(23), endUtc: iso(24) },
    { externalId: "b", title: "Two",   startUtc: iso(23), endUtc: iso(24) },
    { externalId: "c", title: "Three", startUtc: iso(24), endUtc: iso(25) },
    { externalId: "d", title: "Four",  startUtc: iso(25), endUtc: iso(26) },
    { externalId: "e", title: "Five",  startUtc: iso(26), endUtc: iso(27) },
  ]},
  meals: { used: true, primarySlot: "dinner", planned: null },
  groceries: { listExists: false, itemCount: 29 },
  family: { memberCount: 4, obligations: [
    { assigneeId: "x" }, { assigneeId: "y" }, { assigneeId: null },
  ]},
  habits: { all: [
    { name: "Hydration", streak: 6, streakShields: 1, completedToday: false },
    { name: "Reading",   streak: 4, streakShields: 0, completedToday: false },
  ]},
  birthdays: [{ name: "Saarth", relative: "in 3 days" }],
  upcoming: [{ date: "2026-08-05", title: "GetTogether", kind: "party" }],
  party: {
    active: true, contested: false, name: "Saarth Bday",
    dateUtc: new Date("2026-08-03T00:00:00Z"),
    menuPlanned: false, menuItemCount: 0, pendingCount: 3, confirmedCount: 2,
  },
};

const errs = [];
const orig = console.error;
console.error = (...a) => errs.push(a.join(" "));
const found = buildCandidates(ctx);
console.error = orig;

console.log("   rules producing output: " + found.length + " of 12");
found.sort((a,b) => b.score - a.score).forEach(c =>
  console.log("      " + String(c.score).padStart(3) + "  " + c.kind));

// A rule that throws is swallowed so one bad rule can't kill the dashboard —
// which also means it silently stops existing. Surface it here instead.
if (errs.length) {
  console.log("   RULE ERRORS:");
  errs.forEach(e => console.log("      " + e));
  process.exit(1);
}

// Guards
const contested = buildCandidates({ ...ctx, party: { ...ctx.party, contested: true } });
console.log("   contested party suppresses party rules: " +
  (contested.some(c => c.kind.startsWith("party_") || c.kind === "rsvp_pending") ? "NO" : "yes"));

const shielded = buildCandidates({ ...ctx,
  habits: { all: [{ name: "Hydration", streak: 6, streakShields: 1, completedToday: false }] } });
const both = shielded.filter(c => c.kind === "streak_shield" || c.kind === "streak_at_risk");
console.log("   one message per habit: " + (both.length === 1 ? "yes" : "NO (" + both.length + ")"));
RULES_EOF
node ./.pb_rules.js || { echo "   a rule threw — see above"; rm -f ./.pb_rules.js; exit 1; }
rm -f ./.pb_rules.js
echo

echo "3. Clearing the cached brief"
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
echo "     git add -A && git commit -m 'Port reminder rules: shields, party menu, RSVPs' && git push"
echo "  then Manual Deploy on Render."
echo "=========================================="

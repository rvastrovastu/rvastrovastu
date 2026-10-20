#!/usr/bin/env bash
#
# The meal card follows the clock, and the review shows all day.
#
# 1. "TODAY'S DINNER" ALL DAY
#    Both clients ALREADY read meal.slot dynamically — iOS capitalises it, web
#    upper-cases it. The server was hardcoding 'dinner', so both were faithfully
#    rendering the wrong thing.
#
#    Fixed where the fault was. Breakfast until 11, lunch until 16, dinner
#    after — so the card says "Today's breakfast" at 8 AM, which is the meal
#    that actually matters then.
#
#    No client change needed. One deploy covers both.
#
# 2. THE REVIEW WAS HIDDEN 18 HOURS A DAY
#    A hard 6 PM gate meant the card was invisible for most of the hours anyone
#    opens the app. "2 of 8 done" at lunchtime is useful — it just is not a
#    verdict.
#
#    The heading changes instead of the card disappearing:
#        before 6 PM   TODAY SO FAR
#        after         TODAY'S REVIEW
#
#    That was me over-thinking it: hiding useful information to avoid a wording
#    problem a heading solves.
#
# Usage:
#   bash ~/Downloads/meal-slot-and-review.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }

echo "PlanBhai — meal slot + review timing"
echo

echo "1. Backend"
A="backend/services/daybrief/context.adapter.js"
cp "$A" "$A.bakslot"
cat > "$A" << 'PLANBHAI_EOF'
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

/**
 * Do two item names refer to the same thing?
 *
 * Mirrors AppState.itemsMatch on iOS deliberately — "have paneer" and "need
 * paneer" must not disagree because one side runs on the server. Receipts say
 * "PANEER 500G MALAI"; grocery lists say "Paneer".
 *
 * KNOWN: substring matching means "Butter" matches "Peanut Butter", so
 * haveRatio reads optimistic. The honest fix is a curated alias list, not a
 * cleverer regex, and only worth building if it bites.
 */
function itemsMatch(a, b) {
  const x = String(a || '').toLowerCase().trim();
  const y = String(b || '').toLowerCase().trim();
  if (!x || !y) return false;
  // Two characters would match almost anything; three is the shortest real
  // grocery word — egg, oil, tea.
  if (x.length < 3 || y.length < 3) return x === y;
  return x.includes(y) || y.includes(x);
}

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

/**
 * Which meal is the one to show right now.
 *
 * The card always said "Today's dinner", which is useful for about four hours a
 * day and stale for the rest — at 8 AM the meal that matters is breakfast.
 *
 * Boundaries: breakfast until 11, lunch until 16, dinner after.
 */
function currentMealSlot(nowUtc, tz) {
  const hour = Number(
    new Intl.DateTimeFormat('en-US', { timeZone: tz, hour: 'numeric', hour12: false })
      .format(nowUtc)
  );
  if (hour < 11) return 'breakfast';
  if (hour < 16) return 'lunch';
  return 'dinner';
}

async function loadMeals(bundle, tz, localDate, nowUtc = new Date()) {
  const slot = currentMealSlot(nowUtc, tz);
  // Pantry is user-keyed, so merge across members: a household cooks from one
  // kitchen even though the app stores the inventory per person.
  const pantry = [
    ...(bundle.shared('pantry') || []),
    ...bundle.mergedArray('pantry'),
  ]
    .map((p) => p && (p.name || p.item))
    .filter(Boolean);

  const best = bundle.bestOf('meal_plan');
  if (!best || !Array.isArray(best.data.meals)) {
    return { used: false, primarySlot: slot, planned: null, slots: [] };
  }

  const today = weekdayName(localDate, tz);
  const row = best.data.meals.find((m) => m.day === today);

  if (!row) return { used: true, primarySlot: slot, planned: null, slots: [] };

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

  // Whichever meal is current, falling back to dinner so a half-filled plan
  // still shows something rather than nothing.
  const meal = row[slot] || row.dinner;

  // Which of this week's grocery items are already on hand?
  //
  // meal_plan carries ONE groceryList for the whole week rather than per meal,
  // so this is the week's coverage, not tonight's dish specifically. That is
  // the honest granularity the data supports — claiming per-dish precision
  // from week-level input would be a more confident lie than saying nothing.
  const weekList = (best.data.groceryList || [])
    .map((g) => g && (g.item || g.name))
    .filter(Boolean);

  let haveRatio = null;
  let missing = [];

  if (pantry.length > 0 && weekList.length > 0) {
    const have = weekList.filter((item) => pantry.some((p) => itemsMatch(p, item)));
    haveRatio = have.length / weekList.length;
    missing = weekList.filter((item) => !pantry.some((p) => itemsMatch(p, item))).slice(0, 8);
  }
  // With an empty pantry haveRatio stays null — genuinely unknown, not zero.
  // readiness scores 60 for "planned, coverage unknown" rather than punishing a
  // real meal plan for missing data.

  return {
    used: true,
    primarySlot: slot,
    pantryCount: pantry.length,
    planned:
      meal && meal.name
        ? {
            title: meal.name,
            recipeId: null,
            haveRatio,
            missing,
            calories: meal.calories == null ? null : meal.calories,
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
async function loadHabits(bundle, localDate) {
  const raw = bundle.mergedArray('habits');

  // Two shapes exist in the wild. Older records use `name` with no id; newer
  // ones written by the habit tracker use `title` plus an id and streakShields.
  // Reading only one of them silently turns the other into nulls.
  const normalized = raw
    .map((h) => ({
      name: h.title || h.name || null,
      streak: h.streak || 0,
      // Derive completion from the date where we have one. Nothing clears the
      // bare `completedToday` boolean at midnight — on iOS a launch-time pass
      // covered it, on web nothing did — so trusting it would show yesterday's
      // ticks as today's. Records without a date fall back to the boolean.
      completedToday: h.lastCompletedDate
        ? h.lastCompletedDate === localDate
        : Boolean(h.completedToday),
      lastCompletedDate: h.lastCompletedDate || null,
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
      soft('meals', () => loadMeals(bundle, tz, localDate, nowUtc), {
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
      soft('habits', () => loadHabits(bundle, localDate), {
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
node --check "$A" || { echo "   PARSE FAILED — reverting"; cp "$A.bakslot" "$A"; exit 1; }
echo "   wrote + parses"
grep -q "function currentMealSlot" "$A" && echo "   ok   slot follows the clock"
echo

echo "2. Web"
W="web/src/pages/Brief.jsx"
cp "$W" "$W.bakslot"
cat > "$W" << 'PLANBHAI_EOF'
import { useEffect, useState, useCallback } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api';
import { useHousehold } from '../HouseholdContext';
import { useAuth } from '../AuthContext';

/**
 * The Brief — the same DayBrief contract iOS renders, in web's light theme.
 *
 * Structure is ported; styling is not. iOS is dark charcoal with jewel tones;
 * this is Serene Productivity — cream, sage, terracotta. A glassmorphic dark
 * card would look broken here.
 *
 * Two honesty rules carried over from iOS:
 *   1. A section with no data does not render. An empty shell implies the app
 *      knows something it doesn't.
 *   2. Nothing is computed client-side. Every number comes from the brief.
 */

// Suggestions carry both `deeplink` (planbhai://) and `webPath`. Web uses
// webPath — but the contract's /habits and /grocery don't exist in this
// router, so they're translated rather than left to 404.
const PATH_MAP = {
  '/habits': '/lifestyle',
  '/grocery': '/meals',
  '/planner': '/calendar',
};
const webRoute = (p) => (p ? PATH_MAP[p] || p : null);

function ringColor(score) {
  if (score >= 80) return 'var(--forest)';
  if (score >= 60) return 'var(--teal)';
  if (score >= 40) return 'var(--amber)';
  return 'var(--rose)';
}

/** "19:00" -> "7 PM". The server sends 24h; people read 12h. */
function displayTime(hhmm) {
  const [h, m] = String(hhmm || '').split(':').map(Number);
  if (Number.isNaN(h)) return hhmm;
  const suffix = h < 12 ? 'AM' : 'PM';
  const h12 = h % 12 === 0 ? 12 : h % 12;
  return m === 0 ? `${h12} ${suffix}` : `${h12}:${String(m).padStart(2, '0')} ${suffix}`;
}

function relativeSync(iso) {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return 'recently';
  const mins = Math.floor((Date.now() - d.getTime()) / 60000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m ago`;
  return `${Math.floor(mins / 60)}h ago`;
}

export default function Brief({ embedded = false }) {
  const { scopeId } = useHousehold();
  const { user } = useAuth();

  const [brief, setBrief] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showBreakdown, setShowBreakdown] = useState(false);
  const [pending, setPending] = useState(null);   // habit name mid-request
  const [acting, setActing] = useState(null);     // suggestion id mid-request
  const [review, setReview] = useState(null);

  const load = useCallback(async () => {
    if (!scopeId) return;              // HouseholdContext resolves it async
    setLoading(true);
    setError('');
    try {
      const tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
      setBrief(await api.fetchDayBrief(scopeId, tz));
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }, [scopeId]);

  // Depending on scopeId rather than checking it once avoids the race iOS hit:
  // the household resolves after first render, and a one-shot check loses.
  useEffect(() => { load(); }, [load]);

  // Shown all day. A hard 6 PM gate hid the card for most of the hours anyone
  // opens the app — and "2 of 8 done" at lunchtime is useful, it just is not a
  // verdict. The heading changes instead of the card disappearing.
  useEffect(() => {
    if (!scopeId) return;
    let cancelled = false;
    (async () => {
      try {
        const tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
        const res = await api.fetchDayReview(scopeId, tz);
        if (!cancelled) setReview(res?.review || null);
      } catch {
        // Silent. A missing review should not disturb the rest of the page.
      }
    })();
    return () => { cancelled = true; };
  }, [scopeId]);

  /**
   * Performs a suggestion's action, then reloads so the row disappears and the
   * counts update. Reload rather than optimistic patching: adding groceries
   * changes the gap suggestion, the grocery count and the meal coverage bar at
   * once, and guessing all three client-side would drift.
   */
  const runAction = async (s) => {
    if (acting) return;
    setActing(s.id);
    try {
      const res = await api.runSuggestionAction(scopeId, s.action);
      await load();
      if (res?.added === 0 && res?.skipped > 0) {
        alert('Those are already on your list.');
      }
    } catch (e) {
      alert(`Couldn't do that: ${e.message}`);
    } finally {
      setActing(null);
    }
  };

  /**
   * Toggle one of YOUR habits. The garden only ever shows your own, so there is
   * nothing here that belongs to someone else.
   *
   * Optimistic: the flower changes immediately and reverts if the write fails.
   * A tap that appears to do nothing for 300ms feels broken.
   */
  const toggleHabit = async (habit) => {
    if (pending) return;
    const next = !habit.completedToday;
    setPending(habit.name);

    setBrief((prev) => {
      if (!prev?.habits?.all) return prev;
      const all = prev.habits.all.map((h) =>
        h.name === habit.name
          ? { ...h, completedToday: next, streak: Math.max((h.streak || 0) + (next ? 1 : -1), 0) }
          : h
      );
      return {
        ...prev,
        habits: { ...prev.habits, all, completedToday: all.filter((h) => h.completedToday).length },
      };
    });

    try {
      const tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
      await api.completeHabit(habit.name, next, tz);
    } catch (e) {
      // Put it back rather than leaving a flower that lies.
      setBrief((prev) => {
        if (!prev?.habits?.all) return prev;
        const all = prev.habits.all.map((h) =>
          h.name === habit.name
            ? { ...h, completedToday: habit.completedToday, streak: habit.streak }
            : h
        );
        return {
          ...prev,
          habits: { ...prev.habits, all, completedToday: all.filter((h) => h.completedToday).length },
        };
      });
      alert(`Couldn't update that habit: ${e.message}`);
    } finally {
      setPending(null);
    }
  };

  if (!scopeId) {
    return (
      <div className="content-container">
        <div className="card empty-state">
          <div className="empty-state-icon">🏠</div>
          <div className="empty-state-text">Pick a household to see your day.</div>
        </div>
      </div>
    );
  }

  if (loading && !brief) {
    return (
      <div className="content-container">
        <div className="loading-spinner" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="content-container">
        <div className="card empty-state">
          <div className="empty-state-icon">⚠️</div>
          <div className="empty-state-text">{error}</div>
          <button className="btn-secondary" onClick={load} style={{ marginTop: 12 }}>
            Try again
          </button>
        </div>
      </div>
    );
  }

  if (!brief) return null;

  const b = brief;
  const r = b.readiness;
  const counts = b.counts || {};

  const dayAndDate = (() => {
    // From the brief's own localDate, not the browser clock — they disagree
    // around midnight and while travelling, and a date contradicting the data
    // below it is worse than none.
    const d = new Date(`${b.localDate}T12:00:00`);
    return d.toLocaleDateString(undefined, {
      weekday: 'long', month: 'long', day: 'numeric',
    }).toUpperCase();
  })();

  const firstName = (user?.name || '').split(' ')[0];
  const timeOfDay = b.greeting?.timeOfDay || 'day';
  const salutation = firstName
    ? `Good ${timeOfDay.charAt(0).toUpperCase() + timeOfDay.slice(1)}, ${firstName}`
    : `Good ${timeOfDay}`;

  const heroLines = [];
  if (counts.events > 0) heroLines.push(`${counts.events} event${counts.events === 1 ? '' : 's'} today`);
  if (counts.meals > 0) heroLines.push(`${counts.meals} meal${counts.meals === 1 ? '' : 's'} planned`);
  if (b.habits?.total > 0) heroLines.push(`${b.habits.completedToday || 0} of ${b.habits.total} habits done`);
  if (counts.choresOpen > 0) heroLines.push(`${counts.choresOpen} chore${counts.choresOpen === 1 ? '' : 's'} to pick up`);
  if (counts.groceries > 0) heroLines.push(`${counts.groceries} items on the grocery list`);
  if (counts.upcoming > 0) heroLines.push(`${counts.upcoming} thing${counts.upcoming === 1 ? '' : 's'} coming up`);

  const applicable = (r?.breakdown || []).filter((d) => d.applicable);
  const weakest = applicable.length
    ? applicable.reduce((a, c) => (a.score <= c.score ? a : c))
    : null;
  const notCounted = (r?.breakdown || []).filter((d) => !d.applicable).map((d) => d.domain);

  const earned = [];
  if (b.habits?.longestStreak >= 3) earned.push(['🔥', `${b.habits.longestStreak} day streak`]);
  if (b.habits?.total > 0 && b.habits.completedToday === b.habits.total) earned.push(['💪', 'All habits done']);
  if (counts.choresDone > 0) earned.push(['🏆', `${counts.choresDone} chores done`]);
  if (r?.score >= 90) earned.push(['✨', 'Day under control']);

  return (
    <div className={embedded ? "brief brief-embedded" : "brief"}>
      {/* Hero — skipped when embedded, because the Dashboard's own hero
          already carries the date, greeting, readiness ring and counts. */}
      {!embedded && (
      <div className="brief-hero">
        <div className="brief-hero-top">
          <div>
            <div className="brief-date">{dayAndDate}</div>
            <div className="brief-salutation">{salutation}</div>
            <div className="brief-line">{b.greeting?.line}</div>
          </div>
          <img src="/logo.png" alt="" className="brief-logo" />
        </div>

        {heroLines.length > 0 && (
          <>
            <div className="brief-divider" />
            <ul className="brief-checklist">
              {heroLines.map((line) => (
                <li key={line}><span className="brief-check">✓</span>{line}</li>
              ))}
            </ul>
          </>
        )}

        {r && (
          <div className="brief-hero-verdict">
            {r.score >= 80 ? 'Everything fits.' : r.label}
          </div>
        )}
      </div>
      )}

      {/* Today's Focus */}
      {r && (
        <div className="card brief-section">
          <div className="brief-label">TODAY'S FOCUS</div>
          <div className="brief-focus">
            <div
              className="brief-ring"
              style={{
                background: `conic-gradient(${ringColor(r.score)} ${r.score * 3.6}deg, var(--bg-card-soft) 0deg)`,
              }}
            >
              <div className="brief-ring-inner">
                {/* Wrapped so the number and % align to each other's baseline,
                    while the pair as a whole stays centred in the circle.
                    Baseline-aligning them directly against the circle pushed
                    the group low and left. */}
                <span className="brief-ring-value">
                  <span className="brief-ring-score">{r.score}</span>
                  <span className="brief-ring-pct">%</span>
                </span>
              </div>
            </div>
            <div>
              <div className="brief-focus-label">{r.label}</div>
              {/* A score with no explanation is anxiety with a percentage
                  attached — always pair it with the weakest domain. */}
              {weakest?.reason && <div className="brief-focus-reason">{weakest.reason}</div>}
            </div>
          </div>

          {applicable.length > 0 && (
            <>
              <button className="brief-link" onClick={() => setShowBreakdown((v) => !v)}>
                {showBreakdown ? 'Hide detail' : 'Why this score?'}
              </button>
              {showBreakdown && (
                <div className="brief-breakdown">
                  {applicable.map((d) => (
                    <div className="brief-breakdown-row" key={d.domain}>
                      <span className="brief-domain">{d.domain}</span>
                      <span className="brief-domain-score" style={{ color: ringColor(d.score) }}>
                        {d.score}
                      </span>
                      <span className="brief-domain-reason">{d.reason}</span>
                    </div>
                  ))}
                  {notCounted.length > 0 && (
                    <div className="brief-not-counted">Not counted: {notCounted.join(', ')}</div>
                  )}
                </div>
              )}
            </>
          )}
        </div>
      )}

      {/* Suggestions
        *
        * A suggestion with an `action` DOES the thing; one without navigates.
        * Previously every CTA was a label on a link, so "Add to list" opened a
        * screen rather than adding anything — the button promised something the
        * row never performed. */}
      {b.suggestions?.length > 0 && (
        <div className="card brief-section">
          <div className="brief-label">BHAI SUGGESTS</div>
          {b.suggestions.map((s) => {
            const to = webRoute(s.webPath);
            const busy = acting === s.id;

            const body = (
              <>
                <span className="brief-suggestion-icon">{s.icon}</span>
                <span className="brief-suggestion-text">{s.title}</span>
              </>
            );

            if (s.locked) {
              return (
                <div className="brief-suggestion" key={s.id}>
                  {body}<span className="brief-cta locked">🔒</span>
                </div>
              );
            }

            if (s.action) {
              return (
                <div className="brief-suggestion" key={s.id}>
                  {body}
                  <button
                    className="brief-cta brief-cta-btn"
                    disabled={busy}
                    onClick={() => runAction(s)}
                  >
                    {busy ? 'Adding…' : s.cta}
                  </button>
                </div>
              );
            }

            return to ? (
              <Link className="brief-suggestion" to={to} key={s.id}>
                {body}{s.cta && <span className="brief-cta">{s.cta}</span>}
              </Link>
            ) : (
              <div className="brief-suggestion" key={s.id}>
                {body}{s.cta && <span className="brief-cta">{s.cta}</span>}
              </div>
            );
          })}
        </div>
      )}

      {/* Timeline */}
      {b.timeline?.length > 0 && (
        <div className="card brief-section">
          <div className="brief-label">TODAY'S TIMELINE</div>
          <div className="brief-timeline">
            {b.timeline.map((t, i) => (
              <div className={`brief-tl-row${t.isNow ? ' now' : ''}`} key={`${t.start}-${i}`}>
                <span className="brief-tl-time">{displayTime(t.start)}</span>
                <span className="brief-tl-rail">
                  <span className="brief-tl-dot" />
                  {i < b.timeline.length - 1 && <span className="brief-tl-line" />}
                </span>
                <span className="brief-tl-title">
                  {t.icon && <span className="brief-tl-icon">{t.icon}</span>}
                  {t.title}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Ask BhAI — skipped when embedded. The Dashboard has a real composer
          that calls /api/ai/bhai; this one only navigates, so showing both
          would put the weaker version underneath the working one. */}
      {!embedded && (
      <div className="card brief-section">
        <div className="brief-label">ASK BhAI</div>
        <div className="brief-prompts">
          {[
            ['🍽', 'Plan dinner', '/meals'],
            ['📅', 'Schedule my week', '/meals'],
            ['📖', 'Find recipes', '/meals'],
            ['🛒', 'Grocery list', '/meals'],
            ['🎂', 'Organize a party', '/party'],
            ['💪', 'Build a habit', '/lifestyle'],
            ['💰', 'Split expenses', '/household'],
            ['👨‍👩‍👧', 'Family plans', '/household'],
          ].map(([icon, text, to]) => (
            <Link className="brief-prompt" to={to} key={text}>
              <span>{icon}</span>{text}
            </Link>
          ))}
        </div>
      </div>
      )}

      {/* My Day — schedule blocks live on their own page. Counting only
          schedule rows means the label describes what tapping actually edits. */}
      {(() => {
        const blocks = (b.timeline || []).filter((t) => t.source === 'schedule').length;
        return (
          <Link className="card brief-myday" to="/my-day">
            <span className="brief-myday-icon">🗓</span>
            <span className="brief-myday-text">
              <strong>My Day</strong>
              <small>
                {blocks === 0
                  ? 'Set up the shape of your day'
                  : `${blocks} block${blocks === 1 ? '' : 's'} today · edit`}
              </small>
            </span>
            <span className="brief-myday-chev">›</span>
          </Link>
        );
      })()}

      {/* Households. Which one you are in changes almost everything else on
          this page, so it belongs here rather than only in Me. */}
      <Link className="card brief-myday" to="/household">
        <span className="brief-myday-icon">🏠</span>
        <span className="brief-myday-text">
          <strong>{b.householdName || 'Household'}</strong>
          <small>Meals, chores, wall and calendar</small>
        </span>
        <span className="brief-myday-chev">›</span>
      </Link>

      {/* Evening review. Counts are rules; only the sentence is written by a
          model, over facts it was handed. */}
      {review?.hasSchedule && (
        <div className="card brief-section">
          <div className="brief-label">
            {new Date().getHours() >= 18 ? "TODAY'S REVIEW" : 'TODAY SO FAR'}
          </div>

          <p className="review-summary">{review.summary}</p>

          <div className="review-count">
            {review.today.done} of {review.today.scheduled} done
            {review.today.moved > 0 && <span className="review-moved"> · {review.today.moved} moved</span>}
          </div>

          {/* A week's tally, not a day's. One missed session is a Tuesday;
              0/5 is the app noticing something you would not. */}
          {review.week?.slipping?.length > 0 && (
            <div className="review-block">
              <div className="review-sub">SLIPPING THIS WEEK</div>
              {review.week.slipping.map((t) => (
                <div className="review-row" key={t.title}>
                  <span>{t.title}</span>
                  <strong>{t.done}/{t.of}</strong>
                </div>
              ))}
            </div>
          )}

          {review.week?.consistent?.length > 0 && (
            <div className="review-steady">
              Holding steady: {review.week.consistent.map((t) => t.title).join(', ')}
            </div>
          )}
        </div>
      )}

      {/* Upcoming */}
      {b.upcoming?.length > 0 && (
        <div className="card brief-section">
          <div className="brief-label">UPCOMING</div>
          <div className="brief-scroll">
            {b.upcoming.map((u) => (
              <div className="brief-upcoming-row" key={`${u.date}-${u.title}`}>
                <span className="brief-upcoming-day">{u.day}</span>
                <span>{u.icon} {u.title}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Family */}
      {b.family?.length > 0 && (
        <div className="card brief-section">
          <div className="brief-label">FAMILY</div>
          <div className="brief-scroll">
            {b.family.map((m) => (
              <div className="brief-family-row" key={m.memberId || m.name}>
                <span className="brief-avatar">{(m.name || '?').charAt(0).toUpperCase()}</span>
                <span className="brief-family-text">
                  <strong>{m.name}</strong>
                  <small>{m.status}</small>
                </span>
                {m.state === 'done' && <span className="brief-done">✓</span>}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Meal */}
      {b.meal && (
        <div className="card brief-section">
          <div className="brief-label">TODAY'S {(b.meal.slot || 'dinner').toUpperCase()}</div>
          <div className="brief-meal-title">{b.meal.title}</div>
          {typeof b.meal.haveRatio === 'number' && (
            <div className="brief-meal-bar">
              <div style={{ width: `${Math.round(b.meal.haveRatio * 100)}%` }} />
              <span>{Math.round(b.meal.haveRatio * 100)}% available</span>
            </div>
          )}
          {b.meal.missing?.length > 0 && (
            <div className="brief-meal-missing">Need: {b.meal.missing.join(', ')}</div>
          )}
          {/* haveRatio null means the pantry is empty and coverage is genuinely
              unknown. Saying nothing beats implying everything's on hand. */}
        </div>
      )}

      {/* Habit garden */}
      {b.habits?.total > 0 && (
        <div className="card brief-section">
          <div className="brief-label">HABIT GARDEN</div>
          <div className="brief-garden">
            {(b.habits.all || []).map((h) => (
              <button
                type="button"
                className={`brief-sprout${pending === h.name ? ' busy' : ''}`}
                key={h.name}
                onClick={() => toggleHabit(h)}
                aria-pressed={h.completedToday}
                title={h.completedToday ? 'Tap to undo' : 'Tap to mark done'}
              >
                <span className={h.completedToday ? '' : 'dim'}>
                  {h.completedToday ? '🌸' : '🌱'}
                </span>
                <small>{h.name}</small>
                {h.streak > 0 && <em>{h.streak}d</em>}
              </button>
            ))}
          </div>
          <div className="brief-garden-count">
            {b.habits.completedToday} of {b.habits.total} blooming today
            {b.habits.household && b.habits.household.total > b.habits.total && (
              <span className="brief-garden-household">
                {' · '}household {b.habits.household.completedToday}/{b.habits.household.total}
              </span>
            )}
          </div>
        </div>
      )}

      {/* Achievements — only badges backed by real data. */}
      {earned.length > 0 && (
        <div className="card brief-section">
          <div className="brief-label">ACHIEVEMENTS</div>
          <div className="brief-badges">
            {earned.map(([emoji, title]) => (
              <div className="brief-badge" key={title}>
                <span>{emoji}</span><small>{title}</small>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Web's timeline is only as fresh as the last iOS sync. Showing the
          staleness beats a timeline people quietly stop trusting. */}
      {b.calendarSyncedAt && (
        <div className="brief-sync">Calendar synced {relativeSync(b.calendarSyncedAt)}</div>
      )}
    </div>
  );
}
PLANBHAI_EOF
grep -q "TODAY SO FAR" "$W" && echo "   ok   review shows all day" \
  || { echo "   MISSING — reverting"; cp "$W.bakslot" "$W"; exit 1; }
echo

echo "3. iOS — reminder"
grep -q "private var isEvening: Bool { true }" PlanBhai/ios/PlanBhai/Views/DayBriefView.swift \
  && echo "   ok   already showing all day" \
  || echo "   NOT YET — run the isEvening change from the previous step"
echo

echo "4. Clearing the cached brief"
cd backend
cat > ./.pb_bust.js << 'BUST_EOF'
require("dotenv").config();
const m = require("mongoose");
(async () => {
  await m.connect(process.env.MONGODB_URI);
  const r = await require("./models/DayBrief").deleteMany({});
  console.log("   cleared " + r.deletedCount + " — the old slot was cached");
  await m.disconnect();
})().catch(e => { console.error("   " + e.message); process.exit(0); });
BUST_EOF
node ./.pb_bust.js
rm -f ./.pb_bust.js
cd ..
echo

echo "5. Building web"
(cd web && npm run build 2>&1 | grep -E "ERROR|error during|✓ built" | head -4)
echo

echo "=========================================="
echo "  Deploy BOTH — the meal slot is server-side:"
echo "     git add -A && git commit -m 'Meal card follows the clock; review shows all day' && git push"
echo "     (Render: Manual Deploy)   then   cd web && vercel --prod"
echo
echo "  Check it right now:"
echo "     curl the brief and look at meal.slot — before 11 it should read"
echo "     breakfast, not dinner."
echo "=========================================="

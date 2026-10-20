#!/usr/bin/env bash
#
# Tappable habit garden.
#
# WHAT CHANGES
#   The garden now shows YOUR habits, not the household's merged set. Everything
#   in it is yours, so everything is tappable — and there is no way to tick off
#   somebody else's water intake. A household count sits beside your own so a
#   shared dashboard doesn't feel solitary.
#
# THE BUG THIS FIXES ALONG THE WAY
#   Habits stored `completedToday` as a bare boolean with no date, and nothing
#   cleared it at midnight. iOS survived on a launch-time pass; web had nothing,
#   so a tapped habit would have read as complete forever.
#
#   Records now carry `lastCompletedDate`, and completion is DERIVED from it
#   rather than trusted. The field is additive — older records fall back to the
#   boolean until their next write.
#
# THE STREAK RULE, and how it differs from the old iOS behaviour
#   iOS decremented the streak on any un-complete. Right for a mis-tap, wrong
#   the next morning: un-checking Monday's habit on Tuesday removed a day that
#   was legitimately earned. Now only TODAY's completion is reversible.
#
#   The arithmetic lives on the server so both clients agree. iOS's local
#   completeHabit() is untouched and still used by the habit tracker screen —
#   worth migrating it to this endpoint later so there is one rule, not two.
#
# Usage:
#   bash ~/Downloads/install-habit-tap.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
[ -d backend/services ] || { echo "ERROR: backend/services not found"; exit 1; }
[ -d web/src/pages ] || { echo "ERROR: web/src/pages not found"; exit 1; }

echo "PlanBhai — tappable habit garden"
echo

write() {
  local dest="$1"
  [ -f "$dest" ] && cp "$dest" "$dest.bakhabit"
  cat > "$dest"
  echo "   wrote $dest"
}

echo "1. Backend"
write 'backend/services/habits.service.js' << 'PLANBHAI_EOF'
const AppData = require('../models/AppData');
const { localDateIn } = require('./daybrief/tz.util');

/**
 * Habit completion — the one place that decides what a streak is worth.
 *
 * WHY THIS EXISTS ON THE SERVER
 *   Habits are stored as { name, streak, completedToday, streakShields } with
 *   no date attached, and nothing ever clears `completedToday`. On iOS that was
 *   survivable because a forgiving-streak pass runs at app launch. On web
 *   nothing runs, so a tapped habit would read as complete forever.
 *
 *   Adding `lastCompletedDate` lets completion be derived rather than trusted:
 *   a habit is complete today only if it was completed today. The field is
 *   additive — records without it still work, they just fall back to the old
 *   boolean until their next write.
 *
 * THE RULE, and how it differs from iOS
 *   iOS decrements the streak on any un-complete. That is right for a mis-tap
 *   and wrong the next morning: un-checking Monday's habit on Tuesday removed
 *   a day that was legitimately earned. With a date we can tell those apart —
 *   only today's completion is worth taking back.
 */

/** Today in the caller's timezone. Habits roll over at local midnight. */
const todayIn = (tz) => localDateIn(new Date(), tz || 'UTC');

/**
 * Is this habit complete *today*?
 *
 * Prefers the date. Falls back to the stored boolean only for records written
 * before the date existed — otherwise a habit ticked last week would still
 * read as done.
 */
function isCompleteToday(habit, today) {
  if (habit.lastCompletedDate) return habit.lastCompletedDate === today;
  return Boolean(habit.completedToday);
}

/** Habits carry either `title` (tracker) or `name` (older records). */
const habitName = (h) => h.title || h.name || null;

const sameHabit = (h, name) =>
  String(habitName(h) || '').trim().toLowerCase() === String(name).trim().toLowerCase();

/**
 * Toggles one habit for one user.
 *
 * @param {string} userId  the CALLER's id — never another member's. The garden
 *                         shows only your own habits, so there is nothing to
 *                         tap that isn't yours.
 * @param {string} name    habit name
 * @param {boolean} done   desired state
 * @param {string} tz      caller's timezone; decides when "today" rolls over
 */
async function setHabitCompletion({ userId, name, done, tz }) {
  const today = todayIn(tz);

  const row = await AppData.findOne({ userId, type: 'habits' }).lean();
  if (!row || !Array.isArray(row.data)) {
    return { ok: false, reason: 'no habits for this user' };
  }

  const habits = row.data.map((h) => ({ ...h }));
  const idx = habits.findIndex((h) => sameHabit(h, name));
  if (idx === -1) return { ok: false, reason: 'habit not found' };

  const h = habits[idx];
  const wasCompleteToday = isCompleteToday(h, today);

  if (done && !wasCompleteToday) {
    h.streak = (h.streak || 0) + 1;
    h.completedToday = true;
    h.lastCompletedDate = today;
  } else if (!done && wasCompleteToday) {
    // Only today's completion is reversible. A streak earned on previous days
    // is not undone by un-checking today — that was the iOS bug.
    h.streak = Math.max((h.streak || 0) - 1, 0);
    h.completedToday = false;
    h.lastCompletedDate = null;
  } else {
    // Already in the requested state. Still normalize the stale boolean so the
    // record stops lying about a completion from another day.
    h.completedToday = wasCompleteToday;
  }

  habits[idx] = h;

  await AppData.findOneAndUpdate(
    { userId, type: 'habits' },
    { userId, type: 'habits', data: habits },
    { upsert: true }
  );

  return {
    ok: true,
    habit: {
      name: habitName(h),
      streak: h.streak || 0,
      completedToday: isCompleteToday(h, today),
      streakShields: h.streakShields || 0,
    },
  };
}

module.exports = { setHabitCompletion, isCompleteToday, habitName, todayIn };
PLANBHAI_EOF
write 'backend/routes/habits.routes.js' << 'PLANBHAI_EOF'
const express = require('express');
const { setHabitCompletion } = require('../services/habits.service');
const { bustBriefsForOwner } = require('../services/daybrief/daybrief.service');
const { isValidTz } = require('../services/daybrief/tz.util');

const router = express.Router();

// >>> EDIT if your middleware is named differently.
const requireAuth = require('../middleware/requireAuth');

/**
 * POST /api/habits/complete   { name, done, tz }
 *
 * Writes only to the CALLER's own habits. The garden shows your habits and
 * nobody else's, so there is nothing tappable that isn't yours — which means no
 * ownership check is needed beyond authentication.
 */
router.post('/complete', requireAuth, async (req, res) => {
  const userId = String(req.user._id);
  const { name, done, tz } = req.body || {};

  if (!name || typeof name !== 'string') {
    return res.status(400).json({ success: false, message: 'name is required' });
  }
  if (typeof done !== 'boolean') {
    return res.status(400).json({ success: false, message: 'done must be true or false' });
  }
  // Habits roll over at the user's local midnight, not the server's.
  const zone = isValidTz(tz) ? tz : 'UTC';

  try {
    const result = await setHabitCompletion({ userId, name, done, tz: zone });
    if (!result.ok) {
      return res.status(404).json({ success: false, message: result.reason });
    }

    // The brief caches habit state; without this the garden would revert on the
    // next load until midnight.
    await bustBriefsForOwner(userId).catch((e) =>
      console.error('[habits] cache bust failed:', e.message)
    );

    return res.json({ success: true, habit: result.habit });
  } catch (err) {
    console.error('[habits/complete]', err);
    return res.status(500).json({ success: false, message: 'Could not update the habit' });
  }
});

module.exports = router;
PLANBHAI_EOF
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
write 'backend/services/daybrief/daybrief.service.js' << 'PLANBHAI_EOF'
const mongoose = require('mongoose');
const DayBrief = require('../../models/DayBrief');
const Household = require('../../models/Household');
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
const { buildSuggestions } = require('./suggestions.service');
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
    suggestions: buildSuggestions(ctx),
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

    // Habits carry no schedule, so they stay out of the readiness score (see
    // readiness.service.js) — but the client still needs them for the habit
    // garden and the streak badge, so they're exposed here.
    // Household-wide totals only. The per-user split happens in
    // decorateForRead — the brief is shared, so it cannot bake in one member's
    // habits without showing them to everyone.
    habits: {
      total: ctx.habits?.total || 0,
      completedToday: ctx.habits?.completedToday || 0,
      longestStreak: ctx.habits?.longestStreak || 0,
      all: (ctx.habits?.all || []).slice(0, 24),
    },

    // Counts the hero checklist reads. Derived, not stored — the client should
    // never have to recompute what the server already knows.
    counts: {
      events: (ctx.calendar?.events || []).filter((e) => !e.allDay).length,
      meals: (ctx.meals?.slots || []).length,
      choresOpen: (ctx.family?.obligations || []).length,
      choresDone: ctx.family?.choresDone || 0,
      groceries: ctx.groceries?.itemCount || 0,
      upcoming: (ctx.upcoming || []).length,
      notes: (ctx.notes || []).length,
    },

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

  // The garden is personal: split the household's habits into the caller's own
  // (tappable) and a household summary (read-only). Doing this at read time
  // keeps the cached brief shared while each member sees their own garden.
  if (doc.habits && Array.isArray(doc.habits.all)) {
    const uid = String(user._id);
    const all = doc.habits.all;
    const mine = all.filter((h) => String(h.ownerUserId) === uid);

    doc.habits = {
      household: {
        total: all.length,
        completedToday: all.filter((h) => h.completedToday).length,
      },
      total: mine.length,
      completedToday: mine.filter((h) => h.completedToday).length,
      longestStreak: mine.reduce((m, h) => Math.max(m, h.streak || 0), 0),
      all: mine,
    };
  }

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

/**
 * Busts briefs for an AppData owner id.
 *
 * AppData.userId is overloaded — it holds a household id for shared types
 * (groceries, events, calendar_events, party_events, household_notes) and a user
 * id for personal ones (habits, chores, meal_plan, family_members). So:
 *
 *   household id -> bust that household
 *   user id      -> bust EVERY household they belong to, because their chores,
 *                   habits and meal_plan feed each of those dashboards
 *
 * Without this, a saved meal or ticked-off chore wouldn't appear until midnight,
 * which reads to a user as "the app is broken" — and worse, they can't tell which
 * parts of the dashboard are live, so it undermines trust in all of it.
 */
async function bustBriefsForOwner(ownerId) {
  if (!ownerId || !mongoose.Types.ObjectId.isValid(String(ownerId))) {
    return { deletedCount: 0 };
  }

  const oid = new mongoose.Types.ObjectId(String(ownerId));
  const scopeIds = new Set();

  const [asHousehold, memberOf] = await Promise.all([
    Household.exists({ _id: oid }),
    Household.find({ members: oid }).select('_id').lean(),
  ]);

  if (asHousehold) scopeIds.add(String(oid));
  for (const h of memberOf) scopeIds.add(String(h._id));

  if (scopeIds.size === 0) return { deletedCount: 0 };

  const today = new Date().toISOString().slice(0, 10);
  return DayBrief.deleteMany({
    scopeId: { $in: [...scopeIds].map((s) => new mongoose.Types.ObjectId(s)) },
    localDate: { $gte: today },
  });
}

module.exports = {
  getTodayBrief,
  bustDayBrief,
  bustBriefsForOwner,
  buildBrief,
  decorateForRead,
};
PLANBHAI_EOF

for f in backend/services/habits.service.js backend/routes/habits.routes.js \
         backend/services/daybrief/context.adapter.js \
         backend/services/daybrief/daybrief.service.js; do
  node --check "$f" || { echo "   PARSE FAILED: $f"; exit 1; }
done
echo "   all parse"
echo

echo "2. Mounting the route"
if grep -q "habits.routes" backend/server.js; then
  echo "   already mounted"
else
  cp backend/server.js backend/server.js.bakhabit
  python3 - backend/server.js << 'PY_EOF'
import sys, re
p = sys.argv[1]
s = open(p).read()
m = None
for m in re.finditer(r"app\.use\(\s*['\"]/api[^\n]*\n", s): pass
if not m:
    print("   ERROR: no /api mounts found"); sys.exit(2)
s = s[:m.end()] + "app.use('/api/habits', require('./routes/habits.routes'));\n" + s[m.end():]
open(p, "w").write(s)
print("   added /api/habits")
PY_EOF
  [ $? -ne 0 ] && { cp backend/server.js.bakhabit backend/server.js; echo "   reverted"; exit 1; }
  node --check backend/server.js && echo "   server.js parses"
fi
echo

echo "3. iOS"
write "PlanBhai/ios/PlanBhai/DayBriefModels.swift" << 'PLANBHAI_EOF'
import Foundation

// MARK: - Wire models
//
// Mirrors GET /api/dashboard/today. Every field the server may omit or null is
// optional here — `readiness` is genuinely null for a household with nothing
// plannable yet, and treating that as an error would break the empty state.

struct DayBrief: Codable {
    let localDate: String
    let tz: String
    let state: String              // "empty" | "sparse" | "rich"
    let greeting: Greeting?
    let readiness: Readiness?      // null when no domain applies
    let signals: [Signal]?
    let suggestions: [Suggestion]?
    let timeline: [TimelineRow]?
    let meal: Meal?
    let family: [FamilyRow]?
    let upcoming: [UpcomingRow]?
    let habits: Habits?
    let counts: Counts?
    let calendarSyncedAt: String?

    struct Habits: Codable {
        let total: Int?
        let completedToday: Int?
        let longestStreak: Int?
        let all: [Habit]?

        struct Habit: Codable, Identifiable {
            let name: String
            let streak: Int?
            let completedToday: Bool?
            let lastCompletedDate: String?
            var id: String { name }
        }

        /// Household-wide totals, shown alongside your own so a shared
        /// dashboard doesn't feel solitary.
        struct HouseholdSummary: Codable {
            let total: Int?
            let completedToday: Int?
        }
    }

    struct Counts: Codable {
        let events: Int?
        let meals: Int?
        let choresOpen: Int?
        let choresDone: Int?
        let groceries: Int?
        let upcoming: Int?
        let notes: Int?
    }

    struct Greeting: Codable {
        let timeOfDay: String      // morning | afternoon | evening | night
        let line: String
    }

    struct Readiness: Codable {
        let score: Int
        let label: String
        let breakdown: [Domain]?

        struct Domain: Codable {
            let domain: String
            let score: Int
            let applicable: Bool
            let reason: String?
        }

        /// Lowest-scoring applicable domain — the one thing most worth surfacing.
        var weakest: Domain? {
            (breakdown ?? []).filter { $0.applicable }.min { $0.score < $1.score }
        }
    }

    struct Suggestion: Codable, Identifiable {
        let id: String
        let kind: String?
        let icon: String?
        let title: String
        let subtitle: String?
        let cta: String?
        let deeplink: String?
        let webPath: String?
        let locked: Bool?
    }

    struct Signal: Codable, Identifiable {
        let icon: String?
        let text: String
        let kind: String?
        let priority: Int?
        var id: String { (kind ?? "") + text }
    }

    struct TimelineRow: Codable, Identifiable {
        let start: String          // "HH:mm"
        let end: String?
        let title: String
        let kind: String?          // habit | event | meal | task | routine
        let source: String?
        let sourceId: String?
        let icon: String?
        let isNow: Bool?
        var id: String { start + title }
    }

    struct Meal: Codable {
        let slot: String?
        let title: String
        let haveRatio: Double?
        let missing: [String]?
    }

    struct FamilyRow: Codable, Identifiable {
        let memberId: String?
        let name: String
        let status: String?
        let state: String?         // done | pending | upcoming
        let icon: String?
        var id: String { (memberId ?? "") + name }
    }

    struct UpcomingRow: Codable, Identifiable {
        let day: String
        let date: String
        let title: String
        let icon: String?
        var id: String { date + title }
    }
}

// MARK: - Service

enum DayBriefError: LocalizedError {
    case noHousehold
    case notSignedIn
    case server(Int, String)

    var errorDescription: String? {
        switch self {
        case .noHousehold: return "No household selected yet."
        case .notSignedIn: return "You need to sign in."
        case .server(let code, let body):
            return "Couldn't load your day (\(code)). \(body)"
        }
    }
}

@MainActor
final class DayBriefService {
    static let shared = DayBriefService()

    /// Must match APIService.baseURL — it's private there, so it's repeated.
    private let baseURL = "https://planbhai.onrender.com"

    private init() {}

    func fetch(householdId: String, token: String) async throws -> DayBrief {
        // The server keys its cache on timezone, so the device reports its own
        // rather than assuming one.
        let tz = TimeZone.current.identifier
        var comps = URLComponents(string: "\(baseURL)/api/dashboard/today")!
        comps.queryItems = [
            URLQueryItem(name: "scopeId", value: householdId),
            URLQueryItem(name: "tz", value: tz)
        ]

        var request = URLRequest(url: comps.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw DayBriefError.server(0, "No response")
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw DayBriefError.server(http.statusCode, String(body.prefix(140)))
        }

        return try JSONDecoder().decode(DayBrief.self, from: data)
    }

    /// Toggles one of the caller's own habits.
    ///
    /// Streak arithmetic lives on the server so iOS and web agree: only
    /// today's completion is reversible, and un-checking tomorrow no longer
    /// removes a day that was legitimately earned.
    @discardableResult
    func completeHabit(name: String, done: Bool, token: String) async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/api/habits/complete") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "name": name,
            "done": done,
            "tz": TimeZone.current.identifier
        ])
        request.timeoutInterval = 15

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { return false }
        return (200...299).contains(http.statusCode)
    }
}
PLANBHAI_EOF
write "PlanBhai/ios/PlanBhai/Views/DayBriefView.swift" << 'PLANBHAI_EOF'
import SwiftUI

/// The Brief — "this app already understands my day".
///
/// Row order: hero, score, suggestions, timeline, Ask BhAI, upcoming, family,
/// meal, habit garden, achievements.
///
/// The vision's "Smart Life Categories" row was removed. It navigated to the
/// same tabs Ask BhAI already reaches, and a screen with a tab bar, a category
/// grid AND a prompt grid is three navigation systems competing for the same
/// taps. Ask BhAI won because verb phrases ("Plan dinner") read as things the
/// app does for you, which is the premise; noun tiles ("Meals") just restate
/// the tab bar.
///
/// Two honesty rules run through this file:
///   1. A section that has no data does not render. An empty shell implies the
///      app knows something it doesn't, and users catch that fast.
///   2. Nothing is invented client-side. Every number comes from the brief.
struct DayBriefView: View {
    @EnvironmentObject var appState: AppState
    var selectedTab: Binding<Int>? = nil      // lets the category row switch tabs

    @State private var brief: DayBrief?
    @State private var isLoading = true
    @State private var errorText: String?
    @State private var showBreakdown = false
    @State private var heroAppeared = false
    @State private var togglingHabit: String?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0F0F1A"), Color(hex: "0F172A"), Color(hex: "111827")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()

            blob(PB.navy, 320, x: 160, y: -170, blur: 80, op: 0.20)
            blob(PB.teal, 250, x: -130, y: 260, blur: 65, op: 0.11)
            blob(PB.mauve, 220, x: 140, y: 620, blur: 70, op: 0.08)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    if isLoading && brief == nil {
                        ProgressView().tint(.white).padding(.top, 120)
                    } else if let errorText {
                        errorCard(errorText)
                    } else if let b = brief {
                        heroCard(b)                                   // Hero
                        if let r = b.readiness { scoreCard(r) }        // 1 — Today's Focus
                        suggestionsRow(b)                              // 2 — AI suggestions
                        if let t = b.timeline, !t.isEmpty { timelineCard(t) }   // 3
                        askBhaiCard                                    // 4 — Ask BhAI
                        if let u = b.upcoming, !u.isEmpty { upcomingCard(u) }   // 5
                        if let f = b.family, !f.isEmpty { familyCard(f) }       // 6
                        if let m = b.meal { mealCard(m) }              // 7
                        habitGarden(b)                                 // 8
                        achievements(b)                                // 9
                        syncFooter(b)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120)
            }
            .refreshable { await load() }
        }
        .task { await load() }
        // If the household changes — first load, or the user switches — refresh.
        .onChange(of: appState.activeHouseholdId) { _ in
            Task { await load() }
        }
    }

    // MARK: - Hero

    private func heroCard(_ b: DayBrief) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    // Day and date first. It anchors everything below it in
                    // "today" — without it a dashboard could be showing any day.
                    Text(dayAndDate)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PB.soft)
                        .tracking(0.9)

                    HStack(spacing: 7) {
                        Text(salutation)
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text(timeEmoji).font(.system(size: 20))
                    }

                    Text(b.greeting?.line ?? "Here's your day.")
                        .font(.system(size: 13))
                        .foregroundStyle(PB.mid)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 1)
                }
                Spacer(minLength: 8)

                // Same treatment as PageHeader and the old dashboard: 44pt,
                // circle-clipped, gradient stroke. Sits in the hero rather than
                // above it — a PageHeader here would stack a third heading over
                // the date and greeting.
                //
                // The old version carried an ellipsis badge opening All
                // Features. That sheet lives in DashboardView, so this is
                // non-interactive for now; a logo that looks tappable and
                // isn't is worse than one that plainly isn't.
                Image("PlanBhaiLogo")
                    .resizable().scaledToFit()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(
                        LinearGradient(colors: [PB.navy, PB.teal, PB.mauve],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 2))
                    .shadow(color: PB.navy.opacity(0.55), radius: 10, y: 3)
            }

            Rectangle()
                .fill(LinearGradient(colors: [PB.navy.opacity(0.5), PB.teal.opacity(0.25), .clear],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)

            // Every line here is a real count from the brief. No placeholders —
            // a checklist that lists things you don't have is the fastest way to
            // lose trust in the whole screen.
            VStack(alignment: .leading, spacing: 9) {
                ForEach(Array(heroLines(b).enumerated()), id: \.offset) { i, line in
                    HStack(spacing: 9) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(PB.forest)
                            .frame(width: 15, height: 15)
                            .background(Circle().fill(PB.forest.opacity(0.16)))
                        Text(line)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(PB.mid)
                    }
                    .opacity(heroAppeared ? 1 : 0)
                    .offset(y: heroAppeared ? 0 : 6)
                    .animation(.easeOut(duration: 0.32).delay(Double(i) * 0.05), value: heroAppeared)
                }
            }

            if let r = b.readiness {
                Text(r.score >= 80 ? "Everything fits." : r.label)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(colors: [PB.navy.opacity(0.22), PB.teal.opacity(0.10)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(PB.glassBorder, lineWidth: 1))
        .padding(.top, 14)
        .onAppear { heroAppeared = true }
    }

    private func heroLines(_ b: DayBrief) -> [String] {
        var out: [String] = []
        guard let c = b.counts else { return out }
        if let n = c.events, n > 0    { out.append("\(n) event\(n == 1 ? "" : "s") today") }
        if let n = c.meals, n > 0     { out.append("\(n) meal\(n == 1 ? "" : "s") planned") }
        if let h = b.habits, let t = h.total, t > 0 {
            out.append("\(h.completedToday ?? 0) of \(t) habits done")
        }
        if let n = c.choresOpen, n > 0 { out.append("\(n) chore\(n == 1 ? "" : "s") to pick up") }
        if let n = c.groceries, n > 0  { out.append("\(n) items on the grocery list") }
        if let n = c.upcoming, n > 0   { out.append("\(n) thing\(n == 1 ? "" : "s") coming up") }
        return out
    }

    // MARK: - 1. Today's Focus

    private func scoreCard(_ r: DayBrief.Readiness) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Today's Focus", icon: "target", color: PB.forest)

            HStack(spacing: 20) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.07), lineWidth: 11)
                    Circle()
                        .trim(from: 0, to: CGFloat(max(0, min(100, r.score))) / 100)
                        .stroke(AngularGradient(colors: [ringColor(r.score),
                                                         ringColor(r.score).opacity(0.5)],
                                                center: .center),
                                style: StrokeStyle(lineWidth: 11, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.9), value: r.score)
                    VStack(spacing: -2) {
                        Text("\(r.score)")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("%").font(.system(size: 11, weight: .bold)).foregroundStyle(PB.soft)
                    }
                }
                .frame(width: 94, height: 94)

                VStack(alignment: .leading, spacing: 7) {
                    Text(r.label)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    // A score with no explanation is anxiety with a percentage
                    // attached — always pair it with the weakest domain.
                    if let w = r.weakest, let reason = w.reason, !reason.isEmpty {
                        Text(reason)
                            .font(.system(size: 12))
                            .foregroundStyle(PB.soft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }

            if let breakdown = r.breakdown, !breakdown.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) { showBreakdown.toggle() }
                } label: {
                    HStack(spacing: 5) {
                        Text(showBreakdown ? "Hide detail" : "Why this score?")
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: showBreakdown ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(PB.sky)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 14)
                }
                .buttonStyle(.plain)

                if showBreakdown {
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(breakdown.filter { $0.applicable }, id: \.domain) { d in
                            HStack(alignment: .top, spacing: 10) {
                                Text(d.domain.capitalized)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(PB.mid)
                                    .frame(width: 72, alignment: .leading)
                                Text("\(d.score)")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(ringColor(d.score))
                                    .frame(width: 26, alignment: .trailing)
                                Text(d.reason ?? "")
                                    .font(.system(size: 11))
                                    .foregroundStyle(PB.soft)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                        }
                        if !notCounted(breakdown).isEmpty {
                            Text("Not counted: \(notCounted(breakdown))")
                                .font(.system(size: 10))
                                .foregroundStyle(PB.muted)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.top, 12)
                }
            }
        }
        .padding(18)
        .glassCard()
    }

    // MARK: - 2. AI suggestions

    @ViewBuilder
    private func suggestionsRow(_ b: DayBrief) -> some View {
        // Never an empty shell — the card only exists when there is something
        // real to suggest. "No suggestions right now" is a box that costs
        // attention and returns nothing.
        if let items = b.suggestions, !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("Bhai suggests", icon: "lightbulb.fill", color: PB.amber)

                ForEach(items) { s in
                    Button {
                        open(s)
                    } label: {
                        HStack(spacing: 12) {
                            Text(s.icon ?? "💡").font(.system(size: 20))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(s.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                if let sub = s.subtitle, !sub.isEmpty {
                                    Text(sub)
                                        .font(.system(size: 11))
                                        .foregroundStyle(PB.soft)
                                }
                            }

                            Spacer(minLength: 6)

                            if s.locked == true {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(PB.muted)
                            } else if let cta = s.cta {
                                Text(cta)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(PB.amber)
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(PB.amber.opacity(0.14)))
                            }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(PB.glass))
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .stroke(PB.glassBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .glassCard()
        }
    }

    /// Routes a suggestion to the right tab. Deliberately maps known
    /// destinations rather than opening the deeplink URL — a suggestion that
    /// goes nowhere is worse than one that was never shown.
    private func open(_ s: DayBrief.Suggestion) {
        guard s.locked != true, let path = s.deeplink else { return }
        let tab: Int?
        switch true {
        case path.contains("meals"):     tab = 1
        case path.contains("habits"):    tab = 2
        case path.contains("party"):     tab = 3
        case path.contains("household"), path.contains("grocery"): tab = 4
        case path.contains("planner"):   tab = 0
        default:                         tab = nil
        }
        if let tab { selectedTab?.wrappedValue = tab }
    }

    // MARK: - 3. Timeline

    private func timelineCard(_ rows: [DayBrief.TimelineRow]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Today's Timeline", icon: "clock.fill", color: PB.sky)

            scrollSection(maxHeight: 220) {
              VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                HStack(alignment: .top, spacing: 12) {
                    Text(displayTime(row.start))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(row.isNow == true ? PB.teal : PB.muted)
                        .frame(width: 52, alignment: .leading)

                    VStack(spacing: 0) {
                        ZStack {
                            if row.isNow == true {
                                Circle().fill(PB.teal.opacity(0.25)).frame(width: 16, height: 16)
                            }
                            Circle()
                                .fill(row.isNow == true ? PB.teal : kindColor(row.kind))
                                .frame(width: 8, height: 8)
                        }
                        .frame(width: 16, height: 16)
                        if idx < rows.count - 1 {
                            Rectangle().fill(Color.white.opacity(0.09))
                                .frame(width: 1.5).frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: 16)

                    HStack(spacing: 7) {
                        if let icon = row.icon { Text(icon).font(.system(size: 13)) }
                        Text(row.title)
                            .font(.system(size: 14, weight: row.isNow == true ? .bold : .medium))
                            .foregroundStyle(row.isNow == true ? .white : PB.mid)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.bottom, 18)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                }
              }
            }
        }
        .padding(18)
        .glassCard()
    }

    // MARK: - 4. Ask BhAI

    private var askBhaiCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Ask BhAI", icon: "sparkles", color: PB.amber)

            // Two columns rather than a horizontal strip: side-scrolling hides
            // options behind a gesture nobody knows to make, and these are the
            // things the app can actually do for you.
            scrollSection(maxHeight: 150) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8),
                                    GridItem(.flexible(), spacing: 8)],
                          spacing: 8) {
                    ForEach(prompts, id: \.text) { p in
                        Button {
                            selectedTab?.wrappedValue = p.tab
                        } label: {
                            HStack(spacing: 6) {
                                Text(p.icon).font(.system(size: 13))
                                Text(p.text)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(PB.mid)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 12).fill(PB.glass))
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(p.color.opacity(0.30), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.trailing, 4)
            }
        }
        .padding(18)
        .glassCard()
    }

    /// Each prompt routes to the screen that actually performs it.
    ///
    /// There is no Ask BhAI conversation view yet, and a chip that opens a chat
    /// which can't do anything would be worse than one that takes you straight
    /// to the planner. When a compose screen exists, these become its seed text.
    private struct Prompt {
        let icon: String
        let text: String
        let tab: Int
        let color: Color
    }

    private var prompts: [Prompt] {
        [Prompt(icon: "🍽", text: "Plan dinner",       tab: 1, color: PB.teal),
         Prompt(icon: "📅", text: "Schedule my week",  tab: 1, color: PB.teal),
         Prompt(icon: "📖", text: "Find recipes",      tab: 1, color: PB.teal),
         Prompt(icon: "🛒", text: "Grocery list",      tab: 4, color: PB.navy),
         Prompt(icon: "🎂", text: "Organize a party",  tab: 3, color: PB.rose),
         Prompt(icon: "💪", text: "Build a habit",     tab: 2, color: PB.forest),
         Prompt(icon: "💰", text: "Split expenses",    tab: 4, color: PB.amber),
         Prompt(icon: "👨‍👩‍👧", text: "Family plans",     tab: 4, color: PB.mauve)]
    }

    // MARK: - 5. Upcoming

    private func upcomingCard(_ rows: [DayBrief.UpcomingRow]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Upcoming", icon: "calendar", color: PB.navyLight)
            scrollSection(maxHeight: 108) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(rows) { r in
                        HStack(spacing: 12) {
                            Text(r.day)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(PB.soft)
                                .frame(width: 76, alignment: .leading)
                            if let icon = r.icon { Text(icon).font(.system(size: 13)) }
                            Text(r.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(PB.mid)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard()
    }

    // MARK: - 6. Family snapshot

    private func familyCard(_ rows: [DayBrief.FamilyRow]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Family", icon: "person.3.fill", color: PB.mauve)
            scrollSection(maxHeight: 156) {
              VStack(alignment: .leading, spacing: 12) {
                ForEach(rows) { m in
                HStack(spacing: 12) {
                    Text(String(m.name.prefix(1)).uppercased())
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(memberColor(m.name).opacity(0.30)))
                        .overlay(Circle().stroke(memberColor(m.name).opacity(0.55), lineWidth: 1))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(m.status ?? "")
                            .font(.system(size: 11))
                            .foregroundStyle(PB.soft)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: m.state == "done" ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 15))
                        .foregroundStyle(m.state == "done" ? PB.forest : PB.muted)
                }
                }
              }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard()
    }

    private func memberColor(_ name: String) -> Color {
        PB.memberColors[abs(name.hashValue) % PB.memberColors.count]
    }

    // MARK: - 7. Meal

    private func mealCard(_ meal: DayBrief.Meal) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionLabel("Today's \(meal.slot?.capitalized ?? "Dinner")",
                         icon: "fork.knife", color: PB.amber)

            Text(meal.title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            if let ratio = meal.haveRatio {
                HStack(spacing: 9) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08))
                            Capsule().fill(PB.forest)
                                .frame(width: geo.size.width * CGFloat(max(0, min(1, ratio))))
                        }
                    }
                    .frame(height: 6)
                    Text("\(Int(ratio * 100))% available")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PB.forest)
                }
            }

            if let missing = meal.missing, !missing.isEmpty {
                Text("Need: \(missing.joined(separator: ", "))")
                    .font(.system(size: 12))
                    .foregroundStyle(PB.warning)
            }
            // When haveRatio is nil the pantry is empty, so coverage is genuinely
            // unknown. Saying nothing beats implying everything's on hand.
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard()
    }

    // MARK: - 8. Habit garden

    @ViewBuilder
    private func habitGarden(_ b: DayBrief) -> some View {
        if let h = b.habits, let total = h.total, total > 0 {
            VStack(alignment: .leading, spacing: 14) {
                sectionLabel("Habit Garden", icon: "leaf.fill", color: PB.forest)

                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(h.all ?? []) { habit in
                          Button {
                              Task { await toggleHabit(habit) }
                          } label: {
                            VStack(spacing: 4) {
                                Text(habit.completedToday == true ? "🌸" : "🌱")
                                    .font(.system(size: 26))
                                    .opacity(habit.completedToday == true ? 1 : 0.45)
                                // The habit name matters more than a streak of 0 —
                                // a row of bare zeros reads as failure rather than
                                // as "not yet today".
                                Text(habit.name)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(habit.completedToday == true ? PB.mid : PB.muted)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .frame(width: 58)
                                if let st = habit.streak, st > 0 {
                                    Text("\(st)d")
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .foregroundStyle(PB.forest)
                                }
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 4)
                            .contentShape(Rectangle())
                          }
                          .buttonStyle(.plain)
                          .disabled(togglingHabit != nil)
                          .opacity(togglingHabit == habit.name ? 0.5 : 1)
                        }
                    }
                    .padding(.bottom, 4)
                }

                HStack(spacing: 5) {
                    Text("\(h.completedToday ?? 0) of \(total) blooming today")
                        .font(.system(size: 12))
                        .foregroundStyle(PB.soft)
                    if let hh = h.household, let ht = hh.total, ht > total {
                        Text("· household \(hh.completedToday ?? 0)/\(ht)")
                            .font(.system(size: 12))
                            .foregroundStyle(PB.muted)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .glassCard()
        }
    }

    // MARK: - 9. Achievements

    @ViewBuilder
    private func achievements(_ b: DayBrief) -> some View {
        // Only badges backed by real data. A trophy case full of things the user
        // hasn't done is the opposite of motivating.
        if !earned(b).isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Achievements", icon: "trophy.fill", color: PB.amber)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(earned(b), id: \.title) { a in
                            VStack(spacing: 6) {
                                Text(a.emoji).font(.system(size: 24))
                                Text(a.title)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(PB.mid)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(width: 84, height: 76)
                            .background(RoundedRectangle(cornerRadius: 14).fill(PB.amber.opacity(0.10)))
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .stroke(PB.amber.opacity(0.25), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .glassCard()
        }
    }

    private func earned(_ b: DayBrief) -> [(emoji: String, title: String)] {
        var out: [(emoji: String, title: String)] = []
        if let streak = b.habits?.longestStreak, streak >= 3 {
            out.append(("🔥", "\(streak) day streak"))
        }
        if let h = b.habits, let t = h.total, t > 0, h.completedToday == t {
            out.append(("💪", "All habits done"))
        }
        if let done = b.counts?.choresDone, done > 0 {
            out.append(("🏆", "\(done) chores done"))
        }
        if let r = b.readiness, r.score >= 90 {
            out.append(("✨", "Day under control"))
        }
        return out
    }

    // MARK: - Footer / states

    @ViewBuilder
    private func syncFooter(_ b: DayBrief) -> some View {
        if let synced = b.calendarSyncedAt {
            Text("Calendar synced \(relativeSync(synced))")
                .font(.system(size: 10))
                .foregroundStyle(PB.muted)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func errorCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Couldn't load your day")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(PB.soft)
                .fixedSize(horizontal: false, vertical: true)
            Button { Task { await load() } } label: {
                Text("Try again")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PB.sky)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard()
        .padding(.top, 60)
    }

    // MARK: - Helpers

    private var salutation: String {
        let part = brief?.greeting?.timeOfDay ?? currentTimeOfDay
        let name = appState.currentUser?.name
            ?? UserDefaults.standard.string(forKey: "userName") ?? ""
        let base = "Good \(part.capitalized)"
        return name.isEmpty ? base : "\(base), \(name)"
    }

    /// "FRIDAY, JULY 31" — taken from the brief's localDate, not the device
    /// clock. Those disagree around midnight and while travelling, and showing
    /// a date that doesn't match the data underneath it is worse than showing none.
    private var dayAndDate: String {
        let iso = DateFormatter()
        iso.dateFormat = "yyyy-MM-dd"
        iso.locale = Locale(identifier: "en_US_POSIX")
        iso.timeZone = TimeZone(identifier: brief?.tz ?? TimeZone.current.identifier)

        let date = brief.flatMap { iso.date(from: $0.localDate) } ?? Date()

        let out = DateFormatter()
        out.dateFormat = "EEEE, MMMM d"
        out.timeZone = iso.timeZone
        return out.string(from: date).uppercased()
    }

    private var timeEmoji: String {
        switch brief?.greeting?.timeOfDay ?? currentTimeOfDay {
        case "morning":   return "☀️"
        case "afternoon": return "🌤"
        case "evening":   return "🌆"
        default:          return "🌙"
        }
    }

    private var currentTimeOfDay: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case ..<12: return "morning"
        case ..<17: return "afternoon"
        case ..<21: return "evening"
        default:    return "night"
        }
    }

    /// "19:00" -> "7 PM". The server sends 24h; people read 12h.
    private func displayTime(_ hhmm: String) -> String {
        let parts = hhmm.split(separator: ":")
        guard let h = Int(parts.first ?? "") else { return hhmm }
        let m = parts.count > 1 ? String(parts[1]) : "00"
        let suffix = h < 12 ? "AM" : "PM"
        let h12 = h % 12 == 0 ? 12 : h % 12
        return m == "00" ? "\(h12) \(suffix)" : "\(h12):\(m) \(suffix)"
    }

    private func relativeSync(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let date else { return "recently" }
        let mins = Int(Date().timeIntervalSince(date) / 60)
        if mins < 1 { return "just now" }
        if mins < 60 { return "\(mins)m ago" }
        return "\(mins / 60)h ago"
    }

    private func notCounted(_ b: [DayBrief.Readiness.Domain]) -> String {
        b.filter { !$0.applicable }.map { $0.domain }.joined(separator: ", ")
    }

    private func ringColor(_ score: Int) -> Color {
        switch score {
        case 80...:   return PB.success
        case 60..<80: return PB.sky
        case 40..<60: return PB.warning
        default:      return PB.error
        }
    }

    private func kindColor(_ kind: String?) -> Color {
        switch kind {
        case "meal":  return PB.amber
        case "habit": return PB.forest
        case "event": return PB.navyLight
        case "task":  return PB.mauve
        default:      return PB.soft
        }
    }

    /// Caps a section at roughly three rows and scrolls the rest.
    ///
    /// Indicators stay visible even when everything fits — otherwise a section
    /// with exactly four items looks complete at three, and the user never
    /// learns there's more.
    private func scrollSection<C: View>(maxHeight: CGFloat, @ViewBuilder _ content: () -> C) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            content()
        }
        .frame(maxHeight: maxHeight)
    }

    private func sectionLabel(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(PB.soft)
                .tracking(0.9)
        }
        .padding(.bottom, 14)
    }

    private func blob(_ c: Color, _ s: CGFloat, x: CGFloat, y: CGFloat, blur: CGFloat, op: Double) -> some View {
        Circle().fill(c.opacity(op)).frame(width: s, height: s)
            .offset(x: x, y: y).blur(radius: blur).allowsHitTesting(false)
    }

    /// Toggles one of your own habits.
    ///
    /// Optimistic — the flower changes immediately and reverts on failure. A tap
    /// that appears to do nothing for 300ms feels broken. The streak arithmetic
    /// is the server's, so iOS and web can't drift apart on what a streak means.
    private func toggleHabit(_ habit: DayBrief.Habits.Habit) async {
        guard togglingHabit == nil, let token = appState.authToken else { return }
        let next = !(habit.completedToday ?? false)
        togglingHabit = habit.name

        applyHabit(named: habit.name, completed: next,
                   streak: max((habit.streak ?? 0) + (next ? 1 : -1), 0))

        do {
            let ok = try await DayBriefService.shared.completeHabit(
                name: habit.name, done: next, token: token)
            if !ok { throw DayBriefError.server(0, "rejected") }
        } catch {
            // Put it back rather than leaving a flower that lies.
            applyHabit(named: habit.name,
                       completed: habit.completedToday ?? false,
                       streak: habit.streak ?? 0)
        }
        togglingHabit = nil
    }

    private func applyHabit(named name: String, completed: Bool, streak: Int) {
        guard let b = brief, let h = b.habits, let all = h.all else { return }
        let updated = all.map { item -> DayBrief.Habits.Habit in
            guard item.name == name else { return item }
            return .init(name: item.name, streak: streak,
                         completedToday: completed,
                         lastCompletedDate: item.lastCompletedDate)
        }
        brief = DayBrief(
            localDate: b.localDate, tz: b.tz, state: b.state, greeting: b.greeting,
            readiness: b.readiness, signals: b.signals, suggestions: b.suggestions,
            timeline: b.timeline, meal: b.meal, family: b.family, upcoming: b.upcoming,
            habits: .init(total: h.total,
                          completedToday: updated.filter { $0.completedToday == true }.count,
                          longestStreak: h.longestStreak, all: updated,
                          household: h.household),
            counts: b.counts, calendarSyncedAt: b.calendarSyncedAt)
    }

    // MARK: - Load

    private func load() async {
        guard let token = appState.authToken else {
            errorText = "You need to sign in."; isLoading = false; return
        }

        // RootView sets activeHouseholdId inside fetchMyHouseholds(), which runs
        // in its own Task. This view's .task fires when it appears — concurrently
        // with that chain, not after it. Checking once loses the race whenever
        // the households call is slow, which showed up as an intermittent
        // "No household selected yet." Wait briefly instead of guessing.
        var household = appState.activeHouseholdId
        var waited = 0
        while household == nil && waited < 6000 {
            try? await Task.sleep(nanoseconds: 200_000_000)
            waited += 200
            household = appState.activeHouseholdId
        }

        guard let household else {
            errorText = "No household selected yet. Pull down to retry."
            isLoading = false
            return
        }
        isLoading = true
        errorText = nil
        do {
            brief = try await DayBriefService.shared.fetch(householdId: household, token: token)
        } catch {
            errorText = error.localizedDescription
        }
        isLoading = false
    }
}

private extension View {
    func glassCard() -> some View {
        self
            .background(RoundedRectangle(cornerRadius: 20).fill(PB.glass))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(PB.glassBorder, lineWidth: 1))
    }
}
PLANBHAI_EOF

echo

echo "4. Web"
write 'web/src/pages/Brief.jsx' << 'PLANBHAI_EOF'
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

export default function Brief() {
  const { scopeId } = useHousehold();
  const { user } = useAuth();

  const [brief, setBrief] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showBreakdown, setShowBreakdown] = useState(false);
  const [pending, setPending] = useState(null);   // habit name mid-request

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
    <div className="brief">
      {/* Hero */}
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

      {/* Suggestions */}
      {b.suggestions?.length > 0 && (
        <div className="card brief-section">
          <div className="brief-label">BHAI SUGGESTS</div>
          {b.suggestions.map((s) => {
            const to = webRoute(s.webPath);
            const inner = (
              <>
                <span className="brief-suggestion-icon">{s.icon}</span>
                <span className="brief-suggestion-text">{s.title}</span>
                {s.locked ? <span className="brief-cta locked">🔒</span> : s.cta && <span className="brief-cta">{s.cta}</span>}
              </>
            );
            return s.locked || !to ? (
              <div className="brief-suggestion" key={s.id}>{inner}</div>
            ) : (
              <Link className="brief-suggestion" to={to} key={s.id}>{inner}</Link>
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

      {/* Ask BhAI */}
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

if grep -q "completeHabit" web/src/api.js; then
  echo "   api.completeHabit already present"
else
  cp web/src/api.js web/src/api.js.bakhabit
  python3 - web/src/api.js << 'PY_EOF'
import sys
p = sys.argv[1]
s = open(p).read()
anchor = "  // ---- Auth ----"
if anchor not in s:
    print("   ERROR: Auth section not found in api.js"); sys.exit(2)
add = """  // ---- Habits ----
  completeHabit: (name, done, tz) =>
    request('/api/habits/complete', { method: 'POST', auth: true, body: { name, done, tz } }),

"""
s = s.replace(anchor, add + anchor, 1)
open(p, "w").write(s)
print("   added api.completeHabit")
PY_EOF
  [ $? -ne 0 ] && { cp web/src/api.js.bakhabit web/src/api.js; echo "   reverted"; exit 1; }
fi

cp web/src/styles.css web/src/styles.css.bakhabit
python3 - web/src/styles.css << 'PY_EOF'
import sys
p = sys.argv[1]
s = open(p).read()
i = s.find("\n/* ---------- Brief ---------- */")
if i == -1:
    print("   ERROR: Brief style block not found"); sys.exit(2)
open(p, "w").write(s[:i])
PY_EOF
[ $? -ne 0 ] && { cp web/src/styles.css.bakhabit web/src/styles.css; exit 1; }
cat >> web/src/styles.css << 'PLANBHAI_EOF'

/* ---------- Brief ---------- */
/* Uses the existing theme variables so it sits with the rest of the app
   rather than importing the iOS dark treatment, which would look broken
   against the cream background. */

.brief {
  display: flex; flex-direction: column; gap: 16px;
  /* Capped and centred. Unconstrained, timeline rows ran the full width of a
     wide monitor, which is unreadable — the eye loses the line. */
  max-width: 780px; margin: 0 auto; padding: 24px 16px 60px;
}

/* Deliberately NOT .hero-card. That class already exists in styles.css with a
   dark landing-page treatment — black background, orange border — which turned
   the checklist into grey-on-black. This is its own thing. */
.brief-hero {
  padding: 24px;
  background: var(--bg-card);
  border: 1px solid var(--border-subtle);
  border-radius: 18px;
}
.brief-salutation {
  font-size: 27px; font-weight: 800; letter-spacing: -0.02em;
  color: var(--text-primary); line-height: 1.15;
}
.brief-line {
  margin-top: 6px; font-size: 14px; line-height: 1.45;
  color: var(--text-secondary);
}
.brief-hero-top { display: flex; justify-content: space-between; align-items: flex-start; gap: 12px; }
.brief-date {
  font-size: 11px; font-weight: 700; letter-spacing: 0.09em;
  color: var(--text-tertiary); margin-bottom: 6px;
}
.brief-logo { width: 44px; height: 44px; border-radius: 50%; object-fit: cover; flex-shrink: 0; }

.brief-divider {
  height: 1px; margin: 16px 0 14px;
  background: linear-gradient(to right, var(--border-strong), transparent);
}
.brief-checklist { list-style: none; margin: 0; padding: 0; display: grid; gap: 9px; }
.brief-checklist li {
  display: flex; align-items: center; gap: 9px;
  font-size: 14px; color: var(--text-primary);
}
.brief-check {
  display: inline-flex; align-items: center; justify-content: center;
  width: 17px; height: 17px; border-radius: 50%; flex-shrink: 0;
  background: var(--sage-tint); color: var(--sage);
  font-size: 10px; font-weight: 800;
}
.brief-hero-verdict {
  margin-top: 16px; font-size: 15px; font-weight: 700; color: var(--text-primary);
}

.brief-section { padding: 18px; }
.brief-label {
  font-size: 10px; font-weight: 700; letter-spacing: 0.1em;
  color: var(--text-tertiary); margin-bottom: 14px;
}

/* Ring drawn with conic-gradient — no SVG, no dependency. */
.brief-focus { display: flex; align-items: center; gap: 18px; }
.brief-ring {
  width: 88px; height: 88px; border-radius: 50%; flex-shrink: 0;
  display: flex; align-items: center; justify-content: center;
}
.brief-ring-inner {
  width: 68px; height: 68px; border-radius: 50%; background: var(--bg-card);
  display: grid; place-items: center;
}
/* The pair aligns internally on the baseline; the pair itself is centred.
   Baseline-aligning against the circle directly dropped the group low. */
.brief-ring-value { display: flex; align-items: baseline; gap: 1px; line-height: 1; }
.brief-ring-score { font-size: 24px; font-weight: 800; line-height: 1; color: var(--text-primary); }
.brief-ring-pct { font-size: 11px; font-weight: 700; line-height: 1; color: var(--text-tertiary); }
.brief-focus-label { font-size: 15px; font-weight: 700; color: var(--text-primary); }
.brief-focus-reason { font-size: 12px; color: var(--text-secondary); margin-top: 4px; }

.brief-link {
  background: none; border: 0; padding: 12px 0 0; cursor: pointer;
  font-size: 12px; font-weight: 600; color: var(--sage);
}
.brief-breakdown { margin-top: 10px; display: grid; gap: 8px; }
.brief-breakdown-row { display: grid; grid-template-columns: 72px 30px 1fr; align-items: baseline; gap: 8px; }
.brief-domain { font-size: 12px; font-weight: 600; text-transform: capitalize; color: var(--text-secondary); }
.brief-domain-score { font-size: 12px; font-weight: 700; text-align: right; }
.brief-domain-reason { font-size: 11px; color: var(--text-tertiary); }
.brief-not-counted { font-size: 10px; color: var(--text-tertiary); margin-top: 4px; }

.brief-suggestion {
  display: flex; align-items: center; gap: 11px;
  padding: 11px 12px; margin-bottom: 8px; border-radius: 12px;
  background: var(--bg-card-soft); border: 1px solid var(--border-subtle);
  text-decoration: none; color: inherit;
}
.brief-suggestion:last-child { margin-bottom: 0; }
a.brief-suggestion:hover { border-color: var(--sage); }
.brief-suggestion-icon { font-size: 18px; }
.brief-suggestion-text { flex: 1; font-size: 13px; font-weight: 600; color: var(--text-primary); }
/* Own class rather than .pill, which uppercases — "OPEN PLANNER" shouted. */
.brief-cta {
  flex-shrink: 0; padding: 5px 11px; border-radius: 999px;
  background: var(--sage-tint); color: var(--sage);
  font-size: 11px; font-weight: 700; white-space: nowrap;
}
.brief-cta.locked { background: var(--bg-card-soft); color: var(--text-tertiary); }

/* Sections cap at roughly three rows, matching iOS — a full timeline was most
   of a screen on its own. */
.brief-scroll, .brief-timeline { max-height: 190px; overflow-y: auto; }

.brief-tl-row { display: grid; grid-template-columns: 62px 16px 1fr; gap: 10px; align-items: start; }
.brief-tl-time { font-size: 11px; font-weight: 700; color: var(--text-tertiary); padding-top: 1px; }
.brief-tl-row.now .brief-tl-time { color: var(--teal); }
.brief-tl-rail { display: flex; flex-direction: column; align-items: center; align-self: stretch; }
.brief-tl-dot { width: 8px; height: 8px; border-radius: 50%; background: var(--border-strong); margin-top: 5px; }
.brief-tl-row.now .brief-tl-dot { background: var(--teal); box-shadow: 0 0 0 4px var(--sage-tint); }
.brief-tl-line { flex: 1; width: 1.5px; background: var(--border-subtle); }
.brief-tl-title { font-size: 14px; color: var(--text-primary); padding-bottom: 16px; }
.brief-tl-row.now .brief-tl-title { color: var(--text-primary); font-weight: 700; }
.brief-tl-icon { margin-right: 6px; }

.brief-prompts { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
.brief-prompt {
  display: flex; align-items: center; gap: 7px;
  padding: 11px 12px; border-radius: 12px;
  background: var(--bg-card-soft); border: 1px solid var(--border-subtle);
  font-size: 13px; font-weight: 600; color: var(--text-primary); text-decoration: none;
}
.brief-prompt:hover { border-color: var(--sage); }

.brief-upcoming-row {
  display: flex; gap: 12px; align-items: center;
  font-size: 14px; color: var(--text-primary); padding: 7px 0;
}
.brief-upcoming-day { width: 84px; font-size: 12px; font-weight: 700; color: var(--text-tertiary); }

.brief-family-row { display: flex; align-items: center; gap: 11px; padding: 8px 0; }
.brief-avatar {
  width: 32px; height: 32px; border-radius: 50%; flex-shrink: 0;
  display: flex; align-items: center; justify-content: center;
  background: var(--sage-tint); color: var(--sage); font-weight: 700; font-size: 13px;
}
.brief-family-text { display: flex; flex-direction: column; flex: 1; }
.brief-family-text strong { font-size: 14px; color: var(--text-primary); }
.brief-family-text small { font-size: 11px; color: var(--text-tertiary); }
.brief-done { color: var(--forest); font-weight: 700; }

.brief-meal-title { font-size: 17px; font-weight: 700; color: var(--text-primary); }
.brief-meal-bar {
  position: relative; height: 6px; border-radius: 3px; margin-top: 12px;
  background: var(--bg-card-soft);
}
.brief-meal-bar > div { height: 100%; border-radius: 3px; background: var(--forest); }
.brief-meal-bar > span {
  position: absolute; right: 0; top: 10px;
  font-size: 11px; font-weight: 600; color: var(--forest);
}
.brief-meal-missing { margin-top: 10px; font-size: 12px; color: var(--amber); }

.brief-garden { display: flex; gap: 14px; overflow-x: auto; padding-bottom: 6px; }
.brief-sprout {
  display: flex; flex-direction: column; align-items: center; gap: 3px;
  min-width: 62px; padding: 8px 4px; border: 0; border-radius: 12px;
  background: transparent; cursor: pointer; font: inherit;
  transition: background 0.15s, transform 0.15s;
}
.brief-sprout:hover { background: var(--bg-card-soft); }
.brief-sprout:active { transform: scale(0.94); }
.brief-sprout.busy { opacity: 0.5; pointer-events: none; }
.brief-sprout > span { font-size: 26px; }
.brief-sprout > span.dim { opacity: 0.45; }
.brief-sprout small { font-size: 9px; text-align: center; color: var(--text-tertiary); line-height: 1.2; }
.brief-sprout em { font-size: 9px; font-weight: 700; font-style: normal; color: var(--forest); }
.brief-garden-count { margin-top: 12px; font-size: 12px; color: var(--text-secondary); }
.brief-garden-household { color: var(--text-tertiary); }

.brief-badges { display: flex; gap: 10px; overflow-x: auto; }
.brief-badge {
  display: flex; flex-direction: column; align-items: center; gap: 5px;
  min-width: 86px; padding: 12px 8px; border-radius: 14px;
  background: var(--terracotta-tint); border: 1px solid var(--border-subtle);
}
.brief-badge span { font-size: 22px; }
.brief-badge small { font-size: 10px; font-weight: 600; text-align: center; color: var(--text-secondary); }

.brief-sync { text-align: center; font-size: 11px; color: var(--text-tertiary); }

@media (max-width: 520px) {
  .brief-prompts { grid-template-columns: 1fr; }
  .brief-breakdown-row { grid-template-columns: 66px 26px 1fr; }
}
PLANBHAI_EOF

echo "   styles updated"
echo

echo "5. Clearing the cached brief"
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

echo "6. Builds"
SIM=$(xcodebuild -scheme PlanBhai -showdestinations 2>/dev/null \
  | grep -oE "name:iPhone [^}]*" | sed 's/name://' | sed 's/ *$//' | head -1)
[ -z "$SIM" ] && SIM="iPhone 17"
xcodebuild -scheme PlanBhai -destination "platform=iOS Simulator,name=$SIM" build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head -10
(cd web && npm run build 2>&1 | grep -E "error|✓ built" | head -3)
echo

echo "=========================================="
echo "  Deploy BOTH — the endpoint is new, so taps 404 until the"
echo "  backend is live:"
echo "     git add -A && git commit -m 'Tappable habit garden' && git push"
echo "     (Render: Manual Deploy)   then   cd web && vercel --prod"
echo "=========================================="

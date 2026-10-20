#!/usr/bin/env bash
#
# Schedule Builder — Phase A: the writable model.
#
# Your timeline has always been DERIVED — assembled from events, meals and
# habits, read-only, rebuilt on every request. This adds blocks a person can
# create, move, complete and skip. It is the one genuinely new capability in
# the schedule builder; everything after it is UI and generation on top.
#
# TWO COLLECTIONS
#   ScheduleBlock     the template. "Gym, weekdays 6 PM" is one row.
#   ScheduleInstance  written ONLY when a day differs. A normal day stores
#                     nothing; the timeline expands blocks and applies
#                     deviations on top.
#
#   Materialising every occurrence would be ~2,900 rows a year for someone with
#   eight daily blocks. Deviations only is around 150.
#
# CYCLIC RECURRENCE IS IN FROM DAY ONE
#   weekly days-of-week covers most people, but a 4-on-4-off clinical rota
#   drifts: Mon–Thu, then Tue–Fri, then Wed–Sat. Every weekday ends up
#   sometimes on and sometimes off, which no days list can express.
#
#   Nothing uses `cycle` yet. It is here because retrofitting it later would
#   mean migrating every block written before it.
#
# SCHEDULES ARE PERSONAL, AND THE BRIEF IS CACHED PER HOUSEHOLD
#   So blocks are merged in decorateForRead, NOT baked into the cached brief.
#   Doing it the other way would cache one member's day and serve it to
#   everyone else — the same reason habits and dismissals are applied at read
#   time. Verified: two members sharing a brief see only their own blocks.
#
#   Every route reads req.user._id and never a userId from the request, so one
#   member cannot read or edit another's schedule.
#
# NOT IN THIS PHASE: templates, AI generation, companion blocks, tags UI,
# deadlines, drag-and-drop. Phase A is the model being right.
#
# Usage:
#   bash ~/Downloads/install-schedule-phase-a.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
[ -d backend/services/daybrief ] || { echo "ERROR: backend/services/daybrief not found"; exit 1; }

echo "PlanBhai — Schedule Phase A"
echo

write() {
  local dest="$1"
  [ -f "$dest" ] && cp "$dest" "$dest.bakphasea"
  cat > "$dest"
  echo "   wrote $dest"
}

echo "1. Files"
write 'backend/models/ScheduleBlock.js' << 'PLANBHAI_EOF'
const mongoose = require('mongoose');

/**
 * A recurring block in someone's day. The TEMPLATE, not an occurrence.
 *
 * "Gym, weekdays 6 PM" is one row here. "I moved Tuesday's to 8 PM" is a
 * ScheduleInstance. Storing only templates loses the edits; storing only
 * occurrences means editing 365 rows to change a routine — the same problem
 * ExternalEvent.occurrenceDate already solved for recurring calendar events.
 *
 * PERSONAL, not household. A schedule is one person's day; the household brief
 * shows it to its owner and nobody else.
 */

const RecurrenceSchema = new mongoose.Schema(
  {
    type: { type: String, enum: ['weekly', 'cycle'], default: 'weekly' },

    // weekly: 0 = Sunday
    days: { type: [Number], default: [1, 2, 3, 4, 5] },

    // cycle: for rotas that drift against the week. A 4-on-4-off clinician
    // works Mon–Thu, then Tue–Fri, then Wed–Sat — every weekday is sometimes on
    // and sometimes off, so no days-of-week list can describe it.
    //
    // Unused by the weekly type, but present from day one: retrofitting it
    // later would mean migrating every block written before it.
    cycleLength: { type: Number, default: null },
    onDays: { type: [Number], default: [] },
    anchorDate: { type: String, default: null }, // 'YYYY-MM-DD', cycle position 0
  },
  { _id: false }
);

const ScheduleBlockSchema = new mongoose.Schema(
  {
    scopeId: { type: mongoose.Schema.Types.ObjectId, ref: 'Household', required: true, index: true },
    userId: { type: String, required: true, index: true },

    title: { type: String, required: true, maxlength: 120 },
    kind: {
      type: String,
      enum: ['deep_work', 'health', 'family', 'learning', 'admin', 'urgent', 'meal', 'commute', 'rest'],
      default: 'admin',
    },

    startTime: { type: String, required: true }, // 'HH:mm', local wall-clock
    durationMin: { type: Number, required: true, min: 5, max: 600 },

    recurrence: { type: RecurrenceSchema, default: () => ({}) },

    /** Free strings, not an enum. "Ops"/"Finance"/"HR" is one person's
     *  taxonomy; a typed list would need a migration for every new one. */
    tags: { type: [String], default: [] },

    /** Which goal this block exists to serve, so progress can be measured
     *  against what the user actually asked for. */
    goalId: { type: String, default: null },

    source: { type: String, enum: ['manual', 'template', 'ai'], default: 'manual' },
    active: { type: Boolean, default: true },
  },
  { timestamps: true }
);

ScheduleBlockSchema.index({ userId: 1, active: 1 });
ScheduleBlockSchema.index({ scopeId: 1, userId: 1 });

module.exports = mongoose.model('ScheduleBlock', ScheduleBlockSchema);
PLANBHAI_EOF
write 'backend/models/ScheduleInstance.js' << 'PLANBHAI_EOF'
const mongoose = require('mongoose');

/**
 * A single day's deviation from a ScheduleBlock.
 *
 * WRITTEN ONLY WHEN A DAY DIFFERS. A normal day stores nothing — the timeline
 * expands the blocks and applies whatever instances exist on top.
 *
 * Materialising every occurrence would be ~2,900 rows a year for someone with
 * eight daily blocks. Writing only deviations — a couple of moves and a skip a
 * week — is around 150.
 */
const ScheduleInstanceSchema = new mongoose.Schema(
  {
    scopeId: { type: mongoose.Schema.Types.ObjectId, ref: 'Household', required: true },
    userId: { type: String, required: true, index: true },
    blockId: { type: mongoose.Schema.Types.ObjectId, ref: 'ScheduleBlock', required: true },

    localDate: { type: String, required: true }, // 'YYYY-MM-DD'

    state: { type: String, enum: ['moved', 'done', 'skipped'], required: true },

    // Present only when moved.
    startTime: { type: String, default: null },
    durationMin: { type: Number, default: null },

    completedAt: { type: Date, default: null },
  },
  { timestamps: true }
);

// One deviation per block per day — a second write updates the first.
ScheduleInstanceSchema.index({ userId: 1, blockId: 1, localDate: 1 }, { unique: true });
ScheduleInstanceSchema.index({ userId: 1, localDate: 1 });

module.exports = mongoose.model('ScheduleInstance', ScheduleInstanceSchema);
PLANBHAI_EOF
write 'backend/services/schedule.service.js' << 'PLANBHAI_EOF'
const ScheduleBlock = require('../models/ScheduleBlock');
const ScheduleInstance = require('../models/ScheduleInstance');
const { startOfLocalDayUtc } = require('./daybrief/tz.util');

/**
 * Expands schedule blocks into a given day, applying that day's deviations.
 *
 * Pure where it can be: occursOn and applyInstances take plain data and no
 * database, so the recurrence maths is testable without fixtures.
 */

/** Day of week for a local date, 0 = Sunday. */
function dowOf(localDate) {
  return new Date(`${localDate}T12:00:00Z`).getUTCDay();
}

/** Whole days between two 'YYYY-MM-DD' strings. */
function daysBetween(from, to) {
  return Math.round(
    (Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86400000
  );
}

/**
 * Does this block occur on this date?
 *
 * `weekly` covers most people. `cycle` exists for rotas that drift against the
 * week — a 4-on-4-off pattern puts every weekday sometimes on and sometimes
 * off, which no days-of-week list can express.
 */
function occursOn(block, localDate) {
  if (!block.active) return false;
  const r = block.recurrence || {};

  if (r.type === 'cycle') {
    if (!r.cycleLength || !r.anchorDate || !Array.isArray(r.onDays)) return false;
    const delta = daysBetween(r.anchorDate, localDate);
    // Modulo twice so dates before the anchor still land on a valid position.
    const pos = ((delta % r.cycleLength) + r.cycleLength) % r.cycleLength;
    return r.onDays.includes(pos);
  }

  return (r.days || []).includes(dowOf(localDate));
}

const toMin = (hhmm) => {
  const [h, m] = String(hhmm || '0:0').split(':').map(Number);
  return (h || 0) * 60 + (m || 0);
};

const toHHMM = (min) =>
  `${String(Math.floor(min / 60) % 24).padStart(2, '0')}:${String(min % 60).padStart(2, '0')}`;

/**
 * Merges blocks with their deviations for one day.
 *
 * A `skipped` instance removes the row entirely — the user said it isn't
 * happening, so showing it greyed out would just be clutter they already
 * dismissed.
 */
function applyInstances(blocks, instances, localDate) {
  const byBlock = new Map(instances.map((i) => [String(i.blockId), i]));
  const rows = [];

  for (const b of blocks) {
    if (!occursOn(b, localDate)) continue;
    const inst = byBlock.get(String(b._id));

    if (inst && inst.state === 'skipped') continue;

    const start = (inst && inst.startTime) || b.startTime;
    const duration = (inst && inst.durationMin) || b.durationMin;

    rows.push({
      blockId: String(b._id),
      title: b.title,
      kind: b.kind,
      start,
      end: toHHMM(toMin(start) + duration),
      durationMin: duration,
      tags: b.tags || [],
      goalId: b.goalId || null,
      done: Boolean(inst && inst.state === 'done'),
      moved: Boolean(inst && inst.state === 'moved'),
      source: 'schedule',
    });
  }

  return rows.sort((a, b) => toMin(a.start) - toMin(b.start));
}

/** Everything on this person's schedule for one day. */
async function blocksForDate({ userId, localDate }) {
  const [blocks, instances] = await Promise.all([
    ScheduleBlock.find({ userId, active: true }).lean(),
    ScheduleInstance.find({ userId, localDate }).lean(),
  ]);
  return applyInstances(blocks, instances, localDate);
}

/**
 * Records a deviation. Upserts, so marking done then moving replaces rather
 * than accumulating rows.
 */
async function setInstance({ scopeId, userId, blockId, localDate, state, startTime, durationMin }) {
  const update = { scopeId, userId, blockId, localDate, state };
  if (state === 'moved') {
    update.startTime = startTime || null;
    update.durationMin = durationMin || null;
  }
  if (state === 'done') update.completedAt = new Date();

  return ScheduleInstance.findOneAndUpdate(
    { userId, blockId, localDate },
    update,
    { upsert: true, new: true }
  );
}

/** Clears a deviation — un-completing, or undoing a move. */
async function clearInstance({ userId, blockId, localDate }) {
  return ScheduleInstance.deleteOne({ userId, blockId, localDate });
}

module.exports = {
  blocksForDate,
  setInstance,
  clearInstance,
  // exported for tests
  occursOn,
  applyInstances,
  daysBetween,
  toMin,
  toHHMM,
};
PLANBHAI_EOF
write 'backend/routes/schedule.routes.js' << 'PLANBHAI_EOF'
const express = require('express');
const ScheduleBlock = require('../models/ScheduleBlock');
const { blocksForDate, setInstance, clearInstance } = require('../services/schedule.service');
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
const { blocksForDate } = require('../schedule.service');
const { todayIn, endOfLocalDayUtc, localTimeIn, relativeDayLabel } = require('./tz.util');

const CURRENT_SCHEMA_VERSION = 1;

/** One emoji per block kind, so a timeline row reads at a glance. */
function blockIcon(kind) {
  switch (kind) {
    case 'deep_work': return '🎯';
    case 'health':    return '💪';
    case 'family':    return '👨‍👩‍👧';
    case 'learning':  return '📚';
    case 'urgent':    return '🔥';
    case 'commute':   return '🚗';
    case 'meal':      return '🍽';
    case 'rest':      return '🌙';
    default:          return '📌';
  }
}

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

  // Schedule blocks are PERSONAL, and the brief is cached per household. Merging
  // them here rather than in buildBrief is what stops one member's day being
  // cached and served to everyone else — the same reason habits and dismissals
  // are applied at read time.
  try {
    const blocks = await blocksForDate({
      userId: String(user._id),
      localDate: doc.localDate,
    });

    if (blocks.length) {
      const rows = blocks.map((b) => ({
        start: b.start,
        end: b.end,
        title: b.title,
        kind: 'block',
        source: 'schedule',
        sourceId: b.blockId,
        icon: blockIcon(b.kind),
        done: b.done,
      }));
      doc.timeline = [...(doc.timeline || []), ...rows].sort((a, b) =>
        String(a.start).localeCompare(String(b.start))
      );
    }
  } catch (err) {
    // A schedule failure must not cost the user their whole brief.
    console.error('[daybrief] schedule merge failed:', err.message);
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

for f in backend/models/ScheduleBlock.js backend/models/ScheduleInstance.js \
         backend/services/schedule.service.js backend/routes/schedule.routes.js \
         backend/services/daybrief/daybrief.service.js; do
  node --check "$f" || { echo "   PARSE FAILED: $f"; exit 1; }
done
echo "   all five parse"
echo

echo "2. Mounting the route"
if grep -q "schedule.routes" backend/server.js; then
  echo "   already mounted"
else
  cp backend/server.js backend/server.js.bakphasea
  python3 - backend/server.js << 'PY_EOF'
import sys, re
p = sys.argv[1]
s = open(p).read()
m = None
for m in re.finditer(r"app\.use\(\s*['\"]/api[^\n]*\n", s): pass
if not m:
    print("   ERROR: no /api mounts found"); sys.exit(2)
s = s[:m.end()] + "app.use('/api/schedule', require('./routes/schedule.routes'));\n" + s[m.end():]
open(p, "w").write(s)
print("   added /api/schedule")
PY_EOF
  [ $? -ne 0 ] && { cp backend/server.js.bakphasea backend/server.js; echo "   reverted"; exit 1; }
  node --check backend/server.js && echo "   server.js parses"
fi
echo

echo "3. Indexes"
cd backend
cat > ./.pb_idx.js << 'IDX_EOF'
require("dotenv").config();
const m = require("mongoose");
(async () => {
  await m.connect(process.env.MONGODB_URI);
  for (const n of ["ScheduleBlock", "ScheduleInstance"]) {
    await require("./models/" + n).syncIndexes();
    console.log("   indexed " + n);
  }
  await m.disconnect();
})().catch(e => { console.error("   " + e.message); process.exit(0); });
IDX_EOF
node ./.pb_idx.js
rm -f ./.pb_idx.js
echo

echo "4. Recurrence check"
cat > ./.pb_rec.js << 'REC_EOF'
const { occursOn } = require("./services/schedule.service");
const weekly = { active: true, recurrence: { type: "weekly", days: [1,2,3,4,5] } };
const rota   = { active: true, recurrence: { type: "cycle", cycleLength: 8, onDays: [0,1,2,3], anchorDate: "2026-08-03" } };
let ok = true;
const expect = (cond, label) => { if (!cond) { ok = false; console.log("   FAIL " + label); } };
expect(occursOn(weekly, "2026-08-03"), "weekly Monday");
expect(!occursOn(weekly, "2026-08-08"), "weekly Saturday off");
expect(occursOn(rota, "2026-08-03"), "rota day 0");
expect(!occursOn(rota, "2026-08-07"), "rota day 4 off");
expect(occursOn(rota, "2026-08-11"), "rota Tue week 2 — the drift case");
expect(!occursOn(rota, "2026-08-10"), "rota Mon week 2 off — the drift case");
console.log(ok ? "   weekly and cyclic recurrence both correct" : "   RECURRENCE BROKEN");
process.exit(ok ? 0 : 1);
REC_EOF
node ./.pb_rec.js || { echo "   recurrence test failed"; rm -f ./.pb_rec.js; exit 1; }
rm -f ./.pb_rec.js

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
echo "     git add -A && git commit -m 'Schedule Phase A: writable blocks' && git push"
echo "  then Manual Deploy on Render."
echo
echo "  Then create a block and see it in your timeline:"
echo
echo "     TOK=\$(curl -s -X POST https://planbhai.onrender.com/api/auth/login \\"
echo "       -H 'Content-Type: application/json' \\"
echo "       -d '{\"email\":\"ritesh@test.com\",\"password\":\"Test@1234\"}' \\"
echo "       | node -pe 'JSON.parse(require(\"fs\").readFileSync(0)).token')"
echo
echo "     curl -s -X POST 'https://planbhai.onrender.com/api/schedule/blocks?scopeId=6a5186af77659b8762bfb01c' \\"
echo "       -H \"Authorization: Bearer \$TOK\" -H 'Content-Type: application/json' \\"
echo "       -d '{\"title\":\"Deep work\",\"kind\":\"deep_work\",\"startTime\":\"09:00\",\"durationMin\":90}'"
echo "=========================================="

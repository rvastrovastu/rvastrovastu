#!/usr/bin/env bash
#
# Schedule Builder — Phase C: profession templates. NO AI.
#
# Eight professions as server-side JSON. Pick one, answer five questions, get a
# day. Every block is derived arithmetically from an anchor time, so applying
# the same template twice gives the same result — a schedule that differs each
# time you generate it is not a schedule.
#
# THREE ENDPOINTS
#   GET  /api/schedule/templates          the list and the five questions
#   POST /api/schedule/templates/preview  what WOULD be created, writes nothing
#   POST /api/schedule/templates/apply    creates the blocks
#
# Served rather than hardcoded per client, so a ninth profession is a server
# edit — no app release, and iOS and web cannot drift.
#
# DELIBERATELY SPARSE — 3 to 5 blocks each, averaging 4.3. A day filled edge to
# edge is the task list this product exists to avoid. These are the anchors a
# day hangs on; the calendar, meals and habits fill the rest.
#
# WARNINGS, NOT SILENT CORRECTION. Say you wake at 9 and start work at 8 and
# the blocks still generate — but you are told. Quietly reordering someone's day
# is worse than showing them the conflict.
#
# APPLYING REPLACES ONLY TEMPLATE-GENERATED BLOCKS. Anything created by hand is
# never touched.
#
# A BUG FOUND WHILE TESTING: toMin() returned 0 for a missing answer, because
# String(undefined || '') is "" and Number("") is 0 — a valid midnight. So
# defaults were never applied and every block landed at 00:00. It now rejects
# anything that is not HH:MM.
#
# Usage:
#   bash ~/Downloads/install-schedule-templates.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
[ -d backend/services ] || { echo "ERROR: backend/services not found"; exit 1; }

echo "PlanBhai — schedule templates"
echo

echo "1. Prerequisite"
[ -f backend/services/schedule.service.js ] \
  && echo "   ok   schedule.service.js" \
  || { echo "   MISSING — run install-schedule-phase-a.sh first"; exit 1; }
echo

write() {
  local dest="$1"
  mkdir -p "$(dirname "$dest")"
  [ -f "$dest" ] && cp "$dest" "$dest.baktpl"
  cat > "$dest"
  echo "   wrote $dest"
}

echo "2. Files"
write 'backend/data/scheduleTemplates.js' << 'PLANBHAI_EOF'
/**
 * Profession day templates.
 *
 * Data, not code — adding a profession is an edit here, not a release. Times
 * are placeholders shifted by the user's answers; `anchor` says WHICH answer
 * moves a block, so a 6 AM riser and a 9 AM riser both get a sensible day.
 *
 * DELIBERATELY SPARSE. Four to six blocks, not twelve. A day filled edge to
 * edge is the task list this product exists to avoid — these are the anchors a
 * day hangs on, and the calendar, meals and habits fill the rest.
 *
 * `offsetMin` is relative to the anchor. Negative is before.
 */

const TEMPLATES = [
  {
    id: 'software_engineer',
    label: 'Software engineer',
    emoji: '💻',
    blocks: [
      { title: 'Morning routine', kind: 'health',    anchor: 'wake',      offsetMin: 0,   durationMin: 45, days: [1,2,3,4,5] },
      { title: 'Deep work',       kind: 'deep_work', anchor: 'workStart', offsetMin: 30,  durationMin: 120, days: [1,2,3,4,5] },
      { title: 'Lunch',           kind: 'meal',      anchor: 'workStart', offsetMin: 240, durationMin: 45, days: [1,2,3,4,5] },
      { title: 'Deep work II',    kind: 'deep_work', anchor: 'workStart', offsetMin: 330, durationMin: 90, days: [1,2,3,4,5] },
      { title: 'Wind down',       kind: 'rest',      anchor: 'sleep',     offsetMin: -60, durationMin: 45, days: [0,1,2,3,4,5,6] },
    ],
  },
  {
    id: 'student',
    label: 'Student',
    emoji: '🎓',
    blocks: [
      { title: 'Morning routine', kind: 'health',   anchor: 'wake',      offsetMin: 0,   durationMin: 30, days: [1,2,3,4,5] },
      { title: 'Study block',     kind: 'learning', anchor: 'workStart', offsetMin: 0,   durationMin: 90, days: [1,2,3,4,5] },
      { title: 'Lunch',           kind: 'meal',     anchor: 'workStart', offsetMin: 210, durationMin: 45, days: [1,2,3,4,5] },
      { title: 'Review',          kind: 'learning', anchor: 'sleep',     offsetMin: -180, durationMin: 60, days: [0,1,2,3,4,5,6] },
    ],
  },
  {
    id: 'working_parent',
    label: 'Working parent',
    emoji: '👨‍👩‍👧',
    blocks: [
      { title: 'Morning rush',    kind: 'family',    anchor: 'wake',      offsetMin: 0,   durationMin: 60, days: [1,2,3,4,5] },
      { title: 'School run',      kind: 'commute',   anchor: 'workStart', offsetMin: -45, durationMin: 30, days: [1,2,3,4,5] },
      { title: 'Focus time',      kind: 'deep_work', anchor: 'workStart', offsetMin: 30,  durationMin: 90, days: [1,2,3,4,5] },
      { title: 'Pickup',          kind: 'commute',   anchor: 'workEnd',   offsetMin: -30, durationMin: 30, days: [1,2,3,4,5] },
      { title: 'Family dinner',   kind: 'family',    anchor: 'familyTime', offsetMin: 0,  durationMin: 90, days: [0,1,2,3,4,5,6] },
    ],
  },
  {
    id: 'homemaker',
    label: 'Homemaker',
    emoji: '🏡',
    blocks: [
      { title: 'Morning routine', kind: 'health', anchor: 'wake',       offsetMin: 0,   durationMin: 45, days: [0,1,2,3,4,5,6] },
      { title: 'House + errands', kind: 'admin',  anchor: 'wake',       offsetMin: 120, durationMin: 120, days: [1,2,3,4,5] },
      { title: 'Meal prep',       kind: 'meal',   anchor: 'familyTime', offsetMin: -90, durationMin: 60, days: [0,1,2,3,4,5,6] },
      { title: 'Family time',     kind: 'family', anchor: 'familyTime', offsetMin: 0,   durationMin: 90, days: [0,1,2,3,4,5,6] },
    ],
  },
  {
    id: 'entrepreneur',
    label: 'Entrepreneur',
    emoji: '🚀',
    blocks: [
      { title: 'Morning routine',  kind: 'health',    anchor: 'wake',      offsetMin: 0,   durationMin: 45, days: [1,2,3,4,5] },
      { title: 'Build time',       kind: 'deep_work', anchor: 'workStart', offsetMin: 0,   durationMin: 150, days: [1,2,3,4,5] },
      { title: 'Calls + admin',    kind: 'admin',     anchor: 'workStart', offsetMin: 300, durationMin: 120, days: [1,2,3,4,5] },
      // Unallocated on purpose. Something always goes wrong; a day with no slack
      // means every surprise displaces something that mattered.
      { title: 'Buffer',           kind: 'urgent',    anchor: 'workEnd',   offsetMin: -60, durationMin: 60, days: [1,2,3,4,5] },
      { title: 'Family time',      kind: 'family',    anchor: 'familyTime', offsetMin: 0,  durationMin: 90, days: [0,1,2,3,4,5,6] },
    ],
  },
  {
    id: 'healthcare',
    label: 'Healthcare shift',
    emoji: '🩺',
    // The only template using cyclic recurrence. A 4-on-4-off rota drifts
    // against the week — every weekday ends up sometimes on, sometimes off —
    // so days-of-week cannot describe it.
    cycle: { cycleLength: 8, onDays: [0, 1, 2, 3] },
    blocks: [
      { title: 'Pre-shift',    kind: 'health',  anchor: 'wake',      offsetMin: 0,   durationMin: 45 },
      { title: 'Shift',        kind: 'admin',   anchor: 'workStart', offsetMin: 0,   durationMin: 300 },
      { title: 'Charting',     kind: 'admin',   anchor: 'workStart', offsetMin: 300, durationMin: 45 },
      { title: 'Recovery',     kind: 'rest',    anchor: 'sleep',     offsetMin: -90, durationMin: 60 },
    ],
  },
  {
    id: 'teacher',
    label: 'Teacher',
    emoji: '📚',
    blocks: [
      { title: 'Morning prep',  kind: 'admin',    anchor: 'workStart', offsetMin: -45, durationMin: 45, days: [1,2,3,4,5] },
      { title: 'Teaching',      kind: 'deep_work', anchor: 'workStart', offsetMin: 0,  durationMin: 240, days: [1,2,3,4,5] },
      { title: 'Marking',       kind: 'admin',    anchor: 'workEnd',   offsetMin: -60, durationMin: 60, days: [1,2,3,4,5] },
      { title: 'Family time',   kind: 'family',   anchor: 'familyTime', offsetMin: 0,  durationMin: 90, days: [0,1,2,3,4,5,6] },
    ],
  },
  {
    id: 'flexible',
    label: 'Flexible / other',
    emoji: '🌿',
    blocks: [
      { title: 'Morning routine', kind: 'health',    anchor: 'wake',       offsetMin: 0,  durationMin: 45, days: [0,1,2,3,4,5,6] },
      { title: 'Focus time',      kind: 'deep_work', anchor: 'workStart',  offsetMin: 0,  durationMin: 120, days: [1,2,3,4,5] },
      { title: 'Family time',     kind: 'family',    anchor: 'familyTime', offsetMin: 0,  durationMin: 90, days: [0,1,2,3,4,5,6] },
    ],
  },
];

/**
 * The five questions. Every template block hangs off one of these, so a 6 AM
 * riser and a 9 AM riser both get a day that fits them.
 *
 * Five, not forty. The whole premise is that planning effort approaches zero.
 */
const QUESTIONS = [
  { key: 'wake',       label: 'When do you wake up?',     type: 'time', default: '07:00' },
  { key: 'workStart',  label: 'When does work start?',    type: 'time', default: '09:00' },
  { key: 'workEnd',    label: 'When does it finish?',     type: 'time', default: '17:00' },
  { key: 'familyTime', label: 'When is family time?',     type: 'time', default: '18:30' },
  { key: 'sleep',      label: 'When do you go to bed?',   type: 'time', default: '22:30' },
];

module.exports = { TEMPLATES, QUESTIONS };
PLANBHAI_EOF
write 'backend/services/scheduleTemplate.service.js' << 'PLANBHAI_EOF'
const ScheduleBlock = require('../models/ScheduleBlock');
const { TEMPLATES, QUESTIONS } = require('../data/scheduleTemplates');

/**
 * Turns a template plus five answers into schedule blocks.
 *
 * NO AI. Every block is derived arithmetically from an anchor time, so applying
 * the same template twice gives the same day — which matters, because a
 * schedule that differs each time you generate it is not a schedule.
 */

/**
 * "07:00" -> 420. Anything that isn't HH:MM returns null.
 *
 * The shape check matters: String(undefined || '') is "", which splits to [""],
 * which Number() turns into 0 — a perfectly valid midnight. Without it, a
 * missing answer looked like a real one and defaults were never applied, so
 * every block landed at 00:00.
 */
const toMin = (hhmm) => {
  if (typeof hhmm !== 'string') return null;
  const m = /^(\d{1,2}):(\d{2})$/.exec(hhmm.trim());
  if (!m) return null;
  const h = Number(m[1]);
  const min = Number(m[2]);
  if (h > 23 || min > 59) return null;
  return h * 60 + min;
};

const toHHMM = (min) => {
  // Wrap rather than clamp: a night-shift block at "wake minus 90" can
  // legitimately land the previous evening.
  const w = ((min % 1440) + 1440) % 1440;
  return `${String(Math.floor(w / 60)).padStart(2, '0')}:${String(w % 60).padStart(2, '0')}`;
};

/** Fills missing answers from the question defaults. */
function normalizeAnswers(answers) {
  const out = {};
  for (const q of QUESTIONS) {
    const given = answers && answers[q.key];
    out[q.key] = toMin(given) != null ? given : q.default;
  }
  return out;
}

/**
 * @returns {{ blocks: Array, warnings: string[] }}
 *
 * Warnings rather than silent correction. If someone says they wake at 9 and
 * work starts at 8, the blocks still generate — but they are told, because
 * quietly reordering their day would be worse than showing them the conflict.
 */
function buildBlocks({ templateId, answers }) {
  const template = TEMPLATES.find((t) => t.id === templateId);
  if (!template) return { blocks: [], warnings: ['Unknown template'] };

  const a = normalizeAnswers(answers);
  const warnings = [];

  if (toMin(a.workStart) < toMin(a.wake)) {
    warnings.push('Work starts before you wake — check those times.');
  }
  if (toMin(a.workEnd) < toMin(a.workStart)) {
    warnings.push('Work finishes before it starts — check those times.');
  }

  const blocks = [];
  for (const b of template.blocks) {
    const anchor = toMin(a[b.anchor]);
    if (anchor == null) continue;

    const startTime = toHHMM(anchor + (b.offsetMin || 0));

    const recurrence = template.cycle
      ? {
          type: 'cycle',
          cycleLength: template.cycle.cycleLength,
          onDays: template.cycle.onDays,
          // Anchored to today, so the rota starts from when it was set up.
          anchorDate: new Date().toISOString().slice(0, 10),
          days: [],
        }
      : { type: 'weekly', days: b.days || [1, 2, 3, 4, 5] };

    blocks.push({
      title: b.title,
      kind: b.kind,
      startTime,
      durationMin: b.durationMin,
      recurrence,
      source: 'template',
    });
  }

  // Overlaps within a generated day mean the template's offsets fight the
  // user's answers — a short work day compressing blocks into each other, say.
  // Reported, not resolved: the user knows their day better than the arithmetic.
  const sorted = [...blocks].sort((x, y) => toMin(x.startTime) - toMin(y.startTime));
  for (let i = 1; i < sorted.length; i++) {
    const prevEnd = toMin(sorted[i - 1].startTime) + sorted[i - 1].durationMin;
    if (toMin(sorted[i].startTime) < prevEnd) {
      warnings.push(`"${sorted[i - 1].title}" and "${sorted[i].title}" overlap.`);
    }
  }

  return { blocks: sorted, warnings };
}

/**
 * Writes the blocks.
 *
 * Existing template-generated blocks are removed first, so re-applying replaces
 * rather than accumulating. Blocks the user created by hand are NEVER touched —
 * losing something you typed because you tried a template is unforgivable.
 */
async function applyTemplate({ scopeId, userId, templateId, answers }) {
  const { blocks, warnings } = buildBlocks({ templateId, answers });
  if (blocks.length === 0) return { created: 0, replaced: 0, warnings };

  const prior = await ScheduleBlock.deleteMany({ userId, source: 'template' });

  const created = await ScheduleBlock.insertMany(
    blocks.map((b) => ({ ...b, scopeId, userId, active: true }))
  );

  return { created: created.length, replaced: prior.deletedCount || 0, warnings };
}

module.exports = { TEMPLATES, QUESTIONS, buildBlocks, applyTemplate, toMin, toHHMM };
PLANBHAI_EOF
write 'backend/routes/schedule.routes.js' << 'PLANBHAI_EOF'
const express = require('express');
const ScheduleBlock = require('../models/ScheduleBlock');
const { blocksForDate, setInstance, clearInstance } = require('../services/schedule.service');
const { rangeForHousehold, MAX_DAYS } = require('../services/scheduleRange.service');
const {
  TEMPLATES, QUESTIONS, buildBlocks, applyTemplate,
} = require('../services/scheduleTemplate.service');
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

/**
 * GET /api/schedule/templates
 *
 * The profession list and the five questions. Served rather than hardcoded in
 * each client, so adding a ninth profession is a server edit — no app release,
 * and iOS and web can never drift.
 */
router.get('/templates', requireAuth, (req, res) => {
  res.json({
    success: true,
    templates: TEMPLATES.map((t) => ({
      id: t.id,
      label: t.label,
      emoji: t.emoji,
      blockCount: t.blocks.length,
      cyclic: Boolean(t.cycle),
    })),
    questions: QUESTIONS,
  });
});

/**
 * POST /api/schedule/templates/preview   { templateId, answers }
 *
 * What WOULD be created. Nothing is written — applying a template replaces the
 * existing generated blocks, so seeing it first is the difference between a
 * choice and a surprise.
 */
router.post('/templates/preview', requireAuth, requireHouseholdMember, (req, res) => {
  const { templateId, answers } = req.body || {};
  const { blocks, warnings } = buildBlocks({ templateId, answers });
  if (blocks.length === 0) {
    return res.status(422).json({ success: false, message: warnings[0] || 'Nothing to create' });
  }
  res.json({ success: true, blocks, warnings });
});

/**
 * POST /api/schedule/templates/apply   { templateId, answers }
 *
 * Replaces previously template-generated blocks. Blocks the user made by hand
 * are never touched — losing something you typed because you tried a template
 * would be unforgivable.
 */
router.post('/templates/apply', requireAuth, requireHouseholdMember, async (req, res) => {
  const { templateId, answers } = req.body || {};
  try {
    const result = await applyTemplate({
      scopeId: req.scopeId,
      userId: String(req.user._id),
      templateId,
      answers,
    });
    if (result.created === 0) {
      return res.status(422).json({
        success: false,
        message: result.warnings[0] || 'Nothing to create',
      });
    }
    await bustBriefsForOwner(String(req.user._id)).catch(() => {});
    res.json({ success: true, ...result });
  } catch (err) {
    console.error('[schedule/templates/apply]', err);
    res.status(500).json({ success: false, message: 'Could not apply that template' });
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

for f in backend/data/scheduleTemplates.js backend/services/scheduleTemplate.service.js \
         backend/routes/schedule.routes.js; do
  node --check "$f" || { echo "   PARSE FAILED: $f"; exit 1; }
done
echo "   all three parse"
echo

echo "3. Generating a day for each profession"
cd backend
cat > ./.pb_tpl.js << 'TPL_EOF'
const { TEMPLATES } = require("./data/scheduleTemplates");
const { buildBlocks } = require("./services/scheduleTemplate.service");

const answers = { wake:"06:30", workStart:"09:00", workEnd:"17:30", familyTime:"18:30", sleep:"22:30" };
let bad = 0;

for (const t of TEMPLATES) {
  const { blocks, warnings } = buildBlocks({ templateId: t.id, answers });
  const midnight = blocks.filter(b => b.startTime === "00:00").length;
  const flag = blocks.length === 0 ? "  NO BLOCKS" : midnight > 1 ? "  SUSPECT: several at 00:00" : "";
  if (flag) bad += 1;
  console.log("   " + t.emoji + " " + t.label.padEnd(20) + blocks.length + " blocks" + flag);
  for (const w of warnings) console.log("        ! " + w);
}
console.log(bad === 0 ? "   every template produced a sensible day" : "   " + bad + " template(s) look wrong");
process.exit(bad === 0 ? 0 : 1);
TPL_EOF
node ./.pb_tpl.js || { echo "   template generation failed"; rm -f ./.pb_tpl.js; exit 1; }
rm -f ./.pb_tpl.js
cd ..
echo

echo "=========================================="
echo "  Deploy:"
echo "     git add -A && git commit -m 'Schedule templates: 8 professions, no AI' && git push"
echo "  then Manual Deploy on Render."
echo
echo "  Try it — this REPLACES any template-generated blocks you have:"
echo
echo "     TOK=\$(curl -s -X POST https://planbhai.onrender.com/api/auth/login \\"
echo "       -H 'Content-Type: application/json' \\"
echo "       -d '{\"email\":\"ritesh@test.com\",\"password\":\"Test@1234\"}' \\"
echo "       | node -pe 'JSON.parse(require(\"fs\").readFileSync(0)).token')"
echo
echo "     curl -s -X POST 'https://planbhai.onrender.com/api/schedule/templates/preview?scopeId=6a5186af77659b8762bfb01c' \\"
echo "       -H \"Authorization: Bearer \$TOK\" -H 'Content-Type: application/json' \\"
echo "       -d '{\"templateId\":\"software_engineer\",\"answers\":{\"wake\":\"06:30\",\"workStart\":\"09:00\",\"workEnd\":\"17:30\",\"familyTime\":\"18:30\",\"sleep\":\"22:30\"}}' \\"
echo "       | node -pe 'JSON.parse(require(\"fs\").readFileSync(0)).blocks.map(b=>\"  \"+b.startTime+\"  \"+b.title).join(\"\\n\")'"
echo
echo "  preview writes nothing. Swap to /apply when the day looks right."
echo
echo "  NO UI YET — the picker is the next step, once you have seen what these"
echo "  produce against your own hours."
echo "=========================================="

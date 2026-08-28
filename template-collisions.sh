#!/usr/bin/env bash
#
# Template preview now shows what you already have, and flags real duplicates.
#
# THE PROBLEM, seen on your own data
#   Applying the software engineer template on top of six hand-made blocks gave:
#       06:30 template Morning routine
#       07:00 manual   Morning routine
#       09:00 manual   Deep work
#       09:30 template Deep work
#       14:00 manual   Deep work II
#       14:30 template Deep work II
#   The same day described twice, half an hour out of step.
#
# WHAT PREVIEW RETURNS NOW
#   blocks      what the template proposes
#   existing    what you already have, with its source
#   collisions  pairs that are genuinely the same thing
#
# HOW A COLLISION IS DECIDED — both conditions, never either.
#   Overlapping time ALONE is too broad: on your data, template "Lunch" at 13:00
#   overlaps manual "Walk" at 12:30, and those are different things happening at
#   once, which is a normal day.
#   Matching titles ALONE is too narrow: the same routine at a different hour is
#   fine.
#   Together they catch exactly the three real duplicates and nothing else.
#
# APPLY TAKES A MODE
#   keep        default — template blocks are replaced, hand-made ones are not
#   replaceAll  clears everything, including hand-made blocks
#
# replaceAll is destructive and only ever sent after the user has SEEN the
# collision list. That is the whole point of returning it.
#
# Usage:
#   bash ~/Downloads/template-collisions.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }

echo "PlanBhai — template collisions"
echo

write() {
  local dest="$1"
  [ -f "$dest" ] && cp "$dest" "$dest.bakcoll"
  cat > "$dest"
  echo "   wrote $dest"
}

echo "1. Backend"
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

/** Do two titles describe the same thing? */
function titlesMatch(a, b) {
  const norm = (t) => String(t || '').toLowerCase().replace(/[^a-z0-9 ]/g, ' ').replace(/\s+/g, ' ').trim();
  const x = norm(a);
  const y = norm(b);
  if (!x || !y) return false;
  if (x === y) return true;
  // "Lunch" vs "Lunch + walk" — one contains the other, so they are probably
  // the same slot described differently.
  return x.includes(y) || y.includes(x);
}

/**
 * Which proposed blocks clash with what the user already has?
 *
 * BOTH conditions, not either. Overlapping time alone is too broad — a deep
 * work block overlapping lunch is a normal busy day, not a duplicate. Matching
 * titles alone is too narrow — the same routine at a different hour is fine.
 *
 * Together they catch the real case: "Morning routine" at 06:30 proposed while
 * "Morning routine" at 07:00 already exists.
 */
function findCollisions(proposed, existing) {
  const out = [];
  for (const p of proposed) {
    const pStart = toMin(p.startTime);
    const pEnd = pStart + p.durationMin;

    for (const e of existing) {
      const eStart = toMin(e.startTime);
      if (eStart == null) continue;
      const eEnd = eStart + (e.durationMin || 0);

      const overlaps = pStart < eEnd && pEnd > eStart;
      if (!overlaps) continue;
      if (!titlesMatch(p.title, e.title)) continue;

      out.push({
        proposed: { title: p.title, startTime: p.startTime, durationMin: p.durationMin },
        existing: {
          id: String(e._id || e.id || ''),
          title: e.title,
          startTime: e.startTime,
          durationMin: e.durationMin,
        },
      });
      break;   // one clash per proposed block is enough to warn about
    }
  }
  return out;
}

/**
 * Writes the blocks.
 *
 * Existing template-generated blocks are removed first, so re-applying replaces
 * rather than accumulating. Blocks the user created by hand are NEVER touched —
 * losing something you typed because you tried a template is unforgivable.
 */
async function applyTemplate({ scopeId, userId, templateId, answers, mode = 'keep' }) {
  const { blocks, warnings } = buildBlocks({ templateId, answers });
  if (blocks.length === 0) return { created: 0, replaced: 0, warnings };

  let replaced = 0;

  if (mode === 'replaceAll') {
    // Everything goes, including blocks made by hand. Only ever reached when
    // the user has seen the collision list and chosen this explicitly.
    const r = await ScheduleBlock.deleteMany({ userId });
    replaced = r.deletedCount || 0;
  } else {
    // Default. Previously generated blocks are replaced so re-applying does not
    // accumulate; anything made by hand is untouched.
    const r = await ScheduleBlock.deleteMany({ userId, source: 'template' });
    replaced = r.deletedCount || 0;
  }

  const created = await ScheduleBlock.insertMany(
    blocks.map((b) => ({ ...b, scopeId, userId, active: true }))
  );

  return { created: created.length, replaced, mode, warnings };
}

module.exports = {
  TEMPLATES, QUESTIONS, buildBlocks, applyTemplate,
  findCollisions, titlesMatch, toMin, toHHMM,
};
PLANBHAI_EOF
write 'backend/routes/schedule.routes.js' << 'PLANBHAI_EOF'
const express = require('express');
const ScheduleBlock = require('../models/ScheduleBlock');
const { blocksForDate, setInstance, clearInstance } = require('../services/schedule.service');
const { rangeForHousehold, MAX_DAYS } = require('../services/scheduleRange.service');
const {
  TEMPLATES, QUESTIONS, buildBlocks, applyTemplate, findCollisions,
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
router.post('/templates/preview', requireAuth, requireHouseholdMember, async (req, res) => {
  const { templateId, answers } = req.body || {};
  const { blocks, warnings } = buildBlocks({ templateId, answers });
  if (blocks.length === 0) {
    return res.status(422).json({ success: false, message: warnings[0] || 'Nothing to create' });
  }

  try {
    // Returned alongside the proposal so the user can see their existing day
    // next to the suggested one, rather than discovering the overlap after
    // applying it.
    const existing = await ScheduleBlock.find({ userId: String(req.user._id), active: true })
      .sort({ startTime: 1 })
      .lean();

    res.json({
      success: true,
      blocks,
      warnings,
      existing: existing.map((b) => ({
        id: String(b._id),
        title: b.title,
        startTime: b.startTime,
        durationMin: b.durationMin,
        kind: b.kind,
        source: b.source || 'manual',
      })),
      collisions: findCollisions(blocks, existing),
    });
  } catch (err) {
    console.error('[schedule/templates/preview]', err);
    res.status(500).json({ success: false, message: 'Could not preview that template' });
  }
});

/**
 * POST /api/schedule/templates/apply   { templateId, answers }
 *
 * Replaces previously template-generated blocks. Blocks the user made by hand
 * are never touched — losing something you typed because you tried a template
 * would be unforgivable.
 */
router.post('/templates/apply', requireAuth, requireHouseholdMember, async (req, res) => {
  const { templateId, answers, mode } = req.body || {};

  // 'keep' by default — the least destructive. 'replaceAll' is only ever sent
  // after the user has seen the collision list and chosen it.
  if (mode && !['keep', 'replaceAll'].includes(mode)) {
    return res.status(400).json({ success: false, message: 'Unknown mode' });
  }

  try {
    const result = await applyTemplate({
      scopeId: req.scopeId,
      userId: String(req.user._id),
      templateId,
      answers,
      mode: mode || 'keep',
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

for f in backend/services/scheduleTemplate.service.js backend/routes/schedule.routes.js; do
  node --check "$f" || { echo "   PARSE FAILED: $f"; exit 1; }
done
echo "   both parse"
echo

echo "2. Collision logic against your real blocks"
cd backend
cat > ./.pb_coll.js << 'COLL_EOF'
const { findCollisions } = require("./services/scheduleTemplate.service");

const existing = [
  { title: "Morning routine", startTime: "07:00", durationMin: 30 },
  { title: "Deep work",       startTime: "09:00", durationMin: 120 },
  { title: "Walk",            startTime: "12:30", durationMin: 45 },
  { title: "Deep work II",    startTime: "14:00", durationMin: 90 },
  { title: "Family time",     startTime: "18:30", durationMin: 90 },
];
const proposed = [
  { title: "Morning routine", startTime: "06:30", durationMin: 45 },
  { title: "Deep work",       startTime: "09:30", durationMin: 120 },
  { title: "Lunch",           startTime: "13:00", durationMin: 45 },
  { title: "Deep work II",    startTime: "14:30", durationMin: 90 },
  { title: "Wind down",       startTime: "21:30", durationMin: 45 },
];

const c = findCollisions(proposed, existing);
console.log("   " + c.length + " collision(s):");
c.forEach(x => console.log("      " + x.proposed.startTime + " " + x.proposed.title +
                           "  <->  " + x.existing.startTime + " " + x.existing.title));

const lunchFlagged = c.some(x => x.proposed.title === "Lunch");
if (c.length !== 3 || lunchFlagged) {
  console.log("   WRONG — expected exactly the 3 duplicates, and Lunch not flagged");
  process.exit(1);
}
console.log("   correct: 3 duplicates caught, Lunch vs Walk left alone");
COLL_EOF
node ./.pb_coll.js || { echo "   collision logic failed"; rm -f ./.pb_coll.js; exit 1; }
rm -f ./.pb_coll.js
cd ..
echo

echo "=========================================="
echo "  Deploy:"
echo "     git add -A && git commit -m 'Template preview shows existing blocks and collisions' && git push"
echo "  then Manual Deploy on Render."
echo
echo "  Preview now returns existing + collisions. Try it:"
echo
echo "     curl -s -X POST '.../api/schedule/templates/preview?scopeId=...' \\"
echo "       -H \"Authorization: Bearer \$TOK\" -H 'Content-Type: application/json' \\"
echo "       -d '{\"templateId\":\"software_engineer\",\"answers\":{...}}' \\"
echo "       | node -pe 'const d=JSON.parse(require(\"fs\").readFileSync(0)); d.collisions.length + \" collisions\"'"
echo
echo "  NO UI YET. The picker comes next, and it can now show the choice"
echo "  honestly because the data behind it exists."
echo "=========================================="

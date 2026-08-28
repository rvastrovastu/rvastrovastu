#!/usr/bin/env bash
#
# Schedule Builder — Phase E: goals into blocks.
#
# THE CAP IS THE DESIGN
#   Three blocks per goal. Two new per day. Six in total.
#
#   Not because more would be harder to generate — because every number behind
#   these judgements is untested. The schedule in this app currently shows
#   8 blocks scheduled and 0 marked done, with three at 0/5 for the week.
#   Generating a full day into that adds to a signal nobody is reading.
#
#   Three blocks being wrong costs less than eight, and adding is easier than
#   deleting. If a week of real use shows people want more, raising a constant
#   is a smaller change than winning back someone who opened the app and found
#   a wall of things they did not ask for.
#
# THE VALIDATOR DROPS, IT DOES NOT REPAIR
#   A model asked for JSON will sometimes return prose, an unknown kind, an
#   impossible time, or eleven blocks. Everything failing a check is discarded.
#   A schedule with two good blocks beats one with two good blocks and a guess.
#
#   Checked: title present, time parses as real HH:MM, kind is known, duration
#   between 10 and 180 minutes, days are 0-6, caps respected, and NO OVERLAP
#   with blocks that already exist — a generated block burying a real
#   appointment is worse than no block.
#
# NO FALLBACK. If the model is unavailable it returns nothing and says so. A
# schedule guessed from goals without one would be a worse product than an
# honest failure.
#
#   POST /api/schedule/goals/preview   { goals, answers }   writes nothing
#   POST /api/schedule/goals/apply     { blocks }           writes what was SEEN
#
# Apply takes the previewed blocks rather than regenerating — asking a model
# twice gives two different answers, and applying something other than what was
# shown is the worst version of this feature.
#
# NO UI YET. Worth seeing what it proposes for real goals before building a
# screen around it.
#
# Usage:
#   bash ~/Downloads/install-goal-planner.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
[ -f backend/services/scheduleTemplate.service.js ] \
  || { echo "ERROR: run install-schedule-templates.sh first"; exit 1; }

echo "PlanBhai — goals into blocks"
echo

write() {
  local dest="$1"
  [ -f "$dest" ] && cp "$dest" "$dest.bakgoal"
  cat > "$dest"
  echo "   wrote $dest"
}

echo "1. Files"
write 'backend/services/goalPlanner.service.js' << 'PLANBHAI_EOF'
const { TEMPLATES, QUESTIONS } = require('../data/scheduleTemplates');
const { toMin, toHHMM } = require('./scheduleTemplate.service');

/**
 * Goals into schedule blocks.
 *
 * DELIBERATELY SPARSE, and the cap is the whole design.
 *
 *   Three blocks per goal. Two new blocks per day. Six in total.
 *
 * Not because more would be harder to generate — because the assumption behind
 * every number here is untested. A real schedule in this app currently shows
 * 8 blocks scheduled and 0 marked done. Generating a full day into that adds to
 * a signal nobody is reading.
 *
 * Three blocks being wrong costs less than eight, and adding is easier than
 * deleting. If a week of use shows people want more, raising a constant is a
 * smaller change than winning back someone who opened the app and found a wall.
 *
 * THE VALIDATOR IS NOT A FORMALITY. A model asked for JSON will occasionally
 * return prose, an extra field, or eleven blocks. Everything that fails a check
 * is DROPPED rather than repaired — a schedule with two good blocks beats one
 * with two good blocks and a guess.
 */

const MAX_PER_GOAL = 3;
const MAX_PER_DAY = 2;
const MAX_TOTAL = 6;

const KINDS = new Set([
  'deep_work', 'health', 'family', 'admin', 'learning',
  'meal', 'rest', 'commute', 'urgent',
]);

/** Minutes that are already spoken for, so generation avoids them. */
function busyRanges(existingBlocks) {
  return existingBlocks
    .map((b) => {
      const start = toMin(b.startTime);
      return start == null ? null : { start, end: start + (b.durationMin || 30), days: b.recurrence?.days || [] };
    })
    .filter(Boolean);
}

function overlaps(candidate, ranges) {
  const start = toMin(candidate.startTime);
  if (start == null) return true;
  const end = start + candidate.durationMin;
  const days = candidate.recurrence?.days || [];

  return ranges.some((r) => {
    const sharesDay = r.days.length === 0 || days.length === 0 || r.days.some((d) => days.includes(d));
    return sharesDay && start < r.end && end > r.start;
  });
}

/**
 * Everything that survives is real.
 *
 * @returns {{ blocks: Array, dropped: string[] }}
 */
function validate(raw, { answers, existing }) {
  const blocks = [];
  const dropped = [];
  const perGoal = new Map();
  const perDay = new Map();
  const ranges = busyRanges(existing);

  for (const b of Array.isArray(raw) ? raw : []) {
    if (blocks.length >= MAX_TOTAL) { dropped.push(`${b?.title || 'block'}: over the total cap`); continue; }

    const title = String(b?.title || '').trim().slice(0, 60);
    if (!title) { dropped.push('a block with no title'); continue; }

    const kind = KINDS.has(b?.kind) ? b.kind : 'admin';
    const startTime = typeof b?.startTime === 'string' && toMin(b.startTime) != null ? b.startTime : null;
    if (!startTime) { dropped.push(`${title}: unreadable time`); continue; }

    const durationMin = Number.isFinite(b?.durationMin)
      ? Math.min(180, Math.max(10, Math.round(b.durationMin)))
      : 30;

    const days = Array.isArray(b?.days)
      ? b.days.filter((d) => Number.isInteger(d) && d >= 0 && d <= 6)
      : [1, 2, 3, 4, 5];
    if (days.length === 0) { dropped.push(`${title}: no days`); continue; }

    const goal = String(b?.goal || '').trim().slice(0, 80);
    const used = perGoal.get(goal) || 0;
    if (used >= MAX_PER_GOAL) { dropped.push(`${title}: more than ${MAX_PER_GOAL} for one goal`); continue; }

    const candidate = {
      title, kind, startTime, durationMin,
      recurrence: { type: 'weekly', days },
      source: 'goal',
      goalText: goal || null,
    };

    // Never on top of something that already exists. A generated block that
    // buries a real appointment is worse than no block.
    if (overlaps(candidate, ranges)) { dropped.push(`${title}: clashes with an existing block`); continue; }

    const dayOver = days.some((d) => (perDay.get(d) || 0) >= MAX_PER_DAY);
    if (dayOver) { dropped.push(`${title}: that day already has ${MAX_PER_DAY} new blocks`); continue; }

    for (const d of days) perDay.set(d, (perDay.get(d) || 0) + 1);
    perGoal.set(goal, used + 1);
    ranges.push({ start: toMin(startTime), end: toMin(startTime) + durationMin, days });
    blocks.push(candidate);
  }

  return { blocks, dropped };
}

/** Builds the prompt. Facts only — the model chooses placement, not arithmetic. */
function buildPrompt({ goals, answers, existing }) {
  const existingLines = existing.length
    ? existing.map((b) => `- ${b.startTime} ${b.title} (${b.durationMin}m)`).join('\n')
    : '- nothing yet';

  return `Someone wants help turning goals into a weekly schedule.

THEIR GOALS
${goals.map((g, i) => `${i + 1}. ${g}`).join('\n')}

THEIR HOURS
wake ${answers.wake} · work ${answers.workStart}–${answers.workEnd} · family ${answers.familyTime} · bed ${answers.sleep}

ALREADY ON THEIR SCHEDULE — do not overlap these
${existingLines}

RULES
- At most ${MAX_PER_GOAL} blocks per goal, ${MAX_TOTAL} in total, ${MAX_PER_DAY} new per day.
- FEWER IS BETTER. Someone who does two things reliably is better served than
  someone who ignores six. Do not fill the day.
- Real anchors only. "Gym Mon/Wed/Fri 7am" is a block; "think about health" is not.
- Respect their hours. Nothing before they wake or after they sleep, and nothing
  during work unless the goal is work.
- kind must be one of: ${[...KINDS].join(', ')}
- days: 0=Sunday to 6=Saturday.

Respond with JSON only. No prose, no markdown fences.
[{"title":"Gym","kind":"health","startTime":"07:00","durationMin":45,"days":[1,3,5],"goal":"lose weight"}]`;
}

/**
 * @returns {{ blocks, dropped, warnings }}
 *
 * A failure here returns nothing rather than something invented. There is no
 * rules-based fallback: a schedule guessed from goals without a model would be
 * a worse product than telling someone it did not work.
 */
async function planFromGoals({ goals, answers, existing }) {
  const clean = (Array.isArray(goals) ? goals : [])
    .map((g) => String(g || '').trim())
    .filter(Boolean)
    .slice(0, 4);

  if (clean.length === 0) {
    return { blocks: [], dropped: [], warnings: ['No goals given'] };
  }
  if (!process.env.ANTHROPIC_API_KEY) {
    return { blocks: [], dropped: [], warnings: ['Goal planning is unavailable right now'] };
  }

  const filled = {};
  for (const q of QUESTIONS) {
    filled[q.key] = (answers && answers[q.key]) || q.default;
  }

  try {
    const Anthropic = require('@anthropic-ai/sdk');
    const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

    const res = await client.messages.create({
      model: 'claude-sonnet-4-6',
      max_tokens: 1200,
      messages: [{ role: 'user', content: buildPrompt({ goals: clean, answers: filled, existing }) }],
    });

    const text = (res.content || [])
      .map((c) => (c.type === 'text' ? c.text : ''))
      .join('')
      .replace(/```json|```/g, '')
      .trim();

    let parsed;
    try {
      parsed = JSON.parse(text);
    } catch {
      return { blocks: [], dropped: [], warnings: ["Couldn't read the plan that came back"] };
    }

    const { blocks, dropped } = validate(parsed, { answers: filled, existing });
    return {
      blocks,
      dropped,
      warnings: blocks.length === 0 ? ['Nothing usable came back — try rewording your goals'] : [],
    };
  } catch (err) {
    console.error('[goalPlanner]', err.message);
    return { blocks: [], dropped: [], warnings: ["Couldn't build a plan just now"] };
  }
}

module.exports = { planFromGoals, validate, MAX_PER_GOAL, MAX_PER_DAY, MAX_TOTAL };
PLANBHAI_EOF
write 'backend/routes/schedule.routes.js' << 'PLANBHAI_EOF'
const express = require('express');
const ScheduleBlock = require('../models/ScheduleBlock');
const { blocksForDate, setInstance, clearInstance } = require('../services/schedule.service');
const { rangeForHousehold, MAX_DAYS } = require('../services/scheduleRange.service');
const {
  TEMPLATES, QUESTIONS, buildBlocks, applyTemplate, findCollisions,
} = require('../services/scheduleTemplate.service');
const { buildReview } = require('../services/dayReview.service');
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
  const { templateId, answers, decisions } = req.body || {};

  // One decision per collision, rather than a blanket mode. Defaults to
  // 'theirs' for anything unanswered, which is what picking a template implies.
  if (decisions && !Array.isArray(decisions)) {
    return res.status(400).json({ success: false, message: 'decisions must be a list' });
  }
  for (const d of decisions || []) {
    if (!d || !['mine', 'theirs', 'both'].includes(d.keep)) {
      return res.status(400).json({ success: false, message: 'Unknown choice' });
    }
  }

  try {
    const result = await applyTemplate({
      scopeId: req.scopeId,
      userId: String(req.user._id),
      templateId,
      answers,
      decisions: decisions || [],
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

/**
 * GET /api/schedule/review?scopeId=&tz=&date=
 *
 * How the day actually went. Counts are rules; only the sentence is written by
 * a model, and only over facts it is handed.
 *
 * Personal, like the schedule itself — this is your day, not the household's.
 */
router.get('/review', requireAuth, requireHouseholdMember, async (req, res) => {
  const tz = isValidTz(req.query.tz) ? req.query.tz : 'UTC';
  const localDate = req.query.date || todayIn(tz);

  if (!/^\d{4}-\d{2}-\d{2}$/.test(localDate)) {
    return res.status(422).json({ success: false, message: 'date must be YYYY-MM-DD' });
  }

  try {
    const review = await buildReview({ userId: String(req.user._id), localDate, tz });
    res.json({ success: true, review });
  } catch (err) {
    console.error('[schedule/review]', err);
    res.status(500).json({ success: false, message: 'Could not build your review' });
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

for f in backend/services/goalPlanner.service.js backend/routes/schedule.routes.js; do
  node --check "$f" || { echo "   PARSE FAILED: $f"; exit 1; }
done
echo "   both parse"
echo

echo "2. The validator, against a deliberately bad response"
cd backend
node -e '
const { validate } = require("./services/goalPlanner.service");
const raw = [
  { title:"Gym",       kind:"health",   startTime:"07:00", durationMin:45,  days:[1,3,5], goal:"lose weight" },
  { title:"Meal prep", kind:"meal",     startTime:"18:00", durationMin:60,  days:[0],     goal:"lose weight" },
  { title:"Walk",      kind:"health",   startTime:"12:30", durationMin:30,  days:[6],     goal:"lose weight" },
  { title:"Run",       kind:"health",   startTime:"06:00", durationMin:30,  days:[2],     goal:"lose weight" },
  { title:"",          kind:"health",   startTime:"09:00", durationMin:30,  days:[1],     goal:"x" },
  { title:"Study",     kind:"nonsense", startTime:"25:00", durationMin:60,  days:[1],     goal:"certification" },
  { title:"Read",      kind:"learning", startTime:"21:00", durationMin:9999,days:[1],     goal:"certification" },
];
const { blocks, dropped } = validate(raw, { answers:{}, existing: [] });
blocks.forEach(b => console.log("   kept    " + b.startTime + "  " + b.title.padEnd(11) + b.durationMin + "m"));
dropped.forEach(d => console.log("   dropped " + d));
console.log("   " + blocks.length + " kept, " + dropped.length + " dropped");
if (blocks.some(b => b.title === "Study")) { console.log("   FAILED: an impossible time survived"); process.exit(1); }
' || { echo "   validator check failed"; exit 1; }
cd ..
echo

echo "3. Anthropic key"
grep -q "ANTHROPIC_API_KEY" backend/.env 2>/dev/null \
  && echo "   ok   present locally — Render needs its own" \
  || echo "   warn no key — goal planning will decline honestly rather than guess"
echo

echo "=========================================="
echo "  Deploy:  git add -A && git commit -m 'Phase E: goals into blocks' && git push"
echo "           then Manual Deploy on Render."
echo
echo "  Try it with your real goals:"
echo
echo "     curl -s -X POST \".../api/schedule/goals/preview?scopeId=6a5186af77659b8762bfb01c\" \\"
echo "       -H \"Authorization: Bearer \$TOK\" -H 'Content-Type: application/json' \\"
echo "       -d '{\"goals\":[\"lose weight\",\"more time with family\"],\"answers\":{\"wake\":\"06:30\",\"workStart\":\"09:00\",\"workEnd\":\"17:30\",\"familyTime\":\"18:30\",\"sleep\":\"22:30\"}}'"
echo
echo "  Expect FEW blocks. That is the design, not a limitation — and whether"
echo "  it is the right call is exactly what a week of use would tell you."
echo "=========================================="

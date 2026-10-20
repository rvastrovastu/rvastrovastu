#!/usr/bin/env bash
#
# Schedule Builder — Phase D: the evening review.
#
# WHAT IT IS FOR
#   Without it the app schedules things and never learns whether they happened.
#   Blocks sit unmarked, the day rolls over, and the schedule slowly becomes
#   fiction nobody corrects. This is what makes it self-correcting.
#
# THE SPLIT
#   RULES COUNT. Scheduled, done, moved, missed, and which blocks keep slipping
#   across the week. All countable, so none of it goes near a model — a review
#   that miscounts your day is worse than no review.
#
#   AI WRITES ONE SENTENCE, over facts it is handed and nothing else. Same
#   division as the suggestion engine: models are good at phrasing and bad at
#   arithmetic.
#
# TWO JUDGEMENTS WORTH KNOWING
#   A block needs 3+ scheduled days before "slipping" applies. One missed gym
#   session is a Tuesday; four is a pattern worth naming.
#
#   The bad-day line offers no consolation. Being told "tomorrow is a new day"
#   after missing everything is worse than being told nothing, so the prompt
#   forbids it and the fallback simply states the count.
#
# GET /api/schedule/review?scopeId=&tz=&date=
#   Personal, like the schedule itself. Falls back to a rules-written line if
#   the model is unavailable or returns something that fails validation.
#
# NO UI YET — worth seeing what it says about a real day before building a
# screen around it.
#
# Usage:
#   bash ~/Downloads/install-day-review.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
[ -f backend/services/schedule.service.js ] \
  || { echo "ERROR: run install-schedule-phase-a.sh first"; exit 1; }

echo "PlanBhai — evening review"
echo

write() {
  local dest="$1"
  [ -f "$dest" ] && cp "$dest" "$dest.bakreview"
  cat > "$dest"
  echo "   wrote $dest"
}

echo "1. Backend"
write 'backend/services/dayReview.service.js' << 'PLANBHAI_EOF'
const ScheduleBlock = require('../models/ScheduleBlock');
const ScheduleInstance = require('../models/ScheduleInstance');
const { blocksForDate } = require('./schedule.service');
const { localDateIn } = require('./daybrief/tz.util');

/**
 * The evening review.
 *
 * RULES GATHER THE FACTS. What was scheduled, what got marked done, what
 * slipped, how the week is tracking. All of it is countable, so none of it goes
 * near a model — a review that miscounts your day is worse than no review.
 *
 * AI ONLY WRITES THE SENTENCE, and only over facts it is handed. That split is
 * the same one used for suggestions, and for the same reason: the model is good
 * at phrasing and bad at arithmetic.
 *
 * WHAT THIS IS FOR
 *   Without it the app schedules things and never learns whether they happened.
 *   Blocks sit unmarked, the day rolls over, and the schedule slowly becomes
 *   fiction that nobody corrects.
 */

const dayName = (localDate, tz) =>
  new Intl.DateTimeFormat('en-US', { timeZone: tz, weekday: 'long' })
    .format(new Date(`${localDate}T12:00:00Z`));

/** The seven days ending on localDate, oldest first. */
function weekEnding(localDate) {
  const out = [];
  const end = Date.parse(`${localDate}T00:00:00Z`);
  for (let i = 6; i >= 0; i--) {
    out.push(new Date(end - i * 86400000).toISOString().slice(0, 10));
  }
  return out;
}

/**
 * Everything the review needs, counted rather than inferred.
 */
async function gatherFacts({ userId, localDate, tz }) {
  const todaysBlocks = await blocksForDate({ userId, localDate });

  const done = todaysBlocks.filter((b) => b.done);
  const moved = todaysBlocks.filter((b) => b.moved);
  const missed = todaysBlocks.filter((b) => !b.done);

  // A week of instances, to see what keeps slipping. Blocks are templates, so
  // "scheduled" is derived; only deviations are stored.
  const dates = weekEnding(localDate);
  const [blocks, instances] = await Promise.all([
    ScheduleBlock.find({ userId, active: true }).lean(),
    ScheduleInstance.find({ userId, localDate: { $in: dates } }).lean(),
  ]);

  // Which blocks are habitually skipped? Counted across the week, because one
  // missed gym session is a Tuesday and four is a pattern worth naming.
  const perBlock = new Map();
  for (const b of blocks) {
    perBlock.set(String(b._id), { title: b.title, scheduled: 0, done: 0 });
  }
  for (const date of dates) {
    const rows = await blocksForDate({ userId, localDate: date });
    for (const r of rows) {
      const e = perBlock.get(r.blockId);
      if (!e) continue;
      e.scheduled += 1;
      if (r.done) e.done += 1;
    }
  }

  const slipping = [...perBlock.values()]
    .filter((e) => e.scheduled >= 3 && e.done / e.scheduled < 0.5)
    .sort((a, b) => a.done / a.scheduled - b.done / b.scheduled)
    .slice(0, 3);

  const consistent = [...perBlock.values()]
    .filter((e) => e.scheduled >= 3 && e.done / e.scheduled >= 0.8)
    .slice(0, 3);

  return {
    localDate,
    dayName: dayName(localDate, tz),
    today: {
      scheduled: todaysBlocks.length,
      done: done.length,
      moved: moved.length,
      missed: missed.map((b) => ({ title: b.title, start: b.start })),
      doneTitles: done.map((b) => b.title),
    },
    week: {
      slipping: slipping.map((e) => ({ title: e.title, done: e.done, of: e.scheduled })),
      consistent: consistent.map((e) => ({ title: e.title, done: e.done, of: e.scheduled })),
    },
    // Nothing to review is a real state, not an error. A day with no blocks
    // should say so rather than manufacture encouragement.
    hasSchedule: todaysBlocks.length > 0,
    instanceCount: instances.length,
  };
}

/**
 * One sentence about the day, written over the facts above.
 *
 * Falls back to a plain rules-built line if the model is unavailable or says
 * something that fails validation — a review is not worth a broken sentence.
 */
async function narrate(facts) {
  const t = facts.today;

  const fallback = () => {
    if (!facts.hasSchedule) return "No blocks scheduled today.";
    if (t.done === 0) return `Nothing marked done from ${t.scheduled} blocks today.`;
    if (t.done === t.scheduled) return `All ${t.scheduled} blocks done.`;
    return `${t.done} of ${t.scheduled} blocks done.`;
  };

  if (!process.env.ANTHROPIC_API_KEY || !facts.hasSchedule) {
    return { line: fallback(), generatedBy: 'rule' };
  }

  try {
    const Anthropic = require('@anthropic-ai/sdk');
    const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

    const res = await client.messages.create({
      model: 'claude-sonnet-4-6',
      max_tokens: 200,
      messages: [{
        role: 'user',
        content: `Write ONE sentence summarising someone's day. Under 140 characters.

Facts — use only these, invent nothing:
- ${t.done} of ${t.scheduled} blocks done${t.moved ? `, ${t.moved} moved` : ''}
- Completed: ${t.doneTitles.join(', ') || 'none'}
- Missed: ${t.missed.map((m) => m.title).join(', ') || 'none'}
${facts.week.slipping.length ? `- Slipping this week: ${facts.week.slipping.map((s) => `${s.title} ${s.done}/${s.of}`).join(', ')}` : ''}

Tone: a friend noticing, not a coach. No exclamation marks, no emoji, no
questions. If the day went badly, say so plainly without consolation — being
told "tomorrow's a new day" when you missed everything is worse than silence.

Respond with the sentence only.`,
      }],
    });

    const line = (res.content || [])
      .map((c) => (c.type === 'text' ? c.text : ''))
      .join('')
      .trim()
      .replace(/^["']|["']$/g, '');

    // Length and shape checks. A model that returns a paragraph, or asks a
    // question, is not doing the job asked of it.
    if (!line || line.length > 200 || line.includes('\n') || line.includes('?')) {
      return { line: fallback(), generatedBy: 'rule' };
    }
    return { line, generatedBy: 'ai' };
  } catch (err) {
    console.error('[review] narration failed:', err.message);
    return { line: fallback(), generatedBy: 'rule' };
  }
}

async function buildReview({ userId, localDate, tz }) {
  const facts = await gatherFacts({ userId, localDate, tz });
  const { line, generatedBy } = await narrate(facts);
  return { ...facts, summary: line, generatedBy };
}

module.exports = { buildReview, gatherFacts, weekEnding };
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

node --check backend/services/dayReview.service.js || exit 1
node --check backend/routes/schedule.routes.js || exit 1
echo "   both parse"
echo

echo "2. Anthropic key"
grep -q "ANTHROPIC_API_KEY" backend/.env 2>/dev/null \
  && echo "   ok   present locally — Render needs its own" \
  || echo "   warn no key — the review still works, using the rules-written line"
echo

echo "=========================================="
echo "  Deploy:"
echo "     git add -A && git commit -m 'Phase D: evening review' && git push"
echo "  then Manual Deploy on Render."
echo
echo "  Then see what it says about today:"
echo
echo "     TOK=\$(curl -s -X POST https://planbhai.onrender.com/api/auth/login \\"
echo "       -H 'Content-Type: application/json' \\"
echo "       -d '{\"email\":\"ritesh@test.com\",\"password\":\"Test@1234\"}' \\"
echo "       | node -pe 'JSON.parse(require(\"fs\").readFileSync(0)).token')"
echo
echo "     curl -s \"https://planbhai.onrender.com/api/schedule/review?scopeId=6a5186af77659b8762bfb01c&tz=America/Chicago\" \\"
echo "       -H \"Authorization: Bearer \$TOK\" | node -pe 'const r=JSON.parse(require(\"fs\").readFileSync(0)).review; r.summary+\"\\n\\ndone \"+r.today.done+\"/\"+r.today.scheduled+(r.week.slipping.length?\"\\nslipping: \"+r.week.slipping.map(s=>s.title+\" \"+s.done+\"/\"+s.of).join(\", \"):\"\")'"
echo
echo "  Expect it to be thin — your blocks are a day old and mostly unmarked."
echo "  That IS the point: it will tell you the schedule is not being used,"
echo "  which is the first honest thing it can say."
echo "=========================================="

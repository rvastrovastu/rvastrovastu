#!/usr/bin/env bash
#
# Thirteen templates, and planning merged into My Day.
#
# TEMPLATES: 8 -> 13, and 4 blocks -> 6-7 each.
#   Software engineer · Busy parent · College student · Doctor · Nurse ·
#   Teacher · Founder · Homemaker · Freelancer · Frequent traveller ·
#   Fitness focused · Event planner · Something else
#
#   Missing anchors added — the engineer had no family time, the student had no
#   classes, the teacher had no lunch, the homemaker had no school run.
#
#   Filler resisted. "Check email", "stretch", "review tomorrow" are real
#   activities but not anchors, and adding them makes every day look identical.
#   Six to seven blocks: enough to feel like a day, not a wall.
#
# CONFIDENCE IS NOT UNIFORM. The engineering, parent, student and homemaker days
# come from direct knowledge. The clinical, freelance and event ones are
# informed guesses — plausible and editable, and worth a glance from someone who
# does that job before being treated as authoritative. The file says so.
#
# A BUG FOUND WHILE TESTING: the overlap warning compared clock times and
# ignored `days`, so a Monday gym session and a Sunday meal prep at the same
# hour were reported as colliding. It now checks whether the blocks share a day
# at all — false positives gone, real same-day overlaps still caught.
#
# PLANNING MERGED INTO MY DAY
#   The setup flow now renders in place of the block list rather than at its own
#   URL. Planning a day and editing it are the same task; splitting them across
#   two pages meant the planner was somewhere you had to already know about.
#
#   Empty My Day offers "Plan my day". A populated one offers "Start from a
#   template" beside "Add a block". /setup-day still works standalone.
#
# Usage:
#   bash ~/Downloads/expand-templates.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }

echo "PlanBhai — 13 templates, planning in My Day"
echo

write() {
  local dest="$1"
  [ -f "$dest" ] && cp "$dest" "$dest.bakexp"
  cat > "$dest"
  echo "   wrote $dest"
}

echo "1. Backend"
write 'backend/data/scheduleTemplates.js' << 'PLANBHAI_EOF'
/**
 * Day templates.
 *
 * Data, not code — adding or correcting one is an edit here, not a release.
 * Times are placeholders shifted by the user's answers; `anchor` says WHICH
 * answer moves a block, so a 6 AM riser and a 9 AM riser both get a day that
 * fits them.
 *
 * SIX TO SEVEN BLOCKS. Not four (too sparse to feel like a day) and not twelve
 * (a wall of items is the task list this product exists to avoid). These are
 * the anchors a day hangs on; the calendar, meals and habits fill the rest.
 *
 * CONFIDENCE VARIES. The engineering, parent, student and homemaker days come
 * from direct knowledge. The clinical, legal-adjacent and trade ones are
 * informed guesses — plausible, editable, and worth a glance from someone who
 * actually does that job before they are treated as authoritative.
 *
 * `offsetMin` is relative to the anchor. Negative is before.
 */

const TEMPLATES = [
  {
    id: 'software_engineer',
    label: 'Software engineer',
    emoji: '👩‍💻',
    blocks: [
      { title: 'Morning routine',  kind: 'health',    anchor: 'wake',       offsetMin: 0,   durationMin: 45, days: [1,2,3,4,5] },
      { title: 'Deep work',        kind: 'deep_work', anchor: 'workStart',  offsetMin: 30,  durationMin: 120, days: [1,2,3,4,5] },
      { title: 'Lunch',            kind: 'meal',      anchor: 'workStart',  offsetMin: 240, durationMin: 45, days: [1,2,3,4,5] },
      { title: 'Meetings & review', kind: 'admin',    anchor: 'workStart',  offsetMin: 330, durationMin: 90, days: [1,2,3,4,5] },
      { title: 'Deep work II',     kind: 'deep_work', anchor: 'workStart',  offsetMin: 450, durationMin: 60, days: [1,2,3,4,5] },
      { title: 'Family time',      kind: 'family',    anchor: 'familyTime', offsetMin: 0,   durationMin: 90, days: [0,1,2,3,4,5,6] },
      { title: 'Wind down',        kind: 'rest',      anchor: 'sleep',      offsetMin: -60, durationMin: 45, days: [0,1,2,3,4,5,6] },
    ],
  },
  {
    id: 'busy_parent',
    label: 'Busy parent',
    emoji: '👨‍👩‍👧',
    blocks: [
      { title: 'Morning rush',   kind: 'family',    anchor: 'wake',       offsetMin: 0,   durationMin: 60, days: [1,2,3,4,5] },
      { title: 'School run',     kind: 'commute',   anchor: 'workStart',  offsetMin: -45, durationMin: 30, days: [1,2,3,4,5] },
      { title: 'Focus time',     kind: 'deep_work', anchor: 'workStart',  offsetMin: 30,  durationMin: 120, days: [1,2,3,4,5] },
      { title: 'Lunch',          kind: 'meal',      anchor: 'workStart',  offsetMin: 240, durationMin: 30, days: [1,2,3,4,5] },
      { title: 'Pickup',         kind: 'commute',   anchor: 'workEnd',    offsetMin: -30, durationMin: 30, days: [1,2,3,4,5] },
      { title: 'Family dinner',  kind: 'family',    anchor: 'familyTime', offsetMin: 0,   durationMin: 90, days: [0,1,2,3,4,5,6] },
      { title: 'Kids bedtime',   kind: 'family',    anchor: 'sleep',      offsetMin: -90, durationMin: 45, days: [0,1,2,3,4,5,6] },
    ],
  },
  {
    id: 'college_student',
    label: 'College student',
    emoji: '🎓',
    blocks: [
      { title: 'Morning routine', kind: 'health',   anchor: 'wake',       offsetMin: 0,   durationMin: 30, days: [1,2,3,4,5] },
      { title: 'Classes',         kind: 'learning', anchor: 'workStart',  offsetMin: 0,   durationMin: 180, days: [1,2,3,4,5] },
      { title: 'Lunch',           kind: 'meal',     anchor: 'workStart',  offsetMin: 195, durationMin: 45, days: [1,2,3,4,5] },
      { title: 'Study block',     kind: 'learning', anchor: 'workStart',  offsetMin: 255, durationMin: 90, days: [1,2,3,4,5] },
      { title: 'Gym or social',   kind: 'health',   anchor: 'workEnd',    offsetMin: 0,   durationMin: 60, days: [1,2,3,4,5] },
      { title: 'Evening study',   kind: 'learning', anchor: 'sleep',      offsetMin: -180, durationMin: 90, days: [0,1,2,3,4,5,6] },
      { title: 'Wind down',       kind: 'rest',     anchor: 'sleep',      offsetMin: -45, durationMin: 30, days: [0,1,2,3,4,5,6] },
    ],
  },
  {
    id: 'doctor',
    label: 'Doctor',
    emoji: '🩺',
    blocks: [
      { title: 'Pre-shift routine', kind: 'health', anchor: 'wake',       offsetMin: 0,   durationMin: 45, days: [1,2,3,4,5] },
      { title: 'Rounds',            kind: 'admin',  anchor: 'workStart',  offsetMin: 0,   durationMin: 120, days: [1,2,3,4,5] },
      { title: 'Clinic',            kind: 'admin',  anchor: 'workStart',  offsetMin: 150, durationMin: 180, days: [1,2,3,4,5] },
      { title: 'Lunch',             kind: 'meal',   anchor: 'workStart',  offsetMin: 345, durationMin: 30, days: [1,2,3,4,5] },
      { title: 'Notes & follow-up', kind: 'admin',  anchor: 'workEnd',    offsetMin: -60, durationMin: 60, days: [1,2,3,4,5] },
      { title: 'Family time',       kind: 'family', anchor: 'familyTime', offsetMin: 0,   durationMin: 90, days: [0,1,2,3,4,5,6] },
      { title: 'Wind down',         kind: 'rest',   anchor: 'sleep',      offsetMin: -45, durationMin: 30, days: [0,1,2,3,4,5,6] },
    ],
  },
  {
    id: 'nurse',
    label: 'Nurse',
    emoji: '💉',
    // The only cyclic template. Three twelve-hour shifts then four off is a
    // 7-day cycle that lands on different weekdays each rotation, which
    // days-of-week cannot express.
    cycle: { cycleLength: 7, onDays: [0, 1, 2] },
    blocks: [
      { title: 'Pre-shift',   kind: 'health', anchor: 'wake',      offsetMin: 0,   durationMin: 45 },
      { title: 'Handover',    kind: 'admin',  anchor: 'workStart', offsetMin: 0,   durationMin: 30 },
      { title: 'Shift',       kind: 'admin',  anchor: 'workStart', offsetMin: 30,  durationMin: 270 },
      { title: 'Break',       kind: 'meal',   anchor: 'workStart', offsetMin: 300, durationMin: 30 },
      { title: 'Shift II',    kind: 'admin',  anchor: 'workStart', offsetMin: 330, durationMin: 240 },
      { title: 'Charting',    kind: 'admin',  anchor: 'workStart', offsetMin: 570, durationMin: 45 },
      { title: 'Recovery',    kind: 'rest',   anchor: 'sleep',     offsetMin: -90, durationMin: 60 },
    ],
  },
  {
    id: 'teacher',
    label: 'Teacher',
    emoji: '📚',
    blocks: [
      { title: 'Morning prep',  kind: 'admin',     anchor: 'workStart',  offsetMin: -45, durationMin: 45, days: [1,2,3,4,5] },
      { title: 'Teaching',      kind: 'deep_work', anchor: 'workStart',  offsetMin: 0,   durationMin: 210, days: [1,2,3,4,5] },
      { title: 'Lunch',         kind: 'meal',      anchor: 'workStart',  offsetMin: 210, durationMin: 30, days: [1,2,3,4,5] },
      { title: 'Teaching II',   kind: 'deep_work', anchor: 'workStart',  offsetMin: 240, durationMin: 120, days: [1,2,3,4,5] },
      { title: 'Marking',       kind: 'admin',     anchor: 'workEnd',    offsetMin: -60, durationMin: 60, days: [1,2,3,4,5] },
      { title: 'Family time',   kind: 'family',    anchor: 'familyTime', offsetMin: 0,   durationMin: 90, days: [0,1,2,3,4,5,6] },
      { title: 'Wind down',     kind: 'rest',      anchor: 'sleep',      offsetMin: -45, durationMin: 30, days: [0,1,2,3,4,5,6] },
    ],
  },
  {
    id: 'entrepreneur',
    label: 'Founder',
    emoji: '🚀',
    blocks: [
      { title: 'Morning routine',   kind: 'health',    anchor: 'wake',       offsetMin: 0,   durationMin: 45, days: [1,2,3,4,5] },
      { title: 'Build time',        kind: 'deep_work', anchor: 'workStart',  offsetMin: 0,   durationMin: 150, days: [1,2,3,4,5] },
      { title: 'Lunch',             kind: 'meal',      anchor: 'workStart',  offsetMin: 240, durationMin: 30, days: [1,2,3,4,5] },
      { title: 'Calls & admin',     kind: 'admin',     anchor: 'workStart',  offsetMin: 300, durationMin: 120, days: [1,2,3,4,5] },
      // Unallocated on purpose. Something always goes wrong; a day with no
      // slack means every surprise displaces something that mattered.
      { title: 'Buffer',            kind: 'urgent',    anchor: 'workEnd',    offsetMin: -60, durationMin: 60, days: [1,2,3,4,5] },
      { title: 'Family time',       kind: 'family',    anchor: 'familyTime', offsetMin: 0,   durationMin: 90, days: [0,1,2,3,4,5,6] },
      { title: 'Plan tomorrow',     kind: 'admin',     anchor: 'sleep',      offsetMin: -60, durationMin: 30, days: [0,1,2,3,4] },
    ],
  },
  {
    id: 'homemaker',
    label: 'Homemaker',
    emoji: '🏡',
    blocks: [
      { title: 'Morning routine', kind: 'health',  anchor: 'wake',       offsetMin: 0,    durationMin: 45, days: [0,1,2,3,4,5,6] },
      { title: 'School run',      kind: 'commute', anchor: 'wake',       offsetMin: 90,   durationMin: 30, days: [1,2,3,4,5] },
      { title: 'House & errands', kind: 'admin',   anchor: 'wake',       offsetMin: 150,  durationMin: 120, days: [1,2,3,4,5] },
      { title: 'Lunch',           kind: 'meal',    anchor: 'wake',       offsetMin: 300,  durationMin: 45, days: [0,1,2,3,4,5,6] },
      { title: 'Pickup',          kind: 'commute', anchor: 'familyTime', offsetMin: -150, durationMin: 30, days: [1,2,3,4,5] },
      { title: 'Meal prep',       kind: 'meal',    anchor: 'familyTime', offsetMin: -90,  durationMin: 60, days: [0,1,2,3,4,5,6] },
      { title: 'Family time',     kind: 'family',  anchor: 'familyTime', offsetMin: 0,    durationMin: 90, days: [0,1,2,3,4,5,6] },
    ],
  },
  {
    id: 'freelancer',
    label: 'Freelancer',
    emoji: '💼',
    blocks: [
      { title: 'Morning routine',  kind: 'health',    anchor: 'wake',      offsetMin: 0,   durationMin: 45, days: [1,2,3,4,5] },
      { title: 'Client work',      kind: 'deep_work', anchor: 'workStart', offsetMin: 0,   durationMin: 150, days: [1,2,3,4,5] },
      { title: 'Lunch',            kind: 'meal',      anchor: 'workStart', offsetMin: 240, durationMin: 45, days: [1,2,3,4,5] },
      { title: 'Client work II',   kind: 'deep_work', anchor: 'workStart', offsetMin: 300, durationMin: 120, days: [1,2,3,4,5] },
      // Freelancers get paid by remembering to invoice. Worth its own block.
      { title: 'Admin & invoices', kind: 'admin',     anchor: 'workEnd',   offsetMin: -60, durationMin: 60, days: [1,2,3,4,5] },
      { title: 'Wind down',        kind: 'rest',      anchor: 'sleep',     offsetMin: -60, durationMin: 45, days: [0,1,2,3,4,5,6] },
    ],
  },
  {
    id: 'frequent_traveler',
    label: 'Frequent traveller',
    emoji: '✈️',
    blocks: [
      { title: 'Morning routine', kind: 'health',    anchor: 'wake',       offsetMin: 0,   durationMin: 45, days: [1,2,3,4,5] },
      { title: 'Focus time',      kind: 'deep_work', anchor: 'workStart',  offsetMin: 0,   durationMin: 120, days: [1,2,3,4,5] },
      { title: 'Lunch',           kind: 'meal',      anchor: 'workStart',  offsetMin: 240, durationMin: 45, days: [1,2,3,4,5] },
      { title: 'Calls',           kind: 'admin',     anchor: 'workStart',  offsetMin: 300, durationMin: 90, days: [1,2,3,4,5] },
      { title: 'Pack & prep',     kind: 'admin',     anchor: 'familyTime', offsetMin: -60, durationMin: 30, days: [0,4,6] },
      { title: 'Family time',     kind: 'family',    anchor: 'familyTime', offsetMin: 0,   durationMin: 90, days: [0,1,2,3,4,5,6] },
      { title: 'Wind down',       kind: 'rest',      anchor: 'sleep',      offsetMin: -45, durationMin: 30, days: [0,1,2,3,4,5,6] },
    ],
  },
  {
    id: 'fitness',
    label: 'Fitness focused',
    emoji: '💪',
    blocks: [
      { title: 'Morning workout', kind: 'health',    anchor: 'wake',       offsetMin: 0,   durationMin: 60, days: [1,2,3,4,5] },
      { title: 'Breakfast',       kind: 'meal',      anchor: 'wake',       offsetMin: 75,  durationMin: 30, days: [0,1,2,3,4,5,6] },
      { title: 'Focus time',      kind: 'deep_work', anchor: 'workStart',  offsetMin: 0,   durationMin: 120, days: [1,2,3,4,5] },
      { title: 'Lunch',           kind: 'meal',      anchor: 'workStart',  offsetMin: 240, durationMin: 45, days: [1,2,3,4,5] },
      { title: 'Evening training', kind: 'health',   anchor: 'workEnd',    offsetMin: 30,  durationMin: 60, days: [1,3,5] },
      // Weekends only — on training days (Mon/Wed/Fri) it collided with
      // evening training, which the generator flagged.
      { title: 'Meal prep',       kind: 'meal',      anchor: 'familyTime', offsetMin: 0,   durationMin: 45, days: [0,6] },
      { title: 'Wind down',       kind: 'rest',      anchor: 'sleep',      offsetMin: -45, durationMin: 30, days: [0,1,2,3,4,5,6] },
    ],
  },
  {
    id: 'event_planner',
    label: 'Event planner',
    emoji: '🎉',
    blocks: [
      { title: 'Morning routine',  kind: 'health', anchor: 'wake',       offsetMin: 0,   durationMin: 45, days: [1,2,3,4,5] },
      { title: 'Client calls',     kind: 'admin',  anchor: 'workStart',  offsetMin: 0,   durationMin: 90, days: [1,2,3,4,5] },
      { title: 'Vendor coordination', kind: 'admin', anchor: 'workStart', offsetMin: 105, durationMin: 120, days: [1,2,3,4,5] },
      { title: 'Lunch',            kind: 'meal',   anchor: 'workStart',  offsetMin: 240, durationMin: 45, days: [1,2,3,4,5] },
      { title: 'Site visits',      kind: 'admin',  anchor: 'workStart',  offsetMin: 300, durationMin: 120, days: [1,2,3,4,5] },
      // Events go wrong on the day. Slack is not optional in this one.
      { title: 'Buffer',           kind: 'urgent', anchor: 'workEnd',    offsetMin: -60, durationMin: 60, days: [1,2,3,4,5] },
      { title: 'Family time',      kind: 'family', anchor: 'familyTime', offsetMin: 0,   durationMin: 90, days: [0,1,2,3,4,5,6] },
    ],
  },
  {
    id: 'flexible',
    label: 'Something else',
    emoji: '🌿',
    blocks: [
      { title: 'Morning routine', kind: 'health',    anchor: 'wake',       offsetMin: 0,   durationMin: 45, days: [0,1,2,3,4,5,6] },
      { title: 'Focus time',      kind: 'deep_work', anchor: 'workStart',  offsetMin: 0,   durationMin: 120, days: [1,2,3,4,5] },
      { title: 'Lunch',           kind: 'meal',      anchor: 'workStart',  offsetMin: 240, durationMin: 45, days: [1,2,3,4,5] },
      { title: 'Focus time II',   kind: 'deep_work', anchor: 'workStart',  offsetMin: 300, durationMin: 90, days: [1,2,3,4,5] },
      { title: 'Family time',     kind: 'family',    anchor: 'familyTime', offsetMin: 0,   durationMin: 90, days: [0,1,2,3,4,5,6] },
      { title: 'Wind down',       kind: 'rest',      anchor: 'sleep',      offsetMin: -45, durationMin: 30, days: [0,1,2,3,4,5,6] },
    ],
  },
];

/**
 * The five questions. Every block hangs off one of these, so a 6 AM riser and a
 * 9 AM riser both get a day that fits them.
 *
 * Five, not forty. The whole premise is that planning effort approaches zero.
 */
const QUESTIONS = [
  { key: 'wake',       label: 'When do you wake up?',   type: 'time', default: '07:00' },
  { key: 'workStart',  label: 'When does work start?',  type: 'time', default: '09:00' },
  { key: 'workEnd',    label: 'When does it finish?',   type: 'time', default: '17:00' },
  { key: 'familyTime', label: 'When is family time?',   type: 'time', default: '18:30' },
  { key: 'sleep',      label: 'When do you go to bed?', type: 'time', default: '22:30' },
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
    const prev = sorted[i - 1];
    const cur = sorted[i];
    if (toMin(cur.startTime) >= toMin(prev.startTime) + prev.durationMin) continue;

    // Overlapping CLOCK times only matter if the blocks share a day. A Monday
    // gym session and a Sunday meal prep at the same hour never collide —
    // ignoring `days` reported an overlap that could not happen.
    const prevDays = prev.recurrence?.days || [];
    const curDays = cur.recurrence?.days || [];
    const sharesDay =
      prev.recurrence?.type === 'cycle' ||
      cur.recurrence?.type === 'cycle' ||
      prevDays.some((d) => curDays.includes(d));

    if (sharesDay) {
      warnings.push(`"${prev.title}" and "${cur.title}" overlap.`);
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

node --check backend/data/scheduleTemplates.js || exit 1
node --check backend/services/scheduleTemplate.service.js || exit 1
echo "   both parse"
echo

echo "2. Every template, against real hours"
cd backend
cat > ./.pb_all.js << 'ALL_EOF'
const { TEMPLATES } = require("./data/scheduleTemplates");
const { buildBlocks } = require("./services/scheduleTemplate.service");
const answers = { wake:"06:30", workStart:"09:00", workEnd:"17:30", familyTime:"18:30", sleep:"22:30" };
let bad = 0, warned = 0;
for (const t of TEMPLATES) {
  const { blocks, warnings } = buildBlocks({ templateId: t.id, answers });
  const midnight = blocks.filter(b => b.startTime === "00:00").length;
  if (blocks.length === 0 || midnight > 1) bad += 1;
  warned += warnings.length;
  console.log("   " + t.emoji + " " + t.label.padEnd(22) + blocks.length + " blocks" +
              (t.cycle ? "  (rota)" : "") +
              (blocks.length === 0 ? "  NO BLOCKS" : midnight > 1 ? "  SUSPECT" : ""));
  warnings.forEach(w => console.log("        ! " + w));
}
console.log("   " + TEMPLATES.length + " templates, " + bad + " broken, " + warned + " warning(s)");
process.exit(bad === 0 ? 0 : 1);
ALL_EOF
node ./.pb_all.js || { echo "   a template failed"; rm -f ./.pb_all.js; exit 1; }
rm -f ./.pb_all.js
cd ..
echo

echo "3. Web"
write 'web/src/pages/SetupDay.jsx' << 'PLANBHAI_EOF'
import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api } from '../api';
import { useHousehold } from '../HouseholdContext';

/**
 * Set up my day — first-run onboarding for the schedule.
 *
 * Three steps: pick a profession, answer five questions, review before
 * anything is written.
 *
 * FRAMED AS ONBOARDING, not a feature you return to. Someone who has already
 * built their day has a better one than a template can propose — five answers
 * cannot beat five decisions. This is for an empty schedule that needs a
 * starting point worth editing.
 *
 * That framing is why the review step matters more than the picker: the day it
 * proposes is a first draft, and saying so honestly is better than presenting
 * it as an answer.
 */
export default function SetupDay({ embedded = false, onDone, onCancel }) {
  const { scopeId } = useHousehold();
  const navigate = useNavigate();

  const [step, setStep] = useState(0);          // 0 profession · 1 questions · 2 review
  const [templates, setTemplates] = useState([]);
  const [questions, setQuestions] = useState([]);
  const [templateId, setTemplateId] = useState(null);
  const [answers, setAnswers] = useState({});
  const [preview, setPreview] = useState(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const res = await api.fetchScheduleTemplates();
        if (cancelled) return;
        setTemplates(res?.templates || []);
        setQuestions(res?.questions || []);
        // Seed from the defaults so someone can skip straight through and still
        // get a sensible day.
        const seed = {};
        for (const q of res?.questions || []) seed[q.key] = q.default;
        setAnswers(seed);
      } catch (e) {
        if (!cancelled) setError(e.message);
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => { cancelled = true; };
  }, []);

  async function loadPreview() {
    setBusy(true);
    setError('');
    try {
      setPreview(await api.previewScheduleTemplate(scopeId, templateId, answers));
      setStep(2);
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }

  async function apply(mode) {
    setBusy(true);
    setError('');
    try {
      await api.applyScheduleTemplate(scopeId, templateId, answers, mode);
      // Embedded, the caller reloads its own list. Standalone, go to My Day.
      if (embedded && onDone) await onDone();
      else navigate('/my-day');
    } catch (e) {
      setError(e.message);
      setBusy(false);
    }
  }

  if (!scopeId) {
    return (
      <div className="content-container">
        <div className="card empty-state">
          <div className="empty-state-icon">🏠</div>
          <div className="empty-state-text">Pick a household first.</div>
        </div>
      </div>
    );
  }

  if (loading) {
    return <div className="content-container"><div className="loading-spinner" /></div>;
  }

  return (
    <div className="content-container setup">
      <div className="page-header">
        <h1>Set up my day</h1>
        <p>
          Answer five questions and we'll sketch a starting point. You can change
          anything afterwards.
        </p>
      </div>

      {error && <div className="error-banner">{error}</div>}

      <div className="setup-steps">
        {['Your work', 'Your hours', 'Review'].map((label, i) => (
          <span key={label} className={`setup-step${i === step ? ' on' : ''}${i < step ? ' done' : ''}`}>
            {i + 1}. {label}
          </span>
        ))}
      </div>

      {step === 0 && (
        <>
          <div className="setup-grid">
            {templates.map((t) => (
              <button
                key={t.id}
                className={`card setup-tile${templateId === t.id ? ' on' : ''}`}
                onClick={() => setTemplateId(t.id)}
              >
                <span className="setup-emoji">{t.emoji}</span>
                <strong>{t.label}</strong>
                <small>{t.blockCount} blocks{t.cyclic ? ' · rota' : ''}</small>
              </button>
            ))}
          </div>
          <div className="setup-actions">
            {embedded && onCancel && (
              <button className="btn-secondary" onClick={onCancel}>Cancel</button>
            )}
            <button className="btn-primary" disabled={!templateId} onClick={() => setStep(1)}>
              Continue
            </button>
          </div>
        </>
      )}

      {step === 1 && (
        <>
          <div className="card setup-questions">
            {questions.map((q) => (
              <div className="setup-question" key={q.key}>
                <label className="field-label">{q.label}</label>
                <input
                  className="field-input"
                  type="time"
                  value={answers[q.key] || q.default}
                  onChange={(e) => setAnswers({ ...answers, [q.key]: e.target.value })}
                />
              </div>
            ))}
          </div>
          <div className="setup-actions">
            <button className="btn-secondary" onClick={() => setStep(0)}>Back</button>
            <button className="btn-primary" disabled={busy} onClick={loadPreview}>
              {busy ? 'Working…' : 'See my day'}
            </button>
          </div>
        </>
      )}

      {step === 2 && preview && (
        <>
          {/* Nothing has been written yet. Showing the proposal before the
              commit is the difference between a choice and a surprise. */}
          <div className="card setup-review">
            <div className="setup-review-label">Your day would look like this</div>
            {preview.blocks.map((b) => (
              <div className="setup-row" key={b.title + b.startTime}>
                <span className="setup-time">{b.startTime}</span>
                <span className="setup-title">{b.title}</span>
                <span className="setup-dur">{b.durationMin}m</span>
              </div>
            ))}
            {preview.warnings?.length > 0 && (
              <div className="setup-warnings">
                {preview.warnings.map((w) => <div key={w}>⚠ {w}</div>)}
              </div>
            )}
          </div>

          {preview.collisions?.length > 0 && (
            <div className="card setup-collisions">
              <div className="setup-review-label">
                You already have {preview.collisions.length} of these
              </div>
              {preview.collisions.map((c) => (
                <div className="setup-row" key={c.existing.id}>
                  <span className="setup-title">{c.existing.title}</span>
                  <span className="setup-dur">
                    yours {c.existing.startTime} · new {c.proposed.startTime}
                  </span>
                </div>
              ))}
              <p className="setup-note">
                Keeping both leaves you with two of each. Replacing removes
                everything on your day, including blocks you made yourself.
              </p>
            </div>
          )}

          <div className="setup-actions">
            <button className="btn-secondary" onClick={() => setStep(1)}>Back</button>
            {preview.collisions?.length > 0 && (
              <button className="btn-danger" disabled={busy} onClick={() => apply('replaceAll')}>
                Replace my day
              </button>
            )}
            <button className="btn-primary" disabled={busy} onClick={() => apply('keep')}>
              {busy ? 'Adding…' : preview.collisions?.length > 0 ? 'Add anyway' : 'Add to my day'}
            </button>
          </div>
        </>
      )}
    </div>
  );
}
PLANBHAI_EOF
write 'web/src/pages/MyDay.jsx' << 'PLANBHAI_EOF'
import { useEffect, useState, useCallback } from 'react';
import { api } from '../api';
import { useHousehold } from '../HouseholdContext';
import SetupDay from './SetupDay';

/**
 * My Day — create and manage schedule blocks.
 *
 * Same endpoints iOS uses, so a block made here appears on the phone and vice
 * versa. Blocks are PERSONAL: the server scopes every read and write to the
 * caller, so this only ever shows your own day even though the household is
 * shared.
 *
 * A list plus an inline form, deliberately — not drag-and-drop. Dragging is the
 * most expensive thing in the schedule spec and a form gets most of the value.
 */

const KINDS = [
  ['deep_work', '🎯', 'Deep work'],
  ['health',    '💪', 'Health'],
  ['family',    '👨‍👩‍👧', 'Family'],
  ['learning',  '📚', 'Learning'],
  ['admin',     '📌', 'Admin'],
  ['urgent',    '🔥', 'Urgent'],
  ['meal',      '🍽', 'Meal'],
  ['commute',   '🚗', 'Commute'],
  ['rest',      '🌙', 'Rest'],
];

const DAY_INITIALS = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
const DURATIONS = [15, 30, 45, 60, 90, 120, 180];

const kindEmoji = (k) => (KINDS.find((x) => x[0] === k) || [, '📌'])[1];

/** "19:00" -> "7 PM". The server stores 24h; people read 12h. */
function display(hhmm) {
  const [h, m] = String(hhmm || '').split(':').map(Number);
  if (Number.isNaN(h)) return hhmm;
  const suffix = h < 12 ? 'AM' : 'PM';
  const h12 = h % 12 === 0 ? 12 : h % 12;
  return m === 0 ? `${h12} ${suffix}` : `${h12}:${String(m).padStart(2, '0')} ${suffix}`;
}

function endTime(start, durationMin) {
  const [h, m] = String(start || '').split(':').map(Number);
  if (Number.isNaN(h)) return start;
  const total = h * 60 + m + durationMin;
  return `${String(Math.floor(total / 60) % 24).padStart(2, '0')}:${String(total % 60).padStart(2, '0')}`;
}

function recurrenceLabel(rec) {
  if (rec?.type === 'cycle' && rec.cycleLength) {
    const on = (rec.onDays || []).length;
    return `${on} on, ${rec.cycleLength - on} off`;
  }
  const d = [...(rec?.days || [])].sort();
  if (d.join() === '1,2,3,4,5') return 'Weekdays';
  if (d.join() === '0,6') return 'Weekends';
  if (d.length === 7) return 'Every day';
  const names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  return d.map((i) => names[i]).join(' ');
}

const durationLabel = (m) =>
  m < 60 ? `${m}m` : m % 60 === 0 ? `${m / 60}h` : `${Math.floor(m / 60)}h ${m % 60}m`;

const emptyDraft = {
  title: '', kind: 'deep_work', startTime: '09:00', durationMin: 60, days: [1, 2, 3, 4, 5],
};

export default function MyDay() {
  const { scopeId } = useHousehold();

  const [blocks, setBlocks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [draft, setDraft] = useState(null);      // null = form closed
  const [saving, setSaving] = useState(false);
  const [planning, setPlanning] = useState(false);

  const load = useCallback(async () => {
    if (!scopeId) return;
    setLoading(true);
    setError('');
    try {
      const res = await api.fetchScheduleBlocks(scopeId);
      setBlocks(res?.blocks || []);
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }, [scopeId]);

  useEffect(() => { load(); }, [load]);

  async function save() {
    if (!draft.title.trim() || draft.days.length === 0) return;
    setSaving(true);
    try {
      const payload = {
        title: draft.title.trim(),
        kind: draft.kind,
        startTime: draft.startTime,
        durationMin: draft.durationMin,
        recurrence: { type: 'weekly', days: [...draft.days].sort() },
      };
      if (draft._id) await api.updateScheduleBlock(scopeId, draft._id, payload);
      else await api.createScheduleBlock(scopeId, payload);
      setDraft(null);
      await load();
    } catch (e) {
      setError(e.message);
    } finally {
      setSaving(false);
    }
  }

  async function remove(id) {
    // Confirmed, because a block carries a routine — rebuilding one is more
    // annoying than the extra tap.
    if (!window.confirm('Delete this block? It will disappear from your Brief and calendar.')) return;
    try {
      await api.deleteScheduleBlock(scopeId, id);
      await load();
    } catch (e) {
      setError(e.message);
    }
  }

  async function togglePaused(b) {
    try {
      // Pausing keeps the block but takes it off the day — a routine you skip
      // for a fortnight shouldn't have to be rebuilt.
      await api.updateScheduleBlock(scopeId, b._id, { active: !b.active });
      await load();
    } catch (e) {
      setError(e.message);
    }
  }

  if (!scopeId) {
    return (
      <div className="content-container">
        <div className="card empty-state">
          <div className="empty-state-icon">🏠</div>
          <div className="empty-state-text">Pick a household first.</div>
        </div>
      </div>
    );
  }

  const sorted = [...blocks].sort((a, b) => a.startTime.localeCompare(b.startTime));

  // The setup flow renders IN PLACE of the list rather than at its own URL.
  // Planning a day and editing it are the same task; splitting them across two
  // pages meant the planner was somewhere you had to know about.
  if (planning) {
    return (
      <SetupDay
        embedded
        onDone={async () => { setPlanning(false); await load(); }}
        onCancel={() => setPlanning(false)}
      />
    );
  }

  return (
    <div className="content-container myday">
      <div className="page-header">
        <h1>My Day</h1>
        <p>The shape of your typical day — these appear on your Brief and calendar</p>
      </div>

      {error && <div className="error-banner">{error}</div>}

      {loading && blocks.length === 0 ? (
        <div className="loading-spinner" />
      ) : (
        <>
          {sorted.length === 0 && !draft && (
            <div className="card empty-state">
              <div className="empty-state-icon">📅</div>
              <div className="empty-state-text">
                No blocks yet. Start from a template for your kind of day, then
                change anything you like.
              </div>
              <button className="btn-primary" style={{ marginTop: 14 }} onClick={() => setPlanning(true)}>
                Plan my day
              </button>
            </div>
          )}

          {sorted.map((b) => (
            <div className={`card myday-row${b.active ? '' : ' paused'}`} key={b._id}>
              <span className="myday-emoji">{kindEmoji(b.kind)}</span>
              <div className="myday-text">
                <strong>{b.title}</strong>
                <small>
                  {display(b.startTime)}–{display(endTime(b.startTime, b.durationMin))}
                  {' · '}{recurrenceLabel(b.recurrence)}
                </small>
              </div>
              {!b.active && <span className="myday-paused">Paused</span>}
              <div className="myday-actions">
                <button className="btn-secondary" onClick={() => togglePaused(b)}>
                  {b.active ? 'Pause' : 'Resume'}
                </button>
                <button
                  className="btn-secondary"
                  onClick={() => setDraft({ ...b, days: b.recurrence?.days || [] })}
                >
                  Edit
                </button>
                <button className="btn-danger" onClick={() => remove(b._id)}>Delete</button>
              </div>
            </div>
          ))}

          {draft ? (
            <div className="card myday-form">
              <div className="field-group">
                <label className="field-label">What is it?</label>
                <input
                  className="field-input"
                  value={draft.title}
                  placeholder="Deep work"
                  onChange={(e) => setDraft({ ...draft, title: e.target.value })}
                />
              </div>

              <div className="field-group">
                <label className="field-label">Type</label>
                <div className="myday-chips">
                  {KINDS.map(([key, emoji, label]) => (
                    <button
                      key={key}
                      className={`myday-chip${draft.kind === key ? ' on' : ''}`}
                      onClick={() => setDraft({ ...draft, kind: key })}
                    >
                      {emoji} {label}
                    </button>
                  ))}
                </div>
              </div>

              <div className="myday-inline">
                <div className="field-group">
                  <label className="field-label">Starts at</label>
                  <input
                    className="field-input"
                    type="time"
                    value={draft.startTime}
                    onChange={(e) => setDraft({ ...draft, startTime: e.target.value })}
                  />
                </div>
                <div className="field-group">
                  <label className="field-label">For how long?</label>
                  <div className="myday-chips">
                    {DURATIONS.map((m) => (
                      <button
                        key={m}
                        className={`myday-chip${draft.durationMin === m ? ' on' : ''}`}
                        onClick={() => setDraft({ ...draft, durationMin: m })}
                      >
                        {durationLabel(m)}
                      </button>
                    ))}
                  </div>
                </div>
              </div>

              <div className="field-group">
                <label className="field-label">Which days?</label>
                <div className="myday-days">
                  {DAY_INITIALS.map((d, i) => (
                    <button
                      key={i}
                      className={`myday-day${draft.days.includes(i) ? ' on' : ''}`}
                      onClick={() =>
                        setDraft({
                          ...draft,
                          days: draft.days.includes(i)
                            ? draft.days.filter((x) => x !== i)
                            : [...draft.days, i],
                        })
                      }
                    >
                      {d}
                    </button>
                  ))}
                </div>
              </div>

              <div className="myday-form-actions">
                <button className="btn-secondary" onClick={() => setDraft(null)}>Cancel</button>
                <button
                  className="btn-primary"
                  onClick={save}
                  disabled={saving || !draft.title.trim() || draft.days.length === 0}
                >
                  {saving ? 'Saving…' : draft._id ? 'Save changes' : 'Add block'}
                </button>
              </div>
            </div>
          ) : (
            <div className="myday-add-row">
              <button className="btn-gradient" onClick={() => setDraft({ ...emptyDraft })}>
                + Add a block
              </button>
              {sorted.length > 0 && (
                <button className="btn-secondary" onClick={() => setPlanning(true)}>
                  Start from a template
                </button>
              )}
            </div>
          )}
        </>
      )}
    </div>
  );
}
PLANBHAI_EOF

grep -q "embedded = false" web/src/pages/SetupDay.jsx && echo "   ok   SetupDay embeds"
grep -q "Plan my day" web/src/pages/MyDay.jsx && echo "   ok   My Day offers planning"
echo

echo "4. Style for the button row"
if grep -q "myday-add-row" web/src/styles.css; then
  echo "   already present"
else
  cat >> web/src/styles.css << 'CSS_EOF'

.myday-add-row { display: flex; gap: 8px; align-self: flex-start; }
@media (max-width: 520px) {
  .myday-add-row { width: 100%; flex-direction: column; }
  .myday-add-row button { width: 100%; }
}
CSS_EOF
  echo "   appended"
fi
echo

echo "5. Building web"
(cd web && npm run build 2>&1 | grep -E "ERROR|error during|✓ built" | head -6)
echo

echo "=========================================="
echo "  Deploy BOTH:"
echo "     git add -A && git commit -m '13 day templates; planning merged into My Day' && git push"
echo "     (Render: Manual Deploy)   then   cd web && vercel --prod"
echo
echo "  Then /my-day — your five blocks, with \"Start from a template\" beside"
echo "  Add a block. Delete them all to see the empty state instead."
echo "=========================================="

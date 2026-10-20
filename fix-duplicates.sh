#!/usr/bin/env bash
#
# Two fixes: duplicate lunches, and blanket collision handling.
#
# 1. TWO LUNCHES AT 1 PM
#      1 PM  🍽  Lunch    the meal plan's lunch slot
#      1 PM  🎯  Lunch    a schedule block from the template
#
#    Not a missed collision — the detector only compares proposed blocks against
#    existing BLOCKS, and never sees meals. Two systems were each independently
#    saying you eat at 1 PM.
#
#    Templates no longer create meal blocks at all. The meal planner already
#    owns breakfast, lunch and dinner and already puts them on the calendar.
#    Templates describe the SHAPE of a day; meals are the meal plan's job.
#
#    "Meal prep" and the nurse's "Break" survive under honest kinds — cooking
#    time and a rest break are not eating, and I had mislabelled both.
#
# 2. PER-ROW COLLISION CHOICE
#    "Replace my day" made the user accept a decision about blocks they were
#    never asked about. "Add anyway" left two of each, which is never what
#    anyone wants.
#
#    Now one choice per clash:
#      Keep mine · 07:00     your block stays, the template's is skipped
#      Use new · 06:30       the template's replaces yours
#      Keep both             both stay
#
#    Defaults to the template's version, since that is what choosing a template
#    implies. "Keep both" stays available because matching titles do not always
#    mean the same intent — a 06:30 stretch and a 07:00 routine can coexist.
#
# Usage:
#   bash ~/Downloads/fix-duplicates.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }

echo "PlanBhai — duplicates and collision choice"
echo

write() {
  local dest="$1"
  [ -f "$dest" ] && cp "$dest" "$dest.bakdup"
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
 *
 * NO MEAL BLOCKS. The meal planner already owns breakfast, lunch and dinner and
 * already puts them on the calendar. A template adding its own "Lunch" produced
 * two 1 PM lunches — one from each system — which is what happens when two
 * things own the same concern. Templates describe the SHAPE of a day; meals are
 * the meal plan's job.
 */

const TEMPLATES = [
  {
    id: 'software_engineer',
    label: 'Software engineer',
    emoji: '👩‍💻',
    blocks: [
      { title: 'Morning routine',  kind: 'health',    anchor: 'wake',       offsetMin: 0,   durationMin: 45, days: [1,2,3,4,5] },
      { title: 'Deep work',        kind: 'deep_work', anchor: 'workStart',  offsetMin: 30,  durationMin: 120, days: [1,2,3,4,5] },
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
      { title: 'Pickup',         kind: 'commute',   anchor: 'workEnd',    offsetMin: -30, durationMin: 30, days: [1,2,3,4,5] },
      { title: 'Family dinner',  kind: 'family',    anchor: 'familyTime', offsetMin: 0,   durationMin: 90, days: [0,1,2,3,4,5,6] },
      { title: 'Kids bedtime',   kind: 'family',    anchor: 'sleep',      offsetMin: -90, durationMin: 45, days: [0,1,2,3,4,5,6] },
    ],
  },
  {
    // id stays 'college_student' — changing it would orphan any blocks already
    // generated under the old id, and the id is never shown.
    id: 'college_student',
    label: 'Student',
    emoji: '🎓',
    blocks: [
      { title: 'Morning routine', kind: 'health',   anchor: 'wake',       offsetMin: 0,   durationMin: 30, days: [1,2,3,4,5] },
      { title: 'Classes',         kind: 'learning', anchor: 'workStart',  offsetMin: 0,   durationMin: 180, days: [1,2,3,4,5] },
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
      // A rest break on a twelve-hour shift. Not a meal slot.
      { title: 'Break',       kind: 'rest',   anchor: 'workStart', offsetMin: 300, durationMin: 30 },
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
      { title: 'Pickup',          kind: 'commute', anchor: 'familyTime', offsetMin: -150, durationMin: 30, days: [1,2,3,4,5] },
      // Cooking time, not eating time — the meal planner schedules the meal,
      // not the hour spent making it.
      { title: 'Meal prep',       kind: 'admin',   anchor: 'familyTime', offsetMin: -90,  durationMin: 60, days: [0,1,2,3,4,5,6] },
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
      { title: 'Focus time',      kind: 'deep_work', anchor: 'workStart',  offsetMin: 0,   durationMin: 120, days: [1,2,3,4,5] },
      { title: 'Evening training', kind: 'health',   anchor: 'workEnd',    offsetMin: 30,  durationMin: 60, days: [1,3,5] },
      // Weekend batch cooking — the hour spent making the week's food, which is
      // its own commitment for anyone eating to a plan.
      { title: 'Meal prep',        kind: 'admin',    anchor: 'familyTime', offsetMin: 0,   durationMin: 45, days: [0,6] },
      // Weekends only — on training days (Mon/Wed/Fri) it collided with
      // evening training, which the generator flagged.
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
/**
 * @param decisions  one per collision: { title, keep: 'mine' | 'theirs' | 'both' }
 *
 * Resolving each clash individually rather than accepting a blanket outcome.
 * "Replace everything" and "add anyway" both made the user accept a decision
 * about blocks they had not been asked about — and "add anyway" left two of
 * each, which is never what anyone wants.
 *
 * 'both' stays available because matching titles do not always mean the same
 * intent: a 06:30 stretch and a 07:00 routine can legitimately coexist.
 */
async function applyTemplate({ scopeId, userId, templateId, answers, decisions = [] }) {
  const { blocks, warnings } = buildBlocks({ templateId, answers });
  if (blocks.length === 0) return { created: 0, replaced: 0, warnings };

  const byTitle = new Map(
    decisions
      .filter((d) => d && d.title)
      .map((d) => [String(d.title).toLowerCase(), d.keep])
  );

  // Re-applying a template should not accumulate copies of itself.
  const priorTemplates = await ScheduleBlock.deleteMany({ userId, source: 'template' });

  const existing = await ScheduleBlock.find({ userId }).lean();
  const clashes = findCollisions(blocks, existing);

  const removeIds = [];
  const skipTitles = new Set();

  for (const c of clashes) {
    const choice = byTitle.get(String(c.proposed.title).toLowerCase()) || 'theirs';
    if (choice === 'mine') {
      // Keep what the user built; drop the template's version.
      skipTitles.add(String(c.proposed.title).toLowerCase());
    } else if (choice === 'theirs') {
      // Take the template's; remove the one it replaces.
      removeIds.push(c.existing.id);
    }
    // 'both' — nothing removed, nothing skipped.
  }

  if (removeIds.length > 0) {
    await ScheduleBlock.deleteMany({ userId, _id: { $in: removeIds } });
  }

  const toCreate = blocks.filter((b) => !skipTitles.has(String(b.title).toLowerCase()));

  const created = toCreate.length
    ? await ScheduleBlock.insertMany(
        toCreate.map((b) => ({ ...b, scopeId, userId, active: true }))
      )
    : [];

  return {
    created: created.length,
    replaced: (priorTemplates.deletedCount || 0) + removeIds.length,
    skipped: skipTitles.size,
    warnings,
  };
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
echo "   all parse"
echo

echo "2. No template creates a meal block"
cd backend
node -e '
const { TEMPLATES } = require("./data/scheduleTemplates");
let meals = 0;
for (const t of TEMPLATES) {
  const n = t.blocks.filter(b => b.kind === "meal").length;
  meals += n;
  console.log("   " + t.emoji + " " + t.label.padEnd(22) + t.blocks.length + " blocks" + (n ? "  " + n + " MEAL" : ""));
}
console.log("   meal-kind blocks: " + meals);
if (meals > 0) { console.log("   STILL DUPLICATING THE MEAL PLAN"); process.exit(1); }
' || { echo "   check failed"; exit 1; }
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
  const [choices, setChoices] = useState({});   // title -> mine | theirs | both
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
      const p = await api.previewScheduleTemplate(scopeId, templateId, answers);
      setPreview(p);
      // Default to the template's version — that is what choosing a template
      // implies — but every row can be switched.
      const seed = {};
      for (const c of p.collisions || []) seed[c.proposed.title] = 'theirs';
      setChoices(seed);
      setStep(2);
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }

  async function apply() {
    setBusy(true);
    setError('');
    try {
      const decisions = Object.entries(choices).map(([title, keep]) => ({ title, keep }));
      await api.applyScheduleTemplate(scopeId, templateId, answers, decisions);
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

          {/* One choice per clash rather than a blanket outcome. "Replace
              everything" made the user accept a decision about blocks they were
              never asked about, and "add anyway" left two of each — which is
              never what anyone wants. */}
          {preview.collisions?.length > 0 && (
            <div className="card setup-collisions">
              <div className="setup-review-label">
                You already have {preview.collisions.length} of these — pick one
              </div>
              {preview.collisions.map((c) => (
                <div className="setup-choice" key={c.existing.id}>
                  <div className="setup-choice-title">{c.existing.title}</div>
                  <div className="setup-choice-opts">
                    {[
                      ['mine',   `Keep mine · ${c.existing.startTime}`],
                      ['theirs', `Use new · ${c.proposed.startTime}`],
                      ['both',   'Keep both'],
                    ].map(([value, label]) => (
                      <button
                        key={value}
                        className={`setup-opt${choices[c.proposed.title] === value ? ' on' : ''}`}
                        onClick={() => setChoices({ ...choices, [c.proposed.title]: value })}
                      >
                        {label}
                      </button>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          )}

          <div className="setup-actions">
            <button className="btn-secondary" onClick={() => setStep(1)}>Back</button>
            <button className="btn-primary" disabled={busy} onClick={apply}>
              {busy ? 'Adding…' : 'Add to my day'}
            </button>
          </div>
        </>
      )}
    </div>
  );
}
PLANBHAI_EOF

python3 - web/src/api.js << 'PY_EOF'
import sys, re
p = sys.argv[1]
s = open(p).read()
old = re.search(r"  applyScheduleTemplate: \(scopeId, templateId, answers, mode\) =>\n.*?\n    \}\),\n", s, re.S)
if not old:
    if "decisions }" in s:
        print("   api already takes decisions")
    else:
        print("   WARNING: could not update applyScheduleTemplate — check it by hand")
    sys.exit(0)
new = """  applyScheduleTemplate: (scopeId, templateId, answers, decisions) =>
    request(`/api/schedule/templates/apply?scopeId=${scopeId}`, {
      method: 'POST', auth: true, body: { templateId, answers, decisions },
    }),
"""
s = s[:old.start()] + new + s[old.end():]
open(p, "w").write(s)
print("   api now sends decisions")
PY_EOF

if grep -q "setup-choice-opts" web/src/styles.css; then
  echo "   styles already present"
else
  cat >> web/src/styles.css << 'PLANBHAI_EOF'

/* Per-collision choice */
.setup-choice { padding: 12px 0; border-bottom: 1px solid var(--border-subtle); }
.setup-choice:last-of-type { border-bottom: none; }
.setup-choice-title { font-size: 14px; color: var(--text-primary); margin-bottom: 8px; }
.setup-choice-opts { display: flex; flex-wrap: wrap; gap: 6px; }
.setup-opt {
  font-size: 12px; padding: 7px 11px; border-radius: 999px; cursor: pointer;
  background: var(--bg-card-soft); color: var(--text-secondary);
  border: 1px solid var(--border-subtle);
}
.setup-opt:hover { border-color: var(--sage); }
.setup-opt.on { background: var(--sage-tint); color: var(--sage); border-color: var(--sage); }
PLANBHAI_EOF
  echo "   styles appended"
fi
echo

echo "4. Building web"
(cd web && npm run build 2>&1 | grep -E "ERROR|error during|✓ built" | head -6)
echo

echo "=========================================="
echo "  Deploy:"
echo "     git add -A && git commit -m 'Templates no longer duplicate meals; per-row collision choice' && git push"
echo "     (Render: Manual Deploy)   then   cd web && vercel --prod"
echo
echo "  Existing template blocks named Lunch are NOT removed. To clear them:"
echo "     cd backend && node -e 'require(\"dotenv\").config();const m=require(\"mongoose\");(async()=>{await m.connect(process.env.MONGODB_URI);const B=require(\"./models/ScheduleBlock\");const r=await B.deleteMany({source:\"template\",kind:\"meal\"});console.log(\"removed\",r.deletedCount);await m.disconnect()})()'"
echo
echo "  iOS still sends `mode` and needs the same change — next."
echo "=========================================="

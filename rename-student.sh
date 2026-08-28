#!/usr/bin/env bash
#
# "College student" -> "Student".
#
# The id stays 'college_student'. Changing it would orphan any blocks already
# generated under the old one, and the id is never shown to anyone — only the
# label is.
#
# Only the template data changes. Both platforms fetch the list from the server,
# so one deploy updates both.
#
# Usage:
#   bash ~/Downloads/rename-student.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
F="backend/data/scheduleTemplates.js"
[ -f "$F" ] || { echo "ERROR: $F not found"; exit 1; }

echo "PlanBhai — rename Student"
echo

cp "$F" "$F.bakname"
cat > "$F" << 'PLANBHAI_EOF'
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
    // id stays 'college_student' — changing it would orphan any blocks already
    // generated under the old id, and the id is never shown.
    id: 'college_student',
    label: 'Student',
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
node --check "$F" || { echo "   PARSE FAILED — reverting"; cp "$F.bakname" "$F"; exit 1; }
echo "   wrote + parses"
echo

echo "Templates now:"
cd backend
node -e '
const { TEMPLATES } = require("./data/scheduleTemplates");
TEMPLATES.forEach(t => console.log("   " + t.emoji + " " + t.label));
const s = TEMPLATES.find(t => t.id === "college_student");
if (!s || s.label !== "Student") { console.log("   RENAME FAILED"); process.exit(1); }
'
RC=$?
cd ..
[ "$RC" != "0" ] && { cp "$F.bakname" "$F"; echo "   reverted"; exit 1; }
echo

echo "=========================================="
echo "  Deploy:"
echo "     git add -A && git commit -m 'Rename College student template to Student' && git push"
echo "  then Manual Deploy on Render. Both platforms fetch the list from the"
echo "  server, so no client release is needed."
echo
echo "  Revert:  cp $F.bakname $F"
echo "=========================================="

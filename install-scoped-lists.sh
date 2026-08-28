#!/usr/bin/env bash
#
# Personal lists alongside household ones.
#
# WHAT WAS THERE
#   Everything was household-scoped. Right for a meal plan, wrong for the things
#   only you need — your own shopping, your own habits.
#
# WHAT THIS ADDS
#   groceries_personal      yours alone, per household. Switching households
#                           switches your list with it, because what you need
#                           for the flat is not what you need at your parents'.
#
#   habits_household        NEW. Habits everyone ticks — a family water
#                           challenge, a Sunday walk. Personal habits already
#                           worked; the shared kind was what was missing.
#
#   habits_household_done   who has ticked what, PER PERSON. A shared habit
#                           anyone could tick for everyone would tell you
#                           nothing about whether the family actually did it.
#
# UNTOUCHED
#   `groceries` stays the household list, so there is no migration and nothing
#   to lose. The meal plan's shortfall still lands there — the meal is the
#   household's, so its missing ingredients are too.
#
#   `habits` stays personal, which already worked.
#
# THE COMPOUND KEY
#   Personal-within-a-household cannot key on the user alone, or your list
#   follows you between households. It cannot key on the household alone, or it
#   is not personal. So: `<userId>:<householdId>`.
#
# ADMIN ONLY for shared habits — one appears on everyone's screen, so adding one
# is a decision about other people's days.
#
#   GET/POST /api/lists/groceries/personal
#   GET/POST /api/lists/habits/household
#   POST     /api/lists/habits/household/done
#
# NO UI YET. The endpoints come first so the clients can be built against
# something known to work.
#
# Usage:
#   bash ~/Downloads/install-scoped-lists.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
[ -d backend/routes ] || { echo "ERROR: backend/routes not found"; exit 1; }

echo "PlanBhai — personal and household lists"
echo

write() {
  local dest="$1"
  [ -f "$dest" ] && cp "$dest" "$dest.bakscoped"
  cat > "$dest"
  echo "   wrote $dest"
}

echo "1. Files"
write 'backend/services/scopedLists.service.js' << 'PLANBHAI_EOF'
const AppData = require('../models/AppData');

/**
 * Personal and household lists, side by side.
 *
 * THE DISTINCTION
 *   groceries          the household's list. Everyone sees it, everyone adds to
 *                      it, and the meal plan's shortfall lands here — because
 *                      the meal is the household's, so its missing ingredients
 *                      are too.
 *
 *   groceries_personal yours alone, scoped to the active household. Switching
 *                      households switches your personal list with it, because
 *                      what you need for the flat is not what you need at your
 *                      parents'.
 *
 *   habits             already personal, and stay that way.
 *
 *   habits_household   NEW. Ones everyone ticks — a family water challenge,
 *                      everyone out for a walk on Sunday. Personal habits
 *                      already worked; what was missing was the shared kind.
 *
 * WHY THE KEY IS COMPOUND
 *   Personal data scoped to a household cannot key on the user alone, or your
 *   list follows you between households. It cannot key on the household alone,
 *   or it is not personal. So: `<userId>:<householdId>`.
 */

const personalKey = (userId, householdId) => `${userId}:${householdId}`;

async function readList(key, type) {
  const row = await AppData.findOne({ userId: key, type }).lean();
  return Array.isArray(row && row.data) ? row.data : [];
}

async function writeList(key, type, data) {
  return AppData.findOneAndUpdate(
    { userId: key, type },
    { userId: key, type, data },
    { upsert: true, new: true }
  );
}

/** Your personal groceries for this household. */
async function personalGroceries({ userId, householdId }) {
  return readList(personalKey(userId, householdId), 'groceries_personal');
}

async function savePersonalGroceries({ userId, householdId, items }) {
  return writeList(personalKey(userId, householdId), 'groceries_personal', items);
}

/** Habits the whole household shares. */
async function householdHabits({ householdId }) {
  return readList(String(householdId), 'habits_household');
}

async function saveHouseholdHabits({ householdId, habits }) {
  return writeList(String(householdId), 'habits_household', habits);
}

/**
 * Who has done a shared habit today.
 *
 * Completions are stored per-person — a household habit that anyone could tick
 * on everyone's behalf would tell you nothing about whether the family actually
 * drank the water.
 */
async function householdHabitCompletions({ householdId, memberIds, localDate }) {
  const out = {};
  for (const id of memberIds) {
    const rows = await readList(personalKey(id, householdId), 'habits_household_done');
    out[String(id)] = rows.filter((r) => r.date === localDate).map((r) => r.habitId);
  }
  return out;
}

async function setHouseholdHabitDone({ userId, householdId, habitId, localDate, done }) {
  const key = personalKey(userId, householdId);
  const rows = await readList(key, 'habits_household_done');
  const without = rows.filter((r) => !(r.habitId === habitId && r.date === localDate));
  const next = done ? [...without, { habitId, date: localDate }] : without;

  // Keep 60 days. A completion log that grows forever is a document that
  // eventually stops loading.
  const cutoff = new Date(Date.now() - 60 * 86400000).toISOString().slice(0, 10);
  await writeList(key, 'habits_household_done', next.filter((r) => r.date >= cutoff));
  return done;
}

module.exports = {
  personalKey,
  personalGroceries, savePersonalGroceries,
  householdHabits, saveHouseholdHabits,
  householdHabitCompletions, setHouseholdHabitDone,
};
PLANBHAI_EOF
write 'backend/routes/scopedLists.routes.js' << 'PLANBHAI_EOF'
const express = require('express');
const Household = require('../models/Household');
const {
  personalGroceries, savePersonalGroceries,
  householdHabits, saveHouseholdHabits,
  householdHabitCompletions, setHouseholdHabitDone,
} = require('../services/scopedLists.service');
const { bustDayBrief } = require('../services/daybrief/daybrief.service');

const router = express.Router();

// >>> EDIT if your middleware is named differently.
const requireAuth = require('../middleware/requireAuth');
const requireHouseholdMember = require('../middleware/requireHouseholdMember');

/**
 * Personal lists alongside household ones.
 *
 * Everything in the app was household-scoped, which is right for a meal plan
 * and wrong for the things only you need. These endpoints add the personal
 * half without disturbing the shared one — `groceries` is untouched, so no
 * migration and nothing to lose.
 */

/** GET /api/lists/groceries/personal?scopeId= */
router.get('/groceries/personal', requireAuth, requireHouseholdMember, async (req, res) => {
  try {
    const items = await personalGroceries({
      userId: String(req.user._id),
      householdId: String(req.scopeId),
    });
    res.json({ success: true, items });
  } catch (err) {
    console.error('[lists/groceries/personal]', err);
    res.status(500).json({ success: false, message: 'Could not load your list' });
  }
});

/** POST /api/lists/groceries/personal   { items } */
router.post('/groceries/personal', requireAuth, requireHouseholdMember, async (req, res) => {
  const { items } = req.body || {};
  if (!Array.isArray(items)) {
    return res.status(400).json({ success: false, message: 'items must be a list' });
  }
  try {
    await savePersonalGroceries({
      userId: String(req.user._id),
      householdId: String(req.scopeId),
      items,
    });
    res.json({ success: true, count: items.length });
  } catch (err) {
    console.error('[lists/groceries/personal save]', err);
    res.status(500).json({ success: false, message: 'Could not save your list' });
  }
});

/**
 * GET /api/lists/habits/household?scopeId=&tz=
 *
 * The shared habits, plus who has done each today. Completions are per-person —
 * a household habit anyone could tick for everyone would tell you nothing about
 * whether the family actually did it.
 */
router.get('/habits/household', requireAuth, requireHouseholdMember, async (req, res) => {
  const localDate = req.query.date || new Date().toISOString().slice(0, 10);
  try {
    const household = await Household.findById(req.scopeId).populate('members', 'name').lean();
    const memberIds = (household?.members || []).map((m) => String(m._id));

    const [habits, done] = await Promise.all([
      householdHabits({ householdId: req.scopeId }),
      householdHabitCompletions({ householdId: req.scopeId, memberIds, localDate }),
    ]);

    res.json({
      success: true,
      habits,
      // Keyed by habit, listing who is done — the useful direction, because the
      // question is "who still needs to", not "what has this person done".
      completions: habits.map((h) => ({
        habitId: h.id,
        doneBy: (household?.members || [])
          .filter((m) => (done[String(m._id)] || []).includes(h.id))
          .map((m) => ({ id: String(m._id), name: m.name })),
      })),
      memberCount: memberIds.length,
    });
  } catch (err) {
    console.error('[lists/habits/household]', err);
    res.status(500).json({ success: false, message: 'Could not load shared habits' });
  }
});

/** POST /api/lists/habits/household   { habits }  — admin only. */
router.post('/habits/household', requireAuth, requireHouseholdMember, async (req, res) => {
  const { habits } = req.body || {};
  if (!Array.isArray(habits)) {
    return res.status(400).json({ success: false, message: 'habits must be a list' });
  }
  try {
    const household = await Household.findById(req.scopeId);
    if (!household) {
      return res.status(404).json({ success: false, message: 'Household not found' });
    }
    // A shared habit appears on everyone's screen, so adding one is a decision
    // about other people's days.
    if (!household.isAdmin(req.user._id)) {
      return res.status(403).json({
        success: false,
        message: 'Only the household owner can change shared habits',
      });
    }

    await saveHouseholdHabits({ householdId: req.scopeId, habits });
    await bustDayBrief(req.scopeId).catch(() => {});
    res.json({ success: true, count: habits.length });
  } catch (err) {
    console.error('[lists/habits/household save]', err);
    res.status(500).json({ success: false, message: 'Could not save shared habits' });
  }
});

/** POST /api/lists/habits/household/done   { habitId, date, done } */
router.post('/habits/household/done', requireAuth, requireHouseholdMember, async (req, res) => {
  const { habitId, date, done } = req.body || {};
  if (!habitId) {
    return res.status(400).json({ success: false, message: 'habitId is required' });
  }
  try {
    await setHouseholdHabitDone({
      userId: String(req.user._id),
      householdId: String(req.scopeId),
      habitId,
      localDate: date || new Date().toISOString().slice(0, 10),
      done: done !== false,
    });
    await bustDayBrief(req.scopeId).catch(() => {});
    res.json({ success: true });
  } catch (err) {
    console.error('[lists/habits/household/done]', err);
    res.status(500).json({ success: false, message: 'Could not update that' });
  }
});

module.exports = router;
PLANBHAI_EOF

for f in backend/services/scopedLists.service.js backend/routes/scopedLists.routes.js; do
  node --check "$f" || { echo "   PARSE FAILED: $f"; exit 1; }
done
echo "   both parse"
echo

echo "2. Mounting"
if grep -q "scopedLists.routes" backend/server.js; then
  echo "   already mounted"
else
  cp backend/server.js backend/server.js.bakscoped
  python3 - backend/server.js << 'PY_EOF'
import sys, re
p = sys.argv[1]
s = open(p).read()
m = None
for m in re.finditer(r"app\.use\(\s*['\"]/api[^\n]*\n", s): pass
if not m:
    print("   ERROR: no /api mounts found"); sys.exit(2)
s = s[:m.end()] + "app.use('/api/lists', require('./routes/scopedLists.routes'));\n" + s[m.end():]
open(p, "w").write(s)
print("   mounted /api/lists")
PY_EOF
  [ $? -ne 0 ] && { cp backend/server.js.bakscoped backend/server.js; exit 1; }
  node --check backend/server.js && echo "   server.js parses"
fi
echo

echo "3. Nothing existing was touched"
cd backend
node -e '
require("dotenv").config();
const m = require("mongoose");
(async () => {
  await m.connect(process.env.MONGODB_URI);
  const A = require("./models/AppData");
  for (const t of ["groceries", "habits"]) {
    const rows = await A.find({ type: t }).lean();
    const total = rows.reduce((n, r) => n + ((r.data || []).length), 0);
    console.log("   " + t.padEnd(12) + rows.length + " record(s), " + total + " item(s) — unchanged");
  }
  await m.disconnect();
})().catch(e => console.log("   " + e.message));
' 2>/dev/null
cd ..
echo

echo "=========================================="
echo "  Deploy:  git add -A && git commit -m 'Personal and household lists' && git push"
echo "           then Manual Deploy on Render."
echo
echo "  Test:"
echo "     curl \".../api/lists/habits/household?scopeId=6a5186af77659b8762bfb01c\" \\"
echo "       -H \"Authorization: Bearer \$TOK\""
echo
echo "  Returns an empty list — nothing has been added yet, which is correct."
echo "  The UI comes next: a Household/Mine toggle on groceries, and a shared"
echo "  habits section showing who still needs to."
echo "=========================================="

#!/usr/bin/env bash
#
# Web parity: shared habits placed, invite codes ready.
#
# A SILENT FAILURE CAUGHT BEFORE SHIPPING
#   Both components originally read `household` and `isAdmin` from
#   useHousehold(). The context exposes `activeHousehold` and no isAdmin at all
#   — so both would have installed, built cleanly, and rendered NOTHING, with no
#   way to tell broken from empty.
#
#   That is the same class of bug as the thirteen found this morning. It
#   surfaced because the names were checked before shipping rather than after.
#
# WHO IS ADMIN NOW COMES FROM THE SERVER
#   It decides this on every write anyway. A client-side guess — from a
#   localStorage key whose name I would have had to assume — is a second source
#   of truth that can disagree with the first.
#
#   SharedHabits reads isAdmin from the response.
#   InviteCodes uses the 403 itself: reaching the success path IS the check.
#
# SHARED HABITS IS PLACED AUTOMATICALLY, anchored on the `<>` fragment opener —
# the same safe shape that worked for the grocery toggle. Inserting after a
# fragment cannot land mid-tag, which is how six earlier attempts failed.
#
# INVITE CODES IS NOT PLACED. HouseholdDetail.jsx has no members heading to
# anchor on; its invite code lives inside a join modal. One line, where you can
# see the surroundings — the script prints it at the end.
#
# Usage:
#   bash ~/Downloads/web-parity2.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }

echo "PlanBhai — web parity"
echo

echo "1. Backend: the habits endpoint reports isAdmin"
R="backend/routes/scopedLists.routes.js"
cp "$R" "$R.bakparity2"
cat > "$R" << 'PLANBHAI_EOF'
const express = require('express');
const Household = require('../models/Household');
const {
  personalGroceries, savePersonalGroceries,
  householdHabits, saveHouseholdHabits,
  householdHabitCompletions, setHouseholdHabitDone,
} = require('../services/scopedLists.service');
const { bustDayBrief } = require('../services/daybrief/daybrief.service');

const router = express.Router();

/**
 * Same rule the model uses, computed from a lean document.
 *
 * `.lean()` returns a plain object with no methods, so household.isAdmin() is
 * not available here — and calling it off the schema would be fragile.
 */
function isHouseholdAdmin(household, userId) {
  if (!household) return false;
  const uid = String(userId);
  if (String(household.createdBy) === uid) return true;
  return (household.admins || []).some((a) => String(a) === uid);
}

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
      // The server already decides this on every write. Telling the client
      // means one source of truth instead of a client-side guess at storage
      // keys that could disagree.
      isAdmin: isHouseholdAdmin(household, req.user._id),
      meId: String(req.user._id),
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
node --check "$R" || { echo "   PARSE FAILED — reverting"; cp "$R.bakparity2" "$R"; exit 1; }
grep -q "function isHouseholdAdmin" "$R" && echo "   ok   computed from the lean document"
echo

echo "2. Components"
cd web
cat > src/pages/SharedHabits.jsx << 'PLANBHAI_EOF'
import { useCallback, useEffect, useState } from 'react';
import { api } from '../api';
import { useHousehold } from '../HouseholdContext';

/**
 * Habits the whole household shares.
 *
 * Personal habits already worked — yours are yours. What was missing is the
 * shared kind: a family water challenge, a Sunday walk, where the useful
 * information is not "did I do it" but "who still needs to".
 *
 * Completions are per person. One tick standing in for everyone would say
 * nothing about whether the family actually did the thing.
 *
 * Drop this in and render <SharedHabits /> wherever it belongs — on Lifestyle,
 * under the personal habits list.
 */
export default function SharedHabits() {
  // The context exposes activeHousehold, not `household`, and no isAdmin —
  // so admin is derived here from createdBy, the same field the server checks.
  // Reading names the context does not provide would have rendered NOTHING,
  // silently, with the build still passing.
  const { scopeId, activeHousehold } = useHousehold();
  const household = activeHousehold;

  // Who is admin comes from the SERVER, which decides it on every write
  // anyway. Guessing client-side — from a localStorage key I would have had to
  // assume the name of — is a second source of truth that can disagree.
  const [isAdmin, setIsAdmin] = useState(false);
  const [meId, setMeId] = useState(null);

  const [habits, setHabits] = useState([]);
  const [completions, setCompletions] = useState([]);
  const [editing, setEditing] = useState(false);
  const [newName, setNewName] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    if (!scopeId) return;
    try {
      const res = await api.fetchSharedHabits(scopeId);
      setHabits(res?.habits || []);
      setCompletions(res?.completions || []);
      setIsAdmin(Boolean(res?.isAdmin));
      setMeId(res?.meId || null);
    } catch {
      // Silent. A missing section should not disturb the rest of the page.
    }
  }, [scopeId]);

  useEffect(() => { load(); }, [load]);

  if (!scopeId) return null;

  const doneFor = (habitId) =>
    completions.find((c) => c.habitId === habitId)?.doneBy || [];

  /** "Rit, Jim done · 1 to go" — the point of a shared habit. */
  const statusLine = (doneBy) => {
    const members = household?.members || [];
    if (!members.length) return 'No one yet';
    const doneIds = new Set(doneBy.map((p) => p.id));
    const waiting = members.filter((m) => !doneIds.has(m.id || m._id));
    if (!waiting.length) return "Everyone's done";
    if (!doneBy.length) return 'No one yet';
    return `${doneBy.map((p) => p.name).join(', ')} done · ${waiting.length} to go`;
  };

  async function toggle(habit) {
    if (busy) return;
    setBusy(true);
    const mine = doneFor(habit.id).some((p) => p.id === meId);
    try {
      await api.setSharedHabitDone(scopeId, habit.id, !mine);
      await load();
    } catch {
      setError("Couldn't update that.");
    }
    setBusy(false);
  }

  async function add() {
    const name = newName.trim();
    if (!name || busy) return;
    setBusy(true);
    setError('');
    try {
      await api.saveSharedHabits(scopeId, [...habits, { id: crypto.randomUUID().toUpperCase(), name }]);
      setNewName('');
      await load();
    } catch (e) {
      setError(e.message || "Couldn't add that.");
    }
    setBusy(false);
  }

  async function remove(habit) {
    if (busy) return;
    setBusy(true);
    try {
      await api.saveSharedHabits(scopeId, habits.filter((h) => h.id !== habit.id));
      await load();
    } catch {
      setError("Couldn't remove that.");
    }
    setBusy(false);
  }

  return (
    <div className="card shared-habits">
      <div className="shared-habits-head">
        <span className="brief-label">
          SHARED WITH {(household?.name || 'HOUSEHOLD').toUpperCase()}
        </span>
        {/* Admin only, matching the endpoint. A shared habit lands on
            everyone's screen, so adding one is a decision about other
            people's days. */}
        {isAdmin && (
          <button className="shared-habits-edit" onClick={() => setEditing(!editing)}>
            {editing ? 'Done' : 'Edit'}
          </button>
        )}
      </div>

      {error && <p className="shared-habits-error">{error}</p>}

      {habits.length === 0 ? (
        <p className="shared-habits-empty">
          {isAdmin
            ? 'Habits everyone ticks — a water challenge, a Sunday walk. Tap Edit to add one.'
            : 'Nothing shared yet. The household owner can add habits everyone tracks together.'}
        </p>
      ) : (
        habits.map((h) => {
          const doneBy = doneFor(h.id);
          const mine = doneBy.some((p) => p.id === meId);
          return (
            <div className="shared-habit-row" key={h.id}>
              <button
                className={`shared-habit-check${mine ? ' on' : ''}`}
                onClick={() => toggle(h)}
                disabled={busy}
                aria-label={mine ? 'Mark not done' : 'Mark done'}
              >
                {mine ? '✓' : ''}
              </button>
              <div className="shared-habit-text">
                <strong>{h.name}</strong>
                <small>{statusLine(doneBy)}</small>
              </div>
              {editing && isAdmin && (
                <button className="shared-habit-remove" onClick={() => remove(h)}>×</button>
              )}
            </div>
          );
        })
      )}

      {editing && isAdmin && (
        <div className="shared-habits-add">
          <input
            className="field-input"
            value={newName}
            placeholder="New shared habit"
            onChange={(e) => setNewName(e.target.value)}
            onKeyDown={(e) => { if (e.key === 'Enter') add(); }}
          />
          <button className="btn-primary" onClick={add} disabled={busy || !newName.trim()}>
            Add
          </button>
        </div>
      )}
    </div>
  );
}
PLANBHAI_EOF
echo "   wrote SharedHabits.jsx"
cat > src/pages/InviteCodes.jsx << 'PLANBHAI_EOF'
import { useCallback, useEffect, useState } from 'react';
import { api } from '../api';
import { useHousehold } from '../HouseholdContext';

/**
 * Personal invite codes.
 *
 * The household's shared code is permanent — anyone with it joins as a new
 * member, attached to nothing. A PERSONAL code is single-use and tied to a
 * family member, so when Jim joins with his, his label links to his account and
 * the chores assigned to "Jim" become chores assigned to a person.
 *
 * No email. Sharing is solved by whatever you already use to talk to Jim, and a
 * mail pipeline is maintenance for a job a six-character string does.
 *
 * Drop this in and render <InviteCodes /> on the household detail page.
 */
export default function InviteCodes() {
  // The context exposes activeHousehold, not `household`, and no isAdmin —
  // so admin is derived here from createdBy, the same field the server checks.
  // Reading names the context does not provide would have rendered NOTHING,
  // silently, with the build still passing.
  const { scopeId, activeHousehold } = useHousehold();
  const household = activeHousehold;

  // Who is admin comes from the SERVER, which decides it on every write
  // anyway. Guessing client-side — from a localStorage key I would have had to
  // assume the name of — is a second source of truth that can disagree.
  const [isAdmin, setIsAdmin] = useState(false);

  const [invites, setInvites] = useState([]);
  const [name, setName] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [copied, setCopied] = useState(null);

  const load = useCallback(async () => {
    if (!scopeId) return;
    try {
      const res = await api.fetchInvites(scopeId);
      setInvites(res?.invites || []);
      // The endpoint returns 403 to non-admins, so reaching this line IS the
      // permission check — no second guess needed about who owns what.
      setIsAdmin(true);
    } catch {
      setIsAdmin(false);
    }
  }, [scopeId]);

  useEffect(() => { load(); }, [load]);

  // Admin only, matching the endpoint. Anyone being able to bring strangers
  // into a household with everyone's meals, chores and calendar is not small.
  if (!isAdmin || !scopeId) return null;

  async function create() {
    if (busy) return;
    setBusy(true);
    setError('');
    try {
      const res = await api.createInvite(scopeId, name.trim());
      setName('');
      await load();
      if (res?.invite?.code) share(res.invite.code);
    } catch (e) {
      setError(e.message || "Couldn't create that invite.");
    }
    setBusy(false);
  }

  /**
   * The native share sheet where it exists, clipboard everywhere else.
   *
   * On a phone this opens Messages or WhatsApp; on a desktop browser there is
   * nothing to share to, so copying is the honest equivalent rather than a
   * worse imitation of the phone behaviour.
   */
  async function share(code) {
    const text = `Join ${household?.name || 'our household'} on PlanBhai with this code: ${code}`;
    if (navigator.share) {
      try { await navigator.share({ text }); return; } catch { /* dismissed */ }
    }
    try {
      await navigator.clipboard.writeText(code);
      setCopied(code);
      setTimeout(() => setCopied(null), 2000);
    } catch {
      setError('Copy failed — the code is above, you can select it.');
    }
  }

  async function revoke(id) {
    setBusy(true);
    try {
      await api.revokeInvite(id);
      await load();
    } catch {
      setError("Couldn't revoke that.");
    }
    setBusy(false);
  }

  return (
    <div className="card invite-codes">
      <div className="brief-label">INVITE SOMEONE</div>
      <p className="invite-note">
        A personal code links them to a family member, so their chores follow them.
      </p>

      <div className="invite-create">
        <input
          className="field-input"
          value={name}
          placeholder="Their name"
          onChange={(e) => setName(e.target.value)}
          onKeyDown={(e) => { if (e.key === 'Enter') create(); }}
        />
        <button className="btn-primary" onClick={create} disabled={busy}>
          {busy ? 'Working…' : 'Create code'}
        </button>
      </div>

      {error && <p className="invite-error">{error}</p>}

      {invites.map((i) => (
        <div className="invite-row" key={i.id}>
          <div className="invite-who">
            <strong>{i.inviteeName || 'Anyone'}</strong>
            <code>{i.code}</code>
          </div>
          <button className="invite-share" onClick={() => share(i.code)}>
            {copied === i.code ? 'Copied' : 'Share'}
          </button>
          <button className="invite-revoke" onClick={() => revoke(i.id)} aria-label="Revoke">
            ×
          </button>
        </div>
      ))}
    </div>
  );
}
PLANBHAI_EOF
echo "   wrote InviteCodes.jsx"
grep -q "activeHousehold" src/pages/SharedHabits.jsx && echo "   ok   uses the real context name"
grep -q "localStorage.getItem" src/pages/SharedHabits.jsx \
  && echo "   WARN still guessing at storage" \
  || echo "   ok   no storage guesses"
echo

echo "3. Placing SharedHabits"
cp src/pages/Lifestyle.jsx src/pages/Lifestyle.jsx.bakparity2
cat > /tmp/pb_pp.py << 'PLANBHAI_EOF'
import sys

# Lifestyle: line 234 is `<>` on its own — the same safe shape that worked for
# the grocery toggle. Inserting after a fragment opener cannot land mid-tag.
p = 'src/pages/Lifestyle.jsx'
s = open(p).read()
if 'SharedHabits' in s:
    print("   Lifestyle: already placed")
else:
    old = """      {tab === 'habits' && (
        <>
"""
    if old not in s:
        print("   ERROR: the habits tab is not in the expected shape"); sys.exit(2)
    s = s.replace(old, old + "          <SharedHabits />\n\n", 1)

    imp = "import { useHousehold } from '../HouseholdContext';"
    if imp in s:
        s = s.replace(imp, imp + "\nimport SharedHabits from './SharedHabits';", 1)
    else:
        first = s.index('\n', s.index('import ')) + 1
        s = s[:first] + "import SharedHabits from './SharedHabits';\n" + s[first:]
    open(p, 'w').write(s)
    print("   Lifestyle: SharedHabits placed under the habits tab")
PLANBHAI_EOF
python3 /tmp/pb_pp.py
RC=$?
rm -f /tmp/pb_pp.py
if [ "$RC" != "0" ]; then
  cp src/pages/Lifestyle.jsx.bakparity2 src/pages/Lifestyle.jsx
  echo "   reverted Lifestyle"; exit 1
fi
echo

echo "4. Building"
npm run build 2>&1 | grep -E "ERROR|error during|✓ built" | head -6
cd ..
echo

echo "=========================================="
echo "  Deploy BOTH — the habits endpoint changed:"
echo "     git add -A && git commit -m 'Web parity: shared habits' && git push"
echo "     (Render: Manual Deploy)   then   cd web && vercel --prod"
echo
echo "  Lifestyle -> Habits now shows the shared section."
echo
echo "  INVITE CODES still needs one line in HouseholdDetail.jsx, wherever a"
echo "  household's own detail is shown:"
echo "     import InviteCodes from './InviteCodes';"
echo "     <InviteCodes />"
echo
echo "  It hides itself for non-admins, so placement is low risk."
echo "=========================================="

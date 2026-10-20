#!/usr/bin/env bash
#
# Web parity: shared habits and invite codes.
#
# WRITTEN AS COMPLETE FILES, PLACED BY HAND
#   Six JSX insertions failed tonight, every one because a regex anchor moved as
#   the file changed underneath it. The components themselves were never the
#   problem. So these are whole files, and placing them is one line you write
#   where you can see it.
#
# SHARED HABITS
#   Personal habits already worked. The shared kind is what was missing — a
#   family water challenge, a Sunday walk — where the useful information is not
#   "did I do it" but "who still needs to". Completions are per person; one tick
#   standing in for everyone would say nothing.
#
# INVITE CODES
#   The household's shared code is permanent and attaches to nothing. A personal
#   code is single-use and tied to a family member, so Jim's label links to his
#   account when he joins.
#
#   Share uses navigator.share on a phone and the clipboard on a desktop, where
#   there is nothing to share to. Copying is the honest desktop equivalent
#   rather than a worse imitation of the phone.
#
# BOTH ARE ADMIN-GATED, matching the endpoints.
#
# Usage:
#   bash ~/Downloads/web-parity.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT/web" 2>/dev/null || { echo "ERROR: no web/ under $ROOT"; exit 1; }

echo "PlanBhai — web parity components"
echo

echo "1. Checking what the components expect"
grep -q "isAdmin" src/HouseholdContext.jsx 2>/dev/null \
  && echo "   ok   isAdmin from useHousehold" \
  || echo "   WARN useHousehold may not expose isAdmin — see the note at the end"
grep -q "household" src/HouseholdContext.jsx 2>/dev/null \
  && echo "   ok   household from useHousehold" \
  || echo "   WARN useHousehold may not expose household"
echo

echo "2. Components"
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
  const { scopeId, household, isAdmin } = useHousehold();

  const [habits, setHabits] = useState([]);
  const [completions, setCompletions] = useState([]);
  const [editing, setEditing] = useState(false);
  const [newName, setNewName] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [meId, setMeId] = useState(null);

  const load = useCallback(async () => {
    if (!scopeId) return;
    try {
      const res = await api.fetchSharedHabits(scopeId);
      setHabits(res?.habits || []);
      setCompletions(res?.completions || []);
      if (res?.meId) setMeId(res.meId);
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
echo "   wrote src/pages/SharedHabits.jsx"
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
  const { scopeId, household, isAdmin } = useHousehold();

  const [invites, setInvites] = useState([]);
  const [name, setName] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [copied, setCopied] = useState(null);

  const load = useCallback(async () => {
    if (!scopeId || !isAdmin) return;
    try {
      const res = await api.fetchInvites(scopeId);
      setInvites(res?.invites || []);
    } catch {
      // Silent — a failed list should not break the page around it.
    }
  }, [scopeId, isAdmin]);

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
echo "   wrote src/pages/InviteCodes.jsx"
echo

echo "3. api methods"
if grep -q "fetchSharedHabits" src/api.js; then
  echo "   already present"
else
  cp src/api.js src/api.js.bakparity
  python3 - src/api.js << 'PY_EOF'
import sys
p = sys.argv[1]
s = open(p).read()
anchor = "  // ---- Auth ----"
if anchor not in s:
    print("   ERROR: Auth section not found"); sys.exit(2)
add = """  // ---- Shared habits ----
  fetchSharedHabits: (scopeId) =>
    request(`/api/lists/habits/household?scopeId=${scopeId}`, { auth: true }),

  saveSharedHabits: (scopeId, habits) =>
    request(`/api/lists/habits/household?scopeId=${scopeId}`, {
      method: 'POST', auth: true, body: { habits },
    }),

  setSharedHabitDone: (scopeId, habitId, done) =>
    request(`/api/lists/habits/household/done?scopeId=${scopeId}`, {
      method: 'POST', auth: true, body: { habitId, done },
    }),

  // ---- Invite codes ----
  fetchInvites: (householdId) =>
    request(`/api/invites/${householdId}`, { auth: true }),

  createInvite: (householdId, inviteeName) =>
    request('/api/invites/create', {
      method: 'POST', auth: true, body: { householdId, inviteeName },
    }),

  revokeInvite: (inviteId) =>
    request('/api/invites/revoke', { method: 'POST', auth: true, body: { inviteId } }),

"""
s = s.replace(anchor, add + anchor, 1)
open(p, "w").write(s)
print("   added six methods")
PY_EOF
  [ $? -ne 0 ] && { cp src/api.js.bakparity src/api.js; exit 1; }
fi
echo

echo "4. Styles"
if grep -q "shared-habit-row" src/styles.css; then
  echo "   already present"
else
  cat >> src/styles.css << 'PLANBHAI_EOF'

/* ---------- Shared habits ---------- */
.shared-habits { display: flex; flex-direction: column; gap: 10px; }
.shared-habits-head { display: flex; align-items: center; justify-content: space-between; }
.shared-habits-edit {
  background: none; border: none; cursor: pointer;
  font-size: 12px; font-weight: 600; color: var(--sage);
}
.shared-habits-empty, .invite-note {
  font-size: 12px; color: var(--text-tertiary); margin: 0; line-height: 1.5;
}
.shared-habits-error, .invite-error { font-size: 12px; color: var(--rose); margin: 0; }

.shared-habit-row { display: flex; align-items: center; gap: 12px; padding: 4px 0; }
.shared-habit-check {
  width: 24px; height: 24px; border-radius: 50%; cursor: pointer;
  border: 2px solid var(--border-subtle); background: transparent;
  color: #fff; font-size: 13px; line-height: 1; flex-shrink: 0;
}
.shared-habit-check.on { background: var(--forest); border-color: var(--forest); }
.shared-habit-text { display: flex; flex-direction: column; flex: 1; min-width: 0; }
.shared-habit-text strong { font-size: 14px; color: var(--text-primary); }
.shared-habit-text small { font-size: 11px; color: var(--text-tertiary); margin-top: 2px; }
.shared-habit-remove {
  background: none; border: none; cursor: pointer;
  font-size: 18px; color: var(--rose); opacity: 0.7;
}
.shared-habits-add { display: flex; gap: 8px; margin-top: 4px; }

/* ---------- Invite codes ---------- */
.invite-codes { display: flex; flex-direction: column; gap: 10px; }
.invite-create { display: flex; gap: 8px; }
.invite-row {
  display: flex; align-items: center; gap: 10px;
  padding: 10px; border-radius: 10px; background: var(--bg-card-soft);
}
.invite-who { display: flex; flex-direction: column; flex: 1; min-width: 0; }
.invite-who strong { font-size: 13px; color: var(--text-primary); }
.invite-who code {
  font-size: 15px; font-weight: 700; letter-spacing: 2px;
  color: var(--sage); margin-top: 2px;
}
.invite-share {
  padding: 6px 12px; border-radius: 8px; cursor: pointer;
  font-size: 12px; font-weight: 600;
  background: var(--sage-tint); color: var(--sage);
  border: 1px solid var(--sage);
}
.invite-revoke {
  background: none; border: none; cursor: pointer;
  font-size: 18px; color: var(--text-tertiary);
}

@media (max-width: 520px) {
  .invite-create, .shared-habits-add { flex-direction: column; }
  .invite-create button, .shared-habits-add button { width: 100%; }
}
PLANBHAI_EOF
  echo "   appended"
fi
echo

echo "5. Building — the components exist but are not rendered yet"
npm run build 2>&1 | grep -E "ERROR|error during|✓ built" | head -6
echo

echo "=========================================="
echo "  PLACE THEM BY HAND — two lines, where you can see the surroundings."
echo
echo "  src/pages/Lifestyle.jsx, under the personal habits list:"
echo "      import SharedHabits from './SharedHabits';"
echo "      <SharedHabits />"
echo
echo "  src/pages/HouseholdDetail.jsx, near the members section:"
echo "      import InviteCodes from './InviteCodes';"
echo "      <InviteCodes />"
echo
echo "  IF useHousehold DOES NOT EXPOSE isAdmin OR household, the components"
echo "  will render nothing and the build will still pass. Check section 1"
echo "  above — if it warned, tell me and I will read the context and adjust."
echo "=========================================="

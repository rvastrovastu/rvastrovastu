#!/usr/bin/env bash
#
# My Day for web — the last sync gap.
#
# BEFORE
#   iOS   Brief with blocks · merged calendar · create & edit blocks
#   web   Brief with blocks · merged calendar · (read-only)
#
# The endpoints already existed and web simply never called them. This adds
# src/pages/MyDay.jsx, four api methods, a /my-day route, and styles.
#
# Same server, so a block created on the phone appears here and vice versa —
# and both feed the same Brief timeline and calendar.
#
# BLOCKS ARE PERSONAL. The server scopes every schedule read and write to the
# caller, so this shows your own day only, even though the household is shared.
#
# A list plus an inline form, matching iOS's list-plus-sheet. Not drag-and-drop:
# that is the most expensive item in the schedule spec and a form delivers most
# of the value.
#
# Pausing keeps a block but takes it off your day — a routine you skip for a
# fortnight should not have to be rebuilt. Deleting asks first.
#
# Usage:
#   bash ~/Downloads/install-web-myday.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT/web" 2>/dev/null || { echo "ERROR: no web/ under $ROOT"; exit 1; }

echo "PlanBhai — My Day for web"
echo

echo "1. Checking"
for f in src/api.js src/App.jsx src/HouseholdContext.jsx src/styles.css; do
  [ -f "$f" ] && echo "   ok   $f" || { echo "   MISSING $f"; exit 1; }
done
echo

echo "2. Page"
mkdir -p src/pages
[ -f src/pages/MyDay.jsx ] && cp src/pages/MyDay.jsx src/pages/MyDay.jsx.bakmyday
cat > src/pages/MyDay.jsx << 'PLANBHAI_EOF'
import { useEffect, useState, useCallback } from 'react';
import { api } from '../api';
import { useHousehold } from '../HouseholdContext';

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
                No blocks yet. Add the things that happen most days — a morning
                routine, focus time, dinner.
              </div>
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
            <button className="btn-gradient myday-add" onClick={() => setDraft({ ...emptyDraft })}>
              + Add a block
            </button>
          )}
        </>
      )}
    </div>
  );
}
PLANBHAI_EOF
echo "   wrote src/pages/MyDay.jsx"
echo

echo "3. api methods"
if grep -q "fetchScheduleBlocks" src/api.js; then
  echo "   already present"
else
  cp src/api.js src/api.js.bakmyday
  python3 - src/api.js << 'PY_EOF'
import sys
p = sys.argv[1]
s = open(p).read()
anchor = "  // ---- Auth ----"
if anchor not in s:
    print("   ERROR: Auth section not found"); sys.exit(2)
add = """  // ---- Schedule blocks ----
  fetchScheduleBlocks: (scopeId) =>
    request(`/api/schedule/blocks?scopeId=${scopeId}`, { auth: true }),

  createScheduleBlock: (scopeId, block) =>
    request(`/api/schedule/blocks?scopeId=${scopeId}`, { method: 'POST', auth: true, body: block }),

  updateScheduleBlock: (scopeId, id, fields) =>
    request(`/api/schedule/blocks/${id}?scopeId=${scopeId}`, { method: 'PUT', auth: true, body: fields }),

  deleteScheduleBlock: (scopeId, id) =>
    request(`/api/schedule/blocks/${id}?scopeId=${scopeId}`, { method: 'DELETE', auth: true }),

"""
s = s.replace(anchor, add + anchor, 1)
open(p, "w").write(s)
print("   added four schedule methods")
PY_EOF
  [ $? -ne 0 ] && { cp src/api.js.bakmyday src/api.js; echo "   reverted"; exit 1; }
fi
echo

echo "4. Route"
if grep -q '"/my-day"' src/App.jsx; then
  echo "   already routed"
else
  cp src/App.jsx src/App.jsx.bakmyday
  python3 - src/App.jsx << 'PY_EOF'
import sys, re
p = sys.argv[1]
s = open(p).read()
m = re.search(r'\n(\s*)<Route path="/meals" element=\{', s)
if not m:
    print("   ERROR: could not find the /meals route to anchor on"); sys.exit(2)
indent = m.group(1)
block = (f'\n{indent}<Route path="/my-day" element={{\n'
         f'{indent}  <ProtectedRoute><MyDay /></ProtectedRoute>\n'
         f'{indent}}} />')
s = s[:m.start()] + block + s[m.start():]

if "lazy(" in s:
    lz = re.search(r"const (\w+) = lazy\(\(\) => import\('\./pages/(\w+)'\)\);", s)
    if lz:
        s = s.replace(lz.group(0), lz.group(0) + "\nconst MyDay = lazy(() => import('./pages/MyDay'));", 1)
    else:
        s = "import MyDay from './pages/MyDay';\n" + s
else:
    s = "import MyDay from './pages/MyDay';\n" + s

open(p, "w").write(s)
print("   added /my-day")
PY_EOF
  [ $? -ne 0 ] && { cp src/App.jsx.bakmyday src/App.jsx; echo "   reverted"; exit 1; }
fi
echo

echo "5. Styles"
if grep -q "^.myday {" src/styles.css; then
  echo "   already appended"
else
  cp src/styles.css src/styles.css.bakmyday
  cat >> src/styles.css << 'PLANBHAI_EOF'

/* ---------- My Day ---------- */
/* Uses the existing theme variables so it sits with the rest of the app. */

.myday { display: flex; flex-direction: column; gap: 12px; max-width: 780px; }

.myday-row {
  display: flex; align-items: center; gap: 14px; padding: 14px 16px;
}
.myday-row.paused { opacity: 0.55; }
.myday-emoji { font-size: 22px; flex-shrink: 0; }
.myday-text { display: flex; flex-direction: column; flex: 1; min-width: 0; }
.myday-text strong { font-size: 15px; color: var(--text-primary); }
.myday-text small { font-size: 12px; color: var(--text-tertiary); margin-top: 2px; }
.myday-paused {
  font-size: 10px; font-weight: 700; text-transform: uppercase;
  color: var(--text-tertiary); background: var(--bg-card-soft);
  padding: 4px 9px; border-radius: 999px; white-space: nowrap;
}
.myday-actions { display: flex; gap: 6px; flex-shrink: 0; }
.myday-actions button { font-size: 12px; padding: 6px 11px; }

.myday-form { display: flex; flex-direction: column; gap: 18px; padding: 20px; }
.myday-inline { display: grid; grid-template-columns: 150px 1fr; gap: 18px; align-items: start; }

.myday-chips { display: flex; flex-wrap: wrap; gap: 7px; }
.myday-chip {
  font-size: 12px; font-weight: 600; padding: 8px 12px; border-radius: 999px;
  background: var(--bg-card-soft); color: var(--text-secondary);
  border: 1px solid var(--border-subtle); cursor: pointer;
}
.myday-chip:hover { border-color: var(--sage); }
.myday-chip.on {
  background: var(--sage-tint); color: var(--sage); border-color: var(--sage);
}

.myday-days { display: flex; gap: 7px; }
.myday-day {
  width: 40px; height: 40px; border-radius: 50%;
  font-size: 13px; font-weight: 700; cursor: pointer;
  background: var(--bg-card-soft); color: var(--text-tertiary);
  border: 1px solid var(--border-subtle);
}
.myday-day.on {
  background: var(--sage-tint); color: var(--sage); border-color: var(--sage);
}

.myday-form-actions { display: flex; justify-content: flex-end; gap: 8px; }
.myday-add { align-self: flex-start; }

@media (max-width: 560px) {
  .myday-inline { grid-template-columns: 1fr; }
  .myday-row { flex-wrap: wrap; }
  .myday-actions { width: 100%; justify-content: flex-end; }
}
PLANBHAI_EOF
  echo "   appended to src/styles.css"
fi
echo

echo "6. Building"
if [ -d node_modules ]; then
  npm run build 2>&1 | grep -E "error|✓ built" | head -8
else
  echo "   node_modules missing"
fi
echo

echo "=========================================="
echo "  Visit /my-day. Blocks made here appear on the phone, and vice versa."
echo
echo "  NOT LINKED IN THE NAV — your topnav already has nine items. Add it"
echo "  wherever it fits, or reach it from the Brief. I have not touched the"
echo "  nav because that is a layout decision on a bar that is already full."
echo
echo "  Revert:"
echo "     rm web/src/pages/MyDay.jsx"
echo "     cp web/src/api.js.bakmyday web/src/api.js"
echo "     cp web/src/App.jsx.bakmyday web/src/App.jsx"
echo "     cp web/src/styles.css.bakmyday web/src/styles.css"
echo "=========================================="

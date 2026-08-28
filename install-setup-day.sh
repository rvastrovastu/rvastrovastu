#!/usr/bin/env bash
#
# "Set up my day" — first-run onboarding for the schedule. Web.
#
# Three steps: pick a profession, answer five questions, review before anything
# is written.
#
# FRAMED AS ONBOARDING, NOT A FEATURE YOU RETURN TO.
#   Testing this against a real day made the reason obvious. Five hand-made
#   blocks beat the template's five every time — the template proposed the same
#   things thirty minutes off, and the hand-made ones were chosen deliberately.
#   Five answers cannot beat five decisions.
#
#   So this is for an empty schedule that needs a starting point worth editing,
#   and the review step matters more than the picker: the day it proposes is a
#   first draft, and saying so is better than presenting it as an answer.
#
# THE REVIEW STEP
#   Nothing is written until it is confirmed. If blocks already exist, the
#   collisions are shown with both times, and the choice is explicit:
#     Add anyway    — leaves two of each, stated plainly
#     Replace my day — removes everything INCLUDING hand-made blocks
#
#   The collision card is amber, not red. Having two of something is a choice
#   to make, not an error to fix.
#
# Reachable at /setup-day. Not linked in the nav — the topnav is already full,
# and this is a one-time flow better reached from an empty My Day.
#
# Usage:
#   bash ~/Downloads/install-setup-day.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT/web" 2>/dev/null || { echo "ERROR: no web/ under $ROOT"; exit 1; }

echo "PlanBhai — Set up my day"
echo

echo "1. Page"
[ -f src/pages/SetupDay.jsx ] && cp src/pages/SetupDay.jsx src/pages/SetupDay.jsx.baksetup
cat > src/pages/SetupDay.jsx << 'PLANBHAI_EOF'
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
export default function SetupDay() {
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
      navigate('/my-day');
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
          <button className="btn-primary setup-next" disabled={!templateId} onClick={() => setStep(1)}>
            Continue
          </button>
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
echo "   wrote src/pages/SetupDay.jsx"
echo

echo "2. api methods"
if grep -q "fetchScheduleTemplates" src/api.js; then
  echo "   already present"
else
  cp src/api.js src/api.js.baksetup
  python3 - src/api.js << 'PY_EOF'
import sys
p = sys.argv[1]
s = open(p).read()
anchor = "  // ---- Auth ----"
if anchor not in s:
    print("   ERROR: Auth section not found"); sys.exit(2)
add = """  // ---- Schedule templates ----
  fetchScheduleTemplates: () =>
    request('/api/schedule/templates', { auth: true }),

  previewScheduleTemplate: (scopeId, templateId, answers) =>
    request(`/api/schedule/templates/preview?scopeId=${scopeId}`, {
      method: 'POST', auth: true, body: { templateId, answers },
    }),

  applyScheduleTemplate: (scopeId, templateId, answers, mode) =>
    request(`/api/schedule/templates/apply?scopeId=${scopeId}`, {
      method: 'POST', auth: true, body: { templateId, answers, mode },
    }),

"""
s = s.replace(anchor, add + anchor, 1)
open(p, "w").write(s)
print("   added three template methods")
PY_EOF
  [ $? -ne 0 ] && { cp src/api.js.baksetup src/api.js; exit 1; }
fi
echo

echo "3. Route"
if grep -q '"/setup-day"' src/App.jsx; then
  echo "   already routed"
else
  cp src/App.jsx src/App.jsx.baksetup
  python3 - src/App.jsx << 'PY_EOF'
import sys, re
p = sys.argv[1]
s = open(p).read()
m = re.search(r'\n(\s*)<Route path="/my-day" element=\{', s)
if not m:
    m = re.search(r'\n(\s*)<Route path="/meals" element=\{', s)
if not m:
    print("   ERROR: no anchor route found"); sys.exit(2)
indent = m.group(1)
block = (f'\n{indent}<Route path="/setup-day" element={{\n'
         f'{indent}  <ProtectedRoute><SetupDay /></ProtectedRoute>\n'
         f'{indent}}} />')
s = s[:m.start()] + block + s[m.start():]

if "lazy(" in s:
    lz = re.search(r"const (\w+) = lazy\(\(\) => import\('\./pages/(\w+)'\)\);", s)
    if lz:
        s = s.replace(lz.group(0), lz.group(0) + "\nconst SetupDay = lazy(() => import('./pages/SetupDay'));", 1)
    else:
        s = "import SetupDay from './pages/SetupDay';\n" + s
else:
    s = "import SetupDay from './pages/SetupDay';\n" + s

open(p, "w").write(s)
print("   added /setup-day")
PY_EOF
  [ $? -ne 0 ] && { cp src/App.jsx.baksetup src/App.jsx; exit 1; }
fi
echo

echo "4. Styles"
if grep -q "^.setup-tile" src/styles.css; then
  echo "   already appended"
else
  cp src/styles.css src/styles.css.baksetup
  cat >> src/styles.css << 'PLANBHAI_EOF'

/* ---------- Set up my day ---------- */

.setup { max-width: 720px; display: flex; flex-direction: column; gap: 16px; }

.setup-steps { display: flex; gap: 14px; font-size: 12px; color: var(--text-tertiary); }
.setup-step.on { color: var(--sage); font-weight: 600; }
.setup-step.done { color: var(--text-secondary); }

.setup-grid {
  display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 10px;
}
.setup-tile {
  display: flex; flex-direction: column; align-items: flex-start; gap: 4px;
  padding: 16px; cursor: pointer; text-align: left;
  border: 1px solid var(--border-subtle);
}
.setup-tile:hover { border-color: var(--sage); }
.setup-tile.on { border-color: var(--sage); background: var(--sage-tint); }
.setup-emoji { font-size: 24px; }
.setup-tile strong { font-size: 14px; color: var(--text-primary); }
.setup-tile small { font-size: 11px; color: var(--text-tertiary); }

.setup-questions { display: flex; flex-direction: column; gap: 14px; padding: 20px; }
.setup-question { display: flex; align-items: center; justify-content: space-between; gap: 16px; }
.setup-question .field-label { margin: 0; }
.setup-question .field-input { width: 140px; }

.setup-review, .setup-collisions { padding: 20px; }
.setup-review-label {
  font-size: 10px; font-weight: 700; letter-spacing: 0.1em; text-transform: uppercase;
  color: var(--text-tertiary); margin-bottom: 14px;
}
.setup-row {
  display: flex; align-items: baseline; gap: 12px; padding: 7px 0;
  border-bottom: 1px solid var(--border-subtle);
}
.setup-row:last-of-type { border-bottom: none; }
.setup-time {
  font-size: 12px; font-weight: 700; color: var(--text-tertiary);
  width: 52px; flex-shrink: 0;
}
.setup-title { flex: 1; font-size: 14px; color: var(--text-primary); }
.setup-dur { font-size: 12px; color: var(--text-tertiary); }

.setup-warnings { margin-top: 12px; font-size: 12px; color: var(--amber); }
/* The collision card is bordered in amber, not red — having two of something
   is a choice to make, not an error to fix. */
.setup-collisions { border: 1px solid var(--amber); }
.setup-note { margin-top: 12px; font-size: 12px; color: var(--text-secondary); line-height: 1.5; }

.setup-actions { display: flex; gap: 8px; justify-content: flex-end; }
.setup-next { align-self: flex-start; }

@media (max-width: 520px) {
  .setup-question { flex-direction: column; align-items: stretch; gap: 6px; }
  .setup-question .field-input { width: 100%; }
  .setup-actions { flex-direction: column-reverse; }
  .setup-actions button { width: 100%; }
}
PLANBHAI_EOF
  echo "   appended"
fi
echo

echo "5. Building"
if [ -d node_modules ]; then
  npm run build 2>&1 | grep -E "ERROR|error during|✓ built" | head -6
else
  echo "   node_modules missing"
fi
echo

echo "=========================================="
echo "  Visit /setup-day."
echo
echo "  With your five blocks in place you will see the collision card —"
echo "  which is the interesting path, even though the flow is designed for"
echo "  someone with an empty schedule."
echo
echo "  Revert:"
echo "     rm web/src/pages/SetupDay.jsx"
echo "     cp web/src/api.js.baksetup web/src/api.js"
echo "     cp web/src/App.jsx.baksetup web/src/App.jsx"
echo "     cp web/src/styles.css.baksetup web/src/styles.css"
echo "=========================================="

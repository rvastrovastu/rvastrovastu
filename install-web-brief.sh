#!/usr/bin/env bash
#
# The Brief for web.
#
# Renders the same DayBrief contract iOS uses. Structure is ported; STYLING IS
# NOT — iOS is dark charcoal with jewel tones, web is Serene Productivity
# (cream, sage, terracotta). A glassmorphic dark card would look broken here,
# so this uses the existing theme variables and card classes throughout.
#
# WHAT IT ADDS
#   src/pages/Brief.jsx      the page
#   src/brief.css            styles, appended-to via an import in main
#   src/api.js               one method: fetchDayBrief
#   src/App.jsx              /brief behind ProtectedRoute
#
# Added at /brief ALONGSIDE the existing home rather than replacing RootRoute,
# so it can be compared before committing — the same way the temporary seventh
# tab worked on iOS.
#
# TWO WEB-SPECIFIC DIFFERENCES
#   Suggestions use webPath, not the planbhai:// deeplinks. But /habits and
#   /grocery don't exist in this router, so they're mapped to /lifestyle and
#   /meals rather than left to 404.
#
#   The timeline is only as fresh as the last iOS sync — ExternalEvent fills
#   from EventKit. A household with no iOS user sees PlanBhai events and no
#   device calendar, so "Calendar synced 20m ago" is shown rather than hidden.
#
# Usage:
#   bash ~/Downloads/install-web-brief.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT/web" 2>/dev/null || { echo "ERROR: no web/ under $ROOT"; exit 1; }

echo "PlanBhai — the Brief for web"
echo

echo "1. Checking what this depends on"
for f in src/api.js src/App.jsx src/HouseholdContext.jsx src/AuthContext.jsx src/styles.css; do
  [ -f "$f" ] && echo "   ok   $f" || { echo "   MISSING $f"; exit 1; }
done
grep -q "scopeId" src/HouseholdContext.jsx \
  && echo "   ok   useHousehold exposes scopeId" \
  || echo "   warn scopeId not found in HouseholdContext — check the export name"
echo

echo "2. Writing the page"
mkdir -p src/pages
[ -f src/pages/Brief.jsx ] && cp src/pages/Brief.jsx src/pages/Brief.jsx.bak
cat > src/pages/Brief.jsx << 'PLANBHAI_EOF'
import { useEffect, useState, useCallback } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api';
import { useHousehold } from '../HouseholdContext';
import { useAuth } from '../AuthContext';

/**
 * The Brief — the same DayBrief contract iOS renders, in web's light theme.
 *
 * Structure is ported; styling is not. iOS is dark charcoal with jewel tones;
 * this is Serene Productivity — cream, sage, terracotta. A glassmorphic dark
 * card would look broken here.
 *
 * Two honesty rules carried over from iOS:
 *   1. A section with no data does not render. An empty shell implies the app
 *      knows something it doesn't.
 *   2. Nothing is computed client-side. Every number comes from the brief.
 */

// Suggestions carry both `deeplink` (planbhai://) and `webPath`. Web uses
// webPath — but the contract's /habits and /grocery don't exist in this
// router, so they're translated rather than left to 404.
const PATH_MAP = {
  '/habits': '/lifestyle',
  '/grocery': '/meals',
  '/planner': '/calendar',
};
const webRoute = (p) => (p ? PATH_MAP[p] || p : null);

function ringColor(score) {
  if (score >= 80) return 'var(--forest)';
  if (score >= 60) return 'var(--teal)';
  if (score >= 40) return 'var(--amber)';
  return 'var(--rose)';
}

/** "19:00" -> "7 PM". The server sends 24h; people read 12h. */
function displayTime(hhmm) {
  const [h, m] = String(hhmm || '').split(':').map(Number);
  if (Number.isNaN(h)) return hhmm;
  const suffix = h < 12 ? 'AM' : 'PM';
  const h12 = h % 12 === 0 ? 12 : h % 12;
  return m === 0 ? `${h12} ${suffix}` : `${h12}:${String(m).padStart(2, '0')} ${suffix}`;
}

function relativeSync(iso) {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return 'recently';
  const mins = Math.floor((Date.now() - d.getTime()) / 60000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m ago`;
  return `${Math.floor(mins / 60)}h ago`;
}

export default function Brief() {
  const { scopeId } = useHousehold();
  const { user } = useAuth();

  const [brief, setBrief] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showBreakdown, setShowBreakdown] = useState(false);

  const load = useCallback(async () => {
    if (!scopeId) return;              // HouseholdContext resolves it async
    setLoading(true);
    setError('');
    try {
      const tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
      setBrief(await api.fetchDayBrief(scopeId, tz));
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }, [scopeId]);

  // Depending on scopeId rather than checking it once avoids the race iOS hit:
  // the household resolves after first render, and a one-shot check loses.
  useEffect(() => { load(); }, [load]);

  if (!scopeId) {
    return (
      <div className="content-container">
        <div className="card empty-state">
          <div className="empty-state-icon">🏠</div>
          <div className="empty-state-text">Pick a household to see your day.</div>
        </div>
      </div>
    );
  }

  if (loading && !brief) {
    return (
      <div className="content-container">
        <div className="loading-spinner" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="content-container">
        <div className="card empty-state">
          <div className="empty-state-icon">⚠️</div>
          <div className="empty-state-text">{error}</div>
          <button className="btn-secondary" onClick={load} style={{ marginTop: 12 }}>
            Try again
          </button>
        </div>
      </div>
    );
  }

  if (!brief) return null;

  const b = brief;
  const r = b.readiness;
  const counts = b.counts || {};

  const dayAndDate = (() => {
    // From the brief's own localDate, not the browser clock — they disagree
    // around midnight and while travelling, and a date contradicting the data
    // below it is worse than none.
    const d = new Date(`${b.localDate}T12:00:00`);
    return d.toLocaleDateString(undefined, {
      weekday: 'long', month: 'long', day: 'numeric',
    }).toUpperCase();
  })();

  const firstName = (user?.name || '').split(' ')[0];
  const timeOfDay = b.greeting?.timeOfDay || 'day';
  const salutation = firstName
    ? `Good ${timeOfDay.charAt(0).toUpperCase() + timeOfDay.slice(1)}, ${firstName}`
    : `Good ${timeOfDay}`;

  const heroLines = [];
  if (counts.events > 0) heroLines.push(`${counts.events} event${counts.events === 1 ? '' : 's'} today`);
  if (counts.meals > 0) heroLines.push(`${counts.meals} meal${counts.meals === 1 ? '' : 's'} planned`);
  if (b.habits?.total > 0) heroLines.push(`${b.habits.completedToday || 0} of ${b.habits.total} habits done`);
  if (counts.choresOpen > 0) heroLines.push(`${counts.choresOpen} chore${counts.choresOpen === 1 ? '' : 's'} to pick up`);
  if (counts.groceries > 0) heroLines.push(`${counts.groceries} items on the grocery list`);
  if (counts.upcoming > 0) heroLines.push(`${counts.upcoming} thing${counts.upcoming === 1 ? '' : 's'} coming up`);

  const applicable = (r?.breakdown || []).filter((d) => d.applicable);
  const weakest = applicable.length
    ? applicable.reduce((a, c) => (a.score <= c.score ? a : c))
    : null;
  const notCounted = (r?.breakdown || []).filter((d) => !d.applicable).map((d) => d.domain);

  const earned = [];
  if (b.habits?.longestStreak >= 3) earned.push(['🔥', `${b.habits.longestStreak} day streak`]);
  if (b.habits?.total > 0 && b.habits.completedToday === b.habits.total) earned.push(['💪', 'All habits done']);
  if (counts.choresDone > 0) earned.push(['🏆', `${counts.choresDone} chores done`]);
  if (r?.score >= 90) earned.push(['✨', 'Day under control']);

  return (
    <div className="content-container brief">
      {/* Hero */}
      <div className="hero-card brief-hero">
        <div className="brief-hero-top">
          <div>
            <div className="brief-date">{dayAndDate}</div>
            <div className="hero-name">{salutation}</div>
            <div className="hero-greeting">{b.greeting?.line}</div>
          </div>
          <img src="/logo.png" alt="" className="brief-logo" />
        </div>

        {heroLines.length > 0 && (
          <>
            <div className="brief-divider" />
            <ul className="brief-checklist">
              {heroLines.map((line) => (
                <li key={line}><span className="brief-check">✓</span>{line}</li>
              ))}
            </ul>
          </>
        )}

        {r && (
          <div className="brief-hero-verdict">
            {r.score >= 80 ? 'Everything fits.' : r.label}
          </div>
        )}
      </div>

      {/* Today's Focus */}
      {r && (
        <div className="card brief-section">
          <div className="brief-label">TODAY'S FOCUS</div>
          <div className="brief-focus">
            <div
              className="brief-ring"
              style={{
                background: `conic-gradient(${ringColor(r.score)} ${r.score * 3.6}deg, var(--bg-card-soft) 0deg)`,
              }}
            >
              <div className="brief-ring-inner">
                <span className="brief-ring-score">{r.score}</span>
                <span className="brief-ring-pct">%</span>
              </div>
            </div>
            <div>
              <div className="brief-focus-label">{r.label}</div>
              {/* A score with no explanation is anxiety with a percentage
                  attached — always pair it with the weakest domain. */}
              {weakest?.reason && <div className="brief-focus-reason">{weakest.reason}</div>}
            </div>
          </div>

          {applicable.length > 0 && (
            <>
              <button className="brief-link" onClick={() => setShowBreakdown((v) => !v)}>
                {showBreakdown ? 'Hide detail' : 'Why this score?'}
              </button>
              {showBreakdown && (
                <div className="brief-breakdown">
                  {applicable.map((d) => (
                    <div className="brief-breakdown-row" key={d.domain}>
                      <span className="brief-domain">{d.domain}</span>
                      <span className="brief-domain-score" style={{ color: ringColor(d.score) }}>
                        {d.score}
                      </span>
                      <span className="brief-domain-reason">{d.reason}</span>
                    </div>
                  ))}
                  {notCounted.length > 0 && (
                    <div className="brief-not-counted">Not counted: {notCounted.join(', ')}</div>
                  )}
                </div>
              )}
            </>
          )}
        </div>
      )}

      {/* Suggestions */}
      {b.suggestions?.length > 0 && (
        <div className="card brief-section">
          <div className="brief-label">BHAI SUGGESTS</div>
          {b.suggestions.map((s) => {
            const to = webRoute(s.webPath);
            const inner = (
              <>
                <span className="brief-suggestion-icon">{s.icon}</span>
                <span className="brief-suggestion-text">{s.title}</span>
                {s.locked ? <span className="pill">🔒</span> : s.cta && <span className="pill">{s.cta}</span>}
              </>
            );
            return s.locked || !to ? (
              <div className="brief-suggestion" key={s.id}>{inner}</div>
            ) : (
              <Link className="brief-suggestion" to={to} key={s.id}>{inner}</Link>
            );
          })}
        </div>
      )}

      {/* Timeline */}
      {b.timeline?.length > 0 && (
        <div className="card brief-section">
          <div className="brief-label">TODAY'S TIMELINE</div>
          <div className="brief-timeline">
            {b.timeline.map((t, i) => (
              <div className={`brief-tl-row${t.isNow ? ' now' : ''}`} key={`${t.start}-${i}`}>
                <span className="brief-tl-time">{displayTime(t.start)}</span>
                <span className="brief-tl-rail">
                  <span className="brief-tl-dot" />
                  {i < b.timeline.length - 1 && <span className="brief-tl-line" />}
                </span>
                <span className="brief-tl-title">
                  {t.icon && <span className="brief-tl-icon">{t.icon}</span>}
                  {t.title}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Ask BhAI */}
      <div className="card brief-section">
        <div className="brief-label">ASK BhAI</div>
        <div className="brief-prompts">
          {[
            ['🍽', 'Plan dinner', '/meals'],
            ['📅', 'Schedule my week', '/meals'],
            ['📖', 'Find recipes', '/meals'],
            ['🛒', 'Grocery list', '/meals'],
            ['🎂', 'Organize a party', '/party'],
            ['💪', 'Build a habit', '/lifestyle'],
            ['💰', 'Split expenses', '/household'],
            ['👨‍👩‍👧', 'Family plans', '/household'],
          ].map(([icon, text, to]) => (
            <Link className="brief-prompt" to={to} key={text}>
              <span>{icon}</span>{text}
            </Link>
          ))}
        </div>
      </div>

      {/* Upcoming */}
      {b.upcoming?.length > 0 && (
        <div className="card brief-section">
          <div className="brief-label">UPCOMING</div>
          <div className="brief-scroll">
            {b.upcoming.map((u) => (
              <div className="brief-upcoming-row" key={`${u.date}-${u.title}`}>
                <span className="brief-upcoming-day">{u.day}</span>
                <span>{u.icon} {u.title}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Family */}
      {b.family?.length > 0 && (
        <div className="card brief-section">
          <div className="brief-label">FAMILY</div>
          <div className="brief-scroll">
            {b.family.map((m) => (
              <div className="brief-family-row" key={m.memberId || m.name}>
                <span className="brief-avatar">{(m.name || '?').charAt(0).toUpperCase()}</span>
                <span className="brief-family-text">
                  <strong>{m.name}</strong>
                  <small>{m.status}</small>
                </span>
                {m.state === 'done' && <span className="brief-done">✓</span>}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Meal */}
      {b.meal && (
        <div className="card brief-section">
          <div className="brief-label">TODAY'S {(b.meal.slot || 'dinner').toUpperCase()}</div>
          <div className="brief-meal-title">{b.meal.title}</div>
          {typeof b.meal.haveRatio === 'number' && (
            <div className="brief-meal-bar">
              <div style={{ width: `${Math.round(b.meal.haveRatio * 100)}%` }} />
              <span>{Math.round(b.meal.haveRatio * 100)}% available</span>
            </div>
          )}
          {b.meal.missing?.length > 0 && (
            <div className="brief-meal-missing">Need: {b.meal.missing.join(', ')}</div>
          )}
          {/* haveRatio null means the pantry is empty and coverage is genuinely
              unknown. Saying nothing beats implying everything's on hand. */}
        </div>
      )}

      {/* Habit garden */}
      {b.habits?.total > 0 && (
        <div className="card brief-section">
          <div className="brief-label">HABIT GARDEN</div>
          <div className="brief-garden">
            {(b.habits.all || []).map((h) => (
              <div className="brief-sprout" key={h.name}>
                <span className={h.completedToday ? '' : 'dim'}>
                  {h.completedToday ? '🌸' : '🌱'}
                </span>
                <small>{h.name}</small>
                {h.streak > 0 && <em>{h.streak}d</em>}
              </div>
            ))}
          </div>
          <div className="brief-garden-count">
            {b.habits.completedToday} of {b.habits.total} blooming today
          </div>
        </div>
      )}

      {/* Achievements — only badges backed by real data. */}
      {earned.length > 0 && (
        <div className="card brief-section">
          <div className="brief-label">ACHIEVEMENTS</div>
          <div className="brief-badges">
            {earned.map(([emoji, title]) => (
              <div className="brief-badge" key={title}>
                <span>{emoji}</span><small>{title}</small>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Web's timeline is only as fresh as the last iOS sync. Showing the
          staleness beats a timeline people quietly stop trusting. */}
      {b.calendarSyncedAt && (
        <div className="brief-sync">Calendar synced {relativeSync(b.calendarSyncedAt)}</div>
      )}
    </div>
  );
}
PLANBHAI_EOF
echo "   wrote src/pages/Brief.jsx"
echo

echo "3. Styles"
if grep -q "^.brief {" src/styles.css; then
  echo "   already appended, skipping"
else
  cp src/styles.css src/styles.css.bakbrief
  cat >> src/styles.css << 'PLANBHAI_EOF'

/* ---------- Brief ---------- */
/* Uses the existing theme variables so it sits with the rest of the app
   rather than importing the iOS dark treatment, which would look broken
   against the cream background. */

.brief { display: flex; flex-direction: column; gap: 16px; }

.brief-hero { padding: 22px; }
.brief-hero-top { display: flex; justify-content: space-between; align-items: flex-start; gap: 12px; }
.brief-date {
  font-size: 11px; font-weight: 700; letter-spacing: 0.09em;
  color: var(--text-tertiary); margin-bottom: 6px;
}
.brief-logo { width: 44px; height: 44px; border-radius: 50%; object-fit: cover; flex-shrink: 0; }

.brief-divider {
  height: 1px; margin: 16px 0 14px;
  background: linear-gradient(to right, var(--border-strong), transparent);
}
.brief-checklist { list-style: none; margin: 0; padding: 0; display: grid; gap: 9px; }
.brief-checklist li {
  display: flex; align-items: center; gap: 9px;
  font-size: 14px; color: var(--text-secondary);
}
.brief-check {
  display: inline-flex; align-items: center; justify-content: center;
  width: 17px; height: 17px; border-radius: 50%; flex-shrink: 0;
  background: var(--sage-tint); color: var(--sage);
  font-size: 10px; font-weight: 800;
}
.brief-hero-verdict {
  margin-top: 16px; font-size: 15px; font-weight: 700; color: var(--text-primary);
}

.brief-section { padding: 18px; }
.brief-label {
  font-size: 10px; font-weight: 700; letter-spacing: 0.1em;
  color: var(--text-tertiary); margin-bottom: 14px;
}

/* Ring drawn with conic-gradient — no SVG, no dependency. */
.brief-focus { display: flex; align-items: center; gap: 18px; }
.brief-ring {
  width: 88px; height: 88px; border-radius: 50%; flex-shrink: 0;
  display: flex; align-items: center; justify-content: center;
}
.brief-ring-inner {
  width: 68px; height: 68px; border-radius: 50%; background: var(--bg-card);
  display: flex; align-items: baseline; justify-content: center; gap: 1px;
}
.brief-ring-score { font-size: 25px; font-weight: 800; color: var(--text-primary); }
.brief-ring-pct { font-size: 11px; font-weight: 700; color: var(--text-tertiary); }
.brief-focus-label { font-size: 15px; font-weight: 700; color: var(--text-primary); }
.brief-focus-reason { font-size: 12px; color: var(--text-secondary); margin-top: 4px; }

.brief-link {
  background: none; border: 0; padding: 12px 0 0; cursor: pointer;
  font-size: 12px; font-weight: 600; color: var(--sage);
}
.brief-breakdown { margin-top: 10px; display: grid; gap: 8px; }
.brief-breakdown-row { display: grid; grid-template-columns: 72px 30px 1fr; align-items: baseline; gap: 8px; }
.brief-domain { font-size: 12px; font-weight: 600; text-transform: capitalize; color: var(--text-secondary); }
.brief-domain-score { font-size: 12px; font-weight: 700; text-align: right; }
.brief-domain-reason { font-size: 11px; color: var(--text-tertiary); }
.brief-not-counted { font-size: 10px; color: var(--text-tertiary); margin-top: 4px; }

.brief-suggestion {
  display: flex; align-items: center; gap: 11px;
  padding: 11px 12px; margin-bottom: 8px; border-radius: 12px;
  background: var(--bg-card-soft); border: 1px solid var(--border-subtle);
  text-decoration: none; color: inherit;
}
.brief-suggestion:last-child { margin-bottom: 0; }
a.brief-suggestion:hover { border-color: var(--sage); }
.brief-suggestion-icon { font-size: 18px; }
.brief-suggestion-text { flex: 1; font-size: 13px; font-weight: 600; color: var(--text-primary); }

/* Sections cap at roughly three rows, matching iOS — a full timeline was most
   of a screen on its own. */
.brief-scroll, .brief-timeline { max-height: 190px; overflow-y: auto; }

.brief-tl-row { display: grid; grid-template-columns: 62px 16px 1fr; gap: 10px; align-items: start; }
.brief-tl-time { font-size: 11px; font-weight: 700; color: var(--text-tertiary); padding-top: 1px; }
.brief-tl-row.now .brief-tl-time { color: var(--teal); }
.brief-tl-rail { display: flex; flex-direction: column; align-items: center; align-self: stretch; }
.brief-tl-dot { width: 8px; height: 8px; border-radius: 50%; background: var(--border-strong); margin-top: 5px; }
.brief-tl-row.now .brief-tl-dot { background: var(--teal); box-shadow: 0 0 0 4px var(--sage-tint); }
.brief-tl-line { flex: 1; width: 1.5px; background: var(--border-subtle); }
.brief-tl-title { font-size: 14px; color: var(--text-secondary); padding-bottom: 16px; }
.brief-tl-row.now .brief-tl-title { color: var(--text-primary); font-weight: 700; }
.brief-tl-icon { margin-right: 6px; }

.brief-prompts { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
.brief-prompt {
  display: flex; align-items: center; gap: 7px;
  padding: 11px 12px; border-radius: 12px;
  background: var(--bg-card-soft); border: 1px solid var(--border-subtle);
  font-size: 13px; font-weight: 600; color: var(--text-primary); text-decoration: none;
}
.brief-prompt:hover { border-color: var(--sage); }

.brief-upcoming-row {
  display: flex; gap: 12px; align-items: center;
  font-size: 14px; color: var(--text-secondary); padding: 7px 0;
}
.brief-upcoming-day { width: 84px; font-size: 12px; font-weight: 700; color: var(--text-tertiary); }

.brief-family-row { display: flex; align-items: center; gap: 11px; padding: 8px 0; }
.brief-avatar {
  width: 32px; height: 32px; border-radius: 50%; flex-shrink: 0;
  display: flex; align-items: center; justify-content: center;
  background: var(--sage-tint); color: var(--sage); font-weight: 700; font-size: 13px;
}
.brief-family-text { display: flex; flex-direction: column; flex: 1; }
.brief-family-text strong { font-size: 14px; color: var(--text-primary); }
.brief-family-text small { font-size: 11px; color: var(--text-tertiary); }
.brief-done { color: var(--forest); font-weight: 700; }

.brief-meal-title { font-size: 17px; font-weight: 700; color: var(--text-primary); }
.brief-meal-bar {
  position: relative; height: 6px; border-radius: 3px; margin-top: 12px;
  background: var(--bg-card-soft);
}
.brief-meal-bar > div { height: 100%; border-radius: 3px; background: var(--forest); }
.brief-meal-bar > span {
  position: absolute; right: 0; top: 10px;
  font-size: 11px; font-weight: 600; color: var(--forest);
}
.brief-meal-missing { margin-top: 10px; font-size: 12px; color: var(--amber); }

.brief-garden { display: flex; gap: 14px; overflow-x: auto; padding-bottom: 6px; }
.brief-sprout { display: flex; flex-direction: column; align-items: center; gap: 3px; min-width: 60px; }
.brief-sprout > span { font-size: 26px; }
.brief-sprout > span.dim { opacity: 0.45; }
.brief-sprout small { font-size: 9px; text-align: center; color: var(--text-tertiary); line-height: 1.2; }
.brief-sprout em { font-size: 9px; font-weight: 700; font-style: normal; color: var(--forest); }
.brief-garden-count { margin-top: 12px; font-size: 12px; color: var(--text-secondary); }

.brief-badges { display: flex; gap: 10px; overflow-x: auto; }
.brief-badge {
  display: flex; flex-direction: column; align-items: center; gap: 5px;
  min-width: 86px; padding: 12px 8px; border-radius: 14px;
  background: var(--terracotta-tint); border: 1px solid var(--border-subtle);
}
.brief-badge span { font-size: 22px; }
.brief-badge small { font-size: 10px; font-weight: 600; text-align: center; color: var(--text-secondary); }

.brief-sync { text-align: center; font-size: 11px; color: var(--text-tertiary); }

@media (max-width: 520px) {
  .brief-prompts { grid-template-columns: 1fr; }
  .brief-breakdown-row { grid-template-columns: 66px 26px 1fr; }
}
PLANBHAI_EOF
  echo "   appended to src/styles.css"
fi
echo

echo "4. api.js"
if grep -q "fetchDayBrief" src/api.js; then
  echo "   already present"
else
  cp src/api.js src/api.js.bakbrief
  python3 - src/api.js << 'PY_EOF'
import sys
p = sys.argv[1]
s = open(p).read()
anchor = "  // ---- Auth ----"
if anchor not in s:
    print("   ERROR: could not find the Auth section in api.js"); sys.exit(2)
add = """  // ---- Dashboard ----
  fetchDayBrief: (scopeId, tz) =>
    request(`/api/dashboard/today?scopeId=${scopeId}&tz=${encodeURIComponent(tz)}`, { auth: true }),

"""
s = s.replace(anchor, add + anchor, 1)
open(p, "w").write(s)
print("   added fetchDayBrief")
PY_EOF
  [ $? -ne 0 ] && { cp src/api.js.bakbrief src/api.js; echo "   reverted"; exit 1; }
fi
echo

echo "5. Route"
if grep -q '"/brief"' src/App.jsx; then
  echo "   already routed"
else
  cp src/App.jsx src/App.jsx.bakbrief
  python3 - src/App.jsx << 'PY_EOF'
import sys, re
p = sys.argv[1]
s = open(p).read()

m = re.search(r'\n(\s*)<Route path="/meals" element=\{', s)
if not m:
    print("   ERROR: could not find the /meals route to anchor on"); sys.exit(2)
indent = m.group(1)
block = (f'\n{indent}<Route path="/brief" element={{\n'
         f'{indent}  <ProtectedRoute><Brief /></ProtectedRoute>\n'
         f'{indent}}} />')
s = s[:m.start()] + block + s[m.start():]

# Match the existing import style — lazy if the others are, plain otherwise.
if "lazy(" in s:
    lz = re.search(r"const (\w+) = lazy\(\(\) => import\('\./pages/(\w+)'\)\);", s)
    if lz:
        s = s.replace(lz.group(0),
                      lz.group(0) + "\nconst Brief = lazy(() => import('./pages/Brief'));", 1)
    else:
        s = "import Brief from './pages/Brief';\n" + s
else:
    s = "import Brief from './pages/Brief';\n" + s

open(p, "w").write(s)
print("   added /brief")
PY_EOF
  [ $? -ne 0 ] && { cp src/App.jsx.bakbrief src/App.jsx; echo "   reverted"; exit 1; }
fi
echo

echo "6. Building"
if [ -d node_modules ]; then
  npm run build 2>&1 | tail -12
else
  echo "   node_modules missing — run npm install first"
fi
echo

echo "=========================================="
echo "  Try it:  npm run dev  then visit /brief"
echo
echo "  Revert:"
echo "     rm web/src/pages/Brief.jsx"
echo "     cp web/src/App.jsx.bakbrief web/src/App.jsx"
echo "     cp web/src/api.js.bakbrief web/src/api.js"
echo "     cp web/src/styles.css.bakbrief web/src/styles.css"
echo "=========================================="

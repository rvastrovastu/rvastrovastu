#!/usr/bin/env bash
#
# Web: sections that stay visible when empty — matching iOS.
#
# An empty section that DISAPPEARS teaches nothing. A new account's Brief was
# mostly blank, which reads as broken rather than new, and nothing indicated
# where to begin.
#
#   Today's timeline   Your day in order — blocks, meals, events.
#                      Set up My Day →
#   Upcoming           Birthdays and events show here.
#                      Add one in Household →
#   Family             See who's home and what everyone's up to.
#                      Add family members →
#
# This is the first of five pieces web is missing relative to iOS. The others:
#   · personal / household grocery toggle
#   · shared habits section
#   · invite codes
#   · household switcher (may already exist — unverified)
#
# Usage:
#   bash ~/Downloads/web-empty-states.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
B="web/src/pages/Brief.jsx"
[ -f "$B" ] || { echo "ERROR: $B not found"; exit 1; }

echo "PlanBhai — web empty states"
echo

echo "1. Brief"
cp "$B" "$B.bakempty"
cat > "$B" << 'PLANBHAI_EOF'
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

/**
 * A section that stays visible when it has nothing in it.
 *
 * An empty section that DISAPPEARS teaches nothing — a new account's Brief was
 * mostly blank, which reads as broken rather than new. One that says what it is
 * for, and where to go, turns a first run into a short list of next steps.
 */
function EmptySection({ label, line, action, to }) {
  return (
    <div className="card brief-section brief-empty">
      <div className="brief-label">{label}</div>
      <p className="brief-empty-line">{line}</p>
      <Link className="brief-empty-action" to={to}>{action} →</Link>
    </div>
  );
}

export default function Brief({ embedded = false }) {
  const { scopeId } = useHousehold();
  const { user } = useAuth();

  const [brief, setBrief] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showBreakdown, setShowBreakdown] = useState(false);
  const [pending, setPending] = useState(null);   // habit name mid-request
  const [acting, setActing] = useState(null);     // suggestion id mid-request
  const [review, setReview] = useState(null);

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

  // Shown all day. A hard 6 PM gate hid the card for most of the hours anyone
  // opens the app — and "2 of 8 done" at lunchtime is useful, it just is not a
  // verdict. The heading changes instead of the card disappearing.
  useEffect(() => {
    if (!scopeId) return;
    let cancelled = false;
    (async () => {
      try {
        const tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
        const res = await api.fetchDayReview(scopeId, tz);
        if (!cancelled) setReview(res?.review || null);
      } catch {
        // Silent. A missing review should not disturb the rest of the page.
      }
    })();
    return () => { cancelled = true; };
  }, [scopeId]);

  /**
   * Performs a suggestion's action, then reloads so the row disappears and the
   * counts update. Reload rather than optimistic patching: adding groceries
   * changes the gap suggestion, the grocery count and the meal coverage bar at
   * once, and guessing all three client-side would drift.
   */
  const runAction = async (s) => {
    if (acting) return;
    setActing(s.id);
    try {
      const res = await api.runSuggestionAction(scopeId, s.action);
      await load();
      if (res?.added === 0 && res?.skipped > 0) {
        alert('Those are already on your list.');
      }
    } catch (e) {
      alert(`Couldn't do that: ${e.message}`);
    } finally {
      setActing(null);
    }
  };

  /**
   * Toggle one of YOUR habits. The garden only ever shows your own, so there is
   * nothing here that belongs to someone else.
   *
   * Optimistic: the flower changes immediately and reverts if the write fails.
   * A tap that appears to do nothing for 300ms feels broken.
   */
  const toggleHabit = async (habit) => {
    if (pending) return;
    const next = !habit.completedToday;
    setPending(habit.name);

    setBrief((prev) => {
      if (!prev?.habits?.all) return prev;
      const all = prev.habits.all.map((h) =>
        h.name === habit.name
          ? { ...h, completedToday: next, streak: Math.max((h.streak || 0) + (next ? 1 : -1), 0) }
          : h
      );
      return {
        ...prev,
        habits: { ...prev.habits, all, completedToday: all.filter((h) => h.completedToday).length },
      };
    });

    try {
      const tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
      await api.completeHabit(habit.name, next, tz);
    } catch (e) {
      // Put it back rather than leaving a flower that lies.
      setBrief((prev) => {
        if (!prev?.habits?.all) return prev;
        const all = prev.habits.all.map((h) =>
          h.name === habit.name
            ? { ...h, completedToday: habit.completedToday, streak: habit.streak }
            : h
        );
        return {
          ...prev,
          habits: { ...prev.habits, all, completedToday: all.filter((h) => h.completedToday).length },
        };
      });
      alert(`Couldn't update that habit: ${e.message}`);
    } finally {
      setPending(null);
    }
  };

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
    <div className={embedded ? "brief brief-embedded" : "brief"}>
      {/* Hero — skipped when embedded, because the Dashboard's own hero
          already carries the date, greeting, readiness ring and counts. */}
      {!embedded && (
      <div className="brief-hero">
        <div className="brief-hero-top">
          <div>
            <div className="brief-date">{dayAndDate}</div>
            <div className="brief-salutation">{salutation}</div>
            <div className="brief-line">{b.greeting?.line}</div>
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
      )}

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
                {/* Wrapped so the number and % align to each other's baseline,
                    while the pair as a whole stays centred in the circle.
                    Baseline-aligning them directly against the circle pushed
                    the group low and left. */}
                <span className="brief-ring-value">
                  <span className="brief-ring-score">{r.score}</span>
                  <span className="brief-ring-pct">%</span>
                </span>
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

      {/* Suggestions
        *
        * A suggestion with an `action` DOES the thing; one without navigates.
        * Previously every CTA was a label on a link, so "Add to list" opened a
        * screen rather than adding anything — the button promised something the
        * row never performed. */}
      {b.suggestions?.length > 0 && (
        <div className="card brief-section">
          <div className="brief-label">BHAI SUGGESTS</div>
          {b.suggestions.map((s) => {
            const to = webRoute(s.webPath);
            const busy = acting === s.id;

            const body = (
              <>
                <span className="brief-suggestion-icon">{s.icon}</span>
                <span className="brief-suggestion-text">{s.title}</span>
              </>
            );

            if (s.locked) {
              return (
                <div className="brief-suggestion" key={s.id}>
                  {body}<span className="brief-cta locked">🔒</span>
                </div>
              );
            }

            if (s.action) {
              return (
                <div className="brief-suggestion" key={s.id}>
                  {body}
                  <button
                    className="brief-cta brief-cta-btn"
                    disabled={busy}
                    onClick={() => runAction(s)}
                  >
                    {busy ? 'Adding…' : s.cta}
                  </button>
                </div>
              );
            }

            return to ? (
              <Link className="brief-suggestion" to={to} key={s.id}>
                {body}{s.cta && <span className="brief-cta">{s.cta}</span>}
              </Link>
            ) : (
              <div className="brief-suggestion" key={s.id}>
                {body}{s.cta && <span className="brief-cta">{s.cta}</span>}
              </div>
            );
          })}
        </div>
      )}

      {/* Timeline */}
      {!b.timeline?.length && (
        <EmptySection
          label="TODAY'S TIMELINE"
          line="Your day in order — blocks, meals, events and appointments."
          action="Set up My Day"
          to="/my-day"
        />
      )}
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

      {/* Ask BhAI — skipped when embedded. The Dashboard has a real composer
          that calls /api/ai/bhai; this one only navigates, so showing both
          would put the weaker version underneath the working one. */}
      {!embedded && (
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
      )}

      {/* My Day — schedule blocks live on their own page. Counting only
          schedule rows means the label describes what tapping actually edits. */}
      {(() => {
        const blocks = (b.timeline || []).filter((t) => t.source === 'schedule').length;
        return (
          <Link className="card brief-myday" to="/my-day">
            <span className="brief-myday-icon">🗓</span>
            <span className="brief-myday-text">
              <strong>My Day</strong>
              <small>
                {blocks === 0
                  ? 'Set up the shape of your day'
                  : `${blocks} block${blocks === 1 ? '' : 's'} today · edit`}
              </small>
            </span>
            <span className="brief-myday-chev">›</span>
          </Link>
        );
      })()}

      {/* Households. Which one you are in changes almost everything else on
          this page, so it belongs here rather than only in Me. */}
      <Link className="card brief-myday" to="/household">
        <span className="brief-myday-icon">🏠</span>
        <span className="brief-myday-text">
          <strong>{b.householdName || 'Household'}</strong>
          <small>Meals, chores, wall and calendar</small>
        </span>
        <span className="brief-myday-chev">›</span>
      </Link>

      {/* Evening review. Counts are rules; only the sentence is written by a
          model, over facts it was handed. */}
      {review?.hasSchedule && (
        <div className="card brief-section">
          <div className="brief-label">
            {new Date().getHours() >= 18 ? "TODAY'S REVIEW" : 'TODAY SO FAR'}
          </div>

          <p className="review-summary">{review.summary}</p>

          <div className="review-count">
            {review.today.done} of {review.today.scheduled} done
            {review.today.moved > 0 && <span className="review-moved"> · {review.today.moved} moved</span>}
          </div>

          {/* A week's tally, not a day's. One missed session is a Tuesday;
              0/5 is the app noticing something you would not. */}
          {review.week?.slipping?.length > 0 && (
            <div className="review-block">
              <div className="review-sub">SLIPPING THIS WEEK</div>
              {review.week.slipping.map((t) => (
                <div className="review-row" key={t.title}>
                  <span>{t.title}</span>
                  <strong>{t.done}/{t.of}</strong>
                </div>
              ))}
            </div>
          )}

          {review.week?.consistent?.length > 0 && (
            <div className="review-steady">
              Holding steady: {review.week.consistent.map((t) => t.title).join(', ')}
            </div>
          )}
        </div>
      )}

      {/* Upcoming */}
      {!b.upcoming?.length && (
        <EmptySection
          label="UPCOMING"
          line="Birthdays and events show here."
          action="Add one in Household"
          to="/household"
        />
      )}
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
      {!b.family?.length && (
        <EmptySection
          label="FAMILY"
          line="See who's home and what everyone's up to."
          action="Add family members"
          to="/household"
        />
      )}
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
              <button
                type="button"
                className={`brief-sprout${pending === h.name ? ' busy' : ''}`}
                key={h.name}
                onClick={() => toggleHabit(h)}
                aria-pressed={h.completedToday}
                title={h.completedToday ? 'Tap to undo' : 'Tap to mark done'}
              >
                <span className={h.completedToday ? '' : 'dim'}>
                  {h.completedToday ? '🌸' : '🌱'}
                </span>
                <small>{h.name}</small>
                {h.streak > 0 && <em>{h.streak}d</em>}
              </button>
            ))}
          </div>
          <div className="brief-garden-count">
            {b.habits.completedToday} of {b.habits.total} blooming today
            {b.habits.household && b.habits.household.total > b.habits.total && (
              <span className="brief-garden-household">
                {' · '}household {b.habits.household.completedToday}/{b.habits.household.total}
              </span>
            )}
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
n=$(grep -c "<EmptySection" "$B")
[ "$n" = "3" ] && echo "   ok   three empty sections" \
  || { echo "   found $n, expected 3 — reverting"; cp "$B.bakempty" "$B"; exit 1; }
echo

echo "2. Styles"
if grep -q "brief-empty-line" web/src/styles.css; then
  echo "   already present"
else
  cp web/src/styles.css web/src/styles.css.bakempty
  python3 - web/src/styles.css << 'PY_EOF'
import sys
p = sys.argv[1]
s = open(p).read()
i = s.find("\n/* ---------- Home hero ---------- */")
if i == -1:
    print("   ERROR: hero block not found"); sys.exit(2)
open(p, "w").write(s[:i])
PY_EOF
  [ $? -ne 0 ] && { cp web/src/styles.css.bakempty web/src/styles.css; exit 1; }
  cat >> web/src/styles.css << 'PLANBHAI_EOF'

/* ---------- Home hero ---------- */

.hero-date {
  font-size: 11px; font-weight: 500; letter-spacing: 0.09em;
  text-transform: uppercase; opacity: 0.6;
}
.hero-name { font-size: 24px; font-weight: 500; margin-top: 4px; }

.hero-status { margin-top: 16px; }

/* conic-gradient, so no SVG and no dependency */
.hero-ring {
  width: 56px; height: 56px; border-radius: 50%; flex-shrink: 0;
  display: flex; align-items: center; justify-content: center;
}
.hero-ring-inner {
  width: 42px; height: 42px; border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  font-size: 15px; font-weight: 500;
  /* Matches the hero card, so the ring reads as a ring rather than a disc. */
  background: var(--hero-bg, #141527);
}
.hero-verdict { font-size: 15px; font-weight: 500; line-height: 1.35; }
.hero-counts { font-size: 12px; opacity: 0.6; margin-top: 3px; }

.hero-divider {
  height: 1px; background: rgba(255,255,255,0.12); margin: 18px 0;
}

.hero-ask {
  display: flex; align-items: flex-end; gap: 16px;
  /* Breathing room under the divider — the input was sitting on it. */
  margin-top: 8px;
}
/* Image above the name, so the mascot is introduced rather than labelled. */
.hero-bhai-col {
  display: flex; flex-direction: column; align-items: center;
  gap: 8px; flex-shrink: 0; width: 72px;
}
/* Bhai sits beside the input so he reads as the person you are asking,
   rather than a logo in the corner you stopped noticing. */
.hero-bhai {
  width: 56px; height: 56px; border-radius: 50%;
  object-fit: cover; object-position: 35% center;
  background: rgba(255,255,255,0.08);
}
.hero-ask-label {
  font-size: 13px; font-weight: 600; opacity: 0.85; white-space: nowrap;
  /* NOT uppercase. text-transform destroyed the lowercase h in "BhAI", which
     is the one thing about the name that has to survive. */
}
.hero-input {
  flex: 1; min-width: 220px; padding: 11px 14px; border-radius: 8px;
  border: none; background: rgba(255,255,255,0.10);
  color: white; font-size: 13px;
}
.hero-input::placeholder { color: rgba(255,255,255,0.40); }

.hero-try { margin-top: 8px; font-size: 13px; opacity: 0.6; }
/* The hero needs a floor. Without it the next section butts straight up
   against the example links. */
.hero-card { padding-bottom: 26px; }
.hero-card + * { margin-top: 20px; }
.hero-try-sep { opacity: 0.5; }
.hero-try-link {
  background: none; border: none; padding: 0 0 0 4px;
  font-size: 12px; color: #5DCAA5; cursor: pointer; text-decoration: none;
}
.hero-try-link:hover { text-decoration: underline; }

@media (max-width: 560px) {
  .hero-ask { flex-direction: column; gap: 12px; }
  .hero-bhai { width: 44px; height: 44px; }
}

/* My Day row, on the Brief */
.brief-myday {
  display: flex; align-items: center; gap: 13px;
  padding: 14px 16px; text-decoration: none; color: inherit;
}
.brief-myday:hover { border-color: var(--sage); }
.brief-myday-icon { font-size: 20px; }
.brief-myday-text { display: flex; flex-direction: column; flex: 1; min-width: 0; }
.brief-myday-text strong { font-size: 14px; color: var(--text-primary); }
.brief-myday-text small { font-size: 12px; color: var(--text-tertiary); margin-top: 2px; }
.brief-myday-chev { font-size: 20px; color: var(--text-tertiary); }

/* Embedded in the Dashboard, the Brief drops its own width cap and padding so
   its cards align exactly with the hero above. Standalone it keeps the cap,
   because 780px is a comfortable reading width when nothing else is on the
   page to line up with. */
.brief-embedded {
  max-width: none;
  margin: 0;
  padding: 0;
}

/* A CTA that performs an action is a button, not a label on a link. */
.brief-cta-btn {
  border: none; cursor: pointer; font-family: inherit;
}
.brief-cta-btn:hover { background: var(--sage); color: var(--bg-card); }
.brief-cta-btn:disabled { opacity: 0.6; cursor: default; }

/* ---------- Evening review ---------- */
.review-summary {
  font-size: 14px; font-weight: 500; color: var(--text-primary);
  margin: 0 0 8px; line-height: 1.45;
}
.review-count { font-size: 12px; font-weight: 600; color: var(--forest); }
.review-moved { color: var(--text-tertiary); font-weight: 400; }
.review-block { margin-top: 14px; }
.review-sub {
  font-size: 10px; font-weight: 700; letter-spacing: 0.1em;
  color: var(--text-tertiary); margin-bottom: 6px;
}
.review-row {
  display: flex; justify-content: space-between; align-items: baseline;
  font-size: 13px; color: var(--text-secondary); padding: 3px 0;
}
.review-row strong { font-size: 12px; color: var(--amber); }
.review-steady { margin-top: 12px; font-size: 11px; color: var(--text-tertiary); }

/* Sections that stay visible when empty */
.brief-empty-line {
  font-size: 13px; color: var(--text-secondary);
  margin: 0 0 10px; line-height: 1.45;
}
.brief-empty-action {
  font-size: 12px; font-weight: 600; color: var(--sage);
  text-decoration: none;
}
.brief-empty-action:hover { text-decoration: underline; }
PLANBHAI_EOF
  echo "   appended"
fi
echo

echo "3. Building"
(cd web && npm run build 2>&1 | grep -E "ERROR|error during|✓ built" | head -6)
echo

echo "=========================================="
echo "  Deploy:  git add -A && git commit -m 'Web empty states' && git push"
echo "           then cd web && vercel --prod"
echo
echo "  Your account has data in most sections, so sign in fresh to see them all."
echo "=========================================="

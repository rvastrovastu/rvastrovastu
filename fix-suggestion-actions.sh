#!/usr/bin/env bash
#
# Makes "Add to list" actually add to the list.
#
# THE BUG
#   Suggestions carried a CTA like "Add to list" but the whole row was a link.
#   Tapping it opened a screen. The label promised an action the row never
#   performed — and worse, webPath was "/grocery", which is not a route on web
#   at all, so it went nowhere useful either.
#
# THE FIX
#   Rules that CAN act now carry an `action` payload. grocery_gap already knows
#   exactly which ingredients are missing, so it ships them as data rather than
#   only inside the title string.
#
#   POST /api/suggestions/action performs it. Items already on the list are
#   skipped — including ticked ones, because a second "Milk" is worse than
#   doing nothing.
#
#   The other eleven rules carry no action and still navigate, which is right
#   for them: "Open planner" should open the planner.
#
# AFTER ADDING, the page reloads rather than patching optimistically. One tap
# changes the gap suggestion, the grocery count and the meal coverage bar at
# once; guessing all three client-side would drift.
#
# Usage:
#   bash ~/Downloads/fix-suggestion-actions.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
[ -d backend/services/daybrief ] || { echo "ERROR: backend not found"; exit 1; }

echo "PlanBhai — suggestion actions"
echo

write() {
  local dest="$1"
  [ -f "$dest" ] && cp "$dest" "$dest.bakaction"
  cat > "$dest"
  echo "   wrote $dest"
}

echo "1. Backend"
write 'backend/services/daybrief/suggestions.service.js' << 'PLANBHAI_EOF'
/**
 * Suggestion rules engine.
 *
 * Every suggestion here is DETERMINISTIC. "You're missing tomatoes" is a pantry
 * diff; "Mom's birthday in 12 days" is date arithmetic; "streak at risk" is a
 * clock comparison. None of it needs a model, none of it can hallucinate, and
 * it costs nothing to run on every request.
 *
 * Phrasing lives in DEFAULT_TEMPLATES below — edit those to change the voice.
 * Placeholders are filled with today's facts at build time.
 *
 * Each rule returns null when it doesn't apply. Ranking happens at the end.
 */

const { localTimeIn, localHourIn, daysBetween } = require('./tz.util');

/** "17:03" -> "5:03 PM". The rest of the app shows 12-hour; so should these. */
function display(hhmm) {
  const [h, m] = String(hhmm).split(':').map(Number);
  if (isNaN(h)) return hhmm;
  const suffix = h < 12 ? 'AM' : 'PM';
  const h12 = h % 12 === 0 ? 12 : h % 12;
  return m === 0 ? `${h12} ${suffix}` : `${h12}:${String(m).padStart(2, '0')} ${suffix}`;
}

/** Phrasing. Edit freely — placeholders in braces are filled from today's facts. */
const DEFAULT_TEMPLATES = {
  calendar_conflict: 'Two things clash at {time}',
  calendar_overload: '{count} events today — want them rearranged?',
  birthday_upcoming: "{name}'s birthday {relative}",
  birthday_upcoming_unnamed: 'A birthday {relative}',
  party_approaching: '{name} is {relative}',
  chores_unassigned: '{count} chores have nobody assigned',
  meal_unplanned: 'No {slot} planned yet',
  grocery_gap: 'Missing {items} for {meal}',
  streak_at_risk: '{name} streak is at {streak} days',
  grocery_ready: '{count} items on your grocery list',
  next_event: '{name} at {time}',
  streak_shield: '{name} streak is safe — you have a shield',
  party_menu_unplanned: "{name} is {relative} and the menu isn't planned",
  rsvp_pending: '{count} guests have not replied to {name}',
};

const fill = (template, vars) =>
  String(template).replace(/\{(\w+)\}/g, (_, k) => (vars[k] == null ? '' : String(vars[k])));

function make({ kind, entityId, localDate, icon, vars, cta, deeplink, webPath, feature, score, action }) {
  const template = DEFAULT_TEMPLATES[kind];
  return {
    id: `${kind}:${entityId}:${localDate}`,
    kind,
    icon,
    title: fill(template, vars),
    cta,
    deeplink,
    webPath,
    feature,
    score,
    // What tapping the CTA should DO, when it is more than navigation. Without
    // this the label promised something the row never performed — "Add to
    // list" merely opened a screen.
    ...(action ? { action } : {}),
  };
}

// ---------------------------------------------------------------------------
// Rules
// ---------------------------------------------------------------------------

/** Two events at the same time — the user probably knows, but confirming helps. */
function ruleCalendarConflict(ctx) {
  const events = (ctx.calendar?.events || [])
    .filter((e) => !e.allDay)
    .sort((a, b) => new Date(a.startUtc) - new Date(b.startUtc));

  for (let i = 1; i < events.length; i++) {
    if (new Date(events[i].startUtc) < new Date(events[i - 1].endUtc)) {
      return make({
        kind: 'calendar_conflict',
        entityId: String(events[i].externalId || i),
        localDate: ctx.localDate,
        icon: '⚠️',
        vars: { time: display(localTimeIn(new Date(events[i].startUtc), ctx.tz)) },
        cta: 'View day',
        deeplink: 'planbhai://planner',
        webPath: '/planner',
        feature: 'planner',
        score: 85,
      });
    }
  }
  return null;
}

function ruleCalendarOverload(ctx) {
  const count = (ctx.calendar?.events || []).filter((e) => !e.allDay).length;
  if (count < 5) return null;
  return make({
    kind: 'calendar_overload',
    entityId: 'today',
    localDate: ctx.localDate,
    icon: '🧠',
    vars: { count },
    cta: 'Rearrange',
    deeplink: 'planbhai://planner',
    webPath: '/planner',
    feature: 'planner',
    score: 70,
  });
}

function ruleBirthday(ctx) {
  const b = (ctx.birthdays || [])[0];
  if (!b) return null;

  // The calendar entry may just be titled "Birthday" with no name attached.
  // "Someone's birthday today" reads like the app lost the name; "A birthday
  // today" is simply what we know.
  const named = Boolean(String(b.name || '').trim());

  return make({
    kind: named ? 'birthday_upcoming' : 'birthday_upcoming_unnamed',
    entityId: b.date || 'bday',
    localDate: ctx.localDate,
    icon: '🎂',
    vars: { name: b.name, relative: b.relative },
    cta: 'Plan something',
    deeplink: 'planbhai://party',
    webPath: '/party',
    feature: 'party',
    score: b.relative === 'today' ? 95 : 75,
  });
}

/** A party within 10 days with nothing prepared yet. */
function ruleParty(ctx) {
  const soon = (ctx.upcoming || []).find((u) => {
    if (u.kind !== 'party') return false;
    const d = daysBetween(ctx.localDate, u.date);
    return d >= 0 && d <= 10;
  });
  if (!soon) return null;

  const d = daysBetween(ctx.localDate, soon.date);
  return make({
    kind: 'party_approaching',
    entityId: soon.date,
    localDate: ctx.localDate,
    icon: '🎉',
    vars: {
      name: soon.title,
      relative: d === 0 ? 'today' : d === 1 ? 'tomorrow' : `in ${d} days`,
    },
    cta: 'Open planner',
    deeplink: 'planbhai://party',
    webPath: '/party',
    feature: 'party',
    score: d <= 2 ? 88 : 60,
  });
}

/**
 * Chores nobody has picked up. Only fires when the household actually uses
 * assignment — a shared list nobody is named on is a normal way to work, and
 * nagging about it would be noise.
 */
function ruleChoresUnassigned(ctx) {
  const obligations = ctx.family?.obligations || [];
  if (obligations.length === 0) return null;

  const assigned = obligations.filter((o) => o.assigneeId).length;
  if (assigned / obligations.length < 0.5) return null;

  const gap = obligations.length - assigned;
  if (gap === 0) return null;

  return make({
    kind: 'chores_unassigned',
    entityId: 'chores',
    localDate: ctx.localDate,
    icon: '🧹',
    vars: { count: gap },
    cta: 'Assign',
    deeplink: 'planbhai://household',
    webPath: '/household',
    feature: 'household',
    score: 65,
  });
}

/** No dinner planned, and it's late enough that it matters. */
function ruleMealUnplanned(ctx) {
  if (!ctx.meals?.used) return null;
  if (ctx.meals.planned) return null;
  if (localHourIn(new Date(ctx.nowUtc), ctx.tz) < 15) return null;

  return make({
    kind: 'meal_unplanned',
    entityId: ctx.meals.primarySlot || 'dinner',
    localDate: ctx.localDate,
    icon: '🍽',
    vars: { slot: ctx.meals.primarySlot || 'dinner' },
    cta: 'Plan it',
    deeplink: 'planbhai://meals',
    webPath: '/meals',
    feature: 'meals',
    score: 90,
  });
}

/**
 * Ingredients the meal needs that aren't on hand.
 *
 * Requires pantry data. Every account currently has an empty pantry, so this
 * never fires today — but it's the single highest-value suggestion in the
 * product, so the rule is here and ready rather than waiting on a rewrite.
 */
function ruleGroceryGap(ctx) {
  const missing = ctx.meals?.planned?.missing || [];
  if (missing.length === 0) return null;

  return make({
    kind: 'grocery_gap',
    entityId: 'dinner',
    localDate: ctx.localDate,
    icon: '🛒',
    vars: {
      items: missing.slice(0, 3).join(', '),
      meal: ctx.meals.planned.title,
    },
    cta: 'Add to list',
    deeplink: 'planbhai://grocery',
    // /grocery is not a route on web — groceries live under /meals.
    webPath: '/meals',
    feature: 'grocery',
    score: 92,
    // The rule already knows exactly which items are missing, so the CTA can
    // genuinely add them rather than opening a screen and hoping.
    action: { type: 'add_groceries', items: missing.slice(0, 10) },
  });
}

/** A streak worth protecting, not yet done today. */
function ruleStreakAtRisk(ctx) {
  const at = (ctx.habits?.all || [])
    // Shielded habits are handled by ruleStreakShield. Firing both would tell
    // the user their streak is safe AND at risk about the same habit.
    .filter((h) => !h.completedToday && (h.streak || 0) >= 3 && (h.streakShields || 0) === 0)
    .sort((a, b) => (b.streak || 0) - (a.streak || 0))[0];
  if (!at) return null;

  // Only nudge in the evening. Reminding someone at 8 AM that they haven't done
  // a habit yet is nagging, not helping.
  if (localHourIn(new Date(ctx.nowUtc), ctx.tz) < 17) return null;

  return make({
    kind: 'streak_at_risk',
    entityId: at.name,
    localDate: ctx.localDate,
    icon: '🔥',
    vars: { name: at.name, streak: at.streak },
    cta: 'Mark done',
    deeplink: 'planbhai://habits',
    webPath: '/habits',
    feature: 'habits',
    score: 80,
  });
}

/** The next thing happening, when it's close. */
function ruleNextEvent(ctx) {
  const now = new Date(ctx.nowUtc);
  const next = (ctx.calendar?.events || [])
    .filter((e) => !e.allDay && new Date(e.startUtc) > now)
    .sort((a, b) => new Date(a.startUtc) - new Date(b.startUtc))[0];
  if (!next) return null;

  const minsAway = (new Date(next.startUtc) - now) / 60000;
  if (minsAway > 120) return null;

  return make({
    kind: 'next_event',
    entityId: String(next.externalId || 'next'),
    localDate: ctx.localDate,
    icon: '⏰',
    vars: { name: next.title, time: display(localTimeIn(new Date(next.startUtc), ctx.tz)) },
    cta: 'View',
    deeplink: 'planbhai://planner',
    webPath: '/planner',
    feature: 'planner',
    score: 98,
  });
}

/**
 * A streak that would break today, protected by a shield.
 *
 * Ported from the old dashboard's aiAndRemindersCard — the rules engine had no
 * idea shields existed. Only the habit tracker writes streakShields, so this
 * stays quiet for habits saved in the older shape rather than implying everyone
 * has one.
 */
function ruleStreakShield(ctx) {
  const shielded = (ctx.habits?.all || [])
    .filter((h) => !h.completedToday && (h.streakShields || 0) > 0 && (h.streak || 0) >= 1)
    .sort((a, b) => (b.streak || 0) - (a.streak || 0))[0];
  if (!shielded) return null;

  // Same evening-only guard as the plain streak nudge.
  if (localHourIn(new Date(ctx.nowUtc), ctx.tz) < 17) return null;

  return make({
    kind: 'streak_shield',
    entityId: shielded.name,
    localDate: ctx.localDate,
    icon: '🛡',
    vars: { name: shielded.name },
    cta: 'Mark done',
    deeplink: 'planbhai://habits',
    webPath: '/habits',
    feature: 'habits',
    score: 82,
  });
}

/**
 * A named party within 5 days whose menu isn't planned.
 *
 * Silent when the party state is contested — party_event is user-keyed and
 * several members can hold their own. Telling someone the menu isn't ready when
 * another member already planned it is worse than saying nothing.
 */
function rulePartyMenuUnplanned(ctx) {
  const p = ctx.party;
  if (!p || !p.active || p.contested) return null;
  if (p.menuPlanned || p.menuItemCount > 0) return null;
  if (!p.dateUtc) return null;

  const days = Math.floor((new Date(p.dateUtc) - new Date(ctx.nowUtc)) / 86400000);
  if (days < 0 || days > 5) return null;

  return make({
    kind: 'party_menu_unplanned',
    entityId: p.name,
    localDate: ctx.localDate,
    icon: '🍲',
    vars: {
      name: p.name,
      relative: days === 0 ? 'today' : days === 1 ? 'tomorrow' : `in ${days} days`,
    },
    cta: 'Plan menu',
    deeplink: 'planbhai://party',
    webPath: '/party',
    feature: 'party',
    score: days <= 1 ? 94 : 86,
  });
}

/** Guests who haven't replied, while there's still time to chase them. */
function ruleRsvpPending(ctx) {
  const p = ctx.party;
  if (!p || !p.active || p.contested) return null;
  if (p.pendingCount === 0) return null;
  if (!p.dateUtc) return null;

  const days = Math.floor((new Date(p.dateUtc) - new Date(ctx.nowUtc)) / 86400000);
  if (days < 0 || days > 10) return null;

  return make({
    kind: 'rsvp_pending',
    entityId: `${p.name}:rsvp`,
    localDate: ctx.localDate,
    icon: '👥',
    vars: { count: p.pendingCount, name: p.name },
    cta: 'Chase',
    deeplink: 'planbhai://party',
    webPath: '/party',
    feature: 'party',
    score: days <= 3 ? 84 : 62,
  });
}

// ---------------------------------------------------------------------------

const RULES = [
  ruleNextEvent,
  rulePartyMenuUnplanned,
  ruleGroceryGap,
  ruleBirthday,
  ruleMealIfUnplanned,
  ruleRsvpPending,
  ruleStreakShield,
  ruleCalendarConflict,
  ruleParty,
  ruleStreakAtRisk,
  ruleCalendarOverload,
  ruleChoresUnassigned,
];

// Named separately so the array above reads in priority order.
function ruleMealIfUnplanned(ctx) {
  return ruleMealUnplanned(ctx);
}

/** Every suggestion that applies today, unranked. */
function buildCandidates(ctx) {
  const out = [];
  for (const rule of RULES) {
    try {
      const s = rule(ctx);
      if (s) out.push(s);
    } catch (err) {
      console.error(`[suggestions] rule failed:`, err.message);
    }
  }
  return out;
}

/**
 * Picks the top 3.
 *
 * @param {Array}  candidates
 * @param {Array}  rankOrder  optional list of suggestion ids, best first
 *
 * Three is a deliberate cap. A wall of suggestions is a task list wearing a
 * different hat, and the whole point is that the app already handled things.
 *
 * rankOrder is unused today — scores decide. It exists so an ordering can be
 * supplied later without touching the rules, and it ignores any id that isn't
 * in today's candidates.
 */
function selectTop(candidates, rankOrder = null, limit = 3) {
  if (!Array.isArray(rankOrder) || rankOrder.length === 0) {
    return [...candidates].sort((a, b) => b.score - a.score).slice(0, limit);
  }

  const byId = new Map(candidates.map((c) => [c.id, c]));
  const picked = [];
  const seen = new Set();

  for (const id of rankOrder) {
    const c = byId.get(id);
    if (c && !seen.has(id)) {
      picked.push(c);
      seen.add(id);
    }
    if (picked.length >= limit) break;
  }

  if (picked.length < limit) {
    const rest = candidates
      .filter((c) => !seen.has(c.id))
      .sort((a, b) => b.score - a.score);
    picked.push(...rest.slice(0, limit - picked.length));
  }

  return picked;
}

/** Convenience wrapper: build then select. */
function buildSuggestions(ctx, rankOrder = null) {
  return selectTop(buildCandidates(ctx), rankOrder);
}

module.exports = { buildSuggestions, buildCandidates, selectTop, DEFAULT_TEMPLATES, fill };
PLANBHAI_EOF
write 'backend/routes/suggestionAction.routes.js' << 'PLANBHAI_EOF'
const express = require('express');
const AppData = require('../models/AppData');
const { bustDayBrief } = require('../services/daybrief/daybrief.service');
const { randomUUID } = require('crypto');

const router = express.Router();

// >>> EDIT if your middleware is named differently.
const requireAuth = require('../middleware/requireAuth');
const requireHouseholdMember = require('../middleware/requireHouseholdMember');

/**
 * Performs a suggestion's action.
 *
 * Suggestions carried a CTA like "Add to list" but only ever navigated — the
 * label promised something the row never did. Rules that CAN act now carry an
 * `action` payload, and this executes it.
 *
 * Only grocery_gap has one today. The other eleven navigate, which is correct
 * for them: "Open planner" should open the planner.
 */

/** Mirrors the matcher used for the pantry diff, so "have" and "need" agree. */
function itemsMatch(a, b) {
  const x = String(a || '').toLowerCase().trim();
  const y = String(b || '').toLowerCase().trim();
  if (!x || !y) return false;
  if (x.length < 3 || y.length < 3) return x === y;
  return x.includes(y) || y.includes(x);
}

/** POST /api/suggestions/action  { type, items } */
router.post('/action', requireAuth, requireHouseholdMember, async (req, res) => {
  const { type, items } = req.body || {};

  if (type !== 'add_groceries') {
    return res.status(400).json({ success: false, message: 'Unknown action' });
  }
  if (!Array.isArray(items) || items.length === 0) {
    return res.status(400).json({ success: false, message: 'No items to add' });
  }

  try {
    const scopeId = String(req.scopeId);
    const row = await AppData.findOne({ userId: scopeId, type: 'groceries' }).lean();
    const groceries = Array.isArray(row && row.data) ? [...row.data] : [];

    // Skip anything already on the list, checked or not. Adding a second
    // "Milk" because the first is ticked would be worse than doing nothing.
    let added = 0;
    for (const name of items.slice(0, 20)) {
      const clean = String(name || '').trim();
      if (!clean) continue;
      if (groceries.some((g) => itemsMatch(g.item, clean))) continue;

      groceries.push({
        id: randomUUID().toUpperCase(),
        item: clean,
        quantity: '1',
        category: 'Other',
        estimatedPrice: null,
        checked: false,
      });
      added += 1;
    }

    if (added > 0) {
      await AppData.findOneAndUpdate(
        { userId: scopeId, type: 'groceries' },
        { userId: scopeId, type: 'groceries', data: groceries },
        { upsert: true }
      );
      // The brief caches the grocery count and the gap suggestion; without this
      // the row would still be there on the next load.
      await bustDayBrief(req.scopeId).catch(() => {});
    }

    res.json({
      success: true,
      added,
      skipped: items.length - added,
      total: groceries.length,
    });
  } catch (err) {
    console.error('[suggestions/action]', err);
    res.status(500).json({ success: false, message: 'Could not add those items' });
  }
});

module.exports = router;
PLANBHAI_EOF

node --check backend/services/daybrief/suggestions.service.js || exit 1
node --check backend/routes/suggestionAction.routes.js || exit 1
echo "   both parse"
echo

echo "2. Mounting"
if grep -q "suggestionAction.routes" backend/server.js; then
  echo "   already mounted"
else
  cp backend/server.js backend/server.js.bakaction
  python3 - backend/server.js << 'PY_EOF'
import sys, re
p = sys.argv[1]
s = open(p).read()
m = None
for m in re.finditer(r"app\.use\(\s*['\"]/api[^\n]*\n", s): pass
if not m:
    print("   ERROR: no /api mounts found"); sys.exit(2)
s = s[:m.end()] + "app.use('/api/suggestions', require('./routes/suggestionAction.routes'));\n" + s[m.end():]
open(p, "w").write(s)
print("   added /api/suggestions")
PY_EOF
  [ $? -ne 0 ] && { cp backend/server.js.bakaction backend/server.js; exit 1; }
  node --check backend/server.js && echo "   server.js parses"
fi
echo

echo "3. Web"
write 'web/src/pages/Brief.jsx' << 'PLANBHAI_EOF'
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

export default function Brief({ embedded = false }) {
  const { scopeId } = useHousehold();
  const { user } = useAuth();

  const [brief, setBrief] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showBreakdown, setShowBreakdown] = useState(false);
  const [pending, setPending] = useState(null);   // habit name mid-request
  const [acting, setActing] = useState(null);     // suggestion id mid-request

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

if grep -q "runSuggestionAction" web/src/api.js; then
  echo "   api method already present"
else
  cp web/src/api.js web/src/api.js.bakaction
  python3 - web/src/api.js << 'PY_EOF'
import sys
p = sys.argv[1]
s = open(p).read()
anchor = "  // ---- Auth ----"
if anchor not in s:
    print("   ERROR: Auth section not found"); sys.exit(2)
add = """  // ---- Suggestions ----
  runSuggestionAction: (scopeId, action) =>
    request(`/api/suggestions/action?scopeId=${scopeId}`, { method: 'POST', auth: true, body: action }),

"""
s = s.replace(anchor, add + anchor, 1)
open(p, "w").write(s)
print("   added api.runSuggestionAction")
PY_EOF
  [ $? -ne 0 ] && { cp web/src/api.js.bakaction web/src/api.js; exit 1; }
fi

cp web/src/styles.css web/src/styles.css.bakaction
python3 - web/src/styles.css << 'PY_EOF'
import sys
p = sys.argv[1]
s = open(p).read()
i = s.find("\n/* ---------- Home hero ---------- */")
if i == -1:
    print("   ERROR: hero style block not found"); sys.exit(2)
open(p, "w").write(s[:i])
PY_EOF
[ $? -ne 0 ] && { cp web/src/styles.css.bakaction web/src/styles.css; exit 1; }
cat >> web/src/styles.css << 'PLANBHAI_EOF'

/* ---------- Home hero ---------- */

.hero-date {
  font-size: 11px; font-weight: 500; letter-spacing: 0.09em;
  text-transform: uppercase; opacity: 0.6;
}
.hero-name { font-size: 24px; font-weight: 500; margin-top: 4px; }

.hero-status { display: flex; align-items: center; gap: 16px; margin-top: 18px; }

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
PLANBHAI_EOF
echo "   styles updated"
echo

echo "4. Clearing the cached brief"
cd backend
cat > ./.pb_bust.js << 'BUST_EOF'
require("dotenv").config();
const m = require("mongoose");
(async () => {
  await m.connect(process.env.MONGODB_URI);
  const r = await require("./models/DayBrief").deleteMany({});
  console.log("   cleared " + r.deletedCount);
  await m.disconnect();
})().catch(e => { console.error("   " + e.message); process.exit(0); });
BUST_EOF
node ./.pb_bust.js
rm -f ./.pb_bust.js
cd ..
echo

echo "5. Building web"
(cd web && npm run build 2>&1 | grep -E "ERROR|error during|✓ built" | head -6)
echo

echo "=========================================="
echo "  Deploy BOTH — the endpoint is new:"
echo "     git add -A && git commit -m 'Suggestion CTAs perform their action' && git push"
echo "     (Render: Manual Deploy)   then   cd web && vercel --prod"
echo
echo "  Then tap \"Add to list\" — the items land on your grocery list, the"
echo "  suggestion disappears, and the meal coverage bar moves."
echo "=========================================="

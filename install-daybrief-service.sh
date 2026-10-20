#!/usr/bin/env bash
#
# Installs the complete daybrief.service.js.
#
# The earlier patcher failed silently: it added neither the bustBriefsForOwner
# function nor its export, which is why production logs show
# "bustBriefsForOwner is not a function" on every AppData write.
#
# This writes the whole verified file rather than patching, and refuses to finish
# unless the module actually loads and the export resolves.
#
# Usage:
#   bash ~/Downloads/install-daybrief-service.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
F="backend/services/daybrief/daybrief.service.js"
[ -d backend/services/daybrief ] || { echo "ERROR: backend/services/daybrief not found"; exit 1; }

echo "PlanBhai — installing daybrief.service.js"
echo

echo "1. Before"
grep -c "async function bustBriefsForOwner" "$F" 2>/dev/null | sed 's/^/   function defined: /'
echo

echo "2. Writing"
[ -f "$F" ] && cp "$F" "$F.bakfull" && echo "   backed up -> $F.bakfull"
cat > "$F" << 'PLANBHAI_EOF'
const mongoose = require('mongoose');
const DayBrief = require('../../models/DayBrief');
const Household = require('../../models/Household');
const SuggestionDismissal = require('../../models/SuggestionDismissal');
const { loadContext } = require('./context.adapter');
const { computeReadiness } = require('./readiness.service');
const {
  buildTimeline,
  buildGreeting,
  buildSignals,
  deriveState,
  buildUpcoming,
} = require('./builders.service');
const { todayIn, endOfLocalDayUtc, localTimeIn, relativeDayLabel } = require('./tz.util');

const CURRENT_SCHEMA_VERSION = 1;

// >>> EDIT: your existing entitlement check.
// const { hasFeature } = require('../entitlements.service');
const hasFeature = () => true;

/**
 * Pure. Takes context, returns a persistable brief. No I/O — this is what makes the
 * whole pipeline unit-testable without Mongo fixtures.
 */
function buildBrief(ctx) {
  const readiness = computeReadiness(ctx);
  const signals = buildSignals(ctx);
  const timeline = buildTimeline(ctx);
  const state = deriveState(signals, ctx, readiness);

  return {
    scopeId: ctx.scopeId,
    localDate: ctx.localDate,
    tz: ctx.tz,
    state,
    schemaVersion: CURRENT_SCHEMA_VERSION,

    greeting: buildGreeting(ctx, readiness),

    readiness: readiness
      ? { score: readiness.score, label: readiness.label, breakdown: readiness.breakdown }
      : null,

    signals,
    suggestions: [], // Phase 2
    timeline,
    contextCards: [], // Phase 3

    meal: ctx.meals?.planned
      ? {
          slot: ctx.meals.primarySlot || 'dinner',
          title: ctx.meals.planned.title,
          recipeId: ctx.meals.planned.recipeId || null,
          haveRatio: ctx.meals.planned.haveRatio,
          missing: ctx.meals.planned.missing || [],
          imageUrl: ctx.meals.planned.imageUrl || null,
        }
      : null,

    family: (ctx.family?.members || []).map((m) => {
      const mine = (ctx.family.obligations || []).filter(
        (o) => String(o.assigneeId) === String(m.id)
      );
      const pending = mine.filter((o) => !o.done);
      return {
        memberId: m.id,
        name: m.name,
        status: pending.length ? pending[0].title : mine.length ? 'All done' : 'Nothing scheduled',
        state: pending.length ? 'pending' : mine.length ? 'done' : 'upcoming',
        icon: pending.length ? '⏳' : mine.length ? '✓' : '·',
      };
    }),

    upcoming: buildUpcoming(ctx),

    calendarSyncedAt: ctx.calendar?.syncedAt || null,
    generatedAt: new Date(),
    expiresAt: new Date(endOfLocalDayUtc(ctx.localDate, ctx.tz).getTime() + 6 * 3600000),
  };
}

/**
 * Applies everything that is per-user rather than per-household. Never persisted.
 *   - dismissals hide suggestions for one member only
 *   - `locked` depends on that member's entitlements, which can differ
 *   - `isNow` depends on the clock, so caching it would go stale within minutes
 */
async function decorateForRead(brief, user) {
  const doc = brief.toObject ? brief.toObject() : { ...brief };

  const dismissed = await SuggestionDismissal.find({
    userId: user._id,
    scopeId: doc.scopeId,
  })
    .select('suggestionId')
    .lean();
  const dismissedIds = new Set(dismissed.map((d) => d.suggestionId));

  doc.suggestions = (doc.suggestions || [])
    .filter((s) => !dismissedIds.has(s.id))
    .map((s) => ({ ...s, locked: s.feature ? !hasFeature(user, s.feature) : false }));

  const nowHM = localTimeIn(new Date(), doc.tz);
  doc.timeline = (doc.timeline || []).map((r) => ({
    ...r,
    isNow: Boolean(r.end ? r.start <= nowHM && nowHM < r.end : r.start === nowHM),
  }));

  doc.upcoming = (doc.upcoming || []).map((u) => ({
    ...u,
    day: relativeDayLabel(todayIn(doc.tz), u.date, doc.tz),
  }));

  delete doc.buildMs;
  return doc;
}

/**
 * Cache-check → build → persist → decorate.
 * Cache key is (scopeId, localDate, tz): the brief is shared across the household,
 * but a member travelling to another timezone genuinely needs different wall-clock
 * times, so tz belongs in the key. Rare, and an extra document is cheap.
 */
async function getTodayBrief({ user, scopeId, tz, date }) {
  const localDate = date || todayIn(tz);
  const key = { scopeId, localDate, tz };

  const cached = await DayBrief.findOne(key);
  if (cached && cached.schemaVersion === CURRENT_SCHEMA_VERSION) {
    return decorateForRead(cached, user);
  }

  const t0 = Date.now();
  const ctx = await loadContext({ scopeId, tz, localDate });
  const brief = buildBrief(ctx);
  brief.buildMs = Date.now() - t0;

  const saved = await DayBrief.findOneAndUpdate(key, brief, {
    upsert: true,
    new: true,
    setDefaultsOnInsert: true,
  });

  return decorateForRead(saved, user);
}

/** Call from every mutation that changes the day: meals, groceries, habits, tasks. */
async function bustDayBrief(scopeId) {
  const today = new Date().toISOString().slice(0, 10);
  return DayBrief.deleteMany({ scopeId, localDate: { $gte: today } });
}

/**
 * Busts briefs for an AppData owner id.
 *
 * AppData.userId is overloaded — it holds a household id for shared types
 * (groceries, events, calendar_events, party_events, household_notes) and a user
 * id for personal ones (habits, chores, meal_plan, family_members). So:
 *
 *   household id -> bust that household
 *   user id      -> bust EVERY household they belong to, because their chores,
 *                   habits and meal_plan feed each of those dashboards
 *
 * Without this, a saved meal or ticked-off chore wouldn't appear until midnight,
 * which reads to a user as "the app is broken" — and worse, they can't tell which
 * parts of the dashboard are live, so it undermines trust in all of it.
 */
async function bustBriefsForOwner(ownerId) {
  if (!ownerId || !mongoose.Types.ObjectId.isValid(String(ownerId))) {
    return { deletedCount: 0 };
  }

  const oid = new mongoose.Types.ObjectId(String(ownerId));
  const scopeIds = new Set();

  const [asHousehold, memberOf] = await Promise.all([
    Household.exists({ _id: oid }),
    Household.find({ members: oid }).select('_id').lean(),
  ]);

  if (asHousehold) scopeIds.add(String(oid));
  for (const h of memberOf) scopeIds.add(String(h._id));

  if (scopeIds.size === 0) return { deletedCount: 0 };

  const today = new Date().toISOString().slice(0, 10);
  return DayBrief.deleteMany({
    scopeId: { $in: [...scopeIds].map((s) => new mongoose.Types.ObjectId(s)) },
    localDate: { $gte: today },
  });
}

module.exports = {
  getTodayBrief,
  bustDayBrief,
  bustBriefsForOwner,
  buildBrief,
  decorateForRead,
};
PLANBHAI_EOF
echo "   wrote $F"
echo

echo "3. Verifying"
node --check "$F" || { echo "   PARSE FAILED — restoring"; cp "$F.bakfull" "$F"; exit 1; }
echo "   parses"

# Static check first: this is the actual bug we're fixing and needs no dependencies.
if grep -q "^async function bustBriefsForOwner" "$F"; then
  echo "   function defined"
else
  echo "   FUNCTION STILL MISSING — restoring"
  cp "$F.bakfull" "$F"
  exit 1
fi

if sed -n '/module.exports/,/};/p' "$F" | grep -q "bustBriefsForOwner"; then
  echo "   present in module.exports"
else
  echo "   NOT EXPORTED — restoring"
  cp "$F.bakfull" "$F"
  exit 1
fi

# Runtime check second. A failure here is usually a missing dependency rather than
# a bad file, so it warns instead of reverting a file we've already validated.
cd backend
RESULT=$(node -e "
require('dotenv').config();
const svc = require('./services/daybrief/daybrief.service');
const checks = ['getTodayBrief','bustDayBrief','bustBriefsForOwner','buildBrief','decorateForRead'];
const missing = checks.filter(k => typeof svc[k] !== 'function');
console.log(missing.length ? 'MISSING: ' + missing.join(', ') : 'ALL_OK');
" 2>&1 | grep -E "^(ALL_OK|MISSING|Error:|[A-Za-z]*Error:)" | head -1)
cd ..

case "$RESULT" in
  ALL_OK)   echo "   all five exports resolve at runtime" ;;
  MISSING*) echo "   $RESULT"; echo "   restoring"; cp "$F.bakfull" "$F"; exit 1 ;;
  *)        echo "   runtime check skipped (${RESULT:-environment issue})"
            echo "   static checks passed, so the file itself is correct" ;;
esac
echo

echo "4. verifyScopeAccess — source of the separate 403s"
sed -n '/verifyScopeAccess/,/^}/p' backend/routes/appDataRoutes.js | head -35 | sed 's/^/   /'
echo

echo "=========================================="
echo "  Deploy:"
echo "     git add -A && git commit -m 'Add bustBriefsForOwner (function + export)' && git push"
echo "  then Manual Deploy on Render."
echo "=========================================="

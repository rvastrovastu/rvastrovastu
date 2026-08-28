#!/usr/bin/env bash
#
# PlanBhai Phase 0 installer.
# Writes every DayBrief file into the repo. Safe to re-run: existing files are
# backed up to <name>.bak before being overwritten.
#
# Usage:
#   bash ~/Downloads/install-phase0.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -euo pipefail

ROOT="${1:-$(pwd)}"

if [ ! -d "$ROOT/backend" ]; then
  echo "ERROR: no backend/ directory under $ROOT"
  echo "Pass your repo root as the first argument."
  exit 1
fi

cd "$ROOT"
echo "Installing into $ROOT"
echo

# Remove the empty server/ tree created by the earlier mis-step, but only if
# it is genuinely empty -- never delete real work.
if [ -d "server" ]; then
  if [ -z "$(find server -type f 2>/dev/null)" ]; then
    rm -rf server
    echo "  removed empty server/ (created by mistake earlier)"
  else
    echo "  NOTE: server/ contains files; leaving it alone. Check it manually."
  fi
fi

mkdir -p backend/models backend/routes backend/services/daybrief backend/middleware
mkdir -p PlanBhai/Services

write() {
  local dest="$1"
  if [ -f "$dest" ]; then
    cp "$dest" "$dest.bak"
    echo "  backed up $dest -> $dest.bak"
  fi
  cat > "$dest"
  echo "  wrote $dest"
}

write 'backend/models/DayBrief.js' << 'PLANBHAI_EOF'
const mongoose = require('mongoose');

const CURRENT_SCHEMA_VERSION = 1;

/**
 * One cached dashboard brief per (scopeId, localDate, tz).
 *
 * HOUSEHOLD-SCOPED. Nothing in this document may contain a specific person's name
 * or personal state — every member of the household reads the same doc. Per-person
 * concerns are applied at read time in decorateForRead():
 *   - the greeting name is composed client-side from the session
 *   - suggestion dismissals come from the SuggestionDismissal collection
 *   - `locked` is computed per-user via hasFeature()
 */

const BreakdownSchema = new mongoose.Schema(
  {
    domain: {
      type: String,
      enum: ['calendar', 'meals', 'groceries', 'family', 'habits', 'finance'],
      required: true,
    },
    score: { type: Number, min: 0, max: 100, required: true },
    weight: { type: Number, min: 0, max: 1, required: true },
    applicable: { type: Boolean, required: true },
    reason: { type: String, default: '' },
  },
  { _id: false }
);

const SignalSchema = new mongoose.Schema(
  {
    icon: String,
    text: { type: String, maxlength: 40 },
    kind: String,
    priority: { type: Number, default: 50 },
  },
  { _id: false }
);

const SuggestionSchema = new mongoose.Schema(
  {
    id: { type: String, required: true }, // `${kind}:${entityId}:${localDate}`
    kind: { type: String, required: true },
    icon: String,
    title: String,
    subtitle: String,
    cta: String,
    deeplink: String, // planbhai://...  (iOS)
    webPath: String, // /grocery?add=... (web — custom schemes don't work)
    feature: String, // hasFeature() key; `locked` is resolved per-user at read time
    score: { type: Number, default: 0 },
  },
  { _id: false }
);

const TimelineRowSchema = new mongoose.Schema(
  {
    start: String, // 'HH:mm' local wall-clock
    end: String,
    title: String,
    kind: { type: String, enum: ['habit', 'event', 'meal', 'task', 'routine'] },
    source: { type: String, enum: ['planbhai', 'calendar'] },
    sourceId: String,
    icon: String,
    // isNow is NOT stored — computed in decorateForRead()
  },
  { _id: false }
);

const DayBriefSchema = new mongoose.Schema(
  {
    scopeId: { type: mongoose.Schema.Types.ObjectId, ref: 'Household', required: true },
    localDate: { type: String, required: true }, // 'YYYY-MM-DD' in requester's tz
    tz: { type: String, required: true },

    state: { type: String, enum: ['empty', 'sparse', 'rich'], required: true },
    schemaVersion: { type: Number, default: CURRENT_SCHEMA_VERSION },

    greeting: {
      timeOfDay: { type: String, enum: ['morning', 'afternoon', 'evening', 'night'] },
      line: { type: String, maxlength: 90 },
      generatedBy: { type: String, enum: ['rule', 'ai'], default: 'rule' },
    },

    readiness: {
      score: { type: Number, min: 0, max: 100 },
      label: String,
      breakdown: [BreakdownSchema],
    },

    signals: [SignalSchema],
    suggestions: [SuggestionSchema],
    timeline: [TimelineRowSchema],
    contextCards: [{ type: mongoose.Schema.Types.Mixed }], // Phase 3

    meal: { type: mongoose.Schema.Types.Mixed, default: null },
    family: [{ type: mongoose.Schema.Types.Mixed }],
    upcoming: [{ type: mongoose.Schema.Types.Mixed }],

    calendarSyncedAt: { type: Date, default: null }, // drives web's freshness line
    generatedAt: { type: Date, default: Date.now },
    expiresAt: { type: Date, required: true },
    buildMs: Number,
  },
  { timestamps: true }
);

DayBriefSchema.index({ scopeId: 1, localDate: 1, tz: 1 }, { unique: true });
DayBriefSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

module.exports = mongoose.model('DayBrief', DayBriefSchema);
module.exports.CURRENT_SCHEMA_VERSION = CURRENT_SCHEMA_VERSION;

PLANBHAI_EOF

write 'backend/models/ExternalEvent.js' << 'PLANBHAI_EOF'
const mongoose = require('mongoose');

/**
 * Calendar events synced from a device (currently EventKit on iOS).
 *
 * PRIVACY: this collection deliberately stores the minimum needed to render a
 * timeline. Do NOT add notes, attendees, location, URL, or attachments — that is
 * other people's data as much as the user's, and it expands our App Store privacy
 * disclosure obligations for no product benefit.
 *
 * RECURRING EVENTS: EKEvent.eventIdentifier is shared across every occurrence of a
 * recurring series. occurrenceDate is therefore part of the uniqueness key.
 */
const ExternalEventSchema = new mongoose.Schema(
  {
    scopeId: { type: mongoose.Schema.Types.ObjectId, ref: 'Household', required: true, index: true },
    ownerUserId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },

    provider: { type: String, enum: ['eventkit', 'google', 'microsoft'], default: 'eventkit' },
    externalId: { type: String, required: true },
    occurrenceDate: { type: String, required: true }, // 'YYYY-MM-DD' in the event's own tz

    title: { type: String, required: true, maxlength: 200 },
    startUtc: { type: Date, required: true },
    endUtc: { type: Date, required: true },
    sourceTz: { type: String, default: null },
    allDay: { type: Boolean, default: false },
    calendarName: { type: String, maxlength: 100, default: null },
  },
  { timestamps: true }
);

ExternalEventSchema.index(
  { scopeId: 1, provider: 1, externalId: 1, occurrenceDate: 1 },
  { unique: true }
);
ExternalEventSchema.index({ scopeId: 1, startUtc: 1 });
ExternalEventSchema.index({ ownerUserId: 1, provider: 1 });

module.exports = mongoose.model('ExternalEvent', ExternalEventSchema);

PLANBHAI_EOF

write 'backend/models/SuggestionDismissal.js' << 'PLANBHAI_EOF'
const mongoose = require('mongoose');

/**
 * Dismissing a suggestion is personal — if Ritesh dismisses "add tomatoes", it must
 * not vanish for Lata. The brief stays shared; this collection is the per-user
 * overlay applied at read time.
 */
const SuggestionDismissalSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    scopeId: { type: mongoose.Schema.Types.ObjectId, ref: 'Household', required: true },
    suggestionId: { type: String, required: true }, // `${kind}:${entityId}:${localDate}`
    dismissedAt: { type: Date, default: Date.now },
    expiresAt: { type: Date, required: true }, // end of that localDate + 2d
  },
  { timestamps: false }
);

SuggestionDismissalSchema.index({ userId: 1, suggestionId: 1 }, { unique: true });
SuggestionDismissalSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

module.exports = mongoose.model('SuggestionDismissal', SuggestionDismissalSchema);

PLANBHAI_EOF

write 'backend/services/mongo.util.js' << 'PLANBHAI_EOF'
const mongoose = require('mongoose');

/**
 * MongoDB transactions require a replica set or a sharded cluster. Atlas and
 * Render's managed Mongo both give you one; a plain local mongod does not.
 *
 * Rather than making local development depend on reconfiguring Mongo, we detect
 * the capability once and degrade to sequential writes when it's absent. In
 * production this is a no-op — you get real atomicity. Locally you get a working
 * dev loop and one honest warning at startup.
 */

let cached = null;

async function supportsTransactions() {
  if (cached !== null) return cached;

  try {
    const info = await mongoose.connection.db.admin().command({ hello: 1 });
    // setName => replica set member. isdbgrid => mongos in front of a sharded cluster.
    cached = Boolean(info.setName || info.msg === 'isdbgrid');
  } catch (err) {
    cached = false;
  }

  if (!cached) {
    console.warn(
      '[mongo] Standalone server detected — writes will run without transactions.\n' +
        '        Fine for local development. Production MUST run a replica set, or a\n' +
        '        sync that dies halfway will leave a household with a partially\n' +
        '        deleted calendar.'
    );
  }

  return cached;
}

/**
 * Runs `fn(session)` inside a transaction when the deployment supports one, and
 * plainly otherwise. `fn` must accept a session that may be null — mongoose treats
 * `{ session: null }` as "no session", so call sites need no branching.
 */
async function runAtomic(fn) {
  if (await supportsTransactions()) {
    const session = await mongoose.startSession();
    try {
      let result;
      await session.withTransaction(async () => {
        result = await fn(session);
      });
      return result;
    } finally {
      session.endSession();
    }
  }

  return fn(null);
}

/** Test hook — forces re-detection. */
function _reset() {
  cached = null;
}

module.exports = { runAtomic, supportsTransactions, _reset };

PLANBHAI_EOF

write 'backend/services/daybrief/tz.util.js' << 'PLANBHAI_EOF'
/**
 * Timezone helpers built on Intl so we don't add luxon/date-fns-tz as a dependency.
 * Everything here is pure and DST-correct, because Intl consults the real tz database
 * rather than applying a fixed UTC offset.
 */

/** 'YYYY-MM-DD' for a Date as seen in `tz`. */
function localDateIn(date, tz) {
  const f = new Intl.DateTimeFormat('en-CA', {
    timeZone: tz,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  return f.format(date); // en-CA yields YYYY-MM-DD natively
}

/** 'HH:mm' (24h) for a Date as seen in `tz`. */
function localTimeIn(date, tz) {
  const f = new Intl.DateTimeFormat('en-GB', {
    timeZone: tz,
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  });
  return f.format(date);
}

/** Local hour 0-23 in `tz`. */
function localHourIn(date, tz) {
  return parseInt(localTimeIn(date, tz).slice(0, 2), 10);
}

/** Today's date string in `tz`. */
function todayIn(tz, now = new Date()) {
  return localDateIn(now, tz);
}

/**
 * UTC Date for local midnight of `localDate` in `tz`.
 * Works by guessing then correcting against the actual offset — reliable across DST.
 */
function startOfLocalDayUtc(localDate, tz) {
  const [y, m, d] = localDate.split('-').map(Number);
  let guess = Date.UTC(y, m - 1, d, 0, 0, 0);
  for (let i = 0; i < 3; i++) {
    const asLocal = localDateIn(new Date(guess), tz);
    const hour = localHourIn(new Date(guess), tz);
    if (asLocal === localDate && hour === 0) break;
    const drift = (hour === 0 ? 0 : hour > 12 ? hour - 24 : hour) * 3600000;
    guess -= drift;
    if (localDateIn(new Date(guess), tz) !== localDate) {
      guess += (Date.parse(`${localDate}T00:00:00Z`) - Date.parse(`${asLocal}T00:00:00Z`));
    }
  }
  return new Date(guess);
}

/** End of local day (exclusive) = start of next local day. */
function endOfLocalDayUtc(localDate, tz) {
  const start = startOfLocalDayUtc(localDate, tz);
  return startOfLocalDayUtc(localDateIn(new Date(start.getTime() + 26 * 3600000), tz), tz);
}

/** Validate a tz string without throwing. */
function isValidTz(tz) {
  if (!tz || typeof tz !== 'string') return false;
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: tz }).format(new Date());
    return true;
  } catch {
    return false;
  }
}

/** Whole-day difference between two 'YYYY-MM-DD' strings. */
function daysBetween(fromDate, toDate) {
  return Math.round((Date.parse(`${toDate}T00:00:00Z`) - Date.parse(`${fromDate}T00:00:00Z`)) / 86400000);
}

/** 'Tomorrow' / 'Thursday' / 'Aug 4' relative to `fromDate`. */
function relativeDayLabel(fromDate, toDate, tz) {
  const diff = daysBetween(fromDate, toDate);
  if (diff === 0) return 'Today';
  if (diff === 1) return 'Tomorrow';
  const dt = startOfLocalDayUtc(toDate, tz);
  if (diff > 1 && diff <= 6) {
    return new Intl.DateTimeFormat('en-US', { timeZone: tz, weekday: 'long' }).format(dt);
  }
  return new Intl.DateTimeFormat('en-US', { timeZone: tz, month: 'short', day: 'numeric' }).format(dt);
}

module.exports = {
  localDateIn,
  localTimeIn,
  localHourIn,
  todayIn,
  startOfLocalDayUtc,
  endOfLocalDayUtc,
  isValidTz,
  daysBetween,
  relativeDayLabel,
};

PLANBHAI_EOF

write 'backend/services/daybrief/readiness.service.js' << 'PLANBHAI_EOF'
/**
 * Readiness scoring.
 *
 * Readiness measures how much of today is PLANNED AND COVERED — not how much is
 * done. That distinction is the whole point: a completion score reads ~0% at 7 AM,
 * which is the exact anxiety the dashboard exists to remove. Readiness legitimately
 * reads 92% before the user has done anything, because the day is handled.
 *
 * Every function here is pure. No mongoose, no I/O, no Date.now() except what is
 * passed in. That is what makes the formula testable without Mongo fixtures.
 *
 * Expected context shape (built by loadContext, see daybrief.service.js):
 * {
 *   nowUtc: Date,
 *   calendar: { connected, events: [{ startUtc, endUtc, title, allDay,
 *                                     requiresEscort, assigneeId }] },
 *   meals:    { used, primarySlot, planned: { title, haveRatio|null, missing[] }|null },
 *   groceries:{ listExists, missingCount },
 *   family:   { memberCount, obligations: [{ title, assigneeId|null }] },
 *   habits:   { active: [{ id, title, windowEndUtc, completedAt|null }] },
 *   finance:  { tracked, bills: [{ title, dueDate:'YYYY-MM-DD', paid }] },
 *   localDate: 'YYYY-MM-DD'
 * }
 */

const BASE_WEIGHTS = {
  calendar: 0.25,
  meals: 0.2,
  groceries: 0.15,
  family: 0.15,
  habits: 0.15,
  finance: 0.1,
};

const clamp = (n, lo = 0, hi = 100) => Math.max(lo, Math.min(hi, n));

// ---------------------------------------------------------------------------
// Domain scorers. Each returns { applicable, score, reason }.
// ---------------------------------------------------------------------------

function scoreCalendar(cal = {}) {
  const events = (cal.events || []).filter((e) => !e.allDay);
  const applicable = Boolean(cal.connected) || events.length > 0;
  if (!applicable) return { applicable: false, score: 0, reason: '' };

  let score = 100;
  const reasons = [];

  const sorted = [...events].sort((a, b) => new Date(a.startUtc) - new Date(b.startUtc));

  // Overlaps
  let hasOverlap = false;
  for (let i = 1; i < sorted.length; i++) {
    if (new Date(sorted[i].startUtc) < new Date(sorted[i - 1].endUtc)) {
      hasOverlap = true;
      break;
    }
  }
  if (hasOverlap) {
    score -= 25;
    reasons.push('two events overlap');
  }

  // Tight transitions (<15 min between back-to-back events), capped at -30
  let tight = 0;
  for (let i = 1; i < sorted.length; i++) {
    const gapMin = (new Date(sorted[i].startUtc) - new Date(sorted[i - 1].endUtc)) / 60000;
    if (gapMin >= 0 && gapMin < 15) tight++;
  }
  if (tight > 0) {
    score -= Math.min(30, tight * 15);
    reasons.push(`${tight} tight transition${tight > 1 ? 's' : ''}`);
  }

  // Escort-requiring events with nobody assigned
  const unassigned = events.filter((e) => e.requiresEscort && !e.assigneeId).length;
  if (unassigned > 0) {
    score -= 20;
    reasons.push(`${unassigned} pickup${unassigned > 1 ? 's' : ''} unassigned`);
  }

  // Overloaded day
  if (events.length > 5) {
    score -= 10;
    reasons.push(`${events.length} events today`);
  }

  return {
    applicable: true,
    score: clamp(score),
    reason: reasons.length ? capitalize(reasons.join(', ')) : 'Your schedule has room to breathe',
  };
}

function scoreMeals(meals = {}) {
  if (!meals.used) return { applicable: false, score: 0, reason: '' };

  const slot = meals.primarySlot || 'dinner';
  if (!meals.planned) {
    return { applicable: true, score: 0, reason: `No ${slot} planned yet` };
  }

  const { title, haveRatio } = meals.planned;

  if (haveRatio == null) {
    return { applicable: true, score: 60, reason: `${title} planned for ${slot}` };
  }

  const score = clamp(Math.round(60 + 40 * clamp(haveRatio, 0, 1)));
  const reason =
    haveRatio >= 1
      ? `${title} planned, everything on hand`
      : `${title} planned, ${Math.round((1 - haveRatio) * 100)}% of ingredients missing`;

  return { applicable: true, score, reason };
}

function scoreGroceries(groceries = {}) {
  if (!groceries.listExists) return { applicable: false, score: 0, reason: '' };

  const missing = groceries.missingCount || 0;
  if (missing === 0) {
    return { applicable: true, score: 100, reason: 'Nothing missing for today or tomorrow' };
  }

  return {
    applicable: true,
    score: clamp(100 - 12 * missing, 30, 100),
    reason: `${missing} item${missing > 1 ? 's' : ''} short for upcoming meals`,
  };
}

function scoreFamily(family = {}) {
  if ((family.memberCount || 0) <= 1) return { applicable: false, score: 0, reason: '' };

  const obligations = family.obligations || [];
  if (obligations.length === 0) {
    return { applicable: true, score: 100, reason: 'No handoffs needed today' };
  }

  const assigned = obligations.filter((o) => o.assigneeId).length;
  const score = clamp(Math.round((100 * assigned) / obligations.length));
  const gap = obligations.length - assigned;

  return {
    applicable: true,
    score,
    reason:
      gap === 0
        ? 'Everyone knows their part today'
        : `${gap} thing${gap > 1 ? 's' : ''} with nobody assigned`,
  };
}

function scoreHabits(habits = {}, nowUtc) {
  const active = habits.active || [];
  if (active.length === 0) return { applicable: false, score: 0, reason: '' };

  const now = new Date(nowUtc);
  const missed = active.filter(
    (h) => !h.completedAt && h.windowEndUtc && new Date(h.windowEndUtc) < now
  ).length;

  const score = clamp(100 - 20 * missed);
  return {
    applicable: true,
    score,
    reason:
      missed === 0
        ? 'Habits on track'
        : `${missed} habit${missed > 1 ? 's' : ''} past its window`,
  };
}

function scoreFinance(finance = {}, localDate) {
  if (!finance.tracked) return { applicable: false, score: 0, reason: '' };

  const unpaid = (finance.bills || []).filter((b) => !b.paid);
  if (unpaid.length === 0) return { applicable: true, score: 100, reason: 'No bills pending' };

  // daysUntil is a plain date diff — bills are date-granular, not time-granular
  const daysUntil = (d) => Math.round((Date.parse(d) - Date.parse(localDate)) / 86400000);
  const soonest = Math.min(...unpaid.map((b) => daysUntil(b.dueDate)));

  if (soonest < 0) return { applicable: true, score: 0, reason: 'A bill is overdue' };
  if (soonest === 0) return { applicable: true, score: 20, reason: 'A bill is due today' };
  if (soonest === 1) return { applicable: true, score: 40, reason: 'A bill is due tomorrow' };
  if (soonest <= 3) return { applicable: true, score: 70, reason: `A bill is due in ${soonest} days` };
  return { applicable: true, score: 100, reason: 'Nothing due this week' };
}

// ---------------------------------------------------------------------------
// Composite
// ---------------------------------------------------------------------------

const LABELS = [
  [95, 'Everything is under control.'],
  [80, "You're in good shape today."],
  [60, 'A few things need you.'],
  [40, 'Today needs some attention.'],
  [0, "Let's get today sorted."],
];

function labelFor(score) {
  return LABELS.find(([floor]) => score >= floor)[1];
}

/**
 * @returns {{ score, label, breakdown, weakest }} or null when no domain applies
 *          (a brand-new household — callers should render the empty state, not a 0%).
 */
function computeReadiness(ctx) {
  const raw = {
    calendar: scoreCalendar(ctx.calendar),
    meals: scoreMeals(ctx.meals),
    groceries: scoreGroceries(ctx.groceries),
    family: scoreFamily(ctx.family),
    habits: scoreHabits(ctx.habits, ctx.nowUtc),
    finance: scoreFinance(ctx.finance, ctx.localDate),
  };

  const applicable = Object.entries(raw).filter(([, v]) => v.applicable);

  // No applicable domains means we know nothing about this household yet. Returning
  // 0% here would be a lie dressed as data — the empty state is the honest answer.
  if (applicable.length === 0) return null;

  const totalWeight = applicable.reduce((s, [d]) => s + BASE_WEIGHTS[d], 0);

  // Re-normalizing over applicable domains only is what stops a new user from being
  // punished for simply not tracking bills.
  const breakdown = Object.entries(raw).map(([domain, v]) => ({
    domain,
    score: v.score,
    weight: v.applicable ? BASE_WEIGHTS[domain] / totalWeight : 0,
    applicable: v.applicable,
    reason: v.reason,
  }));

  const score = Math.round(
    breakdown.filter((b) => b.applicable).reduce((s, b) => s + b.score * b.weight, 0)
  );

  const weakest = breakdown
    .filter((b) => b.applicable)
    .sort((a, b) => a.score - b.score)[0];

  return { score, label: labelFor(score), breakdown, weakest };
}

function capitalize(s) {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

module.exports = {
  computeReadiness,
  labelFor,
  BASE_WEIGHTS,
  // exported for unit tests
  _scorers: { scoreCalendar, scoreMeals, scoreGroceries, scoreFamily, scoreHabits, scoreFinance },
};

PLANBHAI_EOF

write 'backend/services/daybrief/builders.service.js' << 'PLANBHAI_EOF'
const { localTimeIn, localHourIn, relativeDayLabel } = require('./tz.util');

/**
 * Merges every time-anchored thing in the day into one sorted list. Pure.
 * Calendar events, habits, meals and tasks all land in the same visual river —
 * that's what makes it read as "your day" rather than four separate widgets.
 */
function buildTimeline(ctx) {
  const { tz } = ctx;
  const rows = [];

  for (const e of ctx.calendar?.events || []) {
    if (e.allDay) continue;
    rows.push({
      start: localTimeIn(new Date(e.startUtc), tz),
      end: e.endUtc ? localTimeIn(new Date(e.endUtc), tz) : null,
      title: e.title,
      kind: 'event',
      source: 'calendar',
      sourceId: String(e.externalId || e._id || ''),
      icon: '📅',
      _sortUtc: new Date(e.startUtc).getTime(),
    });
  }

  for (const h of ctx.habits?.active || []) {
    if (!h.windowStartUtc) continue;
    rows.push({
      start: localTimeIn(new Date(h.windowStartUtc), tz),
      end: h.windowEndUtc ? localTimeIn(new Date(h.windowEndUtc), tz) : null,
      title: h.title,
      kind: 'habit',
      source: 'planbhai',
      sourceId: String(h.id || h._id || ''),
      icon: h.icon || '🔁',
      _sortUtc: new Date(h.windowStartUtc).getTime(),
    });
  }

  for (const m of ctx.meals?.slots || []) {
    if (!m.timeUtc) continue;
    rows.push({
      start: localTimeIn(new Date(m.timeUtc), tz),
      end: null,
      title: m.title,
      kind: 'meal',
      source: 'planbhai',
      sourceId: String(m.id || ''),
      icon: '🍽',
      _sortUtc: new Date(m.timeUtc).getTime(),
    });
  }

  for (const t of ctx.tasks?.scheduled || []) {
    if (!t.dueUtc) continue;
    rows.push({
      start: localTimeIn(new Date(t.dueUtc), tz),
      end: null,
      title: t.title,
      kind: 'task',
      source: 'planbhai',
      sourceId: String(t.id || t._id || ''),
      icon: '✓',
      _sortUtc: new Date(t.dueUtc).getTime(),
    });
  }

  return rows.sort((a, b) => a._sortUtc - b._sortUtc).map(({ _sortUtc, ...r }) => r);
}

// ---------------------------------------------------------------------------

/**
 * Greeting. NO PERSONAL NAMES — this document is shared across the household, so
 * the client composes `Good ${timeOfDay}, ${session.firstName}` locally.
 */
function buildGreeting(ctx, readiness) {
  const hour = localHourIn(new Date(ctx.nowUtc), ctx.tz);
  const timeOfDay =
    hour < 12 ? 'morning' : hour < 17 ? 'afternoon' : hour < 21 ? 'evening' : 'night';

  if (!readiness) {
    return { timeOfDay, line: "Let's get your day set up.", generatedBy: 'rule' };
  }

  const s = readiness.score;
  let line;
  if (s >= 95) line = 'Everything is handled. Nothing needs you right now.';
  else if (s >= 80) line = "Your day is set. A couple of small things to glance at.";
  else if (s >= 60) line = readiness.weakest?.reason || 'A few things need you today.';
  else line = readiness.weakest?.reason || "Let's get today sorted.";

  return { timeOfDay, line: line.slice(0, 90), generatedBy: 'rule' };
}

// ---------------------------------------------------------------------------

/** The 5-second scan chips. Client renders the top N by priority. */
function buildSignals(ctx) {
  const signals = [];
  const push = (icon, text, kind, priority) =>
    text && signals.push({ icon, text: String(text).slice(0, 40), kind, priority });

  if (ctx.weather?.summary) {
    push(ctx.weather.icon || '☀️', ctx.weather.summary, 'weather', 30);
  }

  const nextEvent = (ctx.calendar?.events || [])
    .filter((e) => !e.allDay && new Date(e.startUtc) > new Date(ctx.nowUtc))
    .sort((a, b) => new Date(a.startUtc) - new Date(b.startUtc))[0];
  if (nextEvent) {
    push('📅', `${nextEvent.title} at ${localTimeIn(new Date(nextEvent.startUtc), ctx.tz)}`, 'event', 90);
  }

  for (const b of ctx.birthdays || []) {
    push('🎂', `${b.name}'s birthday ${b.relative}`, 'birthday', 70);
  }

  if (ctx.habits?.longestStreak > 2) {
    push('🔥', `Habit streak ${ctx.habits.longestStreak} days`, 'streak', 40);
  }

  const dueSoon = (ctx.finance?.bills || []).filter((b) => !b.paid);
  if (dueSoon.length) {
    push('💰', `${dueSoon.length} bill${dueSoon.length > 1 ? 's' : ''} due soon`, 'bill', 60);
  }

  if (ctx.groceries?.missingCount > 0) {
    push('🛒', `${ctx.groceries.missingCount} groceries running low`, 'grocery', 50);
  }

  if (ctx.meals?.planned?.title) {
    push('🍽', `${ctx.meals.planned.title} tonight`, 'meal', 55);
  }

  return signals.sort((a, b) => b.priority - a.priority);
}

// ---------------------------------------------------------------------------

/**
 * empty / sparse / rich.
 *
 * Weather is excluded deliberately: it's available for every household on earth,
 * so counting it would make a brand-new user look "sparse" when we actually know
 * nothing about them. Faking richness is worse than asking for setup.
 */
function deriveState(signals, ctx) {
  const real = signals.filter((s) => s.kind !== 'weather').length;
  const hasTimeline = (ctx.calendar?.events?.length || 0) + (ctx.habits?.active?.length || 0) > 0;

  if (real === 0 && !hasTimeline) return 'empty';
  if (real <= 3) return 'sparse';
  return 'rich';
}

// ---------------------------------------------------------------------------

/** 'Tomorrow — Dentist' rows for the Upcoming section. */
function buildUpcoming(ctx) {
  return (ctx.upcoming || [])
    .slice(0, 6)
    .map((u) => ({
      day: relativeDayLabel(ctx.localDate, u.date, ctx.tz),
      date: u.date,
      title: u.title,
      kind: u.kind || 'event',
      icon: u.icon || '📌',
    }));
}

module.exports = { buildTimeline, buildGreeting, buildSignals, deriveState, buildUpcoming };

PLANBHAI_EOF

write 'backend/services/daybrief/context.adapter.js' << 'PLANBHAI_EOF'
/**
 * ============================================================================
 *  THIS IS THE ONLY FILE YOU EDIT TO CONNECT PHASE 0 TO YOUR EXISTING MODELS.
 * ============================================================================
 *
 * Everything downstream (readiness, timeline, signals, state) is pure and already
 * finished. Its job is to turn whatever your schemas actually look like into one
 * normalized `ctx` object.
 *
 * Each loader below is independent and fails soft: if one throws, you lose that
 * domain's contribution and nothing else. That matters because a dashboard that
 * 500s because the bills collection hiccuped is worse than one missing a bill chip.
 *
 * Search for  >>> EDIT  to find every spot needing your field names.
 */

const ExternalEvent = require('../../models/ExternalEvent');
const { startOfLocalDayUtc, endOfLocalDayUtc, localDateIn } = require('./tz.util');

// >>> EDIT: point these at your real models.
// const MealPlan     = require('../../models/MealPlan');
// const GroceryList  = require('../../models/GroceryList');
// const Habit        = require('../../models/Habit');
// const Household    = require('../../models/Household');
// const Bill         = require('../../models/Bill');
// const Task         = require('../../models/Task');

/** Never let one bad collection take down the dashboard. */
async function soft(name, fn, fallback) {
  try {
    return await fn();
  } catch (err) {
    console.error(`[daybrief] loader "${name}" failed:`, err.message);
    return fallback;
  }
}

// ---------------------------------------------------------------------------

async function loadCalendar(scopeId, dayStart, dayEnd) {
  const events = await ExternalEvent.find({
    scopeId,
    startUtc: { $lt: dayEnd },
    endUtc: { $gt: dayStart },
  })
    .sort({ startUtc: 1 })
    .lean();

  const latest = await ExternalEvent.findOne({ scopeId }).sort({ updatedAt: -1 }).lean();

  return {
    connected: Boolean(latest),
    syncedAt: latest?.updatedAt || null,
    events: events.map((e) => ({
      externalId: e.externalId,
      title: e.title,
      startUtc: e.startUtc,
      endUtc: e.endUtc,
      allDay: e.allDay,
      // >>> EDIT: if you tag kid-pickup events, map requiresEscort/assigneeId here.
      requiresEscort: false,
      assigneeId: null,
    })),
  };
}

async function loadMeals(scopeId, localDate) {
  // >>> EDIT — replace with your MealPlan query.
  //
  // const plan = await MealPlan.findOne({ scopeId, date: localDate }).lean();
  // const dinner = plan?.slots?.find(s => s.slot === 'dinner');
  // const usedRecently = await MealPlan.exists({
  //   scopeId, date: { $gte: minus14Days(localDate) }
  // });
  //
  // return {
  //   used: Boolean(usedRecently),
  //   primarySlot: 'dinner',
  //   planned: dinner ? {
  //     title:     dinner.recipeName,
  //     recipeId:  dinner.recipeId,
  //     haveRatio: dinner.haveRatio ?? null,   // null = pantry data unavailable
  //     missing:   dinner.missingIngredients || [],
  //   } : null,
  //   slots: (plan?.slots || [])
  //     .filter(s => s.scheduledAt)
  //     .map(s => ({ id: String(s._id), title: s.recipeName, timeUtc: s.scheduledAt })),
  // };

  return { used: false, primarySlot: 'dinner', planned: null, slots: [] };
}

async function loadGroceries(scopeId) {
  // >>> EDIT — missingCount should count items needed for today + tomorrow's meals
  // that aren't on hand. If you don't track pantry state yet, count unchecked items
  // on the active list; it's a rougher signal but directionally right.
  //
  // const list = await GroceryList.findOne({ scopeId, active: true }).lean();
  // return {
  //   listExists: Boolean(list),
  //   missingCount: (list?.items || []).filter(i => !i.checked).length,
  // };

  return { listExists: false, missingCount: 0 };
}

async function loadFamily(scopeId, localDate) {
  // >>> EDIT — obligations are today's things that need a specific person.
  // An obligation with assigneeId === null is what drives the "nobody assigned"
  // penalty and the unassigned_pickup suggestion in Phase 2.
  //
  // const household = await Household.findById(scopeId).lean();
  // const tasks = await Task.find({ scopeId, dueDate: localDate }).lean();
  //
  // return {
  //   memberCount: household?.members?.length || 1,
  //   members: (household?.members || []).map(m => ({
  //     id: String(m.userId), name: m.displayName,
  //   })),
  //   obligations: tasks.map(t => ({ title: t.title, assigneeId: t.assigneeId || null })),
  // };

  return { memberCount: 1, members: [], obligations: [] };
}

async function loadHabits(scopeId, dayStart, dayEnd) {
  // >>> EDIT — windowStartUtc/windowEndUtc are today's scheduled window for each
  // habit, in UTC. They drive both the timeline rows and the "past its window"
  // readiness penalty, so they need real times, not just a date.
  //
  // const habits = await Habit.find({ scopeId, archived: { $ne: true } }).lean();
  // return {
  //   active: habits.map(h => ({
  //     id: String(h._id),
  //     title: h.title,
  //     icon: h.icon,
  //     windowStartUtc: computeWindowStart(h, dayStart),
  //     windowEndUtc:   computeWindowEnd(h, dayStart),
  //     completedAt: (h.completions || [])
  //       .find(c => c.at >= dayStart && c.at < dayEnd)?.at || null,
  //   })),
  //   longestStreak: Math.max(0, ...habits.map(h => h.currentStreak || 0)),
  // };

  return { active: [], longestStreak: 0 };
}

async function loadFinance(scopeId, localDate) {
  // >>> EDIT
  // const bills = await Bill.find({
  //   scopeId, paid: false, dueDate: { $lte: plusDays(localDate, 7) },
  // }).lean();
  // return {
  //   tracked: true,
  //   bills: bills.map(b => ({ title: b.title, dueDate: b.dueDate, paid: b.paid })),
  // };

  return { tracked: false, bills: [] };
}

async function loadUpcoming(scopeId, localDate, dayEnd) {
  const events = await ExternalEvent.find({
    scopeId,
    startUtc: { $gte: dayEnd },
  })
    .sort({ startUtc: 1 })
    .limit(10)
    .lean();

  return events.map((e) => ({
    date: e.occurrenceDate,
    title: e.title,
    kind: 'event',
    icon: '📅',
  }));
}

async function loadBirthdays(scopeId, localDate) {
  // >>> EDIT — pull from household members + saved contacts, 0-14 days out.
  return [];
}

async function loadWeather(scopeId) {
  // >>> EDIT — Phase 0 can ship without this. When you add it: cache by
  // (lat/lon rounded to 2dp, hour), TTL 60 min, hard 2s timeout, and degrade
  // silently. Weather must never be able to slow down the dashboard.
  return null;
}

// ---------------------------------------------------------------------------

/**
 * Builds the full context. Every loader runs in parallel — the dashboard is the
 * most-hit screen in the app, so serial awaits here would be felt immediately.
 */
async function loadContext({ scopeId, tz, localDate, nowUtc = new Date() }) {
  const dayStart = startOfLocalDayUtc(localDate, tz);
  const dayEnd = endOfLocalDayUtc(localDate, tz);

  const [calendar, meals, groceries, family, habits, finance, upcoming, birthdays, weather] =
    await Promise.all([
      soft('calendar', () => loadCalendar(scopeId, dayStart, dayEnd), { connected: false, events: [] }),
      soft('meals', () => loadMeals(scopeId, localDate), { used: false, planned: null, slots: [] }),
      soft('groceries', () => loadGroceries(scopeId), { listExists: false, missingCount: 0 }),
      soft('family', () => loadFamily(scopeId, localDate), { memberCount: 1, members: [], obligations: [] }),
      soft('habits', () => loadHabits(scopeId, dayStart, dayEnd), { active: [], longestStreak: 0 }),
      soft('finance', () => loadFinance(scopeId, localDate), { tracked: false, bills: [] }),
      soft('upcoming', () => loadUpcoming(scopeId, localDate, dayEnd), []),
      soft('birthdays', () => loadBirthdays(scopeId, localDate), []),
      soft('weather', () => loadWeather(scopeId), null),
    ]);

  return {
    scopeId,
    tz,
    localDate,
    nowUtc,
    dayStart,
    dayEnd,
    calendar,
    meals,
    groceries,
    family,
    habits,
    finance,
    upcoming,
    birthdays,
    weather,
    tasks: { scheduled: [] }, // >>> EDIT if you want tasks on the timeline
  };
}

module.exports = { loadContext };

PLANBHAI_EOF

write 'backend/services/daybrief/daybrief.service.js' << 'PLANBHAI_EOF'
const DayBrief = require('../../models/DayBrief');
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
  const state = deriveState(signals, ctx);

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

module.exports = { getTodayBrief, bustDayBrief, buildBrief, decorateForRead };

PLANBHAI_EOF

write 'backend/routes/dashboard.routes.js' << 'PLANBHAI_EOF'
const express = require('express');
const SuggestionDismissal = require('../models/SuggestionDismissal');
const { getTodayBrief } = require('../services/daybrief/daybrief.service');
const { isValidTz, todayIn } = require('../services/daybrief/tz.util');

const router = express.Router();

// >>> EDIT: swap for the middleware already guarding your 10 AI endpoints.
const requireAuth = require('../middleware/requireAuth');
const requireHouseholdMember = require('../middleware/requireHouseholdMember');

/**
 * GET /api/dashboard/today?tz=America/Chicago&scopeId=...&date=YYYY-MM-DD
 *
 * scopeId is validated and attached by requireHouseholdMember. This route never
 * reads it from req.query — that's what keeps a literal ":scopeId" string from
 * reaching a cache key, which is the failure mode you already hit on web.
 */
router.get('/today', requireAuth, requireHouseholdMember, async (req, res) => {
  const { scopeId, user } = req;
  const tz = req.query.tz;

  if (!isValidTz(tz)) {
    return res.status(422).json({ error: 'A valid IANA timezone is required, e.g. America/Chicago' });
  }

  const date = req.query.date;
  if (date && !/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    return res.status(422).json({ error: 'date must be YYYY-MM-DD' });
  }

  try {
    const brief = await getTodayBrief({ user, scopeId, tz, date });
    res.set('Cache-Control', 'private, max-age=60');
    res.json(brief);
  } catch (err) {
    console.error('[dashboard/today] failed', err);
    res.status(500).json({ error: 'Could not build your day' });
  }
});

/** POST /api/dashboard/suggestions/:id/dismiss — personal, not household-wide. */
router.post('/suggestions/:id/dismiss', requireAuth, requireHouseholdMember, async (req, res) => {
  const { scopeId, user } = req;
  const suggestionId = req.params.id;
  const tz = isValidTz(req.query.tz) ? req.query.tz : 'UTC';

  const expiresAt = new Date(Date.parse(`${todayIn(tz)}T00:00:00Z`) + 3 * 86400000);

  await SuggestionDismissal.findOneAndUpdate(
    { userId: user._id, suggestionId },
    { userId: user._id, scopeId, suggestionId, dismissedAt: new Date(), expiresAt },
    { upsert: true }
  );

  res.json({ dismissed: suggestionId });
});

module.exports = router;

PLANBHAI_EOF

write 'backend/routes/calendar.routes.js' << 'PLANBHAI_EOF'
const express = require('express');
const ExternalEvent = require('../models/ExternalEvent');
const DayBrief = require('../models/DayBrief');
const { runAtomic } = require('../services/mongo.util');

const router = express.Router();

// Replace these two with your existing middleware.
const requireAuth = require('../middleware/requireAuth');
const requireHouseholdMember = require('../middleware/requireHouseholdMember');

const MAX_EVENTS = 1000;
const MAX_WINDOW_DAYS = 45;

/**
 * POST /api/calendar/sync
 *
 * The device sends its FULL window every time, not a delta. Anything in the window
 * that isn't in the payload is treated as deleted. This is the only reliable way to
 * handle recurring-event edits and deletions without tracking tombstones on device.
 *
 * Body: { windowStart, windowEnd, syncedAt?, events: [...] }
 */
router.post('/sync', requireAuth, requireHouseholdMember, async (req, res) => {
  const { scopeId } = req; // set by requireHouseholdMember — never trust the raw query
  const userId = req.user._id;
  const { windowStart, windowEnd, events } = req.body || {};

  if (!windowStart || !windowEnd || !Array.isArray(events)) {
    return res.status(400).json({ error: 'windowStart, windowEnd and events[] are required' });
  }

  const start = new Date(windowStart);
  const end = new Date(windowEnd);
  if (isNaN(start) || isNaN(end) || end <= start) {
    return res.status(400).json({ error: 'Invalid sync window' });
  }
  if ((end - start) / 86400000 > MAX_WINDOW_DAYS) {
    return res.status(422).json({ error: `Window may not exceed ${MAX_WINDOW_DAYS} days` });
  }
  if (events.length > MAX_EVENTS) {
    return res.status(413).json({ error: `Too many events (max ${MAX_EVENTS})` });
  }

  // Strip anything we didn't ask for. Defence in depth: even if a future client
  // build starts sending notes or attendees, they never reach the database.
  const sanitized = [];
  for (const e of events) {
    if (!e.externalId || !e.occurrenceDate || !e.startUtc || !e.endUtc) continue;
    if (!/^\d{4}-\d{2}-\d{2}$/.test(e.occurrenceDate)) continue;

    const s = new Date(e.startUtc);
    const en = new Date(e.endUtc);
    if (isNaN(s) || isNaN(en) || en < s) continue;

    sanitized.push({
      externalId: String(e.externalId).slice(0, 256),
      occurrenceDate: e.occurrenceDate,
      title: String(e.title || 'Busy').slice(0, 200),
      startUtc: s,
      endUtc: en,
      sourceTz: e.sourceTz ? String(e.sourceTz).slice(0, 64) : null,
      allDay: Boolean(e.allDay),
      calendarName: e.calendarName ? String(e.calendarName).slice(0, 100) : null,
    });
  }

  let upserted = 0;
  let removed = 0;

  try {
    // Transactional on a replica set (production), sequential on a standalone
    // (local dev). See services/mongo.util.js.
    await runAtomic(async (session) => {
      if (sanitized.length) {
        const ops = sanitized.map((e) => ({
          updateOne: {
            filter: {
              scopeId,
              provider: 'eventkit',
              externalId: e.externalId,
              occurrenceDate: e.occurrenceDate,
            },
            update: { $set: { ...e, scopeId, ownerUserId: userId, provider: 'eventkit' } },
            upsert: true,
          },
        }));
        const result = await ExternalEvent.bulkWrite(ops, { session, ordered: false });
        upserted = (result.upsertedCount || 0) + (result.modifiedCount || 0);
      }

      // Delete-by-omission, scoped to this owner's events inside this window only.
      const keep = sanitized.map((e) => `${e.externalId}::${e.occurrenceDate}`);
      const stale = await ExternalEvent.find(
        {
          scopeId,
          ownerUserId: userId,
          provider: 'eventkit',
          startUtc: { $gte: start, $lt: end },
        },
        { externalId: 1, occurrenceDate: 1 }
      ).session(session);

      const toDelete = stale
        .filter((d) => !keep.includes(`${d.externalId}::${d.occurrenceDate}`))
        .map((d) => d._id);

      if (toDelete.length) {
        const r = await ExternalEvent.deleteMany({ _id: { $in: toDelete } }, { session });
        removed = r.deletedCount || 0;
      }
    });
  } catch (err) {
    console.error('[calendar/sync] failed', err);
    return res.status(500).json({ error: 'Sync failed' });
  }

  // The timeline just changed — drop today-and-forward briefs for this household.
  const today = new Date().toISOString().slice(0, 10);
  await DayBrief.deleteMany({ scopeId, localDate: { $gte: today } });

  res.json({ upserted, removed, received: events.length, syncedAt: new Date().toISOString() });
});

/**
 * DELETE /api/calendar/disconnect
 * Required for the App Store privacy commitment: turning calendar access off must
 * actually remove the data, not just stop syncing.
 */
router.delete('/disconnect', requireAuth, requireHouseholdMember, async (req, res) => {
  const { scopeId } = req;
  const r = await ExternalEvent.deleteMany({
    scopeId,
    ownerUserId: req.user._id,
    provider: 'eventkit',
  });
  const today = new Date().toISOString().slice(0, 10);
  await DayBrief.deleteMany({ scopeId, localDate: { $gte: today } });
  res.json({ removed: r.deletedCount || 0 });
});

module.exports = router;

PLANBHAI_EOF

write 'PlanBhai/Services/CalendarSyncManager.swift' << 'PLANBHAI_EOF'
import Foundation
import EventKit
import Combine

/// Syncs a rolling window of the device calendar to the PlanBhai backend so the web
/// app can render the same timeline. EventKit is Apple-only, so iOS is the ingestion
/// source of truth until Google Calendar OAuth lands.
///
/// PRIVACY: only title, start, end, allDay and calendar name leave the device.
/// Notes, attendees, location, URL and attachments are never read or transmitted —
/// calendar entries contain other people's information, not just the user's.
@MainActor
final class CalendarSyncManager: ObservableObject {

    static let shared = CalendarSyncManager()

    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var isSyncing = false
    @Published private(set) var authorizationDenied = false

    private let store = EKEventStore()
    private var observer: NSObjectProtocol?
    private var debounceTask: Task<Void, Never>?

    /// Rolling window. Yesterday gives us "what just happened" context; +14 days
    /// covers the Upcoming row without pulling the user's entire year.
    private let daysBack = 1
    private let daysForward = 14

    private init() {}

    // MARK: - Permission

    /// Call this only AFTER showing your own explanation screen. The system prompt is
    /// one-shot — if it's denied, the user has to go to Settings, so earning the yes
    /// beforehand matters more than it does for most permissions.
    func requestAccess() async -> Bool {
        do {
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = try await store.requestFullAccessToEvents()
            } else {
                granted = try await store.requestAccess(to: .event)
            }
            authorizationDenied = !granted
            if granted { startObserving() }
            return granted
        } catch {
            authorizationDenied = true
            return false
        }
    }

    var hasAccess: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            return status == .fullAccess
        }
        return status == .authorized
    }

    // MARK: - Change observation

    func startObserving() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            // EventKit fires this repeatedly during a bulk edit — debounce so we
            // don't hammer the backend with a dozen full-window syncs.
            self?.debounceSync(after: 3)
        }
    }

    private func debounceSync(after seconds: UInt64) {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await self?.sync()
        }
    }

    // MARK: - Sync

    @discardableResult
    func sync() async -> Bool {
        guard hasAccess, !isSyncing else { return false }
        isSyncing = true
        defer { isSyncing = false }

        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        guard
            let windowStart = cal.date(byAdding: .day, value: -daysBack, to: startOfToday),
            let windowEnd = cal.date(byAdding: .day, value: daysForward, to: startOfToday)
        else { return false }

        let predicate = store.predicateForEvents(
            withStart: windowStart,
            end: windowEnd,
            calendars: nil
        )

        let payload = store.events(matching: predicate)
            .filter { !$0.isAllDay || $0.startDate != nil }
            .compactMap { Self.encode($0) }

        do {
            let body = SyncRequest(
                windowStart: windowStart,
                windowEnd: windowEnd,
                events: payload
            )
            let response: SyncResponse = try await APIClient.shared.post(
                "/api/calendar/sync",
                body: body
            )
            lastSyncedAt = response.syncedAt
            return true
        } catch {
            print("[CalendarSync] failed:", error.localizedDescription)
            return false
        }
    }

    /// Called from the disconnect toggle in Settings. Deletes server-side copies.
    func disconnect() async {
        _ = try? await APIClient.shared.delete("/api/calendar/disconnect")
        lastSyncedAt = nil
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }

    // MARK: - Encoding

    private static let occurrenceFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static func encode(_ event: EKEvent) -> SyncEvent? {
        guard
            let id = event.eventIdentifier,
            let start = event.startDate,
            let end = event.endDate
        else { return nil }

        // CRITICAL: every occurrence of a recurring series shares one
        // eventIdentifier. Without occurrenceDate in the key, a weekly soccer
        // practice collapses into a single row and the timeline silently loses
        // eleven of its twelve entries.
        let tz = event.timeZone ?? TimeZone.current
        occurrenceFormatter.timeZone = tz

        return SyncEvent(
            externalId: id,
            occurrenceDate: occurrenceFormatter.string(from: start),
            title: event.title ?? "Busy",
            startUtc: start,
            endUtc: end,
            sourceTz: tz.identifier,
            allDay: event.isAllDay,
            calendarName: event.calendar?.title
            // Deliberately omitted: notes, attendees, location, url, attachments.
        )
    }
}

// MARK: - Wire types

struct SyncEvent: Codable {
    let externalId: String
    let occurrenceDate: String
    let title: String
    let startUtc: Date
    let endUtc: Date
    let sourceTz: String
    let allDay: Bool
    let calendarName: String?
}

struct SyncRequest: Codable {
    let windowStart: Date
    let windowEnd: Date
    let events: [SyncEvent]
}

struct SyncResponse: Codable {
    let upserted: Int
    let removed: Int
    let received: Int
    let syncedAt: Date
}

PLANBHAI_EOF


echo
echo "=============================================="
echo "Files installed. Next:"
echo "  bash ~/Downloads/phase0-doctor.sh $ROOT"
echo "=============================================="

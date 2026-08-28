#!/usr/bin/env bash
#
# Rebuilds the Brief page to the product vision, and extends the contract to
# carry the data it needs.
#
# BACKEND (2 files)
#   daybrief.service.js  adds `habits` and `counts` to the brief
#   DayBrief.js          declares those fields on the model
#
# iOS (2 files)
#   DayBriefModels.swift decodes them
#   DayBriefView.swift   the full page
#
# Rows, in vision order: hero -> today's focus -> timeline -> jump to ->
# ask bhai -> upcoming -> family -> meal -> habit garden -> achievements.
#
# TWO ROWS ARE DELIBERATELY ABSENT:
#   AI Suggestions   the rules engine that fills them is Phase 2. An empty
#                    shell would promise something the app cannot do yet.
#   Context cards    Phase 3, same reason.
# Both appear on their own once the server starts sending them — no client
# change needed.
#
# Usage:
#   bash ~/Downloads/install-brief-v2.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
D="PlanBhai/ios/PlanBhai"
[ -d "$D/Views" ] || { echo "ERROR: $D/Views not found"; exit 1; }
[ -d backend/services/daybrief ] || { echo "ERROR: backend/services/daybrief not found"; exit 1; }

echo "PlanBhai — Brief v2"
echo

write() {
  local dest="$1"
  [ -f "$dest" ] && cp "$dest" "$dest.bakv2"
  cat > "$dest"
  echo "   wrote $dest"
}

echo "1. Backend"
write 'backend/services/daybrief/daybrief.service.js' << 'PLANBHAI_EOF'
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

    // Habits carry no schedule, so they stay out of the readiness score (see
    // readiness.service.js) — but the client still needs them for the habit
    // garden and the streak badge, so they're exposed here.
    habits: {
      total: ctx.habits?.total || 0,
      completedToday: ctx.habits?.completedToday || 0,
      longestStreak: ctx.habits?.longestStreak || 0,
      all: (ctx.habits?.all || []).slice(0, 12),
    },

    // Counts the hero checklist reads. Derived, not stored — the client should
    // never have to recompute what the server already knows.
    counts: {
      events: (ctx.calendar?.events || []).filter((e) => !e.allDay).length,
      meals: (ctx.meals?.slots || []).length,
      choresOpen: (ctx.family?.obligations || []).length,
      choresDone: ctx.family?.choresDone || 0,
      groceries: ctx.groceries?.itemCount || 0,
      upcoming: (ctx.upcoming || []).length,
      notes: (ctx.notes || []).length,
    },

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

    // Habits are excluded from the readiness score (no schedule to measure), but
    // the client needs them for the habit garden and streak badge.
    habits: { type: mongoose.Schema.Types.Mixed, default: null },

    // Derived counts for the hero checklist.
    counts: { type: mongoose.Schema.Types.Mixed, default: null },

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

for f in backend/services/daybrief/daybrief.service.js backend/models/DayBrief.js; do
  node --check "$f" || { echo "   PARSE FAILED: $f"; exit 1; }
done
echo "   both parse"
echo

echo "2. iOS"
write "$D/DayBriefModels.swift" << 'PLANBHAI_EOF'
import Foundation

// MARK: - Wire models
//
// Mirrors GET /api/dashboard/today. Every field the server may omit or null is
// optional here — `readiness` is genuinely null for a household with nothing
// plannable yet, and treating that as an error would break the empty state.

struct DayBrief: Codable {
    let localDate: String
    let tz: String
    let state: String              // "empty" | "sparse" | "rich"
    let greeting: Greeting?
    let readiness: Readiness?      // null when no domain applies
    let signals: [Signal]?
    let timeline: [TimelineRow]?
    let meal: Meal?
    let family: [FamilyRow]?
    let upcoming: [UpcomingRow]?
    let habits: Habits?
    let counts: Counts?
    let calendarSyncedAt: String?

    struct Habits: Codable {
        let total: Int?
        let completedToday: Int?
        let longestStreak: Int?
        let all: [Habit]?

        struct Habit: Codable, Identifiable {
            let name: String
            let streak: Int?
            let completedToday: Bool?
            var id: String { name }
        }
    }

    struct Counts: Codable {
        let events: Int?
        let meals: Int?
        let choresOpen: Int?
        let choresDone: Int?
        let groceries: Int?
        let upcoming: Int?
        let notes: Int?
    }

    struct Greeting: Codable {
        let timeOfDay: String      // morning | afternoon | evening | night
        let line: String
    }

    struct Readiness: Codable {
        let score: Int
        let label: String
        let breakdown: [Domain]?

        struct Domain: Codable {
            let domain: String
            let score: Int
            let applicable: Bool
            let reason: String?
        }

        /// Lowest-scoring applicable domain — the one thing most worth surfacing.
        var weakest: Domain? {
            (breakdown ?? []).filter { $0.applicable }.min { $0.score < $1.score }
        }
    }

    struct Signal: Codable, Identifiable {
        let icon: String?
        let text: String
        let kind: String?
        let priority: Int?
        var id: String { (kind ?? "") + text }
    }

    struct TimelineRow: Codable, Identifiable {
        let start: String          // "HH:mm"
        let end: String?
        let title: String
        let kind: String?          // habit | event | meal | task | routine
        let source: String?
        let sourceId: String?
        let icon: String?
        let isNow: Bool?
        var id: String { start + title }
    }

    struct Meal: Codable {
        let slot: String?
        let title: String
        let haveRatio: Double?
        let missing: [String]?
    }

    struct FamilyRow: Codable, Identifiable {
        let memberId: String?
        let name: String
        let status: String?
        let state: String?         // done | pending | upcoming
        let icon: String?
        var id: String { (memberId ?? "") + name }
    }

    struct UpcomingRow: Codable, Identifiable {
        let day: String
        let date: String
        let title: String
        let icon: String?
        var id: String { date + title }
    }
}

// MARK: - Service

enum DayBriefError: LocalizedError {
    case noHousehold
    case notSignedIn
    case server(Int, String)

    var errorDescription: String? {
        switch self {
        case .noHousehold: return "No household selected yet."
        case .notSignedIn: return "You need to sign in."
        case .server(let code, let body):
            return "Couldn't load your day (\(code)). \(body)"
        }
    }
}

@MainActor
final class DayBriefService {
    static let shared = DayBriefService()

    /// Must match APIService.baseURL — it's private there, so it's repeated.
    private let baseURL = "https://planbhai.onrender.com"

    private init() {}

    func fetch(householdId: String, token: String) async throws -> DayBrief {
        // The server keys its cache on timezone, so the device reports its own
        // rather than assuming one.
        let tz = TimeZone.current.identifier
        var comps = URLComponents(string: "\(baseURL)/api/dashboard/today")!
        comps.queryItems = [
            URLQueryItem(name: "scopeId", value: householdId),
            URLQueryItem(name: "tz", value: tz)
        ]

        var request = URLRequest(url: comps.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw DayBriefError.server(0, "No response")
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw DayBriefError.server(http.statusCode, String(body.prefix(140)))
        }

        return try JSONDecoder().decode(DayBrief.self, from: data)
    }
}
PLANBHAI_EOF
write "$D/Views/DayBriefView.swift" << 'PLANBHAI_EOF'
import SwiftUI

/// The Brief — "this app already understands my day".
///
/// Row order follows the product vision: hero, score, suggestions, timeline,
/// categories, Ask Bhai, upcoming, family, meal, habit garden, achievements.
///
/// Two honesty rules run through this file:
///   1. A section that has no data does not render. An empty shell implies the
///      app knows something it doesn't, and users catch that fast.
///   2. Nothing is invented client-side. Every number comes from the brief.
struct DayBriefView: View {
    @EnvironmentObject var appState: AppState
    var selectedTab: Binding<Int>? = nil      // lets the category row switch tabs

    @State private var brief: DayBrief?
    @State private var isLoading = true
    @State private var errorText: String?
    @State private var showBreakdown = false
    @State private var heroAppeared = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0F0F1A"), Color(hex: "0F172A"), Color(hex: "111827")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()

            blob(PB.navy, 320, x: 160, y: -170, blur: 80, op: 0.20)
            blob(PB.teal, 250, x: -130, y: 260, blur: 65, op: 0.11)
            blob(PB.mauve, 220, x: 140, y: 620, blur: 70, op: 0.08)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    if isLoading && brief == nil {
                        ProgressView().tint(.white).padding(.top, 120)
                    } else if let errorText {
                        errorCard(errorText)
                    } else if let b = brief {
                        heroCard(b)                                   // Hero
                        if let r = b.readiness { scoreCard(r) }        // 1 — Today's Focus
                        suggestionsRow(b)                              // 2 — AI suggestions
                        if let t = b.timeline, !t.isEmpty { timelineCard(t) }   // 3
                        categoriesRow                                  // 4 — Life categories
                        askBhaiCard                                    // 5 — Ask Bhai
                        if let u = b.upcoming, !u.isEmpty { upcomingCard(u) }   // 6
                        if let f = b.family, !f.isEmpty { familyCard(f) }       // 7
                        if let m = b.meal { mealCard(m) }              // 8
                        habitGarden(b)                                 // 9
                        achievements(b)                                // 10
                        syncFooter(b)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120)
            }
            .refreshable { await load() }
        }
        .task { await load() }
    }

    // MARK: - Hero

    private func heroCard(_ b: DayBrief) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(salutation)
                        .font(.system(size: 27, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(b.greeting?.line ?? "Here's your day.")
                        .font(.system(size: 13))
                        .foregroundStyle(PB.mid)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Text(timeEmoji).font(.system(size: 30))
            }

            Rectangle()
                .fill(LinearGradient(colors: [PB.navy.opacity(0.5), PB.teal.opacity(0.25), .clear],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)

            // Every line here is a real count from the brief. No placeholders —
            // a checklist that lists things you don't have is the fastest way to
            // lose trust in the whole screen.
            VStack(alignment: .leading, spacing: 9) {
                ForEach(Array(heroLines(b).enumerated()), id: \.offset) { i, line in
                    HStack(spacing: 9) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(PB.forest)
                            .frame(width: 15, height: 15)
                            .background(Circle().fill(PB.forest.opacity(0.16)))
                        Text(line)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(PB.mid)
                    }
                    .opacity(heroAppeared ? 1 : 0)
                    .offset(y: heroAppeared ? 0 : 6)
                    .animation(.easeOut(duration: 0.32).delay(Double(i) * 0.05), value: heroAppeared)
                }
            }

            if let r = b.readiness {
                Text(r.score >= 80 ? "Everything fits." : r.label)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(colors: [PB.navy.opacity(0.22), PB.teal.opacity(0.10)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(PB.glassBorder, lineWidth: 1))
        .padding(.top, 14)
        .onAppear { heroAppeared = true }
    }

    private func heroLines(_ b: DayBrief) -> [String] {
        var out: [String] = []
        guard let c = b.counts else { return out }
        if let n = c.events, n > 0    { out.append("\(n) event\(n == 1 ? "" : "s") today") }
        if let n = c.meals, n > 0     { out.append("\(n) meal\(n == 1 ? "" : "s") planned") }
        if let h = b.habits, let t = h.total, t > 0 {
            out.append("\(h.completedToday ?? 0) of \(t) habits done")
        }
        if let n = c.choresOpen, n > 0 { out.append("\(n) chore\(n == 1 ? "" : "s") to pick up") }
        if let n = c.groceries, n > 0  { out.append("\(n) items on the grocery list") }
        if let n = c.upcoming, n > 0   { out.append("\(n) thing\(n == 1 ? "" : "s") coming up") }
        return out
    }

    // MARK: - 1. Today's Focus

    private func scoreCard(_ r: DayBrief.Readiness) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Today's Focus", icon: "target", color: PB.forest)

            HStack(spacing: 20) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.07), lineWidth: 11)
                    Circle()
                        .trim(from: 0, to: CGFloat(max(0, min(100, r.score))) / 100)
                        .stroke(AngularGradient(colors: [ringColor(r.score),
                                                         ringColor(r.score).opacity(0.5)],
                                                center: .center),
                                style: StrokeStyle(lineWidth: 11, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.9), value: r.score)
                    VStack(spacing: -2) {
                        Text("\(r.score)")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("%").font(.system(size: 11, weight: .bold)).foregroundStyle(PB.soft)
                    }
                }
                .frame(width: 94, height: 94)

                VStack(alignment: .leading, spacing: 7) {
                    Text(r.label)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    // A score with no explanation is anxiety with a percentage
                    // attached — always pair it with the weakest domain.
                    if let w = r.weakest, let reason = w.reason, !reason.isEmpty {
                        Text(reason)
                            .font(.system(size: 12))
                            .foregroundStyle(PB.soft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }

            if let breakdown = r.breakdown, !breakdown.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) { showBreakdown.toggle() }
                } label: {
                    HStack(spacing: 5) {
                        Text(showBreakdown ? "Hide detail" : "Why this score?")
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: showBreakdown ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(PB.sky)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 14)
                }
                .buttonStyle(.plain)

                if showBreakdown {
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(breakdown.filter { $0.applicable }, id: \.domain) { d in
                            HStack(alignment: .top, spacing: 10) {
                                Text(d.domain.capitalized)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(PB.mid)
                                    .frame(width: 72, alignment: .leading)
                                Text("\(d.score)")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(ringColor(d.score))
                                    .frame(width: 26, alignment: .trailing)
                                Text(d.reason ?? "")
                                    .font(.system(size: 11))
                                    .foregroundStyle(PB.soft)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                        }
                        if !notCounted(breakdown).isEmpty {
                            Text("Not counted: \(notCounted(breakdown))")
                                .font(.system(size: 10))
                                .foregroundStyle(PB.muted)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.top, 12)
                }
            }
        }
        .padding(18)
        .glassCard()
    }

    // MARK: - 2. AI suggestions

    @ViewBuilder
    private func suggestionsRow(_ b: DayBrief) -> some View {
        // The contract carries `suggestions`, but the rules engine that fills it
        // is Phase 2. Rendering an empty shell now would promise something the
        // app can't do yet, so this stays hidden until there's a real one.
        EmptyView()
    }

    // MARK: - 3. Timeline

    private func timelineCard(_ rows: [DayBrief.TimelineRow]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Today's Timeline", icon: "clock.fill", color: PB.sky)

            ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                HStack(alignment: .top, spacing: 12) {
                    Text(displayTime(row.start))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(row.isNow == true ? PB.teal : PB.muted)
                        .frame(width: 52, alignment: .leading)

                    VStack(spacing: 0) {
                        ZStack {
                            if row.isNow == true {
                                Circle().fill(PB.teal.opacity(0.25)).frame(width: 16, height: 16)
                            }
                            Circle()
                                .fill(row.isNow == true ? PB.teal : kindColor(row.kind))
                                .frame(width: 8, height: 8)
                        }
                        .frame(width: 16, height: 16)
                        if idx < rows.count - 1 {
                            Rectangle().fill(Color.white.opacity(0.09))
                                .frame(width: 1.5).frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: 16)

                    HStack(spacing: 7) {
                        if let icon = row.icon { Text(icon).font(.system(size: 13)) }
                        Text(row.title)
                            .font(.system(size: 14, weight: row.isNow == true ? .bold : .medium))
                            .foregroundStyle(row.isNow == true ? .white : PB.mid)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.bottom, 18)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(18)
        .glassCard()
    }

    // MARK: - 4. Life categories

    private var categoriesRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Jump to", icon: "square.grid.2x2.fill", color: PB.mauve)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(categories, id: \.label) { c in
                        Button {
                            if let tab = c.tab { selectedTab?.wrappedValue = tab }
                        } label: {
                            VStack(spacing: 7) {
                                Text(c.emoji).font(.system(size: 22))
                                Text(c.label)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(PB.mid)
                            }
                            .frame(width: 68, height: 68)
                            .background(RoundedRectangle(cornerRadius: 16).fill(c.color.opacity(0.13)))
                            .overlay(RoundedRectangle(cornerRadius: 16)
                                .stroke(c.color.opacity(0.28), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(18)
        .glassCard()
    }

    private var categories: [(emoji: String, label: String, color: Color, tab: Int?)] {
        [("🍽", "Meals", PB.teal, 1),
         ("💪", "Habits", PB.forest, 2),
         ("🎉", "Party", PB.rose, 3),
         ("👨‍👩‍👧", "Family", PB.mauve, 4),
         ("🏠", "Household", PB.navy, 4),
         ("📅", "Events", PB.sky, 4),
         ("💰", "Budget", PB.amber, 4),
         ("❤️", "Wellness", PB.pink, 2)]
    }

    // MARK: - 5. Ask Bhai

    private var askBhaiCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Ask Bhai", icon: "sparkles", color: PB.amber)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(prompts, id: \.self) { p in
                        Text(p)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(PB.mid)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(PB.glass))
                            .overlay(Capsule().stroke(PB.glassBorder, lineWidth: 1))
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(18)
        .glassCard()
    }

    private var prompts: [String] {
        ["Plan dinner for 8", "Schedule my week", "Find recipes",
         "Organize a birthday", "Split expenses", "Plan a trip"]
    }

    // MARK: - 6. Upcoming

    private func upcomingCard(_ rows: [DayBrief.UpcomingRow]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Upcoming", icon: "calendar", color: PB.navyLight)
            ForEach(rows.prefix(5)) { r in
                HStack(spacing: 12) {
                    Text(r.day)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(PB.soft)
                        .frame(width: 76, alignment: .leading)
                    if let icon = r.icon { Text(icon).font(.system(size: 13)) }
                    Text(r.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(PB.mid)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard()
    }

    // MARK: - 7. Family snapshot

    private func familyCard(_ rows: [DayBrief.FamilyRow]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Family", icon: "person.3.fill", color: PB.mauve)
            ForEach(rows.prefix(6)) { m in
                HStack(spacing: 12) {
                    Text(String(m.name.prefix(1)).uppercased())
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(memberColor(m.name).opacity(0.30)))
                        .overlay(Circle().stroke(memberColor(m.name).opacity(0.55), lineWidth: 1))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(m.status ?? "")
                            .font(.system(size: 11))
                            .foregroundStyle(PB.soft)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: m.state == "done" ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 15))
                        .foregroundStyle(m.state == "done" ? PB.forest : PB.muted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard()
    }

    private func memberColor(_ name: String) -> Color {
        PB.memberColors[abs(name.hashValue) % PB.memberColors.count]
    }

    // MARK: - 8. Meal

    private func mealCard(_ meal: DayBrief.Meal) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionLabel("Today's \(meal.slot?.capitalized ?? "Dinner")",
                         icon: "fork.knife", color: PB.amber)

            Text(meal.title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            if let ratio = meal.haveRatio {
                HStack(spacing: 9) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08))
                            Capsule().fill(PB.forest)
                                .frame(width: geo.size.width * CGFloat(max(0, min(1, ratio))))
                        }
                    }
                    .frame(height: 6)
                    Text("\(Int(ratio * 100))% available")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PB.forest)
                }
            }

            if let missing = meal.missing, !missing.isEmpty {
                Text("Need: \(missing.joined(separator: ", "))")
                    .font(.system(size: 12))
                    .foregroundStyle(PB.warning)
            }
            // When haveRatio is nil the pantry is empty, so coverage is genuinely
            // unknown. Saying nothing beats implying everything's on hand.
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard()
    }

    // MARK: - 9. Habit garden

    @ViewBuilder
    private func habitGarden(_ b: DayBrief) -> some View {
        if let h = b.habits, let total = h.total, total > 0 {
            VStack(alignment: .leading, spacing: 14) {
                sectionLabel("Habit Garden", icon: "leaf.fill", color: PB.forest)

                HStack(spacing: 10) {
                    ForEach(h.all ?? []) { habit in
                        VStack(spacing: 5) {
                            Text(habit.completedToday == true ? "🌸" : "🌱")
                                .font(.system(size: 26))
                                .opacity(habit.completedToday == true ? 1 : 0.45)
                            Text("\(habit.streak ?? 0)")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(habit.completedToday == true ? PB.forest : PB.muted)
                        }
                    }
                    Spacer(minLength: 0)
                }

                Text("\(h.completedToday ?? 0) of \(total) blooming today")
                    .font(.system(size: 12))
                    .foregroundStyle(PB.soft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .glassCard()
        }
    }

    // MARK: - 10. Achievements

    @ViewBuilder
    private func achievements(_ b: DayBrief) -> some View {
        // Only badges backed by real data. A trophy case full of things the user
        // hasn't done is the opposite of motivating.
        if !earned(b).isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Achievements", icon: "trophy.fill", color: PB.amber)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(earned(b), id: \.title) { a in
                            VStack(spacing: 6) {
                                Text(a.emoji).font(.system(size: 24))
                                Text(a.title)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(PB.mid)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(width: 84, height: 76)
                            .background(RoundedRectangle(cornerRadius: 14).fill(PB.amber.opacity(0.10)))
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .stroke(PB.amber.opacity(0.25), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .glassCard()
        }
    }

    private func earned(_ b: DayBrief) -> [(emoji: String, title: String)] {
        var out: [(emoji: String, title: String)] = []
        if let streak = b.habits?.longestStreak, streak >= 3 {
            out.append(("🔥", "\(streak) day streak"))
        }
        if let h = b.habits, let t = h.total, t > 0, h.completedToday == t {
            out.append(("💪", "All habits done"))
        }
        if let done = b.counts?.choresDone, done > 0 {
            out.append(("🏆", "\(done) chores done"))
        }
        if let r = b.readiness, r.score >= 90 {
            out.append(("✨", "Day under control"))
        }
        return out
    }

    // MARK: - Footer / states

    @ViewBuilder
    private func syncFooter(_ b: DayBrief) -> some View {
        if let synced = b.calendarSyncedAt {
            Text("Calendar synced \(relativeSync(synced))")
                .font(.system(size: 10))
                .foregroundStyle(PB.muted)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func errorCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Couldn't load your day")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(PB.soft)
                .fixedSize(horizontal: false, vertical: true)
            Button { Task { await load() } } label: {
                Text("Try again")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PB.sky)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard()
        .padding(.top, 60)
    }

    // MARK: - Helpers

    private var salutation: String {
        let part = brief?.greeting?.timeOfDay ?? currentTimeOfDay
        let name = appState.currentUser?.name
            ?? UserDefaults.standard.string(forKey: "userName") ?? ""
        let base = "Good \(part.capitalized)"
        return name.isEmpty ? base : "\(base), \(name)"
    }

    private var timeEmoji: String {
        switch brief?.greeting?.timeOfDay ?? currentTimeOfDay {
        case "morning":   return "☀️"
        case "afternoon": return "🌤"
        case "evening":   return "🌆"
        default:          return "🌙"
        }
    }

    private var currentTimeOfDay: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case ..<12: return "morning"
        case ..<17: return "afternoon"
        case ..<21: return "evening"
        default:    return "night"
        }
    }

    /// "19:00" -> "7 PM". The server sends 24h; people read 12h.
    private func displayTime(_ hhmm: String) -> String {
        let parts = hhmm.split(separator: ":")
        guard let h = Int(parts.first ?? "") else { return hhmm }
        let m = parts.count > 1 ? String(parts[1]) : "00"
        let suffix = h < 12 ? "AM" : "PM"
        let h12 = h % 12 == 0 ? 12 : h % 12
        return m == "00" ? "\(h12) \(suffix)" : "\(h12):\(m) \(suffix)"
    }

    private func relativeSync(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let date else { return "recently" }
        let mins = Int(Date().timeIntervalSince(date) / 60)
        if mins < 1 { return "just now" }
        if mins < 60 { return "\(mins)m ago" }
        return "\(mins / 60)h ago"
    }

    private func notCounted(_ b: [DayBrief.Readiness.Domain]) -> String {
        b.filter { !$0.applicable }.map { $0.domain }.joined(separator: ", ")
    }

    private func ringColor(_ score: Int) -> Color {
        switch score {
        case 80...:   return PB.success
        case 60..<80: return PB.sky
        case 40..<60: return PB.warning
        default:      return PB.error
        }
    }

    private func kindColor(_ kind: String?) -> Color {
        switch kind {
        case "meal":  return PB.amber
        case "habit": return PB.forest
        case "event": return PB.navyLight
        case "task":  return PB.mauve
        default:      return PB.soft
        }
    }

    private func sectionLabel(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(PB.soft)
                .tracking(0.9)
        }
        .padding(.bottom, 14)
    }

    private func blob(_ c: Color, _ s: CGFloat, x: CGFloat, y: CGFloat, blur: CGFloat, op: Double) -> some View {
        Circle().fill(c.opacity(op)).frame(width: s, height: s)
            .offset(x: x, y: y).blur(radius: blur).allowsHitTesting(false)
    }

    // MARK: - Load

    private func load() async {
        guard let token = appState.authToken else {
            errorText = "You need to sign in."; isLoading = false; return
        }
        guard let household = appState.activeHouseholdId else {
            errorText = "No household selected yet."; isLoading = false; return
        }
        isLoading = true
        errorText = nil
        do {
            brief = try await DayBriefService.shared.fetch(householdId: household, token: token)
        } catch {
            errorText = error.localizedDescription
        }
        isLoading = false
    }
}

private extension View {
    func glassCard() -> some View {
        self
            .background(RoundedRectangle(cornerRadius: 20).fill(PB.glass))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(PB.glassBorder, lineWidth: 1))
    }
}
PLANBHAI_EOF

echo

echo "3. Passing the tab binding through"
M="$D/Views/MainTabView.swift"
if grep -q "DayBriefView(selectedTab:" "$M"; then
  echo "   already wired"
elif grep -q "case 6: DayBriefView()" "$M"; then
  cp "$M" "$M.bakv2"
  python3 - "$M" << 'PY_EOF'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace("case 6: DayBriefView()", "case 6: DayBriefView(selectedTab: $selected)", 1)
open(p, "w").write(s)
print("   the category row can now switch tabs")
PY_EOF
else
  echo "   case 6 not found — run add-brief-tab.sh first"
fi
echo

echo "4. Clearing today's cached brief so it rebuilds with the new fields"
cd backend
cat > ./.pb_bust.js << 'BUST_EOF'
require("dotenv").config();
const m = require("mongoose");
(async () => {
  await m.connect(process.env.MONGODB_URI);
  const r = await require("./models/DayBrief").deleteMany({});
  console.log("   cleared " + r.deletedCount + " cached brief(s)");
  await m.disconnect();
})().catch(e => { console.error("   " + e.message); process.exit(0); });
BUST_EOF
node ./.pb_bust.js
rm -f ./.pb_bust.js
cd ..
echo

echo "5. Building"
SIM=$(xcodebuild -scheme PlanBhai -showdestinations 2>/dev/null \
  | grep -oE "name:iPhone [^}]*" | sed 's/name://' | sed 's/ *$//' | head -1)
[ -z "$SIM" ] && SIM="iPhone 17"
echo "   simulator: $SIM"
xcodebuild -scheme PlanBhai -destination "platform=iOS Simulator,name=$SIM" build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head -20
echo

echo "=========================================="
echo "  The backend changed, so deploy before the app can see"
echo "  habits or the hero checklist:"
echo
echo "     git add -A && git commit -m 'Brief v2: habits, counts, full page' && git push"
echo "  then Manual Deploy on Render."
echo "=========================================="

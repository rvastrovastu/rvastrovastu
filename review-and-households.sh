#!/usr/bin/env bash
#
# Two things, both platforms.
#
# 1. THE EVENING REVIEW ON WEB
#    Matching iOS: the sentence, the count, and what is slipping this week.
#    Only after 6 PM, and only when there is a schedule to review — a review of
#    a day with no blocks would be manufacturing something to say.
#
#    The weekly tally is the part that earns its place. One missed session is a
#    Tuesday; 0/5 is the app noticing something you would not, and it is the
#    only thing on the card you could not work out from the timeline.
#
# 2. HOUSEHOLDS ON THE HOME PAGE
#    Which household you are in changes almost everything else on the Brief —
#    meals, chores, the wall, the calendar. Burying the switch two taps deep in
#    a settings tab made the most consequential control the hardest to find.
#
#    iOS: a row under the review, opening HouseholdView as a sheet, with the
#    active household's name and "3 households · tap to switch" when there is
#    more than one.
#    Web: a row linking to /household.
#
# Usage:
#   bash ~/Downloads/review-and-households.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
D="PlanBhai/ios/PlanBhai"

echo "PlanBhai — review on web, households on Home"
echo

write() {
  local dest="$1"
  [ -f "$dest" ] && cp "$dest" "$dest.bakrh"
  cat > "$dest"
  echo "   wrote $dest"
}

echo "1. iOS"
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
    let suggestions: [Suggestion]?
    let timeline: [TimelineRow]?
    let meal: Meal?
    let family: [FamilyRow]?
    let upcoming: [UpcomingRow]?
    let habits: Habits?
    let counts: Counts?
    let calendarSyncedAt: String?

    struct Habits: Codable {
        // Your own habits — these are what the garden shows and what you can tap.
        let total: Int?
        let completedToday: Int?
        let longestStreak: Int?
        let all: [Habit]?
        // Household-wide totals, so a shared dashboard doesn't feel solitary.
        let household: HouseholdSummary?

        struct Habit: Codable, Identifiable {
            let name: String
            let streak: Int?
            let completedToday: Bool?
            let lastCompletedDate: String?
            var id: String { name }
        }

        /// Household-wide totals, shown alongside your own so a shared
        /// dashboard doesn't feel solitary.
        struct HouseholdSummary: Codable {
            let total: Int?
            let completedToday: Int?
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

    struct Suggestion: Codable, Identifiable {
        let id: String
        let kind: String?
        let icon: String?
        let title: String
        let subtitle: String?
        let cta: String?
        let deeplink: String?
        let webPath: String?
        let locked: Bool?
        /// What tapping the CTA should DO, when it is more than navigation.
        /// Only grocery_gap carries one today; the rest correctly navigate.
        let action: Action?

        struct Action: Codable {
            let type: String
            let items: [String]?
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

// MARK: - Evening review
//
// Counts come from rules; only `summary` is written by a model, and only over
// facts it was handed.

struct DayReview: Codable {
    let localDate: String
    let dayName: String?
    let summary: String
    let generatedBy: String?
    let hasSchedule: Bool
    let today: Today
    let week: Week

    struct Today: Codable {
        let scheduled: Int
        let done: Int
        let moved: Int
        let missed: [Missed]?
        let doneTitles: [String]?
    }

    struct Missed: Codable, Identifiable {
        let title: String
        let start: String?
        var id: String { title + (start ?? "") }
    }

    struct Week: Codable {
        let slipping: [Tally]?
        let consistent: [Tally]?
    }

    /// "Deep work 0/5" — a week's worth, which is what makes it worth saying.
    /// One missed day is noise.
    struct Tally: Codable, Identifiable {
        let title: String
        let done: Int
        let of: Int
        var id: String { title }
    }
}

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

    private struct ReviewResponse: Decodable {
        let success: Bool
        let review: DayReview
    }

    /// How today actually went. Personal, like the schedule itself.
    func fetchReview(householdId: String, token: String, date: String? = nil) async throws -> DayReview {
        let tz = TimeZone.current.identifier
        let enc = tz.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? tz
        var path = "\(baseURL)/api/schedule/review?scopeId=\(householdId)&tz=\(enc)"
        if let date { path += "&date=\(date)" }

        guard let url = URL(string: path) else { throw DayBriefError.server(0, "Bad URL") }
        var r = URLRequest(url: url)
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        r.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: r)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 500
        guard (200...299).contains(code) else {
            throw DayBriefError.server(code, "Couldn't load your review")
        }
        return try JSONDecoder().decode(ReviewResponse.self, from: data).review
    }

    /// Performs a suggestion's action — currently only adding missing
    /// ingredients to the grocery list.
    ///
    /// Before this, the CTA was a label on a row that merely switched tabs:
    /// "Add to list" opened a screen and added nothing.
    @discardableResult
    func runAction(_ action: DayBrief.Suggestion.Action,
                   householdId: String, token: String) async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/api/suggestions/action?scopeId=\(householdId)")
        else { return false }
        var r = URLRequest(url: url)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        r.httpBody = try? JSONSerialization.data(withJSONObject: [
            "type": action.type,
            "items": action.items ?? [],
        ])
        r.timeoutInterval = 20

        let (_, response) = try await URLSession.shared.data(for: r)
        return (200...299).contains((response as? HTTPURLResponse)?.statusCode ?? 500)
    }

    /// Toggles one of the caller's own habits.
    ///
    /// Streak arithmetic lives on the server so iOS and web agree: only
    /// today's completion is reversible, and un-checking tomorrow no longer
    /// removes a day that was legitimately earned.
    @discardableResult
    func completeHabit(name: String, done: Bool, token: String) async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/api/habits/complete") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "name": name,
            "done": done,
            "tz": TimeZone.current.identifier
        ])
        request.timeoutInterval = 15

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { return false }
        return (200...299).contains(http.statusCode)
    }
}


// MARK: - Evening review
//
// Counts come from rules; only `summary` is written by a model, and only over
// facts it was handed. Every field is optional because a day with no schedule
// is a real state, not an error.

struct DayReview: Codable {
    let localDate: String?
    let dayName: String?
    let summary: String?
    let generatedBy: String?
    let hasSchedule: Bool?
    let today: Today?
    let week: Week?

    struct Today: Codable {
        let scheduled: Int?
        let done: Int?
        let moved: Int?
        let missed: [Missed]?
        let doneTitles: [String]?

        struct Missed: Codable, Identifiable {
            let title: String
            let start: String?
            var id: String { title + (start ?? "") }
        }
    }

    struct Week: Codable {
        let slipping: [Streak]?
        let consistent: [Streak]?

        struct Streak: Codable, Identifiable {
            let title: String
            let done: Int
            let of: Int
            var id: String { title }
        }
    }
}
PLANBHAI_EOF
write "$D/Views/DayBriefView.swift" << 'PLANBHAI_EOF'
import SwiftUI

/// The Brief — "this app already understands my day".
///
/// Row order: hero, score, suggestions, timeline, Ask BhAI, upcoming, family,
/// meal, habit garden, achievements.
///
/// The vision's "Smart Life Categories" row was removed. It navigated to the
/// same tabs Ask BhAI already reaches, and a screen with a tab bar, a category
/// grid AND a prompt grid is three navigation systems competing for the same
/// taps. Ask BhAI won because verb phrases ("Plan dinner") read as things the
/// app does for you, which is the premise; noun tiles ("Meals") just restate
/// the tab bar.
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
    @State private var togglingHabit: String?
    @State private var actingSuggestion: String?
    @State private var showGroceries = false
    @State private var showFamily = false
    @State private var review: DayReview?
    @State private var showHouseholds = false
    @State private var showSchedule = false
    @State private var showCalendar = false
    @State private var bhaiPrompt = ""
    @State private var bhaiPlan: AIBhaiPlan?
    @State private var bhaiLoading = false
    @State private var bhaiError: String?
    @State private var bhaiSaving = false
    @State private var bhaiSaved = false

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
                        myDayRow(b)
                        if let r = review, r.hasSchedule { reviewCard(r) }
                        householdRow
                        if let u = b.upcoming, !u.isEmpty { upcomingCard(u) }   // 5
                        if let f = b.family, !f.isEmpty { familyCard(f) }       // 6
                        if let m = b.meal { mealCard(m) }              // 7
                        habitGarden(b)                                 // 8
                        achievements(b)                                // 9
                        footer
                        syncFooter(b)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120)
            }
            .refreshable { await load() }
        }
        .task {
            await load()
            await loadReview()
        }
        .sheet(isPresented: $showSchedule, onDismiss: { Task { await load() } }) {
            ScheduleView().environmentObject(appState)
        }
        .sheet(isPresented: $showHouseholds) {
            NavigationStack { HouseholdView() }
                .environmentObject(appState)
        }
        .sheet(isPresented: $showFamily) {
            NavigationStack { FamilyHubView() }
                .environmentObject(appState)
        }
        .sheet(isPresented: $showGroceries) {
            NavigationStack { GroceryView() }
                .environmentObject(appState)
        }
        .sheet(isPresented: $showCalendar) {
            CalendarRangeView().environmentObject(appState)
        }
        // If the household changes — first load, or the user switches — refresh.
        .onChange(of: appState.activeHouseholdId) { _ in
            Task { await load() }
        }
    }

    // MARK: - Hero

    private func heroCard(_ b: DayBrief) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    // Day and date first. It anchors everything below it in
                    // "today" — without it a dashboard could be showing any day.
                    Text(dayAndDate)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PB.soft)
                        .tracking(0.9)

                    // One line, always. "Good Morning, Test1" wrapped and left
                    // the emoji stranded on a line of its own; scaling down is
                    // less ugly than that.
                    HStack(spacing: 7) {
                        Text(salutation)
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                        Text(timeEmoji).font(.system(size: 19))
                    }

                    Text(b.greeting?.line ?? "Here's your day.")
                        .font(.system(size: 13))
                        .foregroundStyle(PB.mid)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)

                    if !countsLine(b).isEmpty {
                        Text(countsLine(b))
                            .font(.system(size: 12))
                            .foregroundStyle(PB.soft)
                            .padding(.top, 6)
                    }
                }
                Spacer(minLength: 8)

                // Same treatment as PageHeader and the old dashboard: 44pt,
                // circle-clipped, gradient stroke. Sits in the hero rather than
                // above it — a PageHeader here would stack a third heading over
                // the date and greeting.
                //
                // The old version carried an ellipsis badge opening All
                // Features. That sheet lives in DashboardView, so this is
                // non-interactive for now; a logo that looks tappable and
                // isn't is worse than one that plainly isn't.
                // The mascot has moved down beside the Ask BhAI input, where he
                // reads as the person you're asking rather than branding in the
                // corner. Only the calendar button stays up here — web reaches
                // its calendar from the nav bar, so iOS needs this entry point
                // and the two heroes cannot be pixel-identical.
                VStack(spacing: 10) {
                    Button { showCalendar = true } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(PB.mauve)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(PB.mauve.opacity(0.14)))
                            .overlay(Circle().stroke(PB.mauve.opacity(0.30), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            // The checkmark list is gone. countsLine above says the same thing
            // in one scannable row, and having both meant the hero stated the
            // day's contents twice — the same duplication web had.
            Rectangle()
                .fill(LinearGradient(colors: [PB.navy.opacity(0.5), PB.teal.opacity(0.25), .clear],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)
                .padding(.vertical, 2)

            // Ask BhAI lives INSIDE the hero, as on web — it is the thing you
            // do from here, not a separate card further down the page.
            askBhaiRow
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
        // Never an empty shell — the card only exists when there is something
        // real to suggest. "No suggestions right now" is a box that costs
        // attention and returns nothing.
        if let items = b.suggestions, !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("BhAI. suggests", icon: "lightbulb.fill", color: PB.amber)

                ForEach(items) { s in
                    Button {
                        if s.action != nil {
                            Task { await runSuggestion(s) }
                        } else {
                            open(s)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Text(s.icon ?? "💡").font(.system(size: 20))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(s.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                if let sub = s.subtitle, !sub.isEmpty {
                                    Text(sub)
                                        .font(.system(size: 11))
                                        .foregroundStyle(PB.soft)
                                }
                            }

                            Spacer(minLength: 6)

                            if s.locked == true {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(PB.muted)
                            } else if let cta = s.cta {
                                // A suggestion carrying an action gets a real
                                // button; one without keeps the label and the
                                // whole row navigates. Previously every CTA was
                                // a label on a navigating row, so "Add to list"
                                // opened a screen and added nothing.
                                Text(actingSuggestion == s.id ? "Adding…" : cta)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(s.action != nil ? PB.forest : PB.amber)
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(
                                        (s.action != nil ? PB.forest : PB.amber).opacity(0.16)))
                                    .opacity(actingSuggestion == s.id ? 0.6 : 1)
                            }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(PB.glass))
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .stroke(PB.glassBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .glassCard()
        }
    }

    /// Performs a suggestion's action, then reloads.
    ///
    /// Reload rather than optimistic patching: adding groceries changes the gap
    /// suggestion, the grocery count and the meal coverage bar at once, and
    /// guessing all three locally would drift from what the server says.
    private func runSuggestion(_ s: DayBrief.Suggestion) async {
        guard let action = s.action, actingSuggestion == nil,
              let token = appState.authToken,
              let household = appState.activeHouseholdId else { return }

        actingSuggestion = s.id
        do {
            let ok = try await DayBriefService.shared.runAction(
                action, householdId: household, token: token)
            if ok {
                await load()
                // Show where they went. Adding items and staying put leaves the
                // user to trust that something happened somewhere.
                if action.type == "add_groceries" { showGroceries = true }
            }
        } catch {
            errorText = "Couldn't do that just now."
        }
        actingSuggestion = nil
    }

    /// Routes a suggestion to the right tab. Deliberately maps known
    /// destinations rather than opening the deeplink URL — a suggestion that
    /// goes nowhere is worse than one that was never shown.
    private func open(_ s: DayBrief.Suggestion) {
        guard s.locked != true, let path = s.deeplink else { return }
        let tab: Int?
        switch true {
        case path.contains("meals"):     tab = 1
        case path.contains("habits"):    tab = 2
        case path.contains("party"):     tab = 3
        // Groceries live under Meals, not Household. Routing them to tab 4
        // sent people to a screen that does not contain the list.
        case path.contains("grocery"):   tab = 1
        case path.contains("household"): tab = 4
        case path.contains("planner"):   tab = 0
        default:                         tab = nil
        }
        if let tab { selectedTab?.wrappedValue = tab }
    }

    // MARK: - 3. Timeline

    private func timelineCard(_ rows: [DayBrief.TimelineRow]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Today's Timeline", icon: "clock.fill", color: PB.sky)

            scrollSection(maxHeight: 220) {
              VStack(alignment: .leading, spacing: 0) {
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
            }
        }
        .padding(18)
        .glassCard()
    }

    // MARK: - Households
    //
    // Reachable from Home rather than only from Me. Which household you are in
    // changes almost everything else on this screen — meals, chores, the wall,
    // the calendar — so burying the switch two taps deep in a settings tab made
    // the most consequential control the hardest to find.
    private var householdRow: some View {
        Button { showHouseholds = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "house.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PB.mauve)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(PB.mauve.opacity(0.14)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.activeHousehold?.name ?? "No household")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(householdSubtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(PB.soft)
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11)).foregroundStyle(PB.muted)
            }
            .padding(14)
            .glassCard()
        }
        .buttonStyle(.plain)
    }

    private var householdSubtitle: String {
        let n = appState.households.count
        if n == 0 { return "Create or join one" }
        if n == 1 { return "\(appState.activeHousehold?.members.count ?? 0) members" }
        return "\(n) households · tap to switch"
    }

    // MARK: - Evening review
    //
    // Only after 6 PM. A review at 9 AM is meaningless — the day has not
    // happened yet. Before then the Brief is about what is ahead; after, about
    // what actually occurred.
    private var isEvening: Bool {
        Calendar.current.component(.hour, from: Date()) >= 18
    }

    private func reviewCard(_ r: DayReview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Today's review", icon: "moon.stars.fill", color: PB.mauve)

            Text(r.summary)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Text("\(r.today.done) of \(r.today.scheduled) done")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(r.today.done == 0 ? PB.soft : PB.forest)
                if r.today.moved > 0 {
                    Text("· \(r.today.moved) moved")
                        .font(.system(size: 12))
                        .foregroundStyle(PB.muted)
                }
            }

            // A week's tally, not a day's. One missed session is a Tuesday;
            // 0/5 is the app noticing something you would not.
            if let slipping = r.week.slipping, !slipping.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("SLIPPING THIS WEEK")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PB.soft).tracking(0.8)
                        .padding(.top, 2)

                    ForEach(slipping) { t in
                        HStack {
                            Text(t.title)
                                .font(.system(size: 13))
                                .foregroundStyle(PB.mid)
                            Spacer(minLength: 8)
                            Text("\(t.done)/\(t.of)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(PB.warning)
                        }
                    }
                }
            }

            if let consistent = r.week.consistent, !consistent.isEmpty {
                HStack(spacing: 6) {
                    Text("Holding steady:")
                        .font(.system(size: 11))
                        .foregroundStyle(PB.muted)
                    Text(consistent.map(\.title).joined(separator: ", "))
                        .font(.system(size: 11))
                        .foregroundStyle(PB.forest)
                        .lineLimit(1)
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard()
    }

    private func loadReview() async {
        guard isEvening,
              let token = appState.authToken,
              let household = appState.activeHouseholdId else { return }
        review = try? await DayBriefService.shared.fetchReview(
            householdId: household, token: token)
    }

    // MARK: - My Day
    //
    // Sits under the timeline because that is what it edits. Presented as a
    // sheet rather than pushed: editing a schedule is "step aside, do a thing,
    // come back", and a sheet cannot strand you three screens from home.
    private func myDayRow(_ b: DayBrief) -> some View {
        Button { showSchedule = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "calendar.day.timeline.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PB.forest)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(PB.forest.opacity(0.14)))

                VStack(alignment: .leading, spacing: 2) {
                    Text("My Day")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(scheduleSummary(b))
                        .font(.system(size: 11))
                        .foregroundStyle(PB.soft)
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11)).foregroundStyle(PB.muted)
            }
            .padding(14)
            .glassCard()
        }
        .buttonStyle(.plain)
    }

    /// Counts only schedule rows, so the label describes what tapping edits.
    private func scheduleSummary(_ b: DayBrief) -> String {
        let n = (b.timeline ?? []).filter { $0.source == "schedule" }.count
        if n == 0 { return "Set up the shape of your day" }
        return "\(n) block\(n == 1 ? "" : "s") today · edit"
    }

    // MARK: - 4. Ask BhAI
    //
    // A real composer calling /api/ai/bhai, matching web. Previously this was a
    // grid of chips that only switched tabs — the label promised something the
    // card never did.
    private var askBhaiRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            // .center, not .top — the mascot column is image plus label, and
            // pinning the input to its top left the field floating above the
            // mascot's middle.
            HStack(alignment: .center, spacing: 12) {
                VStack(spacing: 6) {
                    Image("PlanBhaiLogo")
                        .resizable().scaledToFill()
                        .frame(width: 46, height: 46)
                        .clipShape(Circle())
                    Text("Ask BhAI.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PB.mid)
                        .fixedSize()
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        TextField("", text: $bhaiPrompt,
                                  prompt: Text("Dinner for 8 this Saturday, vegetarian")
                                    .foregroundStyle(PB.muted))
                            .font(.system(size: 13))
                            .foregroundStyle(.white)
                            .submitLabel(.go)
                            .onSubmit { Task { await askBhai() } }
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(PB.glass))
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .stroke(PB.glassBorder, lineWidth: 1))

                        Button { Task { await askBhai() } } label: {
                            if bhaiLoading {
                                ProgressView().tint(.white).frame(width: 22)
                            } else {
                                Text("Plan it")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 10).fill(PB.rose))
                        .disabled(bhaiLoading || bhaiPrompt.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity(bhaiPrompt.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                    }

                }
            }

            // Full width, below the input — not squeezed into the column beside
            // the mascot, where three phrases had about 290pt and needed more.
            //
            // Horizontally scrollable so it never truncates on a narrow phone:
            // an example clipped to "this week's mea…" teaches nothing.
            //
            // Tapping fills the field rather than sending, so the ask can be
            // edited first. That is how the shape of a good request gets learned.
            if bhaiPlan == nil {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Text("Try")
                            .font(.system(size: 12))
                            .foregroundStyle(PB.soft)

                        ForEach(Array(bhaiExamples.enumerated()), id: \.offset) { _, ex in
                            Button { bhaiPrompt = ex.1 } label: {
                                Text(ex.0)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(PB.forest)
                                    .fixedSize()
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(PB.forest.opacity(0.12)))
                                    .overlay(Capsule().stroke(PB.forest.opacity(0.28), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 3)
                }
                .padding(.top, 2)
            }

            if let bhaiError {
                Text(bhaiError)
                    .font(.system(size: 12))
                    .foregroundStyle(PB.error)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let plan = bhaiPlan, plan.hasContent {
                bhaiResult(plan)
            }
        }
    }

    @ViewBuilder
    private func bhaiResult(_ p: AIBhaiPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let summary = p.summary {
                Text(summary)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let e = p.event, let name = e.name {
                planSection("Event") {
                    Text([name, e.dateText, e.venue].compactMap { $0 }.filter { !$0.isEmpty }
                            .joined(separator: " · "))
                        .font(.system(size: 12)).foregroundStyle(PB.mid)
                }
            }

            if let menu = p.menu, !menu.isEmpty {
                planSection("Menu") {
                    ForEach(menu) { m in
                        Text("• \(m.name ?? "")").font(.system(size: 12)).foregroundStyle(PB.mid)
                    }
                }
            }

            if let g = p.groceryList, !g.isEmpty {
                planSection("Grocery list") {
                    ForEach(g) { item in
                        Text("• \(item.item ?? "")\(item.quantity.map { " (\($0))" } ?? "")")
                            .font(.system(size: 12)).foregroundStyle(PB.mid)
                    }
                }
            }

            if let b = p.budget, let total = b.estimatedTotal {
                planSection("Budget") {
                    Text("Estimated $\(Int(total))\(b.notes.map { " — \($0)" } ?? "")")
                        .font(.system(size: 12)).foregroundStyle(PB.mid)
                }
            }

            if let t = p.timeline, !t.isEmpty {
                planSection("Timeline") {
                    ForEach(t) { row in
                        Text("\(row.time ?? "") — \(row.task ?? "")")
                            .font(.system(size: 12)).foregroundStyle(PB.mid)
                    }
                }
            }

            if let c = p.checklist, !c.isEmpty {
                planSection("Checklist") {
                    ForEach(c) { row in
                        Text("☐ \(row.task ?? "")").font(.system(size: 12)).foregroundStyle(PB.mid)
                    }
                }
            }

            HStack(spacing: 12) {
                if bhaiSaved {
                    Text("✓ Added to your plan")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PB.forest)
                } else {
                    Button { Task { await saveBhaiPlan() } } label: {
                        Text(bhaiSaving ? "Adding…" : "Add this plan")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Capsule().fill(PB.forest))
                    }
                    .buttonStyle(.plain)
                    .disabled(bhaiSaving)
                }

                Button {
                    bhaiPlan = nil
                    bhaiPrompt = ""
                    bhaiSaved = false
                } label: {
                    Text("Clear")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PB.soft)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
            .padding(.top, 4)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(PB.glassBorder, lineWidth: 1))
    }

    @ViewBuilder
    private func planSection<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(PB.soft).tracking(0.8)
            content()
        }
    }

    /// Saves the plan through the server, which writes the event, its menu and
    /// the grocery list in one place. Doing it client-side — as web does —
    /// re-reads the event list and assumes the last item is yours, so a member
    /// saving at the same moment gets your menu.
    private func saveBhaiPlan() async {
        guard let plan = bhaiPlan, !bhaiSaving,
              let token = appState.authToken,
              let household = appState.activeHouseholdId else { return }

        bhaiSaving = true
        bhaiError = nil
        do {
            let ok = try await AskBhaiService.shared.save(
                plan: plan, householdId: household, token: token)
            bhaiSaved = ok
            if ok { await load() }   // grocery counts and the gap suggestion change
        } catch let DayBriefError.server(_, msg) {
            bhaiError = msg
        } catch {
            bhaiError = "Couldn't save that plan."
        }
        bhaiSaving = false
    }

    private func askBhai() async {
        let text = bhaiPrompt.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !bhaiLoading, let token = appState.authToken else { return }

        bhaiLoading = true
        bhaiError = nil
        bhaiPlan = nil
        bhaiSaved = false
        do {
            bhaiPlan = try await AskBhaiService.shared.plan(prompt: text, token: token)
        } catch let DayBriefError.server(_, msg) {
            bhaiError = msg
        } catch {
            bhaiError = "Couldn't reach BhAI. Check your connection and try again."
        }
        bhaiLoading = false
    }

    // MARK: - 5. Upcoming

    private func upcomingCard(_ rows: [DayBrief.UpcomingRow]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Upcoming", icon: "calendar", color: PB.navyLight)
            scrollSection(maxHeight: 108) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(rows) { r in
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
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard()
    }

    // MARK: - 6. Family snapshot

    private func familyCard(_ rows: [DayBrief.FamilyRow]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Family", icon: "person.3.fill", color: PB.mauve)
            scrollSection(maxHeight: 156) {
              VStack(alignment: .leading, spacing: 12) {
                ForEach(rows) { m in
                // Tappable. These rows looked like a list you could open and
                // were not — the chevron-free HStack gave no hint either way,
                // which is worse than plainly static.
                Button { showFamily = true } label: {
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

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundStyle(PB.muted)
                }
                .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                }
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

    // MARK: - 7. Meal

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

    // MARK: - 8. Habit garden

    @ViewBuilder
    private func habitGarden(_ b: DayBrief) -> some View {
        if let h = b.habits, let total = h.total, total > 0 {
            VStack(alignment: .leading, spacing: 14) {
                sectionLabel("Habit Garden", icon: "leaf.fill", color: PB.forest)

                VStack(spacing: 0) {
                    ForEach(h.all ?? []) { habit in
                          Button {
                              Task { await toggleHabit(habit) }
                          } label: {
                            // A row rather than a tile. At 9pt in a 58pt box the
                            // names were cut off, which made the whole section
                            // ambiguous — you could not tell what you were
                            // tapping.
                            HStack(spacing: 12) {
                                Text(habit.completedToday == true ? "🌸" : "🌱")
                                    .font(.system(size: 24))
                                    .opacity(habit.completedToday == true ? 1 : 0.5)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(habit.name)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(habit.completedToday == true ? PB.mid : .white)
                                        .lineLimit(1)
                                    if let st = habit.streak, st > 0 {
                                        Text("\(st) day streak")
                                            .font(.system(size: 11))
                                            .foregroundStyle(PB.forest)
                                    } else {
                                        Text("Not started")
                                            .font(.system(size: 11))
                                            .foregroundStyle(PB.muted)
                                    }
                                }

                                Spacer(minLength: 0)

                                Image(systemName: habit.completedToday == true
                                        ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20))
                                    .foregroundStyle(habit.completedToday == true ? PB.forest : PB.muted)
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                          }
                      .buttonStyle(.plain)
                      .disabled(togglingHabit != nil)
                      .opacity(togglingHabit == habit.name ? 0.5 : 1)
                    }
                }

                Text("Tap one to mark it done")
                    .font(.system(size: 11))
                    .foregroundStyle(PB.muted)

                HStack(spacing: 5) {
                    Text("\(h.completedToday ?? 0) of \(total) blooming today")
                        .font(.system(size: 12))
                        .foregroundStyle(PB.soft)
                    if let hh = h.household, let ht = hh.total, ht > total {
                        Text("· household \(hh.completedToday ?? 0)/\(ht)")
                            .font(.system(size: 12))
                            .foregroundStyle(PB.muted)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .glassCard()
        }
    }

    // MARK: - 9. Achievements

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

    /// One scannable line, matching web. A stacked checklist competed with the
    /// timeline below it, which is also a list.
    private func countsLine(_ b: DayBrief) -> String {
        var parts: [String] = []
        if let c = b.counts {
            if let e = c.events, e > 0 { parts.append("\(e) event\(e == 1 ? "" : "s")") }
            if let m = c.meals, m > 0 { parts.append("\(m) meals") }
        }
        if let h = b.habits, let total = h.total, total > 0 {
            parts.append("\(h.completedToday ?? 0) of \(total) habits")
        }
        if let c = b.counts, let ch = c.choresOpen, ch > 0 {
            parts.append("\(ch) chore\(ch == 1 ? "" : "s")")
        }
        return parts.joined(separator: " · ")
    }

    /// "FRIDAY, JULY 31" — taken from the brief's localDate, not the device
    /// clock. Those disagree around midnight and while travelling, and showing
    /// a date that doesn't match the data underneath it is worse than showing none.
    private var dayAndDate: String {
        let iso = DateFormatter()
        iso.dateFormat = "yyyy-MM-dd"
        iso.locale = Locale(identifier: "en_US_POSIX")
        iso.timeZone = TimeZone(identifier: brief?.tz ?? TimeZone.current.identifier)

        let date = brief.flatMap { iso.date(from: $0.localDate) } ?? Date()

        let out = DateFormatter()
        out.dateFormat = "EEEE, MMMM d"
        out.timeZone = iso.timeZone
        return out.string(from: date).uppercased()
    }

    /// Changes through the day. The server sends timeOfDay; currentTimeOfDay is
    /// the fallback, and it also produces "night" after 9 PM.
    ///
    /// Evening was a cityscape emoji, which reads as a building rather than a
    /// time of day.
    private var timeEmoji: String {
        switch brief?.greeting?.timeOfDay ?? currentTimeOfDay {
        case "morning":   return "☀️"
        case "afternoon": return "🌤"
        case "evening":   return "🌙"
        default:          return "💤"
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

    /// Caps a section at roughly three rows and scrolls the rest.
    ///
    /// Indicators stay visible even when everything fits — otherwise a section
    /// with exactly four items looks complete at three, and the user never
    /// learns there's more.
    private func scrollSection<C: View>(maxHeight: CGFloat, @ViewBuilder _ content: () -> C) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            content()
        }
        .frame(maxHeight: maxHeight)
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

    /// Toggles one of your own habits.
    ///
    /// Optimistic — the flower changes immediately and reverts on failure. A tap
    /// that appears to do nothing for 300ms feels broken. The streak arithmetic
    /// is the server's, so iOS and web can't drift apart on what a streak means.
    private func toggleHabit(_ habit: DayBrief.Habits.Habit) async {
        guard togglingHabit == nil, let token = appState.authToken else { return }
        let next = !(habit.completedToday ?? false)
        togglingHabit = habit.name

        applyHabit(named: habit.name, completed: next,
                   streak: max((habit.streak ?? 0) + (next ? 1 : -1), 0))

        do {
            let ok = try await DayBriefService.shared.completeHabit(
                name: habit.name, done: next, token: token)
            if !ok { throw DayBriefError.server(0, "rejected") }
        } catch {
            // Put it back rather than leaving a flower that lies.
            applyHabit(named: habit.name,
                       completed: habit.completedToday ?? false,
                       streak: habit.streak ?? 0)
        }
        togglingHabit = nil
    }

    private func applyHabit(named name: String, completed: Bool, streak: Int) {
        guard let b = brief, let h = b.habits, let all = h.all else { return }
        let updated = all.map { item -> DayBrief.Habits.Habit in
            guard item.name == name else { return item }
            return .init(name: item.name, streak: streak,
                         completedToday: completed,
                         lastCompletedDate: item.lastCompletedDate)
        }
        brief = DayBrief(
            localDate: b.localDate, tz: b.tz, state: b.state, greeting: b.greeting,
            readiness: b.readiness, signals: b.signals, suggestions: b.suggestions,
            timeline: b.timeline, meal: b.meal, family: b.family, upcoming: b.upcoming,
            habits: .init(total: h.total,
                          completedToday: updated.filter { $0.completedToday == true }.count,
                          longestStreak: h.longestStreak, all: updated,
                          household: h.household),
            counts: b.counts, calendarSyncedAt: b.calendarSyncedAt)
    }

    // MARK: - Footer

    /// Sits below everything, quiet by design. A copyright line should be
    /// findable, not part of the day.
    private var footer: some View {
        VStack(spacing: 4) {
            Text("PlanBhai.")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(PB.muted)
            Text("© \(currentYear) PlanBhai. All rights reserved.")
                .font(.system(size: 10))
                .foregroundStyle(PB.muted.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 26)
        .padding(.bottom, 8)
    }

    private var currentYear: String {
        String(Calendar.current.component(.year, from: Date()))
    }

    // MARK: - Load

    private func load() async {
        guard let token = appState.authToken else {
            errorText = "You need to sign in."; isLoading = false; return
        }

        // RootView sets activeHouseholdId inside fetchMyHouseholds(), which runs
        // in its own Task. This view's .task fires when it appears — concurrently
        // with that chain, not after it. Checking once loses the race whenever
        // the households call is slow, which showed up as an intermittent
        // "No household selected yet." Wait briefly instead of guessing.
        var household = appState.activeHouseholdId
        var waited = 0
        while household == nil && waited < 6000 {
            try? await Task.sleep(nanoseconds: 200_000_000)
            waited += 200
            household = appState.activeHouseholdId
        }

        guard let household else {
            errorText = "No household selected yet. Pull down to retry."
            isLoading = false
            return
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

n=$(grep -c "struct DayReview: Codable" "$D/DayBriefModels.swift")
[ "$n" = "1" ] && echo "   ok   one DayReview" \
  || { echo "   $n copies — reverting"; cp "$D/DayBriefModels.swift.bakrh" "$D/DayBriefModels.swift"; exit 1; }
grep -q "householdRow" "$D/Views/DayBriefView.swift" && echo "   ok   household row"
grep -q "actingSuggestion: String?" "$D/Views/DayBriefView.swift" && echo "   ok   actingSuggestion kept"
echo

echo "2. Web"
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

  // Only after 6 PM. A review at 9 AM is meaningless — the day has not
  // happened. Before then the Brief is about what is ahead; after, about what
  // occurred.
  useEffect(() => {
    if (!scopeId || new Date().getHours() < 18) return;
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
          <div className="brief-label">TODAY'S REVIEW</div>

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

if grep -q "fetchDayReview" web/src/api.js; then
  echo "   api method already present"
else
  cp web/src/api.js web/src/api.js.bakrh
  python3 - web/src/api.js << 'PY_EOF'
import sys
p = sys.argv[1]
s = open(p).read()
anchor = "  // ---- Auth ----"
if anchor not in s:
    print("   ERROR: Auth section not found"); sys.exit(2)
add = """  // ---- Day review ----
  fetchDayReview: (scopeId, tz) =>
    request(`/api/schedule/review?scopeId=${scopeId}&tz=${encodeURIComponent(tz)}`, { auth: true }),

"""
s = s.replace(anchor, add + anchor, 1)
open(p, "w").write(s)
print("   added api.fetchDayReview")
PY_EOF
  [ $? -ne 0 ] && { cp web/src/api.js.bakrh web/src/api.js; exit 1; }
fi

if grep -q "review-summary" web/src/styles.css; then
  echo "   styles already present"
else
  cp web/src/styles.css web/src/styles.css.bakrh
  python3 - web/src/styles.css << 'PY_EOF'
import sys
p = sys.argv[1]
s = open(p).read()
i = s.find("\n/* ---------- Home hero ---------- */")
if i == -1:
    print("   ERROR: hero block not found"); sys.exit(2)
open(p, "w").write(s[:i])
PY_EOF
  [ $? -ne 0 ] && { cp web/src/styles.css.bakrh web/src/styles.css; exit 1; }
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
PLANBHAI_EOF
  echo "   styles appended"
fi
echo

echo "3. Builds"
SIM=$(xcodebuild -scheme PlanBhai -showdestinations 2>/dev/null \
  | grep -oE "name:iPhone [^}]*" | sed 's/name://' | sed 's/ *$//' | head -1)
[ -z "$SIM" ] && SIM="iPhone 17"
xcodebuild -scheme PlanBhai -destination "platform=iOS Simulator,name=$SIM" build 2>&1 \
  | grep -E "error:|failures\)|BUILD (SUCCEEDED|FAILED)" | head -12
(cd web && npm run build 2>&1 | grep -E "ERROR|error during|✓ built" | head -4)
echo

echo "=========================================="
echo "  Deploy:"
echo "     git add -A && git commit -m 'Review on web; households on Home' && git push"
echo "     then cd web && vercel --prod"
echo
echo "  The review only shows after 6 PM. On web the household row uses"
echo "  b.householdName, which the brief may not carry — if it reads"
echo "  \"Household\", that field needs adding server-side."
echo "=========================================="

#!/usr/bin/env bash
#
# Installs Phase 1: the DayBrief dashboard.
#
# Adds two NEW files. Nothing existing is modified — DashboardView.swift (1,767
# lines, in daily use) is untouched, so you can run both and compare on device
# before deciding which wins.
#
#   DayBriefModels.swift  Codable models + the API call
#   DayBriefView.swift    greeting, readiness ring, signals, timeline, meal,
#                         upcoming, and the empty state
#
# Uses your existing tokens: PB.*, Color(hex:), the charcoal gradient. Targets
# iOS 15+ APIs only, since the codebase still has #available(iOS 17) checks.
#
# Usage:
#   bash ~/Downloads/install-phase1.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
D="PlanBhai/ios/PlanBhai"
[ -d "$D/Views" ] || { echo "ERROR: $D/Views not found"; exit 1; }

echo "PlanBhai — installing Phase 1"
echo

echo "1. Checking what this depends on"
for pair in "PB.glass:AuthView.swift" "PB.success:AuthView.swift" "activeHouseholdId:AppState.swift" "authToken:AppState.swift"; do
  name="${pair%%:*}"; file="${pair##*:}"
  target="$D/$file"
  [ -f "$target" ] || target="$D/Views/$file"
  if grep -q "${name#PB.}" "$target" 2>/dev/null; then
    echo "   ok   $name"
  else
    echo "   MISSING $name in $file — stopping"
    exit 1
  fi
done
echo

echo "2. Writing files"
write() {
  local dest="$1"
  [ -f "$dest" ] && cp "$dest" "$dest.bakp1" && echo "   backed up $dest"
  cat > "$dest"
  echo "   wrote $dest"
}

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
    let calendarSyncedAt: String?

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

/// Phase 1 dashboard: greeting, readiness ring, signal chips, timeline.
///
/// Deliberately a NEW view rather than a replacement for DashboardView — that
/// file is 1,767 lines and in daily use. Run both, compare on device, then
/// decide.
///
/// The premise is "your Bhai already planned your day", so this leads with what
/// IS handled. Readiness measures how much of today is planned and covered, not
/// how much is done — which is why it can honestly read 79% at 7 AM.
struct DayBriefView: View {
    @EnvironmentObject var appState: AppState

    @State private var brief: DayBrief?
    @State private var isLoading = true
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "0F0F1A"), Color(hex: "0F172A"), Color(hex: "111827")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ).ignoresSafeArea()

                blob(PB.navy, 300, x: 150, y: -140, blur: 70, op: 0.18)
                blob(PB.teal, 240, x: -120, y: 320, blur: 60, op: 0.10)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        greetingBlock

                        if isLoading && brief == nil {
                            ProgressView().tint(.white).padding(.top, 60)
                        } else if let errorText {
                            errorCard(errorText)
                        } else if let brief {
                            content(for: brief)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 40)
                }
                .refreshable { await load() }
            }
            .navigationBarHidden(true)
        }
        .task { await load() }
    }

    // MARK: - Sections

    private var greetingBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(salutation)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            // The server never sends a personal name — the brief is shared across
            // the household — so the greeting is composed here and the line below
            // stays household-scoped.
            Text(brief?.greeting?.line ?? "Getting your day together…")
                .font(.system(size: 14))
                .foregroundStyle(PB.mid)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
    }

    @ViewBuilder
    private func content(for b: DayBrief) -> some View {
        if b.state == "empty" {
            emptyState
        } else {
            if let r = b.readiness { readinessCard(r) }

            if let signals = b.signals, !signals.isEmpty {
                signalStrip(signals)
            }

            if let rows = b.timeline, !rows.isEmpty {
                timelineCard(rows)
            }

            if let meal = b.meal { mealCard(meal) }

            if let up = b.upcoming, !up.isEmpty { upcomingCard(up) }

            if let synced = b.calendarSyncedAt {
                // Web's timeline is only as fresh as the last iOS sync, so
                // staleness is shown rather than hidden.
                Text("Calendar synced \(relativeSync(synced))")
                    .font(.system(size: 11))
                    .foregroundStyle(PB.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: Readiness

    private func readinessCard(_ r: DayBrief.Readiness) -> some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: CGFloat(max(0, min(100, r.score))) / 100)
                    .stroke(
                        AngularGradient(
                            colors: [ringColor(r.score), ringColor(r.score).opacity(0.55)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.8), value: r.score)

                VStack(spacing: 0) {
                    Text("\(r.score)")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PB.soft)
                }
            }
            .frame(width: 86, height: 86)

            VStack(alignment: .leading, spacing: 6) {
                Text(r.label)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                // Never show a bare number with no explanation — pair it with the
                // weakest applicable domain so the score means something.
                if let w = r.weakest, let reason = w.reason, !reason.isEmpty {
                    Text(reason)
                        .font(.system(size: 12))
                        .foregroundStyle(PB.soft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .glassCard()
    }

    private func ringColor(_ score: Int) -> Color {
        switch score {
        case 80...:  return PB.success
        case 60..<80: return PB.sky
        case 40..<60: return PB.warning
        default:      return PB.error
        }
    }

    // MARK: Signals

    private func signalStrip(_ signals: [DayBrief.Signal]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(signals.prefix(7)) { s in
                    HStack(spacing: 6) {
                        if let icon = s.icon { Text(icon).font(.system(size: 13)) }
                        Text(s.text)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(PB.mid)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(PB.glass))
                    .overlay(Capsule().stroke(PB.glassBorder, lineWidth: 1))
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: Timeline

    private func timelineCard(_ rows: [DayBrief.TimelineRow]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Today", icon: "clock.fill", color: PB.sky)

            ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                HStack(alignment: .top, spacing: 12) {
                    Text(row.start)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(row.isNow == true ? PB.teal : PB.muted)
                        .frame(width: 44, alignment: .leading)

                    VStack(spacing: 0) {
                        Circle()
                            .fill(row.isNow == true ? PB.teal : kindColor(row.kind))
                            .frame(width: 8, height: 8)
                        if idx < rows.count - 1 {
                            Rectangle()
                                .fill(Color.white.opacity(0.10))
                                .frame(width: 1.5)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: 8)

                    HStack(spacing: 7) {
                        if let icon = row.icon { Text(icon).font(.system(size: 12)) }
                        Text(row.title)
                            .font(.system(size: 14, weight: row.isNow == true ? .bold : .medium))
                            .foregroundStyle(row.isNow == true ? .white : PB.mid)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.bottom, 16)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .glassCard()
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

    // MARK: Meal

    private func mealCard(_ meal: DayBrief.Meal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(meal.slot?.capitalized ?? "Dinner", icon: "fork.knife", color: PB.amber)

            Text(meal.title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            if let missing = meal.missing, !missing.isEmpty {
                Text("Missing: \(missing.joined(separator: ", "))")
                    .font(.system(size: 12))
                    .foregroundStyle(PB.warning)
            } else if meal.haveRatio == nil {
                // Pantry data doesn't exist, so ingredient coverage is genuinely
                // unknown. Saying nothing beats implying everything's on hand.
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard()
    }

    // MARK: Upcoming

    private func upcomingCard(_ rows: [DayBrief.UpcomingRow]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Coming up", icon: "calendar", color: PB.mauve)

            ForEach(rows.prefix(5)) { r in
                HStack(spacing: 10) {
                    Text(r.day)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PB.soft)
                        .frame(width: 78, alignment: .leading)
                    if let icon = r.icon { Text(icon).font(.system(size: 12)) }
                    Text(r.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(PB.mid)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard()
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Let's set up your day")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            // An empty state that pretends is worse than one that asks.
            Text("Add a meal plan, a few habits, or connect your calendar — then this screen fills itself in.")
                .font(.system(size: 13))
                .foregroundStyle(PB.soft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard()
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
            Button {
                Task { await load() }
            } label: {
                Text("Try again")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PB.sky)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard()
    }

    // MARK: - Helpers

    private var salutation: String {
        let part = brief?.greeting?.timeOfDay ?? currentTimeOfDay
        let name = appState.currentUser?.name
            ?? UserDefaults.standard.string(forKey: "userName")
            ?? ""
        let base = "Good \(part.capitalized)"
        return name.isEmpty ? base : "\(base), \(name)"
    }

    private var currentTimeOfDay: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case ..<12: return "morning"
        case ..<17: return "afternoon"
        case ..<21: return "evening"
        default:    return "night"
        }
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

    private func sectionLabel(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(PB.soft)
                .tracking(0.8)
        }
        .padding(.bottom, 12)
    }

    private func blob(_ c: Color, _ s: CGFloat, x: CGFloat, y: CGFloat, blur: CGFloat, op: Double) -> some View {
        Circle().fill(c.opacity(op)).frame(width: s, height: s)
            .offset(x: x, y: y).blur(radius: blur).allowsHitTesting(false)
    }

    // MARK: - Load

    private func load() async {
        guard let token = appState.authToken else {
            errorText = DayBriefError.notSignedIn.localizedDescription
            isLoading = false
            return
        }
        guard let household = appState.activeHouseholdId else {
            errorText = DayBriefError.noHousehold.localizedDescription
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

// MARK: - Card styling

private extension View {
    func glassCard() -> some View {
        self
            .background(RoundedRectangle(cornerRadius: 18).fill(PB.glass))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(PB.glassBorder, lineWidth: 1))
    }
}
PLANBHAI_EOF


echo
echo "3. Parsing"
if command -v swiftc >/dev/null 2>&1; then
  for f in "$D/DayBriefModels.swift" "$D/Views/DayBriefView.swift"; do
    swiftc -parse "$f" >/dev/null 2>&1 && echo "   ok   $(basename "$f")" \
      || echo "   parse issues in $(basename "$f") (type errors only show in a full build)"
  done
fi
echo

echo "4. Building"
SIM=$(xcrun simctl list devices available 2>/dev/null \
  | grep -E "^ +iPhone" | sed 's/ (.*//' | sed 's/^ *//' | head -1)
[ -z "$SIM" ] && SIM="iPhone 17"
echo "   simulator: $SIM"
xcodebuild -scheme PlanBhai -destination "platform=iOS Simulator,name=$SIM" build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head -20
echo

echo "=========================================="
echo "  To see it, add a tab in MainTabView.swift:"
echo
echo "      DayBriefView()"
echo "          .tabItem { Label(\"Brief\", systemImage: \"sparkles\") }"
echo
echo "  Remove the old files with:"
echo "     rm $D/DayBriefModels.swift $D/Views/DayBriefView.swift"
echo "=========================================="

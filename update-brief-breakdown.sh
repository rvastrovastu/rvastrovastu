#!/usr/bin/env bash
#
# Adds the readiness breakdown to DayBriefView.
#
# The first version rendered only the WEAKEST domain's reason — one line. The
# per-domain scores and the "not counted" list were missing entirely.
#
# Now: tap "Why this score?" under the ring to expand
#
#     Calendar   100  Your schedule has room to breathe
#     Meals       60  Homemade Pizza planned for dinner
#     Family      70  6 chores still open
#     Not counted: groceries, habits, finance
#
# Collapsed by default so the five-second read stays a ring and a sentence, but
# one tap away — a score you can't interrogate is just a number to distrust.
#
# Only DayBriefView.swift changes.
#
# Usage:
#   bash ~/Downloads/update-brief-breakdown.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
D="PlanBhai/ios/PlanBhai/Views"
[ -d "$D" ] || { echo "ERROR: $D not found"; exit 1; }

echo "PlanBhai — adding the readiness breakdown"
echo

DEST="$D/DayBriefView.swift"
[ -f "$DEST" ] && cp "$DEST" "$DEST.bakbd" && echo "   backed up $DEST"

cat > "$DEST" << 'PLANBHAI_EOF'
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
    @State private var showBreakdown = false
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
      VStack(alignment: .leading, spacing: 0) {
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

        // Per-domain detail. Collapsed by default so the five-second read stays
        // a ring and a sentence — but one tap away, because a score you can't
        // interrogate is just a number to distrust.
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
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(breakdown.filter { $0.applicable }, id: \.domain) { d in
                        HStack(alignment: .top, spacing: 10) {
                            Text(d.domain.capitalized)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(PB.mid)
                                .frame(width: 74, alignment: .leading)

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

                    // Domains the household doesn't use are excluded from the
                    // score entirely and re-weighted, so nobody is penalised for
                    // features they've never touched. Worth saying out loud.
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
      .padding(16)
      .glassCard()
    }

    private func notCounted(_ breakdown: [DayBrief.Readiness.Domain]) -> String {
        breakdown.filter { !$0.applicable }.map { $0.domain }.joined(separator: ", ")
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
echo "   wrote $DEST"
echo

echo "Verifying"
grep -q "showBreakdown" "$DEST" && echo "   ok   breakdown toggle present"
grep -q "notCounted" "$DEST"    && echo "   ok   not-counted list present"
if command -v swiftc >/dev/null 2>&1; then
  swiftc -parse "$DEST" >/dev/null 2>&1 && echo "   ok   parses" \
    || echo "   parse issues (type errors only show in a full build)"
fi
echo

echo "Building"
SIM=$(xcrun simctl list devices available 2>/dev/null \
  | grep -E "^ +iPhone" | sed 's/ (.*//' | sed 's/^ *//' | head -1)
[ -z "$SIM" ] && SIM="iPhone 17"
echo "   simulator: $SIM"
xcodebuild -scheme PlanBhai -destination "platform=iOS Simulator,name=$SIM" build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head -15
echo

echo "=========================================="
echo "  Revert:  cp $DEST.bakbd $DEST"
echo "=========================================="

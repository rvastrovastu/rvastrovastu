#!/usr/bin/env bash
#
# Adds the PlanBhai logo to the Brief.
#
# Matched to the existing treatment — 44pt, circle-clipped, navy/teal/mauve
# gradient stroke, soft shadow. PageHeader uses 48pt and the old dashboard used
# 42pt; both share the same styling.
#
# Placed inside the hero card's top-right rather than as a PageHeader above it.
# A PageHeader here would stack "PlanBhai." over "FRIDAY, JULY 31" over "Good
# Morning, Rit" — three headings before any content, on a page already carrying
# ten sections. The time-of-day emoji moves next to the greeting.
#
# NOT CARRIED OVER: the old logo had an ellipsis badge that opened the All
# Features sheet. That sheet lives in DashboardView, so this logo is
# non-interactive — something that looks tappable and isn't is worse than
# something that plainly isn't. Say the word and the sheet can move too.
#
# Only DayBriefView.swift changes.
#
# Usage:
#   bash ~/Downloads/add-logo.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
DEST="PlanBhai/ios/PlanBhai/Views/DayBriefView.swift"
[ -f "$DEST" ] || { echo "ERROR: $DEST not found"; exit 1; }

echo "PlanBhai — adding the logo"
echo

echo "1. Checking the asset exists"
if [ -d "PlanBhai/ios/PlanBhai/Assets.xcassets/PlanBhaiLogo.imageset" ]; then
  echo "   ok   PlanBhaiLogo.imageset"
else
  echo "   MISSING PlanBhaiLogo.imageset — Image(\"PlanBhaiLogo\") would render blank"
  exit 1
fi
echo

echo "2. Writing"
cp "$DEST" "$DEST.baklogo"
cat > "$DEST" << 'PLANBHAI_EOF'
import SwiftUI

/// The Brief — "this app already understands my day".
///
/// Row order follows the product vision: hero, score, suggestions, timeline,
/// categories, Ask BhAI, upcoming, family, meal, habit garden, achievements.
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
                        askBhaiCard                                    // 5 — Ask BhAI
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
                    // Day and date first. It anchors everything below it in
                    // "today" — without it a dashboard could be showing any day.
                    Text(dayAndDate)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PB.soft)
                        .tracking(0.9)

                    HStack(spacing: 7) {
                        Text(salutation)
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text(timeEmoji).font(.system(size: 20))
                    }

                    Text(b.greeting?.line ?? "Here's your day.")
                        .font(.system(size: 13))
                        .foregroundStyle(PB.mid)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 1)
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
                Image("PlanBhaiLogo")
                    .resizable().scaledToFit()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(
                        LinearGradient(colors: [PB.navy, PB.teal, PB.mauve],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 2))
                    .shadow(color: PB.navy.opacity(0.55), radius: 10, y: 3)
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
        // Never an empty shell — the card only exists when there is something
        // real to suggest. "No suggestions right now" is a box that costs
        // attention and returns nothing.
        if let items = b.suggestions, !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("Bhai suggests", icon: "lightbulb.fill", color: PB.amber)

                ForEach(items) { s in
                    Button {
                        open(s)
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
                                Text(cta)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(PB.amber)
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(PB.amber.opacity(0.14)))
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
        case path.contains("household"), path.contains("grocery"): tab = 4
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

    // MARK: - 5. Ask BhAI

    private var askBhaiCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Ask BhAI", icon: "sparkles", color: PB.amber)

            // Two columns rather than a horizontal strip: side-scrolling hides
            // options behind a gesture nobody knows to make, and these are the
            // things the app can actually do for you.
            scrollSection(maxHeight: 150) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8),
                                    GridItem(.flexible(), spacing: 8)],
                          spacing: 8) {
                    ForEach(prompts, id: \.text) { p in
                        Button {
                            selectedTab?.wrappedValue = p.tab
                        } label: {
                            HStack(spacing: 6) {
                                Text(p.icon).font(.system(size: 13))
                                Text(p.text)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(PB.mid)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 12).fill(PB.glass))
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(p.color.opacity(0.30), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.trailing, 4)
            }
        }
        .padding(18)
        .glassCard()
    }

    /// Each prompt routes to the screen that actually performs it.
    ///
    /// There is no Ask BhAI conversation view yet, and a chip that opens a chat
    /// which can't do anything would be worse than one that takes you straight
    /// to the planner. When a compose screen exists, these become its seed text.
    private struct Prompt {
        let icon: String
        let text: String
        let tab: Int
        let color: Color
    }

    private var prompts: [Prompt] {
        [Prompt(icon: "🍽", text: "Plan dinner",       tab: 1, color: PB.teal),
         Prompt(icon: "📅", text: "Schedule my week",  tab: 1, color: PB.teal),
         Prompt(icon: "📖", text: "Find recipes",      tab: 1, color: PB.teal),
         Prompt(icon: "🛒", text: "Grocery list",      tab: 4, color: PB.navy),
         Prompt(icon: "🎂", text: "Organize a party",  tab: 3, color: PB.rose),
         Prompt(icon: "💪", text: "Build a habit",     tab: 2, color: PB.forest),
         Prompt(icon: "💰", text: "Split expenses",    tab: 4, color: PB.amber),
         Prompt(icon: "👨‍👩‍👧", text: "Family plans",     tab: 4, color: PB.mauve)]
    }

    // MARK: - 6. Upcoming

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

    // MARK: - 7. Family snapshot

    private func familyCard(_ rows: [DayBrief.FamilyRow]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Family", icon: "person.3.fill", color: PB.mauve)
            scrollSection(maxHeight: 156) {
              VStack(alignment: .leading, spacing: 12) {
                ForEach(rows) { m in
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

                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(h.all ?? []) { habit in
                            VStack(spacing: 4) {
                                Text(habit.completedToday == true ? "🌸" : "🌱")
                                    .font(.system(size: 26))
                                    .opacity(habit.completedToday == true ? 1 : 0.45)
                                // The habit name matters more than a streak of 0 —
                                // a row of bare zeros reads as failure rather than
                                // as "not yet today".
                                Text(habit.name)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(habit.completedToday == true ? PB.mid : PB.muted)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .frame(width: 58)
                                if let st = habit.streak, st > 0 {
                                    Text("\(st)d")
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .foregroundStyle(PB.forest)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 4)
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
echo "   wrote $DEST"
grep -q 'Image("PlanBhaiLogo")' "$DEST" && echo "   logo present"
echo

echo "3. Building"
SIM=$(xcodebuild -scheme PlanBhai -showdestinations 2>/dev/null \
  | grep -oE "name:iPhone [^}]*" | sed 's/name://' | sed 's/ *$//' | head -1)
[ -z "$SIM" ] && SIM="iPhone 17"
echo "   simulator: $SIM"
xcodebuild -scheme PlanBhai -destination "platform=iOS Simulator,name=$SIM" build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head -15
echo

echo "=========================================="
echo "  No backend change — no deploy needed."
echo "  Revert:  cp $DEST.baklogo $DEST"
echo "=========================================="

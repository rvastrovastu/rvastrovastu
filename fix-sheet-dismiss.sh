#!/usr/bin/env bash
#
# Adds a Done button to My Day and the Calendar.
#
# THE BUG
#   Both views carry .navigationBarHidden(true) — correct when they were meant
#   as full screens, wrong now they are presented as sheets. No toolbar, no
#   back button, and swipe-down-to-dismiss is a gesture plenty of people never
#   try. Once you opened My Day you were stuck there.
#
#   BlockEditor was fine — it has a real toolbar with Cancel and Save.
#
# THE FIX
#   A Done button pinned to the top via safeAreaInset, so it stays put while the
#   content scrolls under it.
#
# Only ScheduleView.swift and CalendarRangeView.swift change.
#
# Usage:
#   bash ~/Downloads/fix-sheet-dismiss.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
D="PlanBhai/ios/PlanBhai/Views"
[ -d "$D" ] || { echo "ERROR: $D not found"; exit 1; }

echo "PlanBhai — a way out of the sheets"
echo

write() {
  local dest="$1"
  [ -f "$dest" ] && cp "$dest" "$dest.bakdismiss"
  cat > "$dest"
  echo "   wrote $dest"
}

write "$D/ScheduleView.swift" << 'PLANBHAI_EOF'
import SwiftUI

/// Create and manage schedule blocks.
///
/// A list plus an edit sheet, deliberately — not drag-and-drop. Dragging is the
/// single most expensive thing in the schedule spec (gestures, collision,
/// auto-scroll, undo, twice over for two platforms) and a sheet delivers most
/// of the value. Worth adding once people are actually using schedules.
struct ScheduleView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var blocks: [ScheduleBlock] = []
    @State private var loading = true
    @State private var errorText: String?
    @State private var editing: ScheduleBlock?
    @State private var showingNew = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "0F0F1A"), Color(hex: "0F172A"), Color(hex: "111827")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ).ignoresSafeArea()

                blob(PB.navy, 300, x: 150, y: -140, blur: 70, op: 0.18)
                blob(PB.forest, 220, x: -110, y: 320, blur: 60, op: 0.12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        PageHeader(icon: "calendar.day.timeline.left",
                                   title: "My Day",
                                   subtitle: "The shape of your typical day",
                                   color: PB.forest)
                            .padding(.top, 8)

                        if loading && blocks.isEmpty {
                            ProgressView().tint(.white).padding(.top, 40)
                        } else if let errorText {
                            card { Text(errorText).font(.system(size: 13)).foregroundStyle(PB.soft) }
                        } else if blocks.isEmpty {
                            emptyState
                        } else {
                            ForEach(sorted) { block in
                                Button { editing = block } label: { row(block) }
                                    .buttonStyle(.plain)
                            }
                        }

                        Button { showingNew = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add a block").font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(PB.forest)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 16).fill(PB.forest.opacity(0.12)))
                            .overlay(RoundedRectangle(cornerRadius: 16)
                                .stroke(PB.forest.opacity(0.30), lineWidth: 1))
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 120)
                }
                .refreshable { await load() }
            }
            .navigationBarHidden(true)
            .safeAreaInset(edge: .top) {
                // Presented as a sheet, so there is no back button. Without an
                // explicit control the only way out is a swipe most people
                // never try.
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Text("Done")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(PB.teal)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(PB.glass))
                            .overlay(Capsule().stroke(PB.glassBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
        .task { await load() }
        .sheet(isPresented: $showingNew) {
            BlockEditor(block: nil) { await load() }
                .environmentObject(appState)
        }
        .sheet(item: $editing) { block in
            BlockEditor(block: block) { await load() }
                .environmentObject(appState)
        }
    }

    private var sorted: [ScheduleBlock] {
        blocks.sorted { $0.startTime < $1.startTime }
    }

    private func row(_ b: ScheduleBlock) -> some View {
        HStack(spacing: 12) {
            Text(blockEmoji(b.kind)).font(.system(size: 20))

            VStack(alignment: .leading, spacing: 3) {
                Text(b.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(b.active ? .white : PB.muted)
                Text("\(display(b.startTime))–\(display(b.endTime)) · \(b.recurrenceLabel)")
                    .font(.system(size: 11))
                    .foregroundStyle(PB.soft)
            }

            Spacer(minLength: 0)

            if !b.active {
                Text("Paused")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PB.muted)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11)).foregroundStyle(PB.muted)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(PB.glass))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(PB.glassBorder, lineWidth: 1))
    }

    private var emptyState: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Text("No blocks yet")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                // Honest about what this is for: the shape of a normal day, not
                // a to-do list. That distinction is the whole point.
                Text("Add the things that happen most days — a morning routine, focus time, dinner. They'll appear on your Brief and calendar.")
                    .font(.system(size: 13))
                    .foregroundStyle(PB.soft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 18).fill(PB.glass))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(PB.glassBorder, lineWidth: 1))
    }

    private func blob(_ c: Color, _ s: CGFloat, x: CGFloat, y: CGFloat, blur: CGFloat, op: Double) -> some View {
        Circle().fill(c.opacity(op)).frame(width: s, height: s)
            .offset(x: x, y: y).blur(radius: blur).allowsHitTesting(false)
    }

    /// "19:00" -> "7 PM". The server stores 24h; the app shows 12h everywhere.
    private func display(_ hhmm: String) -> String {
        let p = hhmm.split(separator: ":").compactMap { Int($0) }
        guard p.count == 2 else { return hhmm }
        let suffix = p[0] < 12 ? "AM" : "PM"
        let h = p[0] % 12 == 0 ? 12 : p[0] % 12
        return p[1] == 0 ? "\(h) \(suffix)" : String(format: "%d:%02d %@", h, p[1], suffix)
    }

    private func load() async {
        guard let token = appState.authToken,
              let household = appState.activeHouseholdId else {
            errorText = "Sign in and pick a household first."
            loading = false
            return
        }
        loading = true
        errorText = nil
        do {
            blocks = try await ScheduleService.shared.fetchBlocks(householdId: household, token: token)
        } catch {
            errorText = error.localizedDescription
        }
        loading = false
    }
}
PLANBHAI_EOF
write "$D/CalendarRangeView.swift" << 'PLANBHAI_EOF'
import SwiftUI

/// Month calendar reading the merged range endpoint.
///
/// Same source as web and the Brief — schedule blocks, device calendar events,
/// PlanBhai events, parties, and meals mapped by weekday. Merged server-side so
/// three surfaces cannot disagree about what is on a given Tuesday.
struct CalendarRangeView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var days: [CalendarDay] = []
    @State private var month = Calendar.current.date(
        from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
    @State private var selected: String?
    @State private var loading = true
    @State private var errorText: String?

    private let weekdayInitials = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "0F0F1A"), Color(hex: "0F172A"), Color(hex: "111827")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ).ignoresSafeArea()

                blob(PB.navy, 300, x: 150, y: -150, blur: 70, op: 0.16)
                blob(PB.mauve, 220, x: -110, y: 340, blur: 60, op: 0.10)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        PageHeader(icon: "calendar", title: "Calendar",
                                   subtitle: "Everything, in one place", color: PB.mauve)
                            .padding(.top, 8)

                        monthHeader
                        grid

                        if let errorText {
                            Text(errorText).font(.system(size: 12)).foregroundStyle(PB.soft)
                        } else {
                            dayList
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 120)
                }
                .refreshable { await load() }
            }
            .navigationBarHidden(true)
            .safeAreaInset(edge: .top) {
                // Presented as a sheet, so there is no back button. Without an
                // explicit control the only way out is a swipe most people
                // never try.
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Text("Done")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(PB.teal)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(PB.glass))
                            .overlay(Capsule().stroke(PB.glassBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
        .task { await load() }
    }

    // MARK: - Month

    private var monthHeader: some View {
        HStack {
            Button { shift(-1) } label: {
                Image(systemName: "chevron.left").foregroundStyle(PB.soft)
            }
            Spacer()
            Text(monthLabel)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Button { shift(1) } label: {
                Image(systemName: "chevron.right").foregroundStyle(PB.soft)
            }
        }
        .padding(.horizontal, 6)
    }

    private var grid: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(weekdayInitials[i])
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PB.muted)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                    if let date = cell {
                        dayCell(date)
                    } else {
                        Color.clear.frame(height: 46)
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(PB.glass))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(PB.glassBorder, lineWidth: 1))
    }

    private func dayCell(_ date: String) -> some View {
        let rows = rowsFor(date)
        let isToday = date == todayString
        let isSelected = date == selected

        return Button {
            selected = (selected == date) ? nil : date
        } label: {
            VStack(spacing: 3) {
                Text(String(Int(date.suffix(2)) ?? 0))
                    .font(.system(size: 13, weight: isToday ? .bold : .medium))
                    .foregroundStyle(isToday ? PB.teal : .white.opacity(0.85))
                // A month cell fits a density dot, not twelve rows. Detail
                // belongs in the list below, where it can be read.
                if !rows.isEmpty {
                    Circle().fill(PB.mauve).frame(width: 4, height: 4)
                } else {
                    Circle().fill(.clear).frame(width: 4, height: 4)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? PB.mauve.opacity(0.22) : Color.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(isToday ? PB.teal.opacity(0.5) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Day list

    private var dayList: some View {
        let date = selected ?? todayString
        let rows = rowsFor(date)

        return VStack(alignment: .leading, spacing: 12) {
            Text(longLabel(date).uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(PB.soft).tracking(0.9)

            if rows.isEmpty {
                Text("Nothing scheduled.")
                    .font(.system(size: 13)).foregroundStyle(PB.muted)
            } else {
                ForEach(rows) { r in
                    HStack(spacing: 11) {
                        Text(r.time.map(display) ?? "—")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(PB.muted)
                            .frame(width: 58, alignment: .leading)

                        Text(icon(for: r)).font(.system(size: 13))

                        Text(r.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(r.done == true ? PB.muted : .white)
                            .strikethrough(r.done == true)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18).fill(PB.glass))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(PB.glassBorder, lineWidth: 1))
    }

    private func icon(for r: CalendarRow) -> String {
        switch r.source {
        case "schedule": return "🎯"
        case "meal":     return "🍽"
        case "device":   return "📅"
        case "party":    return "🎉"
        default:         return "📌"
        }
    }

    // MARK: - Helpers

    private var todayString: String { Self.iso.string(from: Date()) }

    private static let iso: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private var monthLabel: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: month)
    }

    private func longLabel(_ date: String) -> String {
        guard let d = Self.iso.date(from: date) else { return date }
        let f = DateFormatter(); f.dateFormat = "EEEE, MMMM d"
        return f.string(from: d)
    }

    private func display(_ hhmm: String) -> String {
        let p = hhmm.split(separator: ":").compactMap { Int($0) }
        guard p.count == 2 else { return hhmm }
        let suffix = p[0] < 12 ? "AM" : "PM"
        let h = p[0] % 12 == 0 ? 12 : p[0] % 12
        return p[1] == 0 ? "\(h) \(suffix)" : String(format: "%d:%02d %@", h, p[1], suffix)
    }

    private func rowsFor(_ date: String) -> [CalendarRow] {
        days.first { $0.localDate == date }?.rows ?? []
    }

    /// Grid cells, with nil for the leading blanks before the 1st.
    private var cells: [String?] {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: month),
              let first = cal.date(from: cal.dateComponents([.year, .month], from: month))
        else { return [] }

        let offset = cal.component(.weekday, from: first) - 1
        var out: [String?] = Array(repeating: nil, count: offset)
        for d in range {
            if let date = cal.date(byAdding: .day, value: d - 1, to: first) {
                out.append(Self.iso.string(from: date))
            }
        }
        return out
    }

    private func shift(_ delta: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: delta, to: month) else { return }
        month = next
        selected = nil
        Task { await load() }
    }

    private func load() async {
        guard let token = appState.authToken,
              let household = appState.activeHouseholdId else {
            errorText = "Sign in and pick a household first."
            loading = false
            return
        }

        let cal = Calendar.current
        guard let first = cal.date(from: cal.dateComponents([.year, .month], from: month)),
              let last = cal.date(byAdding: DateComponents(month: 1, day: -1), to: first)
        else { return }

        loading = true
        errorText = nil
        do {
            days = try await ScheduleService.shared.fetchRange(
                householdId: household, token: token,
                from: Self.iso.string(from: first),
                to: Self.iso.string(from: last))
        } catch {
            errorText = error.localizedDescription
        }
        loading = false
    }
}
PLANBHAI_EOF

echo

echo "Verifying"
for f in ScheduleView CalendarRangeView; do
  grep -q 'Text("Done")' "$D/$f.swift" && echo "   ok   $f has a Done button" \
    || { echo "   MISSING in $f — reverting"; cp "$D/$f.swift.bakdismiss" "$D/$f.swift"; exit 1; }
done
echo

echo "Building"
SIM=$(xcodebuild -scheme PlanBhai -showdestinations 2>/dev/null \
  | grep -oE "name:iPhone [^}]*" | sed 's/name://' | sed 's/ *$//' | head -1)
[ -z "$SIM" ] && SIM="iPhone 17"
echo "   simulator: $SIM"
xcodebuild -scheme PlanBhai -destination "platform=iOS Simulator,name=$SIM" build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head -15
echo

echo "=========================================="
echo "  Revert:"
echo "     cp $D/ScheduleView.swift.bakdismiss $D/ScheduleView.swift"
echo "     cp $D/CalendarRangeView.swift.bakdismiss $D/CalendarRangeView.swift"
echo "=========================================="

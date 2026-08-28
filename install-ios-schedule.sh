#!/usr/bin/env bash
#
# iOS: schedule blocks and a calendar, on the same endpoints web uses.
#
# FIVE NEW FILES, nothing existing modified.
#   ScheduleModels.swift     block, row, calendar day, kinds
#   ScheduleService.swift    /api/schedule — blocks, day, instance, range
#   ScheduleView.swift       "My Day" — the list of blocks
#   BlockEditor.swift        create / edit / pause / delete one block
#   CalendarRangeView.swift  month grid + day list, merged sources
#
# WHY A LIST AND A SHEET, NOT DRAG-AND-DROP
#   Dragging is the single most expensive item in the schedule spec — gestures,
#   collision resolution, auto-scroll, undo, and a separate implementation per
#   platform. A tap-to-edit sheet delivers most of the value for a fraction of
#   the work, and is worth revisiting once people are actually using schedules.
#
# WHY THE MONTH CELL SHOWS A DOT
#   A 46pt cell cannot hold twelve rows legibly. Density in the grid, detail in
#   the list beneath it — which is also how the web calendar behaves, so the two
#   platforms read the same way.
#
# BLOCKS ARE PERSONAL
#   The server scopes every schedule read and write to the caller, so one
#   household member never sees or edits another's day — even though the Brief
#   they share is cached per household.
#
# Usage:
#   bash ~/Downloads/install-ios-schedule.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
D="PlanBhai/ios/PlanBhai"
[ -d "$D/Views" ] || { echo "ERROR: $D/Views not found"; exit 1; }

echo "PlanBhai — iOS schedule + calendar"
echo

echo "1. Checking what these depend on"
for pair in "PB.forest:Views/AuthView.swift" "PageHeader:Views/SharedComponents.swift" \
            "activeHouseholdId:AppState.swift" "authToken:AppState.swift"; do
  name="${pair%%:*}"; file="${pair##*:}"
  if grep -q "${name#PB.}" "$D/$file" 2>/dev/null; then
    echo "   ok   $name"
  else
    echo "   MISSING $name in $file — stopping"
    exit 1
  fi
done
echo

echo "2. Writing"
write() {
  local dest="$1"
  [ -f "$dest" ] && cp "$dest" "$dest.bakios"
  cat > "$dest"
  echo "   wrote $dest"
}

write "PlanBhai/ios/PlanBhai/ScheduleModels.swift" << 'PLANBHAI_EOF'
import Foundation

// MARK: - Schedule
//
// Blocks are the writable backbone of a day. Everything else in the Brief is
// derived — events from the calendar, meals from a plan, habits from a list.
// These are the one thing a person creates and moves directly.
//
// Blocks are PERSONAL. The household brief is shared, but a schedule is one
// person's day, so the server scopes every read and write to the caller.

struct ScheduleBlock: Codable, Identifiable {
    let id: String
    var title: String
    var kind: String
    var startTime: String       // "HH:mm", local wall-clock
    var durationMin: Int
    var recurrence: Recurrence
    var tags: [String]
    var goalId: String?
    var active: Bool

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title, kind, startTime, durationMin, recurrence, tags, goalId, active
    }

    struct Recurrence: Codable {
        var type: String            // "weekly" | "cycle"
        var days: [Int]             // weekly: 0 = Sunday

        // Cycle: for rotas that drift against the week. A 4-on-4-off pattern
        // puts every weekday sometimes on and sometimes off, which no
        // days-of-week list can express. Unused by most people; present so the
        // shape never needs migrating.
        var cycleLength: Int?
        var onDays: [Int]?
        var anchorDate: String?

        init(type: String = "weekly", days: [Int] = [1, 2, 3, 4, 5],
             cycleLength: Int? = nil, onDays: [Int]? = nil, anchorDate: String? = nil) {
            self.type = type; self.days = days
            self.cycleLength = cycleLength; self.onDays = onDays; self.anchorDate = anchorDate
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            type = (try? c.decode(String.self, forKey: .type)) ?? "weekly"
            days = (try? c.decode([Int].self, forKey: .days)) ?? [1, 2, 3, 4, 5]
            cycleLength = try? c.decode(Int.self, forKey: .cycleLength)
            onDays = try? c.decode([Int].self, forKey: .onDays)
            anchorDate = try? c.decode(String.self, forKey: .anchorDate)
        }
    }

    /// Human-readable recurrence, for a list row.
    var recurrenceLabel: String {
        if recurrence.type == "cycle", let len = recurrence.cycleLength {
            let on = recurrence.onDays?.count ?? 0
            return "\(on) on, \(len - on) off"
        }
        let d = recurrence.days.sorted()
        if d == [1, 2, 3, 4, 5] { return "Weekdays" }
        if d == [0, 6] { return "Weekends" }
        if d.count == 7 { return "Every day" }
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return d.map { names[$0] }.joined(separator: " ")
    }

    var endTime: String {
        let parts = startTime.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return startTime }
        let total = parts[0] * 60 + parts[1] + durationMin
        return String(format: "%02d:%02d", (total / 60) % 24, total % 60)
    }
}

/// One expanded occurrence — a block on a specific day, with any deviation
/// already applied by the server.
struct ScheduleRow: Codable, Identifiable {
    let blockId: String
    let title: String
    let kind: String
    let start: String
    let end: String
    let durationMin: Int
    let done: Bool
    let moved: Bool
    var id: String { blockId + start }
}

/// A day from the calendar range endpoint — everything merged, not just blocks.
struct CalendarDay: Codable, Identifiable {
    let localDate: String
    let rows: [CalendarRow]
    var id: String { localDate }
}

struct CalendarRow: Codable, Identifiable {
    let id: String
    let title: String
    let date: String
    let time: String?
    let type: String            // Block | Meal | Calendar | Party | Event
    let source: String          // schedule | meal | device | party | custom | event
    let done: Bool?
    let end: String?
}

// MARK: - Kinds

enum BlockKind: String, CaseIterable, Identifiable {
    case deepWork = "deep_work"
    case health, family, learning, admin, urgent, meal, commute, rest

    var id: String { rawValue }

    var label: String {
        switch self {
        case .deepWork: return "Deep work"
        case .health:   return "Health"
        case .family:   return "Family"
        case .learning: return "Learning"
        case .admin:    return "Admin"
        case .urgent:   return "Urgent"
        case .meal:     return "Meal"
        case .commute:  return "Commute"
        case .rest:     return "Rest"
        }
    }

    var emoji: String {
        switch self {
        case .deepWork: return "🎯"
        case .health:   return "💪"
        case .family:   return "👨‍👩‍👧"
        case .learning: return "📚"
        case .urgent:   return "🔥"
        case .commute:  return "🚗"
        case .meal:     return "🍽"
        case .rest:     return "🌙"
        case .admin:    return "📌"
        }
    }
}

func blockEmoji(_ kind: String) -> String {
    BlockKind(rawValue: kind)?.emoji ?? "📌"
}
PLANBHAI_EOF
write "PlanBhai/ios/PlanBhai/ScheduleService.swift" << 'PLANBHAI_EOF'
import Foundation

/// Talks to /api/schedule. Mirrors DayBriefService's conventions rather than
/// inventing a second networking style.
@MainActor
final class ScheduleService {
    static let shared = ScheduleService()

    /// Must match APIService.baseURL — it's private there, so it's repeated.
    private let baseURL = "https://planbhai.onrender.com"

    private init() {}

    private var tz: String { TimeZone.current.identifier }

    private func request(_ path: String, method: String = "GET",
                         token: String, body: [String: Any]? = nil) -> URLRequest? {
        guard let url = URL(string: baseURL + path) else { return nil }
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        r.timeoutInterval = 20
        if let body {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        return r
    }

    private struct BlocksResponse: Decodable { let success: Bool; let blocks: [ScheduleBlock] }
    private struct BlockResponse: Decodable { let success: Bool; let block: ScheduleBlock? }
    private struct DayResponse: Decodable { let success: Bool; let blocks: [ScheduleRow] }
    private struct RangeResponse: Decodable { let success: Bool; let days: [CalendarDay] }
    private struct PlainResponse: Decodable { let success: Bool; let message: String? }

    // MARK: - Templates

    func fetchBlocks(householdId: String, token: String) async throws -> [ScheduleBlock] {
        guard let r = request("/api/schedule/blocks?scopeId=\(householdId)", token: token) else { return [] }
        let (data, _) = try await URLSession.shared.data(for: r)
        return try JSONDecoder().decode(BlocksResponse.self, from: data).blocks
    }

    @discardableResult
    func createBlock(householdId: String, token: String,
                     title: String, kind: String, startTime: String,
                     durationMin: Int, days: [Int]) async throws -> ScheduleBlock? {
        let body: [String: Any] = [
            "title": title, "kind": kind, "startTime": startTime,
            "durationMin": durationMin,
            "recurrence": ["type": "weekly", "days": days],
            "source": "manual"
        ]
        guard let r = request("/api/schedule/blocks?scopeId=\(householdId)",
                              method: "POST", token: token, body: body) else { return nil }
        let (data, _) = try await URLSession.shared.data(for: r)
        return try JSONDecoder().decode(BlockResponse.self, from: data).block
    }

    @discardableResult
    func updateBlock(householdId: String, token: String, id: String,
                     fields: [String: Any]) async throws -> ScheduleBlock? {
        guard let r = request("/api/schedule/blocks/\(id)?scopeId=\(householdId)",
                              method: "PUT", token: token, body: fields) else { return nil }
        let (data, _) = try await URLSession.shared.data(for: r)
        return try JSONDecoder().decode(BlockResponse.self, from: data).block
    }

    func deleteBlock(householdId: String, token: String, id: String) async throws -> Bool {
        guard let r = request("/api/schedule/blocks/\(id)?scopeId=\(householdId)",
                              method: "DELETE", token: token) else { return false }
        let (_, response) = try await URLSession.shared.data(for: r)
        return ((response as? HTTPURLResponse)?.statusCode ?? 500) < 300
    }

    // MARK: - A day

    func fetchDay(householdId: String, token: String, date: String? = nil) async throws -> [ScheduleRow] {
        var path = "/api/schedule/day?scopeId=\(householdId)&tz=\(tz.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? tz)"
        if let date { path += "&date=\(date)" }
        guard let r = request(path, token: token) else { return [] }
        let (data, _) = try await URLSession.shared.data(for: r)
        return try JSONDecoder().decode(DayResponse.self, from: data).blocks
    }

    /// Records a deviation. `state` is done | skipped | moved | clear —
    /// `clear` removes it, which is how un-completing and undoing a move work.
    @discardableResult
    func setInstance(householdId: String, token: String, blockId: String,
                     localDate: String, state: String,
                     startTime: String? = nil, durationMin: Int? = nil) async throws -> Bool {
        var body: [String: Any] = ["blockId": blockId, "localDate": localDate, "state": state]
        if let startTime { body["startTime"] = startTime }
        if let durationMin { body["durationMin"] = durationMin }
        guard let r = request("/api/schedule/instance?scopeId=\(householdId)",
                              method: "POST", token: token, body: body) else { return false }
        let (_, response) = try await URLSession.shared.data(for: r)
        return ((response as? HTTPURLResponse)?.statusCode ?? 500) < 300
    }

    // MARK: - Calendar range

    /// Everything on the calendar between two dates — blocks, device events,
    /// PlanBhai events, parties and meals, merged server-side so this and the
    /// Brief cannot disagree about a given day.
    func fetchRange(householdId: String, token: String,
                    from: String, to: String) async throws -> [CalendarDay] {
        let enc = tz.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? tz
        guard let r = request(
            "/api/schedule/range?scopeId=\(householdId)&from=\(from)&to=\(to)&tz=\(enc)",
            token: token) else { return [] }
        let (data, _) = try await URLSession.shared.data(for: r)
        return try JSONDecoder().decode(RangeResponse.self, from: data).days
    }
}
PLANBHAI_EOF
write "PlanBhai/ios/PlanBhai/Views/ScheduleView.swift" << 'PLANBHAI_EOF'
import SwiftUI

/// Create and manage schedule blocks.
///
/// A list plus an edit sheet, deliberately — not drag-and-drop. Dragging is the
/// single most expensive thing in the schedule spec (gestures, collision,
/// auto-scroll, undo, twice over for two platforms) and a sheet delivers most
/// of the value. Worth adding once people are actually using schedules.
struct ScheduleView: View {
    @EnvironmentObject var appState: AppState

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
write "PlanBhai/ios/PlanBhai/Views/BlockEditor.swift" << 'PLANBHAI_EOF'
import SwiftUI

/// Create or edit one schedule block.
struct BlockEditor: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let block: ScheduleBlock?
    let onSaved: () async -> Void

    @State private var title = ""
    @State private var kind: BlockKind = .deepWork
    @State private var start = Date()
    @State private var durationMin = 60
    @State private var days: Set<Int> = [1, 2, 3, 4, 5]
    @State private var active = true
    @State private var saving = false
    @State private var errorText: String?
    @State private var confirmDelete = false

    private let dayNames = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0F0F1A").ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        field("What is it?") {
                            TextField("", text: $title, prompt: Text("Deep work").foregroundStyle(PB.muted))
                                .foregroundStyle(.white)
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 12).fill(PB.glass))
                        }

                        field("Type") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(BlockKind.allCases) { k in
                                        Button { kind = k } label: {
                                            HStack(spacing: 5) {
                                                Text(k.emoji).font(.system(size: 13))
                                                Text(k.label).font(.system(size: 12, weight: .medium))
                                            }
                                            .foregroundStyle(kind == k ? .white : PB.soft)
                                            .padding(.horizontal, 12).padding(.vertical, 9)
                                            .background(Capsule().fill(kind == k ? PB.forest.opacity(0.30) : PB.glass))
                                            .overlay(Capsule().stroke(
                                                kind == k ? PB.forest : PB.glassBorder, lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        field("Starts at") {
                            DatePicker("", selection: $start, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .colorScheme(.dark)
                        }

                        field("For how long?") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach([15, 30, 45, 60, 90, 120, 180], id: \.self) { m in
                                        Button { durationMin = m } label: {
                                            Text(m < 60 ? "\(m)m" : (m % 60 == 0 ? "\(m/60)h" : "\(m/60)h \(m%60)m"))
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(durationMin == m ? .white : PB.soft)
                                                .padding(.horizontal, 14).padding(.vertical, 9)
                                                .background(Capsule().fill(durationMin == m ? PB.forest.opacity(0.30) : PB.glass))
                                                .overlay(Capsule().stroke(
                                                    durationMin == m ? PB.forest : PB.glassBorder, lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        field("Which days?") {
                            HStack(spacing: 7) {
                                ForEach(0..<7, id: \.self) { i in
                                    Button {
                                        if days.contains(i) { days.remove(i) } else { days.insert(i) }
                                    } label: {
                                        Text(dayNames[i])
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(days.contains(i) ? .white : PB.muted)
                                            .frame(width: 38, height: 38)
                                            .background(Circle().fill(days.contains(i) ? PB.forest.opacity(0.30) : PB.glass))
                                            .overlay(Circle().stroke(
                                                days.contains(i) ? PB.forest : PB.glassBorder, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        if block != nil {
                            Toggle(isOn: $active) {
                                Text("Active").font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                            }
                            .tint(PB.forest)
                            // Pausing rather than deleting: a block you skip for
                            // a fortnight shouldn't have to be rebuilt.
                            Text("Pausing keeps the block but takes it off your day.")
                                .font(.system(size: 11)).foregroundStyle(PB.muted)
                        }

                        if let errorText {
                            Text(errorText).font(.system(size: 12)).foregroundStyle(PB.error)
                        }

                        if block != nil {
                            Button(role: .destructive) { confirmDelete = true } label: {
                                Text("Delete this block")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(PB.error)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                        }
                    }
                    .padding(18)
                }
            }
            .navigationTitle(block == nil ? "New block" : "Edit block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(PB.soft)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save") { Task { await save() } }
                        .foregroundStyle(canSave ? PB.forest : PB.muted)
                        .disabled(!canSave || saving)
                }
            }
            .alert("Delete this block?", isPresented: $confirmDelete) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) { Task { await remove() } }
            } message: {
                Text("It will disappear from your Brief and calendar. Past days you already completed are unaffected.")
            }
        }
        .onAppear(perform: populate)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !days.isEmpty
    }

    private func field<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(PB.soft).tracking(0.9)
            content()
        }
    }

    private func populate() {
        guard let b = block else { return }
        title = b.title
        kind = BlockKind(rawValue: b.kind) ?? .admin
        durationMin = b.durationMin
        days = Set(b.recurrence.days)
        active = b.active

        let parts = b.startTime.split(separator: ":").compactMap { Int($0) }
        if parts.count == 2 {
            start = Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: Date()) ?? Date()
        }
    }

    private var startString: String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: start)
        return String(format: "%02d:%02d", c.hour ?? 9, c.minute ?? 0)
    }

    private func save() async {
        guard let token = appState.authToken,
              let household = appState.activeHouseholdId else {
            errorText = "Sign in and pick a household first."
            return
        }
        saving = true
        errorText = nil
        do {
            if let existing = block {
                _ = try await ScheduleService.shared.updateBlock(
                    householdId: household, token: token, id: existing.id,
                    fields: [
                        "title": title.trimmingCharacters(in: .whitespaces),
                        "kind": kind.rawValue,
                        "startTime": startString,
                        "durationMin": durationMin,
                        "recurrence": ["type": "weekly", "days": Array(days).sorted()],
                        "active": active,
                    ])
            } else {
                _ = try await ScheduleService.shared.createBlock(
                    householdId: household, token: token,
                    title: title.trimmingCharacters(in: .whitespaces),
                    kind: kind.rawValue, startTime: startString,
                    durationMin: durationMin, days: Array(days).sorted())
            }
            await onSaved()
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
        saving = false
    }

    private func remove() async {
        guard let token = appState.authToken,
              let household = appState.activeHouseholdId,
              let existing = block else { return }
        do {
            _ = try await ScheduleService.shared.deleteBlock(
                householdId: household, token: token, id: existing.id)
            await onSaved()
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
PLANBHAI_EOF
write "PlanBhai/ios/PlanBhai/Views/CalendarRangeView.swift" << 'PLANBHAI_EOF'
import SwiftUI

/// Month calendar reading the merged range endpoint.
///
/// Same source as web and the Brief — schedule blocks, device calendar events,
/// PlanBhai events, parties, and meals mapped by weekday. Merged server-side so
/// three surfaces cannot disagree about what is on a given Tuesday.
struct CalendarRangeView: View {
    @EnvironmentObject var appState: AppState

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

echo "3. Parsing"
if command -v swiftc >/dev/null 2>&1; then
  for f in ScheduleModels ScheduleService; do
    swiftc -parse "$D/$f.swift" >/dev/null 2>&1 && echo "   ok   $f.swift" \
      || echo "   parse issues in $f.swift"
  done
fi
echo

echo "4. Building"
SIM=$(xcodebuild -scheme PlanBhai -showdestinations 2>/dev/null \
  | grep -oE "name:iPhone [^}]*" | sed 's/name://' | sed 's/ *$//' | head -1)
[ -z "$SIM" ] && SIM="iPhone 17"
echo "   simulator: $SIM"
xcodebuild -scheme PlanBhai -destination "platform=iOS Simulator,name=$SIM" build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head -20
echo

echo "=========================================="
echo "  NOT YET REACHABLE — neither view is in the tab bar."
echo
echo "  MainTabView already has six tabs, which is full. Two options:"
echo
echo "    a) Replace SharedCalendarView with CalendarRangeView, and reach"
echo "       ScheduleView from the Brief or from Lifestyle."
echo
echo "    b) Push both from the Brief — a \"My Day\" row that opens ScheduleView,"
echo "       and a calendar button in the header."
echo
echo "  I have not chosen, because it means changing navigation you use daily."
echo "  Tell me which and I will wire it against your real MainTabView."
echo
echo "  Revert:  rm $D/ScheduleModels.swift $D/ScheduleService.swift \\"
echo "              $D/Views/ScheduleView.swift $D/Views/BlockEditor.swift \\"
echo "              $D/Views/CalendarRangeView.swift"
echo "=========================================="

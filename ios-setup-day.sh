#!/usr/bin/env bash
#
# iOS: "Plan my day" — the template picker, matching web.
#
# THREE STEPS, as a sheet from My Day
#   1. What does most of your day look like?   13 professions
#   2. Five questions                          wake, work start, work end,
#                                              family time, bed
#   3. Review                                  the proposed day, before anything
#                                              is written
#
# THE LIST COMES FROM THE SERVER, not a hardcoded copy. A fourteenth profession
# is then a data edit with no app release, and iOS and web cannot drift about
# what the options are.
#
# FIRST-RUN ONBOARDING, NOT A FEATURE TO RETURN TO.
#   Testing against a real day made the reason plain: five hand-made blocks beat
#   the template's five every time, because five answers cannot beat five
#   decisions. This is for an empty schedule that needs a starting point worth
#   editing — which is why the review step carries more weight than the picker.
#
# THE REVIEW STEP
#   Nothing is written until confirmed. If blocks already exist the collisions
#   are shown with both times, and the choice is blunt on purpose:
#     Add anyway     — "leaves you with two of each"
#     Replace my day — "removes everything, including blocks you made yourself"
#
#   Both options lose something. Which one matters is the user's call, made with
#   the facts in front of them.
#
# WHERE IT LIVES
#   Empty My Day  -> "Plan my day"
#   Populated     -> "Start from a template" under Add a block
#
# NO BACKEND CHANGE — the endpoints have been live since the web version.
#
# Usage:
#   bash ~/Downloads/ios-setup-day.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
D="PlanBhai/ios/PlanBhai"
[ -d "$D/Views" ] || { echo "ERROR: $D/Views not found"; exit 1; }

echo "PlanBhai — iOS template picker"
echo

echo "1. Prerequisite"
[ -f "$D/ScheduleService.swift" ] \
  && echo "   ok   ScheduleService" \
  || { echo "   MISSING — run install-ios-schedule.sh first"; exit 1; }
echo

write() {
  local dest="$1"
  [ -f "$dest" ] && cp "$dest" "$dest.bakpick"
  cat > "$dest"
  echo "   wrote $dest"
}

echo "2. Writing"
write "$D/ScheduleModels.swift" << 'PLANBHAI_EOF'
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


// MARK: - Templates
//
// The list and the questions come from the SERVER, not a hardcoded copy here.
// Adding a fourteenth profession is then a data edit with no app release, and
// iOS and web can never drift about what the options are.

struct DayTemplate: Codable, Identifiable {
    let id: String
    let label: String
    let emoji: String
    let blockCount: Int?
    let cyclic: Bool?
}

struct TemplateQuestion: Codable, Identifiable {
    let key: String
    let label: String
    let type: String?
    let `default`: String
    var id: String { key }
}

/// What a template WOULD create, plus what already exists and where they clash.
struct TemplatePreview: Codable {
    let blocks: [PreviewBlock]
    let warnings: [String]?
    let existing: [ExistingBlock]?
    let collisions: [Collision]?

    struct PreviewBlock: Codable, Identifiable {
        let title: String
        let kind: String
        let startTime: String
        let durationMin: Int
        var id: String { title + startTime }
    }

    struct ExistingBlock: Codable, Identifiable {
        let id: String
        let title: String
        let startTime: String
        let durationMin: Int
        let source: String?
    }

    struct Collision: Codable, Identifiable {
        let proposed: PreviewBlock
        let existing: ExistingBlock
        var id: String { existing.id }
    }
}
PLANBHAI_EOF
write "$D/ScheduleService.swift" << 'PLANBHAI_EOF'
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

    // MARK: - Templates

    private struct TemplatesResponse: Decodable {
        let success: Bool
        let templates: [DayTemplate]
        let questions: [TemplateQuestion]
    }
    private struct PreviewResponse: Decodable {
        let success: Bool
        let blocks: [TemplatePreview.PreviewBlock]
        let warnings: [String]?
        let existing: [TemplatePreview.ExistingBlock]?
        let collisions: [TemplatePreview.Collision]?
    }
    private struct ApplyResponse: Decodable {
        let success: Bool
        let created: Int?
        let replaced: Int?
        let message: String?
    }

    func fetchTemplates(token: String) async throws -> ([DayTemplate], [TemplateQuestion]) {
        guard let r = request("/api/schedule/templates", token: token) else { return ([], []) }
        let (data, _) = try await URLSession.shared.data(for: r)
        let res = try JSONDecoder().decode(TemplatesResponse.self, from: data)
        return (res.templates, res.questions)
    }

    /// Writes nothing. Showing the day before committing to it is the
    /// difference between a choice and a surprise.
    func previewTemplate(householdId: String, token: String,
                         templateId: String, answers: [String: String]) async throws -> TemplatePreview {
        guard let r = request("/api/schedule/templates/preview?scopeId=\(householdId)",
                              method: "POST", token: token,
                              body: ["templateId": templateId, "answers": answers])
        else { throw DayBriefError.server(0, "Bad URL") }

        let (data, response) = try await URLSession.shared.data(for: r)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 500
        guard (200...299).contains(code) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
            throw DayBriefError.server(code, msg ?? "Couldn't build that day.")
        }

        let res = try JSONDecoder().decode(PreviewResponse.self, from: data)
        return TemplatePreview(blocks: res.blocks, warnings: res.warnings,
                               existing: res.existing, collisions: res.collisions)
    }

    /// `mode` is "keep" or "replaceAll". replaceAll removes hand-made blocks
    /// too, so it is only ever sent after the collisions have been shown.
    @discardableResult
    func applyTemplate(householdId: String, token: String, templateId: String,
                       answers: [String: String], mode: String) async throws -> Int {
        guard let r = request("/api/schedule/templates/apply?scopeId=\(householdId)",
                              method: "POST", token: token,
                              body: ["templateId": templateId, "answers": answers, "mode": mode])
        else { return 0 }

        let (data, response) = try await URLSession.shared.data(for: r)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 500
        let res = try? JSONDecoder().decode(ApplyResponse.self, from: data)
        guard (200...299).contains(code) else {
            throw DayBriefError.server(code, res?.message ?? "Couldn't set up that day.")
        }
        return res?.created ?? 0
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
write "$D/Views/SetupDayView.swift" << 'PLANBHAI_EOF'
import SwiftUI

/// Set up my day — three steps: profession, hours, review.
///
/// FIRST-RUN ONBOARDING, not a feature to return to. Testing against a real day
/// made the reason plain: five hand-made blocks beat the template's five every
/// time, because five answers cannot beat five decisions. This is for an empty
/// schedule that needs a starting point worth editing.
///
/// That framing is why the review step carries more weight than the picker. The
/// day it proposes is a first draft, and saying so is better than presenting it
/// as an answer.
struct SetupDayView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    /// Called after blocks are written, so the caller can reload its list.
    var onDone: (() async -> Void)?

    @State private var step = 0                 // 0 profession · 1 hours · 2 review
    @State private var templates: [DayTemplate] = []
    @State private var questions: [TemplateQuestion] = []
    @State private var templateId: String?
    @State private var answers: [String: String] = [:]
    @State private var preview: TemplatePreview?
    @State private var loading = true
    @State private var busy = false
    @State private var errorText: String?

    private let stepLabels = ["Your work", "Your hours", "Review"]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "0F0F1A"), Color(hex: "0F172A"), Color(hex: "111827")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ).ignoresSafeArea()

                if loading {
                    ProgressView().tint(.white)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            stepBar

                            if let errorText {
                                Text(errorText)
                                    .font(.system(size: 12))
                                    .foregroundStyle(PB.error)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            switch step {
                            case 0: professionStep
                            case 1: hoursStep
                            default: reviewStep
                            }
                        }
                        .padding(18)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Set up my day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(PB.soft)
                }
            }
        }
        .task { await load() }
    }

    // MARK: - Steps

    private var stepBar: some View {
        HStack(spacing: 12) {
            ForEach(Array(stepLabels.enumerated()), id: \.offset) { i, label in
                Text("\(i + 1). \(label)")
                    .font(.system(size: 11, weight: i == step ? .bold : .regular))
                    .foregroundStyle(i == step ? PB.forest : (i < step ? PB.mid : PB.muted))
            }
        }
    }

    private var professionStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What does most of your day look like?")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(templates) { t in
                    Button { templateId = t.id } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(t.emoji).font(.system(size: 24))
                            Text(t.label)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(t.blockCount ?? 0) blocks\(t.cyclic == true ? " · rota" : "")")
                                .font(.system(size: 10))
                                .foregroundStyle(PB.soft)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14)
                            .fill(templateId == t.id ? PB.forest.opacity(0.20) : PB.glass))
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .stroke(templateId == t.id ? PB.forest : PB.glassBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            primaryButton("Continue", enabled: templateId != nil) { step = 1 }
        }
    }

    private var hoursStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Five questions, then you're done.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            VStack(spacing: 12) {
                ForEach(questions) { q in
                    HStack {
                        Text(q.label)
                            .font(.system(size: 13))
                            .foregroundStyle(PB.mid)
                        Spacer(minLength: 8)
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { dateFrom(answers[q.key] ?? q.default) },
                                set: { answers[q.key] = hhmm(from: $0) }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .colorScheme(.dark)
                    }
                }
            }
            .padding(16)
            .glassCard()

            HStack(spacing: 10) {
                secondaryButton("Back") { step = 0 }
                primaryButton(busy ? "Working…" : "See my day", enabled: !busy) {
                    Task { await loadPreview() }
                }
            }
        }
    }

    @ViewBuilder
    private var reviewStep: some View {
        if let p = preview {
            VStack(alignment: .leading, spacing: 14) {
                // Nothing is written yet.
                VStack(alignment: .leading, spacing: 10) {
                    Text("YOUR DAY WOULD LOOK LIKE THIS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PB.soft).tracking(0.9)

                    ForEach(p.blocks) { b in
                        HStack(spacing: 12) {
                            Text(display(b.startTime))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(PB.muted)
                                .frame(width: 62, alignment: .leading)
                            Text(blockEmoji(b.kind)).font(.system(size: 13))
                            Text(b.title)
                                .font(.system(size: 14))
                                .foregroundStyle(.white)
                            Spacer(minLength: 0)
                            Text("\(b.durationMin)m")
                                .font(.system(size: 11))
                                .foregroundStyle(PB.muted)
                        }
                    }

                    if let w = p.warnings, !w.isEmpty {
                        ForEach(w, id: \.self) { line in
                            Text("⚠ \(line)")
                                .font(.system(size: 11))
                                .foregroundStyle(PB.warning)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .glassCard()

                if let c = p.collisions, !c.isEmpty {
                    collisionCard(c)
                }

                HStack(spacing: 10) {
                    secondaryButton("Back") { step = 1 }
                    if let c = p.collisions, !c.isEmpty {
                        Button { Task { await apply("replaceAll") } } label: {
                            Text("Replace my day")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(PB.error)
                                .padding(.horizontal, 14).padding(.vertical, 11)
                                .background(Capsule().stroke(PB.error.opacity(0.5), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .disabled(busy)
                    }
                    primaryButton(
                        busy ? "Adding…" : ((p.collisions?.isEmpty ?? true) ? "Add to my day" : "Add anyway"),
                        enabled: !busy
                    ) { Task { await apply("keep") } }
                }
            }
        }
    }

    private func collisionCard(_ c: [TemplatePreview.Collision]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOU ALREADY HAVE \(c.count) OF THESE")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(PB.warning).tracking(0.9)

            ForEach(c) { pair in
                HStack {
                    Text(pair.existing.title)
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                    Spacer(minLength: 8)
                    Text("yours \(display(pair.existing.startTime)) · new \(display(pair.proposed.startTime))")
                        .font(.system(size: 11))
                        .foregroundStyle(PB.soft)
                }
            }

            // Blunt on purpose. Both options lose something, and which one
            // matters is the user's call to make with the facts in front of them.
            Text("Keeping both leaves you with two of each. Replacing removes everything on your day, including blocks you made yourself.")
                .font(.system(size: 11))
                .foregroundStyle(PB.soft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(PB.warning.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(PB.warning.opacity(0.35), lineWidth: 1))
    }

    // MARK: - Buttons

    private func primaryButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 12).fill(PB.forest))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PB.soft)
                .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func dateFrom(_ hhmm: String) -> Date {
        let p = hhmm.split(separator: ":").compactMap { Int($0) }
        guard p.count == 2 else { return Date() }
        return Calendar.current.date(bySettingHour: p[0], minute: p[1], second: 0, of: Date()) ?? Date()
    }

    private func hhmm(from date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    private func display(_ hhmm: String) -> String {
        let p = hhmm.split(separator: ":").compactMap { Int($0) }
        guard p.count == 2 else { return hhmm }
        let suffix = p[0] < 12 ? "AM" : "PM"
        let h = p[0] % 12 == 0 ? 12 : p[0] % 12
        return p[1] == 0 ? "\(h) \(suffix)" : String(format: "%d:%02d %@", h, p[1], suffix)
    }

    // MARK: - Data

    private func load() async {
        guard let token = appState.authToken else {
            errorText = "Sign in first."
            loading = false
            return
        }
        do {
            let (t, q) = try await ScheduleService.shared.fetchTemplates(token: token)
            templates = t
            questions = q
            // Seeded from the defaults, so someone can skip straight through and
            // still get a sensible day.
            for question in q where answers[question.key] == nil {
                answers[question.key] = question.default
            }
        } catch {
            errorText = "Couldn't load the templates."
        }
        loading = false
    }

    private func loadPreview() async {
        guard let token = appState.authToken,
              let household = appState.activeHouseholdId,
              let id = templateId else { return }
        busy = true
        errorText = nil
        do {
            preview = try await ScheduleService.shared.previewTemplate(
                householdId: household, token: token, templateId: id, answers: answers)
            step = 2
        } catch let DayBriefError.server(_, msg) {
            errorText = msg
        } catch {
            errorText = "Couldn't build that day."
        }
        busy = false
    }

    private func apply(_ mode: String) async {
        guard let token = appState.authToken,
              let household = appState.activeHouseholdId,
              let id = templateId else { return }
        busy = true
        errorText = nil
        do {
            _ = try await ScheduleService.shared.applyTemplate(
                householdId: household, token: token, templateId: id,
                answers: answers, mode: mode)
            await onDone?()
            dismiss()
        } catch let DayBriefError.server(_, msg) {
            errorText = msg
            busy = false
        } catch {
            errorText = "Couldn't set up that day."
            busy = false
        }
    }
}
PLANBHAI_EOF
write "$D/Views/ScheduleView.swift" << 'PLANBHAI_EOF'
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
    @State private var showingSetup = false

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

                        if !blocks.isEmpty {
                            Button { showingSetup = true } label: {
                                Text("Start from a template")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(PB.soft)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
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
        .sheet(isPresented: $showingNew) {
            BlockEditor(block: nil) { await load() }
                .environmentObject(appState)
        }
        .sheet(isPresented: $showingSetup) {
            SetupDayView(onDone: { await load() })
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
            VStack(alignment: .leading, spacing: 12) {
                Text("No blocks yet")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                // Honest about what this is for: the shape of a normal day, not
                // a to-do list. That distinction is the whole point.
                Text("Start from a template for your kind of day, then change anything you like. Blocks appear on your Brief and calendar.")
                    .font(.system(size: 13))
                    .foregroundStyle(PB.soft)
                    .fixedSize(horizontal: false, vertical: true)

                Button { showingSetup = true } label: {
                    Text("Plan my day")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(PB.forest))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
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

echo

echo "3. Verifying"
for k in "struct DayTemplate" "func fetchTemplates" "func previewTemplate" "func applyTemplate"; do
  grep -qr "$k" "$D" && echo "   ok   $k" \
    || { echo "   MISSING $k"; exit 1; }
done
grep -q "SetupDayView" "$D/Views/ScheduleView.swift" && echo "   ok   reachable from My Day"
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
echo "  Brief -> My Day -> \"Start from a template\"."
echo
echo "  With your five blocks in place you will hit the collision card, which"
echo "  is the interesting path even though the flow is built for an empty day."
echo
echo "  Revert:"
echo "     rm $D/Views/SetupDayView.swift"
echo "     cp $D/ScheduleModels.swift.bakpick $D/ScheduleModels.swift"
echo "     cp $D/ScheduleService.swift.bakpick $D/ScheduleService.swift"
echo "     cp $D/Views/ScheduleView.swift.bakpick $D/Views/ScheduleView.swift"
echo "=========================================="

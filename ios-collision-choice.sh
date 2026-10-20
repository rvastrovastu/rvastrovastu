#!/usr/bin/env bash
#
# iOS: per-collision choice, matching web.
#
# WHY THIS IS REQUIRED, not optional
#   The apply endpoint no longer accepts `mode`. iOS was still sending it, so
#   the picker's final step would fail outright against the deployed server.
#
# WHAT CHANGES
#   Each clash gets its own row with three chips:
#       Keep mine · 07:00     your block stays, the template's is skipped
#       Use new · 06:30       the template's replaces yours
#       Keep both             both stay
#
#   Defaults to the template's version, since that is what choosing a template
#   implies. "Keep both" stays available because matching titles do not always
#   mean the same intent — a 06:30 stretch and a 07:00 routine can coexist.
#
#   "Replace my day" is gone. It made the user accept a decision about blocks
#   they were never asked about.
#
# The review screen now has ONE action button, because every clash is already
# resolved on its own row.
#
# NO BACKEND CHANGE — the endpoint was updated with the web version.
#
# Usage:
#   bash ~/Downloads/ios-collision-choice.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
D="PlanBhai/ios/PlanBhai"
[ -f "$D/Views/SetupDayView.swift" ] || { echo "ERROR: SetupDayView.swift not found"; exit 1; }

echo "PlanBhai — iOS collision choice"
echo

write() {
  local dest="$1"
  [ -f "$dest" ] && cp "$dest" "$dest.bakchoice"
  cat > "$dest"
  echo "   wrote $dest"
}

echo "1. Writing"
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

    /// One decision per collision: ["title": ..., "keep": "mine" | "theirs" | "both"].
    ///
    /// Replaced a blanket `mode`. "Replace my day" made the user accept a
    /// decision about blocks they were never asked about, and "add anyway" left
    /// two of each — which is never what anyone wants.
    @discardableResult
    func applyTemplate(householdId: String, token: String, templateId: String,
                       answers: [String: String],
                       decisions: [[String: String]]) async throws -> Int {
        guard let r = request("/api/schedule/templates/apply?scopeId=\(householdId)",
                              method: "POST", token: token,
                              body: ["templateId": templateId, "answers": answers,
                                     "decisions": decisions])
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
    @State private var choices: [String: String] = [:]   // title -> mine | theirs | both
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
                            Text(tileSubtitle(t))
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
            .background(RoundedRectangle(cornerRadius: 18).fill(PB.glass))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(PB.glassBorder, lineWidth: 1))

            HStack(spacing: 10) {
                secondaryButton("Back") { step = 0 }
                primaryButton(busy ? "Working…" : "See my day", enabled: !busy) {
                    Task { await loadPreview() }
                }
            }
        }
    }

    // Broken into small pieces on purpose. As one nested expression — a VStack
    // holding a ForEach, conditionals, interpolation and ternaries inline — the
    // Swift type-checker gave up on it entirely.
    @ViewBuilder
    private var reviewStep: some View {
        if let p = preview {
            VStack(alignment: .leading, spacing: 14) {
                proposedCard(p)

                if let c = p.collisions, !c.isEmpty {
                    collisionCard(c)
                }

                reviewActions(p)
            }
        }
    }

    private func proposedCard(_ p: TemplatePreview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR DAY WOULD LOOK LIKE THIS")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(PB.soft)
                .tracking(0.9)

            ForEach(p.blocks) { b in
                proposedRow(b)
            }

            warningLines(p.warnings ?? [])
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(PB.glass))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(PB.glassBorder, lineWidth: 1))
    }

    private func proposedRow(_ b: TemplatePreview.PreviewBlock) -> some View {
        HStack(spacing: 12) {
            Text(display(b.startTime))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(PB.muted)
                .frame(width: 62, alignment: .leading)

            Text(blockEmoji(b.kind ?? "admin"))
                .font(.system(size: 13))

            Text(b.title)
                .font(.system(size: 14))
                .foregroundStyle(.white)

            Spacer(minLength: 0)

            Text("\(b.durationMin)m")
                .font(.system(size: 11))
                .foregroundStyle(PB.muted)
        }
    }

    @ViewBuilder
    private func warningLines(_ lines: [String]) -> some View {
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(lines, id: \.self) { line in
                    Text("⚠ " + line)
                        .font(.system(size: 11))
                        .foregroundStyle(PB.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // No "Replace my day" any more. Every clash is resolved individually above,
    // so there is nothing left for a blanket button to decide.
    private func reviewActions(_ p: TemplatePreview) -> some View {
        HStack(spacing: 10) {
            secondaryButton("Back") { step = 1 }
            primaryButton(busy ? "Adding…" : "Add to my day", enabled: !busy) {
                Task { await apply() }
            }
        }
    }

    private func collisionCard(_ c: [TemplatePreview.Collision]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(collisionHeading(c.count))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(PB.warning)
                .tracking(0.9)

            ForEach(c) { pair in
                collisionRow(pair)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(PB.warning.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(PB.warning.opacity(0.35), lineWidth: 1))
    }

    private func collisionHeading(_ n: Int) -> String {
        "YOU ALREADY HAVE \(n) OF THESE — PICK ONE"
    }

    /// One choice per clash rather than a blanket outcome.
    private func collisionRow(_ pair: TemplatePreview.Collision) -> some View {
        // Strings built before the view. Interpolation inside a nested SwiftUI
        // expression is what made the type-checker give up on this screen.
        let title = pair.existing.title
        let mineLabel = "Keep mine · " + display(pair.existing.startTime)
        let theirsLabel = "Use new · " + display(pair.proposed.startTime)
        let current = choices[pair.proposed.title] ?? "theirs"

        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(.white)

            HStack(spacing: 6) {
                choiceChip(mineLabel, value: "mine", current: current, title: pair.proposed.title)
                choiceChip(theirsLabel, value: "theirs", current: current, title: pair.proposed.title)
                choiceChip("Keep both", value: "both", current: current, title: pair.proposed.title)
            }
        }
        .padding(.vertical, 4)
    }

    private func choiceChip(_ label: String, value: String,
                            current: String, title: String) -> some View {
        let selected = current == value
        return Button {
            choices[title] = value
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(selected ? PB.forest : PB.soft)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Capsule().fill(selected ? PB.forest.opacity(0.18) : PB.glass))
                .overlay(Capsule().stroke(selected ? PB.forest : PB.glassBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
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

    private func tileSubtitle(_ t: DayTemplate) -> String {
        let n = t.blockCount ?? 0
        return "\(n) blocks" + (t.cyclic == true ? " · rota" : "")
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
            let p = try await ScheduleService.shared.previewTemplate(
                householdId: household, token: token, templateId: id, answers: answers)
            preview = p
            // Default to the template's version — that is what choosing a
            // template implies — but every row can be switched.
            var seed: [String: String] = [:]
            for c in p.collisions ?? [] { seed[c.proposed.title] = "theirs" }
            choices = seed
            step = 2
        } catch let DayBriefError.server(_, msg) {
            errorText = msg
        } catch let DecodingError.keyNotFound(key, ctx) {
            // Swallowing the decode error is how this looked like a server
            // failure when the server had returned a perfectly good 200.
            errorText = "Missing \(key.stringValue) at \(ctx.codingPath.map(\.stringValue).joined(separator: " → "))"
        } catch let DecodingError.typeMismatch(type, ctx) {
            errorText = "Expected \(type) at \(ctx.codingPath.map(\.stringValue).joined(separator: " → "))"
        } catch let DecodingError.valueNotFound(type, ctx) {
            errorText = "Null \(type) at \(ctx.codingPath.map(\.stringValue).joined(separator: " → "))"
        } catch {
            errorText = error.localizedDescription
        }
        busy = false
    }

    private func apply() async {
        guard let token = appState.authToken,
              let household = appState.activeHouseholdId,
              let id = templateId else { return }
        busy = true
        errorText = nil
        do {
            let decisions = choices.map { ["title": $0.key, "keep": $0.value] }
            _ = try await ScheduleService.shared.applyTemplate(
                householdId: household, token: token, templateId: id,
                answers: answers, decisions: decisions)
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

echo

echo "2. Verifying"
grep -q "decisions: \[\[String: String\]\]" "$D/ScheduleService.swift" \
  && echo "   ok   service sends decisions" \
  || { echo "   MISSING — reverting"; cp "$D/ScheduleService.swift.bakchoice" "$D/ScheduleService.swift"; exit 1; }
grep -q "func choiceChip" "$D/Views/SetupDayView.swift" && echo "   ok   choice chips"
grep -q "replaceAll" "$D/Views/SetupDayView.swift" \
  && echo "   WARN replaceAll still referenced" \
  || echo "   ok   replaceAll removed"
grep -q "mode: String" "$D/ScheduleService.swift" \
  && echo "   WARN mode parameter still present" \
  || echo "   ok   mode removed"
echo

echo "3. Building"
SIM=$(xcodebuild -scheme PlanBhai -showdestinations 2>/dev/null \
  | grep -oE "name:iPhone [^}]*" | sed 's/name://' | sed 's/ *$//' | head -1)
[ -z "$SIM" ] && SIM="iPhone 17"
echo "   simulator: $SIM"
xcodebuild -scheme PlanBhai -destination "platform=iOS Simulator,name=$SIM" build 2>&1 \
  | grep -E "error:|failures\)|BUILD (SUCCEEDED|FAILED)" | head -10
echo

echo "=========================================="
echo "  My Day -> Start from a template -> pick one -> See my day."
echo "  Each clash now has three chips. Choose per row, then Add to my day."
echo
echo "  Revert:"
echo "     cp $D/ScheduleService.swift.bakchoice $D/ScheduleService.swift"
echo "     cp $D/Views/SetupDayView.swift.bakchoice $D/Views/SetupDayView.swift"
echo "=========================================="

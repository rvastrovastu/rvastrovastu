#!/usr/bin/env bash
#
# Fixes "Couldn't build that day".
#
# THE BUG
#   The server returns two shapes for what looked like one thing:
#       blocks[0]               { title, kind, startTime, durationMin }
#       collisions[0].proposed  { title,       startTime, durationMin }
#
#   I reused PreviewBlock for both and declared `kind` as non-optional, so the
#   collision copy failed to decode — and one failed field takes the WHOLE
#   response with it. The endpoint had returned a perfectly good 200 the entire
#   time.
#
# THE FIX
#   `kind` is optional, defaulting to "admin" for its emoji.
#
# HOW IT WAS FOUND
#   The previous build swallowed the decode error into "Couldn't build that
#   day", which pointed at the server. Reporting the real DecodingError named it
#   exactly — "Missing kind at collisions → 0 → proposed" — and the fix was one
#   line.
#
#   The specific error handling stays. A decode failure that names the field is
#   worth far more than one that names nothing, and today has made that point
#   about ten times.
#
# Usage:
#   bash ~/Downloads/fix-preview-decode.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
D="PlanBhai/ios/PlanBhai"

echo "PlanBhai — preview decode fix"
echo

write() {
  local dest="$1"
  [ -f "$dest" ] && cp "$dest" "$dest.bakdecode"
  cat > "$dest"
  echo "   wrote $dest"
}

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
        // Optional. The blocks list carries `kind`; the copy inside a collision
        // does not — the server strips it down to title, time and duration.
        // Requiring it here made the whole preview fail to decode against a
        // perfectly good 200.
        let kind: String?
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

    @ViewBuilder
    private func reviewActions(_ p: TemplatePreview) -> some View {
        let hasCollisions = !(p.collisions ?? []).isEmpty
        let addLabel = hasCollisions ? "Add anyway" : "Add to my day"

        HStack(spacing: 10) {
            secondaryButton("Back") { step = 1 }

            if hasCollisions {
                Button { Task { await apply("replaceAll") } } label: {
                    Text("Replace my day")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PB.error)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(Capsule().stroke(PB.error.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(busy)
            }

            primaryButton(busy ? "Adding…" : addLabel, enabled: !busy) {
                Task { await apply("keep") }
            }
        }
    }

    private func collisionCard(_ c: [TemplatePreview.Collision]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOU ALREADY HAVE \(c.count) OF THESE")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(PB.warning).tracking(0.9)

            ForEach(c) { pair in
                collisionRow(pair)
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

    private func collisionRow(_ pair: TemplatePreview.Collision) -> some View {
        // The times are built before the view rather than interpolated inside
        // it — string building inside a nested SwiftUI expression is what made
        // the type-checker give up on this screen.
        let yours = display(pair.existing.startTime)
        let proposed = display(pair.proposed.startTime)

        return HStack {
            Text(pair.existing.title)
                .font(.system(size: 13))
                .foregroundStyle(.white)

            Spacer(minLength: 8)

            Text("yours " + yours + " · new " + proposed)
                .font(.system(size: 11))
                .foregroundStyle(PB.soft)
        }
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
            preview = try await ScheduleService.shared.previewTemplate(
                householdId: household, token: token, templateId: id, answers: answers)
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

grep -q "let kind: String?" "$D/ScheduleModels.swift" && echo "   ok   kind is optional" \
  || { echo "   MISSING — reverting"; cp "$D/ScheduleModels.swift.bakdecode" "$D/ScheduleModels.swift"; exit 1; }
echo

SIM=$(xcodebuild -scheme PlanBhai -showdestinations 2>/dev/null \
  | grep -oE "name:iPhone [^}]*" | sed 's/name://' | sed 's/ *$//' | head -1)
[ -z "$SIM" ] && SIM="iPhone 17"
echo "Building on $SIM"
xcodebuild -scheme PlanBhai -destination "platform=iOS Simulator,name=$SIM" build 2>&1 \
  | grep -E "error:|failures\)|BUILD (SUCCEEDED|FAILED)" | head -8
echo

echo "=========================================="
echo "  Tap \"See my day\" again — the review screen should appear, with the"
echo "  collision card listing the three blocks you already have."
echo
echo "  Revert:"
echo "     cp $D/ScheduleModels.swift.bakdecode $D/ScheduleModels.swift"
echo "     cp $D/Views/SetupDayView.swift.bakdecode $D/Views/SetupDayView.swift"
echo "=========================================="

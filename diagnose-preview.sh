#!/usr/bin/env bash
#
# "Couldn't build that day" — make iOS say what actually went wrong.
#
# The endpoint returns HTTP 200 with valid collisions; curl confirms it. So the
# failure is iOS DECODING the response, not fetching it — and my catch-all
# turned a decode error into a message that pointed at the server.
#
# That is the same swallowed-failure pattern that cost most of today: a generic
# message where a specific one existed.
#
# Now a DecodingError names the field and the path — "Missing kind at
# blocks → 0" — which is enough to fix the model in one pass instead of
# guessing at it.
#
# Only SetupDayView.swift changes.
#
# Usage:
#   bash ~/Downloads/diagnose-preview.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
DEST="PlanBhai/ios/PlanBhai/Views/SetupDayView.swift"
[ -f "$DEST" ] || { echo "ERROR: $DEST not found"; exit 1; }

echo "PlanBhai — diagnose the preview failure"
echo

cp "$DEST" "$DEST.bakdiag"
cat > "$DEST" << 'PLANBHAI_EOF'
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

            Text(blockEmoji(b.kind))
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
grep -q "DecodingError.keyNotFound" "$DEST" && echo "   ok   decode errors reported" \
  || { echo "   MISSING — reverting"; cp "$DEST.bakdiag" "$DEST"; exit 1; }
echo

SIM=$(xcodebuild -scheme PlanBhai -showdestinations 2>/dev/null \
  | grep -oE "name:iPhone [^}]*" | sed 's/name://' | sed 's/ *$//' | head -1)
[ -z "$SIM" ] && SIM="iPhone 17"
echo "Building on $SIM"
xcodebuild -scheme PlanBhai -destination "platform=iOS Simulator,name=$SIM" build 2>&1 \
  | grep -E "error:|failures\)|BUILD (SUCCEEDED|FAILED)" | head -8
echo

echo "=========================================="
echo "  Run it and tap \"See my day\" again. The red line will now name the"
echo "  field — something like \"Missing kind at blocks → 0\". Send me that"
echo "  and the model fix is one line."
echo
echo "  Revert:  cp $DEST.bakdiag $DEST"
echo "=========================================="

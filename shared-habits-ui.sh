#!/usr/bin/env bash
#
# Shared habits — the household kind, alongside your personal ones.
#
# WHAT WAS MISSING
#   Personal habits already worked; the Brief splits them per member correctly.
#   What did not exist was the SHARED kind — a family water challenge, a Sunday
#   walk — where the useful information is not "did I do it" but "who still
#   needs to".
#
#     8 glasses of water                          ○
#        Rit, Jim done · 1 to go
#
#     Sunday walk                                 ✓
#        Everyone's done
#
# COMPLETIONS ARE PER PERSON. One tick standing in for everyone would say
# nothing about whether the family actually did the thing.
#
# ADMIN ONLY to add or remove, matching the endpoint — a shared habit appears on
# everyone's screen, so adding one is a decision about other people's days.
# Everyone else sees the list and ticks their own.
#
# WORTH KNOWING BEFORE YOU LOOK
#   This shows little until other people have ACCOUNTS. Family Friend has four
#   members, but Jim and Joy are labels with no logins — they cannot tick
#   anything, so the status line will only ever mention the people who can.
#
#   The invite codes built earlier are what populate this. Until someone joins
#   for real, expect a thin section.
#
# Requires the /api/lists endpoints — deploy the backend first if you have not.
#
# Usage:
#   bash ~/Downloads/shared-habits-ui.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
D="PlanBhai/ios/PlanBhai"
H="$D/Views/HabitTrackerView.swift"
[ -f "$H" ] || { echo "ERROR: $H not found"; exit 1; }

echo "PlanBhai — shared habits"
echo

echo "1. Prerequisites"
grep -q "func isAdmin(userId:" "$D/Models.swift" \
  && echo "   ok   Household.isAdmin(userId:)" \
  || { echo "   MISSING isAdmin on the Swift model"; exit 1; }
grep -q "activeHousehold" "$D/AppState.swift" \
  && echo "   ok   activeHousehold" \
  || { echo "   MISSING activeHousehold"; exit 1; }
echo

echo "2. Service"
[ -f "$D/SharedHabitsService.swift" ] && cp "$D/SharedHabitsService.swift" "$D/SharedHabitsService.swift.baksh"
cat > "$D/SharedHabitsService.swift" << 'PLANBHAI_EOF'
import Foundation

/// A habit the whole household shares.
///
/// Personal habits already worked — yours are yours, and the Brief splits them
/// per member. What was missing is the shared kind: a family water challenge, a
/// Sunday walk, where the useful information is who still needs to.
struct SharedHabit: Codable, Identifiable {
    let id: String
    var name: String
    var emoji: String?

    init(id: String = UUID().uuidString.uppercased(), name: String, emoji: String? = nil) {
        self.id = id; self.name = name; self.emoji = emoji
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString.uppercased()
        name = (try? c.decode(String.self, forKey: .name))
            ?? (try? c.decode(String.self, forKey: .title)) ?? ""
        emoji = try? c.decode(String.self, forKey: .emoji)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(emoji, forKey: .emoji)
    }

    enum CodingKeys: String, CodingKey { case id, name, emoji, title }
}

/// Who has done a given shared habit today.
struct SharedHabitCompletion: Codable, Identifiable {
    let habitId: String
    let doneBy: [Person]
    var id: String { habitId }

    struct Person: Codable, Identifiable {
        let id: String
        let name: String
    }
}

@MainActor
final class SharedHabitsService {
    static let shared = SharedHabitsService()
    private let baseURL = "https://planbhai.onrender.com"
    private init() {}

    private struct ListResponse: Decodable {
        let success: Bool
        let habits: [SharedHabit]
        let completions: [SharedHabitCompletion]
        let memberCount: Int?
    }

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

    func fetch(householdId: String, token: String)
        async throws -> ([SharedHabit], [SharedHabitCompletion]) {
        let today = ISO8601DateFormatter.localDay()
        guard let r = request("/api/lists/habits/household?scopeId=\(householdId)&date=\(today)",
                              token: token) else { return ([], []) }
        let (data, response) = try await URLSession.shared.data(for: r)
        guard (200...299).contains((response as? HTTPURLResponse)?.statusCode ?? 500) else {
            return ([], [])
        }
        let res = try JSONDecoder().decode(ListResponse.self, from: data)
        return (res.habits, res.completions)
    }

    /// Admin only, server-side. A shared habit appears on everyone's screen, so
    /// adding one is a decision about other people's days.
    @discardableResult
    func save(householdId: String, token: String, habits: [SharedHabit]) async throws -> Bool {
        let encoded = habits.map { h -> [String: Any] in
            var d: [String: Any] = ["id": h.id, "name": h.name]
            if let e = h.emoji { d["emoji"] = e }
            return d
        }
        guard let r = request("/api/lists/habits/household?scopeId=\(householdId)",
                              method: "POST", token: token, body: ["habits": encoded])
        else { return false }

        let (data, response) = try await URLSession.shared.data(for: r)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 500
        guard (200...299).contains(code) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
            throw DayBriefError.server(code, msg ?? "Couldn't save shared habits.")
        }
        return true
    }

    /// Ticks YOUR completion. Completions are per person — one tick standing in
    /// for everyone would say nothing about whether the family actually did it.
    @discardableResult
    func setDone(householdId: String, token: String, habitId: String, done: Bool) async throws -> Bool {
        guard let r = request("/api/lists/habits/household/done?scopeId=\(householdId)",
                              method: "POST", token: token,
                              body: ["habitId": habitId, "date": ISO8601DateFormatter.localDay(), "done": done])
        else { return false }
        let (_, response) = try await URLSession.shared.data(for: r)
        return (200...299).contains((response as? HTTPURLResponse)?.statusCode ?? 500)
    }
}

extension ISO8601DateFormatter {
    /// "yyyy-MM-dd" in the device's timezone — the day the person is actually
    /// living in, not UTC's.
    static func localDay() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: Date())
    }
}
PLANBHAI_EOF
echo "   wrote $D/SharedHabitsService.swift"
echo

echo "3. Section"
cp "$H" "$H.baksh"
cat > /tmp/pb_sh.swift << 'PLANBHAI_EOF'
// MARK: - Shared habits
//
// Personal habits already worked. What was missing is the shared kind — a
// family water challenge, a Sunday walk — where the useful information is not
// "did I do it" but "who still needs to".
//
// Completions are per person. One tick standing in for everyone would say
// nothing about whether the family actually did the thing.
struct SharedHabitsSection: View {
    @EnvironmentObject var appState: AppState

    @State private var habits: [SharedHabit] = []
    @State private var completions: [SharedHabitCompletion] = []
    @State private var editing = false
    @State private var newName = ""
    @State private var busy = false
    @State private var errorText: String?

    private var household: Household? { appState.activeHousehold }

    private var isAdmin: Bool {
        household?.isAdmin(userId: appState.currentUser?.id ?? "") ?? false
    }

    var body: some View {
        if household != nil {
            VStack(alignment: .leading, spacing: 12) {
                header

                if let errorText {
                    Text(errorText)
                        .font(.system(size: 11)).foregroundStyle(PB.error)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if habits.isEmpty {
                    emptyState
                } else {
                    ForEach(habits) { habit in
                        habitRow(habit)
                    }
                }

                if editing { composer }
            }
            .padding(16)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .task(id: household?.id) { await load() }
        }
    }

    private var header: some View {
        HStack {
            Text("SHARED WITH \(household?.name.uppercased() ?? "HOUSEHOLD")")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.45))
                .tracking(1.1)
                .lineLimit(1)
            Spacer(minLength: 8)
            // Admin only, matching the endpoint. A control that always fails is
            // worse than no control.
            if isAdmin {
                Button { editing.toggle() } label: {
                    Text(editing ? "Done" : "Edit")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PB.forest)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        Text(isAdmin
             ? "Habits everyone ticks — a water challenge, a Sunday walk. Tap Edit to add one."
             : "Nothing shared yet. The household owner can add habits everyone tracks together.")
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.45))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func habitRow(_ habit: SharedHabit) -> some View {
        let done = completions.first { $0.habitId == habit.id }?.doneBy ?? []
        let mine = done.contains { $0.id == appState.currentUser?.id }

        return HStack(alignment: .top, spacing: 12) {
            Button { Task { await toggle(habit, to: !mine) } } label: {
                Image(systemName: mine ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(mine ? PB.forest : PB.muted)
            }
            .buttonStyle(.plain)
            .disabled(busy)

            VStack(alignment: .leading, spacing: 3) {
                Text(habit.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                Text(statusLine(done))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if editing && isAdmin {
                Button { Task { await remove(habit) } } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(PB.error.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    /// "Rit and Jim done · Test1 waiting" — the point of a shared habit. A
    /// personal one cannot tell you this.
    private func statusLine(_ doneBy: [SharedHabitCompletion.Person]) -> String {
        let members = household?.members ?? []
        if members.isEmpty { return "No one yet" }

        let doneIds = Set(doneBy.map(\.id))
        let waiting = members.filter { !doneIds.contains($0.id) }

        if waiting.isEmpty { return "Everyone's done" }
        if doneBy.isEmpty { return "No one yet" }

        let names = doneBy.map(\.name).joined(separator: ", ")
        return "\(names) done · \(waiting.count) to go"
    }

    private var composer: some View {
        HStack(spacing: 8) {
            TextField("", text: $newName,
                      prompt: Text("New shared habit").foregroundStyle(.white.opacity(0.35)))
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))

            Button { Task { await add() } } label: {
                Text("Add")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PB.forest)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(PB.forest.opacity(0.14)))
            }
            .buttonStyle(.plain)
            .disabled(busy || newName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    // MARK: - Data

    private func load() async {
        guard let h = household, let token = appState.authToken else { return }
        if let pair = try? await SharedHabitsService.shared.fetch(householdId: h.id, token: token) {
            habits = pair.0
            completions = pair.1
        }
    }

    private func toggle(_ habit: SharedHabit, to done: Bool) async {
        guard let h = household, let token = appState.authToken, !busy else { return }
        busy = true
        _ = try? await SharedHabitsService.shared.setDone(
            householdId: h.id, token: token, habitId: habit.id, done: done)
        await load()
        busy = false
    }

    private func add() async {
        guard let h = household, let token = appState.authToken else { return }
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        busy = true
        errorText = nil
        do {
            try await SharedHabitsService.shared.save(
                householdId: h.id, token: token, habits: habits + [SharedHabit(name: name)])
            newName = ""
            await load()
        } catch let DayBriefError.server(_, msg) {
            errorText = msg
        } catch {
            errorText = "Couldn't add that."
        }
        busy = false
    }

    private func remove(_ habit: SharedHabit) async {
        guard let h = household, let token = appState.authToken else { return }
        busy = true
        try? await SharedHabitsService.shared.save(
            householdId: h.id, token: token, habits: habits.filter { $0.id != habit.id })
        await load()
        busy = false
    }
}
PLANBHAI_EOF
cat > /tmp/pb_ph.py << 'PLANBHAI_EOF'
import sys
p, section = sys.argv[1], sys.argv[2]
s = open(p).read()

if 'SharedHabitsSection' in s:
    print("   already placed"); sys.exit(3)

# After the personal habits block. The empty case and the ForEach both close
# before this marker.
anchor = """                        if appState.habits.isEmpty {
                            EmptyStateView(icon: "checkmark.circle", color: PB.forest, title: "No habits yet",
                                           subtitle: "Add your first habit to start building better routines")
                        } else {"""
if anchor not in s:
    print("   ERROR: the habits block is not in the expected shape"); sys.exit(2)

# Find where that if/else closes, by locating the next line at the same
# indentation that starts a new statement.
start = s.index(anchor)
depth = 0
i = s.index('{', start + len("                        if appState.habits.isEmpty "))
for j in range(i, len(s)):
    if s[j] == '{': depth += 1
    elif s[j] == '}':
        depth -= 1
        if depth == 0:
            # This closes the `if`. The `else` follows; keep walking.
            rest = s[j+1:j+40]
            if 'else' in rest:
                depth = 0
                k = s.index('{', j)
                for m in range(k, len(s)):
                    if s[m] == '{': depth += 1
                    elif s[m] == '}':
                        depth -= 1
                        if depth == 0:
                            insert_at = m + 1
                            break
                break
            insert_at = j + 1
            break

s = s[:insert_at] + "\n\n                        SharedHabitsSection()\n" + s[insert_at:]
s = s.rstrip() + "\n\n" + open(section).read()
open(p, "w").write(s)
print("   section placed after personal habits")
PLANBHAI_EOF
python3 /tmp/pb_ph.py "$H" /tmp/pb_sh.swift
RC=$?
rm -f /tmp/pb_ph.py /tmp/pb_sh.swift
if [ "$RC" = "3" ]; then
  echo "   nothing to do"
elif [ "$RC" != "0" ]; then
  cp "$H.baksh" "$H"
  rm -f "$D/SharedHabitsService.swift"
  echo "   reverted"; exit 1
fi
echo

echo "4. Verifying"
grep -q "struct SharedHabitsSection" "$H" && echo "   ok   section defined"
grep -q "SharedHabitsSection()" "$H" && echo "   ok   section placed"
echo

echo "5. Building"
SIM=$(xcodebuild -scheme PlanBhai -showdestinations 2>/dev/null \
  | grep -oE "name:iPhone [^}]*" | sed 's/name://' | sed 's/ *$//' | head -1)
[ -z "$SIM" ] && SIM="iPhone 17"
echo "   simulator: $SIM"
xcodebuild -scheme PlanBhai -destination "platform=iOS Simulator,name=$SIM" build 2>&1 \
  | grep -E "error:|failures\)|BUILD (SUCCEEDED|FAILED)" | head -15
echo

echo "=========================================="
echo "  Lifestyle -> Habits. The shared section sits under your own."
echo "  As owner you get Edit; add one and tick it to see the status line."
echo
echo "  Revert:"
echo "     rm $D/SharedHabitsService.swift"
echo "     cp $H.baksh $H"
echo "=========================================="

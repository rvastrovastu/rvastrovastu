#!/usr/bin/env bash
#
# Personal invite codes, on the household screen.
#
# TWO KINDS OF CODE, AND THE DIFFERENCE MATTERS
#   The household's INVITE CODE is permanent and shared. Anyone with it joins as
#   a new member, attached to nothing.
#
#   A PERSONAL code is single-use and tied to a family member. When Jim joins
#   with his, his label links to his account — so the chores assigned to "Jim"
#   become chores assigned to a person the app can actually reach.
#
#   Both sit on the same screen because they answer the same question, and the
#   labels say plainly that they do different things.
#
# NO EMAIL. Creating a code opens the share sheet immediately — Messages,
# WhatsApp, whatever they already use. A code you have to go back and find is a
# code that does not get sent.
#
# ADMIN ONLY, matching the endpoint. A control that always fails is worse than
# no control.
#
# Requires the invite endpoints — deploy the backend first if you have not.
#
# Usage:
#   bash ~/Downloads/ios-invite-ui.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
D="PlanBhai/ios/PlanBhai"
H="$D/Views/HouseholdView.swift"
[ -f "$H" ] || { echo "ERROR: $H not found"; exit 1; }

echo "PlanBhai — invite UI"
echo

echo "1. Checking the model has isAdmin"
grep -q "func isAdmin(userId:" "$D/Models.swift" \
  && echo "   ok   Household.isAdmin(userId:)" \
  || { echo "   MISSING isAdmin on the Swift Household model — the section cannot gate itself"; exit 1; }
echo

echo "2. Service"
[ -f "$D/InviteService.swift" ] && cp "$D/InviteService.swift" "$D/InviteService.swift.bakinv"
cat > "$D/InviteService.swift" << 'PLANBHAI_EOF'
import Foundation

/// A pending invitation to join a household.
struct HouseholdInvite: Codable, Identifiable {
    let id: String
    let code: String
    let inviteeName: String
    let familyMemberId: String?
    let expired: Bool?

    enum CodingKeys: String, CodingKey {
        case id, code, inviteeName, familyMemberId, expired
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        code = (try? c.decode(String.self, forKey: .code)) ?? ""
        inviteeName = (try? c.decode(String.self, forKey: .inviteeName)) ?? ""
        familyMemberId = try? c.decode(String.self, forKey: .familyMemberId)
        expired = try? c.decode(Bool.self, forKey: .expired)
    }
}

/// Household invitations, as shareable codes.
///
/// No email. Sharing is solved by the phone in your hand — the code goes
/// wherever the person already talks to their family.
@MainActor
final class InviteService {
    static let shared = InviteService()
    private let baseURL = "https://planbhai.onrender.com"
    private init() {}

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

    private struct ListResponse: Decodable {
        let success: Bool
        let invites: [HouseholdInvite]
    }
    private struct CreateResponse: Decodable {
        let success: Bool
        let invite: HouseholdInvite?
        let message: String?
    }

    func list(householdId: String, token: String) async throws -> [HouseholdInvite] {
        guard let r = request("/api/invites/\(householdId)", token: token) else { return [] }
        let (data, response) = try await URLSession.shared.data(for: r)
        guard (200...299).contains((response as? HTTPURLResponse)?.statusCode ?? 500) else { return [] }
        return try JSONDecoder().decode(ListResponse.self, from: data).invites
    }

    func create(householdId: String, token: String,
                inviteeName: String, familyMemberId: String? = nil) async throws -> HouseholdInvite {
        var body: [String: Any] = ["householdId": householdId, "inviteeName": inviteeName]
        if let familyMemberId { body["familyMemberId"] = familyMemberId }

        guard let r = request("/api/invites/create", method: "POST", token: token, body: body) else {
            throw DayBriefError.server(0, "Bad URL")
        }
        let (data, response) = try await URLSession.shared.data(for: r)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 500
        let res = try? JSONDecoder().decode(CreateResponse.self, from: data)

        guard (200...299).contains(code), let invite = res?.invite else {
            throw DayBriefError.server(code, res?.message ?? "Couldn't create that invite.")
        }
        return invite
    }

    @discardableResult
    func revoke(inviteId: String, token: String) async throws -> Bool {
        guard let r = request("/api/invites/revoke", method: "POST",
                              token: token, body: ["inviteId": inviteId]) else { return false }
        let (_, response) = try await URLSession.shared.data(for: r)
        return (200...299).contains((response as? HTTPURLResponse)?.statusCode ?? 500)
    }
}
PLANBHAI_EOF
echo "   wrote $D/InviteService.swift"
echo

echo "3. Section"
cp "$H" "$H.bakinv"
cat > /tmp/pb_sec.swift << 'PLANBHAI_EOF'
// MARK: - Personal invites
//
// The household's INVITE CODE above is permanent and shared — anyone with it
// joins as a new member, unattached to anything.
//
// A PERSONAL code is different: single-use, and tied to a family member. When
// Jim joins with his, his label links to his account, so the chores assigned to
// "Jim" become chores assigned to a person the app can actually reach.
//
// Both live on this screen because they answer the same question — how do I get
// someone in — but they do different things, and the labels say so.
struct PersonalInvitesSection: View {
    let household: Household
    @EnvironmentObject var appState: AppState

    @State private var invites: [HouseholdInvite] = []
    @State private var newName = ""
    @State private var busy = false
    @State private var errorText: String?
    @State private var shareCode: String?

    private var isAdmin: Bool {
        household.isAdmin(userId: appState.currentUser?.id ?? "")
    }

    var body: some View {
        // Admin only, matching the endpoint. Showing a control that always
        // fails is worse than not showing it.
        if isAdmin {
            VStack(alignment: .leading, spacing: 12) {
                Text("INVITE SOMEONE").font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.40)).tracking(1.2)

                Text("A personal code links them to a family member, so their chores follow them.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    TextField("", text: $newName,
                              prompt: Text("Their name").foregroundStyle(.white.opacity(0.35)))
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))

                    Button { Task { await create() } } label: {
                        Text(busy ? "…" : "Create")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(household.categoryEnum.color)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10)
                                .fill(household.categoryEnum.color.opacity(0.14)))
                    }
                    .buttonStyle(.plain)
                    .disabled(busy)
                }

                if let errorText {
                    Text(errorText)
                        .font(.system(size: 11)).foregroundStyle(PB.error)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(invites) { invite in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(invite.inviteeName.isEmpty ? "Anyone" : invite.inviteeName)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                            Text(invite.code)
                                .font(.system(size: 15, weight: .black, design: .monospaced))
                                .foregroundStyle(household.categoryEnum.color)
                                .tracking(2)
                        }

                        Spacer(minLength: 0)

                        Button { shareCode = invite.code } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14))
                                .foregroundStyle(household.categoryEnum.color)
                        }
                        .buttonStyle(.plain)

                        Button { Task { await revoke(invite) } } label: {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(11)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .task(id: household.id) { await load() }
            .sheet(isPresented: Binding(
                get: { shareCode != nil },
                set: { if !$0 { shareCode = nil } }
            )) {
                if let code = shareCode {
                    // Whatever they already use to talk to Jim — Messages,
                    // WhatsApp, reading it aloud. Sharing is solved by the phone.
                    ShareSheet(items: [
                        "Join \(household.name) on PlanBhai with this code: \(code)"
                    ])
                }
            }
        }
    }

    private func load() async {
        guard isAdmin, let token = appState.authToken else { return }
        invites = (try? await InviteService.shared.list(householdId: household.id, token: token)) ?? []
    }

    private func create() async {
        guard let token = appState.authToken, !busy else { return }
        busy = true
        errorText = nil
        do {
            let made = try await InviteService.shared.create(
                householdId: household.id, token: token,
                inviteeName: newName.trimmingCharacters(in: .whitespaces))
            newName = ""
            // Straight to the share sheet — a code you have to go and find
            // afterwards is a code that does not get sent.
            shareCode = made.code
            await load()
        } catch let DayBriefError.server(_, msg) {
            errorText = msg
        } catch {
            errorText = "Couldn't create that invite."
        }
        busy = false
    }

    private func revoke(_ invite: HouseholdInvite) async {
        guard let token = appState.authToken else { return }
        try? await InviteService.shared.revoke(inviteId: invite.id, token: token)
        await load()
    }
}

/// UIActivityViewController, so a code goes wherever the person already talks.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
PLANBHAI_EOF
cat > /tmp/pb_place.py << 'PLANBHAI_EOF'
import sys
p = sys.argv[1]
s = open(p).read()

if 'PersonalInvitesSection' in s:
    print("   already placed"); sys.exit(3)

# Right after the existing shared INVITE CODE block — same question, different
# answer, so they belong together.
old = """                        .padding(14).background(household.categoryEnum.color.opacity(0.10)).clipShape(RoundedRectangle(cornerRadius: 12))

                        Button(role: .destructive) { showLeaveConfirm = true } label: {"""
new = """                        .padding(14).background(household.categoryEnum.color.opacity(0.10)).clipShape(RoundedRectangle(cornerRadius: 12))

                        PersonalInvitesSection(household: household)

                        Button(role: .destructive) { showLeaveConfirm = true } label: {"""

if old not in s:
    print("   ERROR: the invite code block is not in the expected shape"); sys.exit(2)

s = s.replace(old, new, 1)
s = s.rstrip() + "\n\n" + open(sys.argv[2]).read()
open(p, "w").write(s)
print("   section placed and appended")
PLANBHAI_EOF
python3 /tmp/pb_place.py "$H" /tmp/pb_sec.swift
RC=$?
rm -f /tmp/pb_place.py /tmp/pb_sec.swift
if [ "$RC" = "3" ]; then
  echo "   nothing to do"
elif [ "$RC" != "0" ]; then
  cp "$H.bakinv" "$H"
  echo "   reverted"; exit 1
fi
echo

echo "4. Verifying"
grep -q "struct PersonalInvitesSection" "$H" && echo "   ok   section defined"
grep -q "PersonalInvitesSection(household:" "$H" && echo "   ok   section placed"
n=$(grep -c "struct ShareSheet" "$D"/*.swift "$D"/Views/*.swift 2>/dev/null | awk -F: '{t+=$2} END {print t}')
[ "${n:-0}" -gt 1 ] && echo "   warn ShareSheet defined $n times — one may need removing" \
                    || echo "   ok   one ShareSheet"
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
echo "  Household -> open one you own -> INVITE SOMEONE."
echo "  Type a name, tap Create, and the share sheet opens with the code."
echo
echo "  Revert:"
echo "     rm $D/InviteService.swift"
echo "     cp $H.bakinv $H"
echo "=========================================="

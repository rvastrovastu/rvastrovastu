#!/usr/bin/env bash
#
# Fixes "Load party_guests failed" and "Load party_menu_items failed".
#
# THE PATTERN, for the fifth and sixth time
#   Web writes JavaScript ids — "mse37xjyqb9hzh". iOS declared `let id: UUID`.
#   The whole list fails to decode, and iOS shows nothing while 30 guests and
#   9 menu items sit in the database.
#
#   Already fixed this way for Challenge, GroupMember, PlanGroup and Habit. I
#   did not check these two at the time, which is why they are still broken.
#
# PARTYMENUITEM WAS WORSE
#   stored    { id, eventId, name, assignedTo, confirmed }
#   declared  { id: UUID, item, quantity, category }
#
#   Not one wrong field — two unrelated models sharing a storage key. It now
#   reads BOTH shapes and writes BOTH spellings, so neither client blanks the
#   other's dishes.
#
# ALSO ADDED: eventId, assignedTo and confirmed, which web writes and iOS was
# silently dropping on every save.
#
# THE GROCERY REPAIR IS ALREADY DONE — 23 rows written as { name, amount } by
# web's old plan-save were converted to { item, quantity } with generated ids.
#
# Only Models.swift changes. Swift will flag any call site still passing a UUID.
#
# Usage:
#   bash ~/Downloads/fix-party-structs.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
M="PlanBhai/ios/PlanBhai/Models.swift"
[ -f "$M" ] || { echo "ERROR: $M not found"; exit 1; }

echo "PlanBhai — party struct decoding"
echo

if grep -A 4 "^struct PartyGuest" "$M" | grep -q "let id: String"; then
  echo "   already tolerant"
  exit 0
fi

echo "1. Replacing PartyGuest and PartyMenuItem"
cp "$M" "$M.bakparty"
cat > /tmp/pb_party.txt << 'PLANBHAI_EOF'
struct PartyGuest: Identifiable, Codable {
    let id: String
    var name: String
    var phone: String
    var rsvpStatus: String
    var dietaryRestrictions: String = ""
    var plusOnes: Int = 0               // additional guests this person is bringing
    var bringingItem: String = ""       // potluck: free-text dish/drink, or claimed menu item's name
    var claimedMenuItemId: String? = nil // potluck: links to a specific PartyMenuItem, if claimed
    var eventId: String? = nil          // which party this guest belongs to — written by web

    init(id: String = UUID().uuidString, name: String, phone: String = "",
         rsvpStatus: String = "Pending", dietaryRestrictions: String = "",
         plusOnes: Int = 0, bringingItem: String = "",
         claimedMenuItemId: String? = nil, eventId: String? = nil) {
        self.id = id; self.name = name; self.phone = phone
        self.rsvpStatus = rsvpStatus; self.dietaryRestrictions = dietaryRestrictions
        self.plusOnes = plusOnes; self.bringingItem = bringingItem
        self.claimedMenuItemId = claimedMenuItemId; self.eventId = eventId
    }

    /// `id` is a String, not a UUID.
    ///
    /// Web writes JavaScript ids like "mse37xjyqb9hzh". Declaring UUID meant
    /// the whole guest list failed to decode — "not in the correct format" —
    /// and iOS showed no guests at all while 30 sat in the database.
    ///
    /// Same fix already applied to Challenge, GroupMember, PlanGroup and Habit.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        phone = (try? c.decode(String.self, forKey: .phone)) ?? ""
        rsvpStatus = (try? c.decode(String.self, forKey: .rsvpStatus)) ?? "Pending"
        dietaryRestrictions = (try? c.decode(String.self, forKey: .dietaryRestrictions)) ?? ""
        plusOnes = (try? c.decode(Int.self, forKey: .plusOnes)) ?? 0
        bringingItem = (try? c.decode(String.self, forKey: .bringingItem)) ?? ""
        claimedMenuItemId = try? c.decode(String.self, forKey: .claimedMenuItemId)
        eventId = try? c.decode(String.self, forKey: .eventId)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, phone, rsvpStatus, dietaryRestrictions
        case plusOnes, bringingItem, claimedMenuItemId, eventId
    }
}

struct PartyMenuItem: Codable, Identifiable {
    let id: String
    /// The dish. Stored as `name` by web, `item` by older iOS records — both
    /// are read, and both are written, so neither client loses the other's data.
    var item: String
    var quantity: String
    var category: String
    var eventId: String? = nil
    var assignedTo: String = "Unassigned"
    var confirmed: Bool = false

    init(id: String = UUID().uuidString, item: String, quantity: String = "1",
         category: String = "Main", eventId: String? = nil,
         assignedTo: String = "Unassigned", confirmed: Bool = false) {
        self.id = id; self.item = item; self.quantity = quantity
        self.category = category; self.eventId = eventId
        self.assignedTo = assignedTo; self.confirmed = confirmed
    }

    /// The stored shape was entirely different from the declared one:
    ///   stored   { id: "mse35dvv…", eventId, name, assignedTo, confirmed }
    ///   declared { id: UUID, item, quantity, category }
    ///
    /// Not one wrong field — two unrelated models sharing a key. Reading both
    /// is what makes the existing 9 menu items visible again.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        item = (try? c.decode(String.self, forKey: .item))
            ?? (try? c.decode(String.self, forKey: .name)) ?? ""
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        quantity = (try? c.decode(String.self, forKey: .quantity)) ?? "1"
        category = (try? c.decode(String.self, forKey: .category)) ?? "Main"
        eventId = try? c.decode(String.self, forKey: .eventId)
        assignedTo = (try? c.decode(String.self, forKey: .assignedTo)) ?? "Unassigned"
        confirmed = (try? c.decode(Bool.self, forKey: .confirmed)) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        // Both spellings, so a save from iOS does not blank the dish on web.
        try c.encode(item, forKey: .item)
        try c.encode(item, forKey: .name)
        try c.encode(quantity, forKey: .quantity)
        try c.encode(category, forKey: .category)
        try c.encodeIfPresent(eventId, forKey: .eventId)
        try c.encode(assignedTo, forKey: .assignedTo)
        try c.encode(confirmed, forKey: .confirmed)
    }

    enum CodingKeys: String, CodingKey {
        case id, item, quantity, category, eventId, assignedTo, confirmed
        case name
    }
}
PLANBHAI_EOF

python3 - "$M" /tmp/pb_party.txt << 'PY_EOF'
import sys, re
path, newfile = sys.argv[1], sys.argv[2]
s = open(path).read()
new = open(newfile).read()

# Split the replacement into its two structs.
i = new.index("struct PartyMenuItem")
guest_new, menu_new = new[:i].rstrip(), new[i:].rstrip()

g = re.search(r"struct PartyGuest: Identifiable, Codable \{.*?\n\}", s, re.S)
if not g:
    print("   ERROR: PartyGuest not in the expected shape"); sys.exit(2)
s = s[:g.start()] + guest_new + s[g.end():]

mm = re.search(r"struct PartyMenuItem: Codable, Identifiable \{.*?\n\}\n", s, re.S)
if not mm:
    print("   ERROR: PartyMenuItem not in the expected shape"); sys.exit(2)
s = s[:mm.start()] + menu_new + "\n" + s[mm.end():]

open(path, "w").write(s)
print("   both replaced")
PY_EOF
if [ $? -ne 0 ]; then
  cp "$M.bakparty" "$M"
  echo "   reverted — no changes made"
  exit 1
fi
rm -f /tmp/pb_party.txt
echo

echo "2. Verifying"
for k in "struct PartyGuest" "struct PartyMenuItem"; do
  n=$(grep -c "^$k" "$M")
  [ "$n" = "1" ] && echo "   ok   one $k" \
    || { echo "   $n copies — reverting"; cp "$M.bakparty" "$M"; exit 1; }
done
grep -A 3 "^struct PartyGuest" "$M" | grep -q "let id: String" && echo "   ok   guest id is String"
grep -q "forKey: .name" "$M" && echo "   ok   menu reads the web shape"
echo

echo "3. Building — expect errors at any call site still passing a UUID"
SIM=$(xcodebuild -scheme PlanBhai -showdestinations 2>/dev/null \
  | grep -oE "name:iPhone [^}]*" | sed 's/name://' | sed 's/ *$//' | head -1)
[ -z "$SIM" ] && SIM="iPhone 17"
echo "   simulator: $SIM"
xcodebuild -scheme PlanBhai -destination "platform=iOS Simulator,name=$SIM" build 2>&1 \
  | grep -E "error:|failures\)|BUILD (SUCCEEDED|FAILED)" | head -20
echo

echo "=========================================="
echo "  Paste any errors — they will be places constructing these with a UUID,"
echo "  or comparing ids. Each is a one-line change."
echo
echo "  Revert:  cp $M.bakparty $M"
echo "=========================================="

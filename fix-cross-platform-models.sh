#!/usr/bin/env bash
#
# Fixes iOS and web silently overwriting each other's data.
#
# THE PROBLEM
#   habits, challenges and groups are written by BOTH apps, and the two
#   disagreed about shape:
#
#     challenges   web {name, totalDays, daysCompleted, startedAt}, no id
#                  iOS {id: UUID, title, goal, progress, target}
#     groups       web id "1785009324938" (a JS timestamp), members {name, contact}
#                  iOS id: UUID, category: GroupCategory, members {id: UUID, phone}
#
#   iOS decoding failed, its in-memory value stayed empty, and the next save
#   wrote that emptiness over the web's record. The two clients have been
#   quietly destroying each other's data.
#
#   That is what emptied 5 habits, 1 challenge and 1 group at 18:11 — and what
#   the console now reports honestly as "data is missing" / "not in the correct
#   format" because the load guard stopped hiding it.
#
# THE FIX
#   `id` becomes String rather than UUID. A synthesised UUID would let each app
#   hold the same record under a different identity — edit a challenge on the
#   phone and get a second one on the web. String ids make them agree.
#
#   Each type decodes BOTH shapes and writes BOTH spellings, so records heal on
#   next save and neither client loses the other's.
#
#   startedAt is preserved even though iOS has no UI for it — dropping a field
#   the other app owns is how this started.
#
# Only Models.swift changes. Swift will flag any construction site that still
# passes a UUID; there are two (AppState:861 and AppState:1287).
#
# Usage:
#   bash ~/Downloads/fix-cross-platform-models.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
M="PlanBhai/ios/PlanBhai/Models.swift"
[ -f "$M" ] || { echo "ERROR: $M not found"; exit 1; }

echo "PlanBhai — reconciling iOS and web shapes"
echo

if grep -q "Cross-platform records" "$M"; then
  echo "   already applied"
  exit 0
fi

echo "1. Replacing Challenge, GroupMember and PlanGroup"
cp "$M" "$M.bakxplat"
cat > /tmp/pb_xplat.txt << 'PLANBHAI_EOF'
// MARK: - Cross-platform records
//
// These three types are written by BOTH iOS and the web app, and the two
// disagreed about shape. Web sends `name` where iOS expects `title`, JavaScript
// timestamp strings where iOS expects a UUID, and omits fields iOS declared
// non-optional. Decoding failed, iOS's in-memory value stayed empty, and the
// next save wrote that emptiness over the web's record — the two clients were
// quietly overwriting each other.
//
// `id` is now String rather than UUID. A synthesised UUID would let both apps
// keep a copy of the same record under different identities, so editing a
// challenge on the phone would create a second one on the web. String ids mean
// they agree on identity permanently.
//
// Each decoder reads BOTH shapes and normalises on write, so the record heals
// the next time it is saved.

struct Challenge: Identifiable, Codable {
    let id: String
    var title: String
    var goal: String
    var progress: Int
    var target: Int
    /// Web sends this; iOS has no UI for it. Kept so an iOS save doesn't erase it.
    var startedAt: String?

    init(id: String = UUID().uuidString, title: String, goal: String = "",
         progress: Int = 0, target: Int = 30, startedAt: String? = nil) {
        self.id = id; self.title = title; self.goal = goal
        self.progress = progress; self.target = target; self.startedAt = startedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Web writes no id at all — derive a stable one from the name so the
        // same challenge keeps the same identity across loads.
        title = (try? c.decode(String.self, forKey: .title))
             ?? (try? c.decode(String.self, forKey: .name)) ?? "Challenge"
        id = (try? c.decode(String.self, forKey: .id)) ?? "web:\(title)"
        goal = (try? c.decode(String.self, forKey: .goal)) ?? ""
        progress = (try? c.decode(Int.self, forKey: .progress))
                ?? (try? c.decode(Int.self, forKey: .daysCompleted)) ?? 0
        target = (try? c.decode(Int.self, forKey: .target))
              ?? (try? c.decode(Int.self, forKey: .totalDays)) ?? 30
        startedAt = try? c.decode(String.self, forKey: .startedAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        // Write both spellings so neither client loses the record.
        try c.encode(title, forKey: .title)
        try c.encode(title, forKey: .name)
        try c.encode(goal, forKey: .goal)
        try c.encode(progress, forKey: .progress)
        try c.encode(progress, forKey: .daysCompleted)
        try c.encode(target, forKey: .target)
        try c.encode(target, forKey: .totalDays)
        try c.encodeIfPresent(startedAt, forKey: .startedAt)
    }

    enum CodingKeys: String, CodingKey {
        case id, title, goal, progress, target
        case name, totalDays, daysCompleted, startedAt
    }
}

struct GroupMember: Identifiable, Codable {
    let id: String
    var name: String
    var phone: String = ""

    init(id: String = UUID().uuidString, name: String, phone: String = "") {
        self.id = id; self.name = name; self.phone = phone
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        id = (try? c.decode(String.self, forKey: .id)) ?? "web:\(name)"
        // Web calls it `contact`.
        phone = (try? c.decode(String.self, forKey: .phone))
             ?? (try? c.decode(String.self, forKey: .contact)) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(phone, forKey: .phone)
        try c.encode(phone, forKey: .contact)
    }

    enum CodingKeys: String, CodingKey { case id, name, phone, contact }
}

struct PlanGroup: Identifiable, Codable {
    let id: String
    var name: String
    var category: GroupCategory
    var members: [GroupMember] = []
    var sharedFeatures: Set<SharedFeature> = []
    var createdAt: String = ""

    init(id: String = UUID().uuidString, name: String, category: GroupCategory = .custom,
         members: [GroupMember] = [], sharedFeatures: Set<SharedFeature> = [],
         createdAt: String = "") {
        self.id = id; self.name = name; self.category = category
        self.members = members; self.sharedFeatures = sharedFeatures; self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        // Web sends a JS timestamp string like "1785009324938" — never a UUID.
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        // Web omits category entirely. `.custom` matches the "custom" default
        // already in the Household schema.
        category = (try? c.decode(GroupCategory.self, forKey: .category)) ?? .custom
        members = (try? c.decode([GroupMember].self, forKey: .members)) ?? []
        sharedFeatures = (try? c.decode(Set<SharedFeature>.self, forKey: .sharedFeatures)) ?? []
        createdAt = (try? c.decode(String.self, forKey: .createdAt)) ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case id, name, category, members, sharedFeatures, createdAt
    }
}
PLANBHAI_EOF

python3 - "$M" /tmp/pb_xplat.txt << 'PY_EOF'
import sys, re
path, newfile = sys.argv[1], sys.argv[2]
s = open(path).read()
new = open(newfile).read()

targets = [
    r"struct Challenge: Identifiable, Codable \{.*?\n\}\n",
    r"struct GroupMember: Identifiable, Codable \{.*?\n\}\n",
    r"struct PlanGroup: Identifiable, Codable \{.*?\n\}\n",
]
for t in targets:
    m = re.search(t, s, re.S)
    if not m:
        print(f"   ERROR: could not find {t[:34]}...")
        sys.exit(2)
    s = s[:m.start()] + s[m.end():]

# Append the replacements at the end — they reference GroupCategory and
# SharedFeature, both declared earlier in the file.
s = s.rstrip() + "\n\n" + new
open(path, "w").write(s)
print("   removed the three old structs and appended the tolerant versions")
PY_EOF
if [ $? -ne 0 ]; then
  cp "$M.bakxplat" "$M"
  echo "   reverted — no changes made"
  exit 1
fi
rm -f /tmp/pb_xplat.txt
echo

echo "2. Verifying"
for k in "struct Challenge" "struct GroupMember" "struct PlanGroup"; do
  n=$(grep -c "^$k" "$M")
  [ "$n" = "1" ] && echo "   ok   one $k" || { echo "   $n copies of $k — reverting"; cp "$M.bakxplat" "$M"; exit 1; }
done
grep -q "let id: UUID" "$M" && echo "   note: other structs still use UUID ids — that is fine, they are iOS-only"
echo

echo "3. Building — expect errors at the two construction sites"
SIM=$(xcodebuild -scheme PlanBhai -showdestinations 2>/dev/null \
  | grep -oE "name:iPhone [^}]*" | sed 's/name://' | sed 's/ *$//' | head -1)
[ -z "$SIM" ] && SIM="iPhone 17"
echo "   simulator: $SIM"
xcodebuild -scheme PlanBhai -destination "platform=iOS Simulator,name=$SIM" build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head -15
echo

echo "=========================================="
echo "  If the build failed on Challenge( or PlanGroup(, those are the two"
echo "  call sites — AppState.swift around lines 861 and 1287. Both need"
echo "  UUID() changed to UUID().uuidString, or the argument dropped entirely"
echo "  since id now defaults."
echo
echo "  Paste the errors and I will patch them against the real code."
echo
echo "  Revert:  cp $M.bakxplat $M"
echo "=========================================="

#!/usr/bin/env bash
#
# Fixes the seven call sites broken by String ids.
#
#   AppState:862   Challenge(id: UUID(), ...)          -> id now defaults, drop it
#   AppState:1288  PlanGroup(id: UUID(), ...)          -> same
#   AppState:1295  addMemberToGroup(groupID: UUID)     -> String
#   AppState:1298  GroupMember(id: UUID(), ...)        -> drop it
#   AppState:1302  removeMemberFromGroup(groupID:memberID:) -> String, String
#   AppState:1307  updateGroupSharedFeatures(groupID:) -> String
#
# The signature changes will surface further errors in the VIEWS that call
# them — that is the point. Every place assuming UUID identity becomes visible,
# which is exactly why the type changed rather than the decoder being patched:
# a synthesised UUID would have compiled cleanly and left the two apps
# disagreeing about identity forever.
#
# Usage:
#   bash ~/Downloads/fix-xplat-callsites.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
F="PlanBhai/ios/PlanBhai/AppState.swift"
[ -f "$F" ] || { echo "ERROR: $F not found"; exit 1; }

echo "PlanBhai — String id call sites"
echo

echo "1. Patching AppState"
cp "$F" "$F.bakcalls"
cat > /tmp/pb_calls.py << 'PLANBHAI_EOF'
import sys, re
p = sys.argv[1]
s = open(p).read()
orig = s

# 1. Challenge constructor — id now defaults, so drop the argument entirely.
old = """            Challenge(
                id: UUID(),
                title: title,"""
new = """            Challenge(
                title: title,"""
if old in s:
    s = s.replace(old, new, 1)
    print("   Challenge() — dropped the id argument")

# 2. PlanGroup constructor
old = """        let group = PlanGroup(
            id: UUID(), name: name, category: category, members: [],"""
new = """        let group = PlanGroup(
            name: name, category: category, members: [],"""
if old in s:
    s = s.replace(old, new, 1)
    print("   PlanGroup() — dropped the id argument")

# 3. Signatures: ids are Strings now so iOS and web agree on identity.
pairs = [
    ("func addMemberToGroup(groupID: UUID, name: String, phone: String = \"\") {",
     "func addMemberToGroup(groupID: String, name: String, phone: String = \"\") {"),
    ("func removeMemberFromGroup(groupID: UUID, memberID: UUID) {",
     "func removeMemberFromGroup(groupID: String, memberID: String) {"),
    ("func updateGroupSharedFeatures(groupID: UUID, features: Set<SharedFeature>) {",
     "func updateGroupSharedFeatures(groupID: String, features: Set<SharedFeature>) {"),
    ("groups[idx].members.append(GroupMember(id: UUID(), name: name, phone: phone))",
     "groups[idx].members.append(GroupMember(name: name, phone: phone))"),
]
for old, new in pairs:
    if old in s:
        s = s.replace(old, new, 1)
        print("   " + old.split("(")[0].replace("func ", "").strip() + " — signature updated")

if s == orig:
    print("   nothing matched — file may already be patched")
    sys.exit(3)

open(p, "w").write(s)

leftover = re.findall(r"(groupID|memberID): UUID", s)
if leftover:
    print(f"   WARNING: {len(leftover)} UUID parameter(s) still present")
PLANBHAI_EOF
python3 /tmp/pb_calls.py "$F"
RC=$?
rm -f /tmp/pb_calls.py
if [ "$RC" = "3" ]; then
  echo "   already patched"
elif [ "$RC" != "0" ]; then
  cp "$F.bakcalls" "$F"
  echo "   reverted"
  exit 1
fi
echo

echo "2. Any remaining UUID assumptions in the views"
grep -rn "groupID:\|memberID:" PlanBhai/ios/PlanBhai/Views/*.swift 2>/dev/null | head -10 | sed 's/^/   /'
echo "   (these compile fine if they pass a group's own .id — Swift will say otherwise)"
echo

echo "3. Building"
SIM=$(xcodebuild -scheme PlanBhai -showdestinations 2>/dev/null \
  | grep -oE "name:iPhone [^}]*" | sed 's/name://' | sed 's/ *$//' | head -1)
[ -z "$SIM" ] && SIM="iPhone 17"
echo "   simulator: $SIM"
xcodebuild -scheme PlanBhai -destination "platform=iOS Simulator,name=$SIM" build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head -20
echo

echo "=========================================="
echo "  If views still fail, paste the errors — they will be places passing a"
echo "  literal UUID rather than a record's own id."
echo
echo "  Revert:"
echo "     cp $F.bakcalls $F"
echo "     cp PlanBhai/ios/PlanBhai/Models.swift.bakxplat PlanBhai/ios/PlanBhai/Models.swift"
echo "=========================================="

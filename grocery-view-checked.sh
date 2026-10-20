#!/usr/bin/env bash
#
# Makes the grocery checkbox persist.
#
# WHAT WAS ACTUALLY WRONG
#   GroceryView already had a checkbox. It wrote to `checkedItems`, a local
#   @State Set<String> of UUIDs — so ticking worked visually and was FORGOTTEN
#   the moment you navigated away. Nothing was stored, nothing reached the
#   pantry, nothing reached the Brief.
#
#   That is why the grocery loop never closed: the UI existed, the storage
#   didn't. Worth knowing, because from the screen it looked finished.
#
# WHAT CHANGES
#   isChecked reads item.checked (persisted) instead of the local set, and the
#   button calls appState.toggleGroceryChecked(item) — which saves AND adds the
#   item to the pantry.
#
#   The strikethrough, colours and layout are untouched.
#
# LEFTOVER
#   `checkedItems` may still be declared and used elsewhere in the file — for a
#   "clear checked" action, or a count. The script reports how many references
#   remain rather than removing a variable it cannot see all uses of.
#
# Usage:
#   bash ~/Downloads/grocery-view-checked.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
F="PlanBhai/ios/PlanBhai/Views/GroceryView.swift"
[ -f "$F" ] || { echo "ERROR: $F not found"; exit 1; }

echo "PlanBhai — persist the grocery checkbox"
echo

echo "1. Prerequisite"
grep -q "func toggleGroceryChecked" PlanBhai/ios/PlanBhai/AppState.swift \
  && echo "   ok   toggleGroceryChecked exists" \
  || { echo "   MISSING toggleGroceryChecked — run grocery-checked.sh first"; exit 1; }
echo

if grep -q "toggleGroceryChecked(item)" "$F"; then
  echo "2. Already patched"
  exit 0
fi

echo "2. Patching the row"
cp "$F" "$F.bakgv"
cat > /tmp/pb_gv.py << 'PLANBHAI_EOF'
import sys, re
p = sys.argv[1]
s = open(p).read()

old = """                                            let isChecked = checkedItems.contains(item.id.uuidString)
                                            HStack(spacing: 14) {
                                                Button {
                                                    if isChecked { checkedItems.remove(item.id.uuidString) }
                                                    else { checkedItems.insert(item.id.uuidString) }
                                                } label: {"""

new = """                                            // Reads the persisted field, not a local @State set.
                                            // The old version ticked visually and forgot on
                                            // navigation — which is why nothing ever reached the
                                            // pantry or the Brief.
                                            let isChecked = item.checked
                                            HStack(spacing: 14) {
                                                Button {
                                                    // Also adds it to the pantry: "I bought the
                                                    // milk" is the same statement as a receipt
                                                    // with milk on it.
                                                    appState.toggleGroceryChecked(item)
                                                } label: {"""

if old not in s:
    print("ERROR: the row is not in the expected shape")
    sys.exit(2)
s = s.replace(old, new, 1)
open(p, "w").write(s)

leftover = len(re.findall(r"checkedItems", s))
print(f"patched; remaining checkedItems references: {leftover}")
PLANBHAI_EOF
python3 /tmp/pb_gv.py "$F"
if [ $? -ne 0 ]; then
  cp "$F.bakgv" "$F"
  echo "   reverted — no changes made"
  rm -f /tmp/pb_gv.py
  exit 1
fi
rm -f /tmp/pb_gv.py
echo

echo "3. Diff"
diff "$F.bakgv" "$F" | sed 's/^/   /'
echo

echo "4. Building"
SIM=$(xcodebuild -scheme PlanBhai -showdestinations 2>/dev/null \
  | grep -oE "name:iPhone [^}]*" | sed 's/name://' | sed 's/ *$//' | head -1)
[ -z "$SIM" ] && SIM="iPhone 17"
echo "   simulator: $SIM"
xcodebuild -scheme PlanBhai -destination "platform=iOS Simulator,name=$SIM" build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head -15
echo

echo "=========================================="
echo "  Tick a grocery item, leave the screen, come back — it should stay"
echo "  ticked. Then check the pantry filled:"
echo
echo "     cd backend && node -e 'require(\"dotenv\").config();const m=require(\"mongoose\");(async()=>{await m.connect(process.env.MONGODB_URI);const A=require(\"./models/AppData\");(await A.find({type:\"pantry\"}).lean()).forEach(r=>console.log(r.userId.slice(-6),(r.data||[]).length+\" items\",JSON.stringify((r.data||[]).slice(0,5))));await m.disconnect()})()'"
echo
echo "  Revert:  cp $F.bakgv $F"
echo "=========================================="

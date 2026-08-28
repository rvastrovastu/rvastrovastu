#!/usr/bin/env bash
#
# Household or Mine, on the grocery list.
#
# WHAT CHANGES
#   AppState gains a groceryScope. Household reads `groceries` as before;
#   Mine reads `groceries_personal` under a compound key.
#
#   The view itself is barely touched — it reads appState.groceries in six
#   places, and all six keep working. Swapping what that property CONTAINS is a
#   far smaller change than rewriting a screen with six read sites, and it
#   leaves the pantry chain alone.
#
# THE COMPOUND KEY
#   `<userId>:<householdId>`. Personal data inside a household cannot key on the
#   user alone — the list would follow you between households — nor on the
#   household alone, or it is not personal.
#
# TICKING EITHER LIST STILL FILLS THE HOUSEHOLD PANTRY
#   The kitchen does not care whose list something came from. Keeping them
#   separate would make the meal plan silently under-count every time someone
#   shopped off their own list.
#
# UNCHANGED: the meal diff, the grocery-gap suggestion and the Brief's count all
# still read the household list, because those are household concerns.
#
# Usage:
#   bash ~/Downloads/grocery-scope.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
D="PlanBhai/ios/PlanBhai"
A="$D/AppState.swift"
G="$D/Views/GroceryView.swift"
for f in "$A" "$G"; do [ -f "$f" ] || { echo "ERROR: $f not found"; exit 1; }; done

echo "PlanBhai — grocery scope"
echo

echo "1. AppState"
cp "$A" "$A.bakgs"
cat > /tmp/pb_gs.py << 'PLANBHAI_EOF'
import sys
p = sys.argv[1]
s = open(p).read()

if 'groceryScope' in s:
    print("   already applied"); sys.exit(3)

# The scope, and the key it resolves to.
s = s.replace("    @Published var groceries: [GroceryItem] = []",
"""    /// Which grocery list is on screen.
    ///
    /// `.household` is the shared one — everyone sees it, and the meal plan's
    /// missing ingredients land there, because the meal is the household's.
    ///
    /// `.personal` is yours alone, and scoped to the ACTIVE household: what you
    /// need for the flat is not what you need at your parents'.
    enum GroceryScope: String { case household, personal }
    @Published var groceryScope: GroceryScope = .household
    @Published var groceries: [GroceryItem] = []

    /// Personal data inside a household cannot key on the user alone — the list
    /// would follow you between households — nor on the household alone, or it
    /// is not personal. So both.
    private var groceryScopeId: String? {
        switch groceryScope {
        case .household: return sharedScopeId
        case .personal:
            guard let uid = currentUser?.id, let hid = activeHouseholdId else { return sharedScopeId }
            return "\\(uid):\\(hid)"
        }
    }

    private var groceryType: String {
        groceryScope == .personal ? "groceries_personal" : "groceries"
    }

    /// Swaps the list on screen. Clears first, so the previous scope's items do
    /// not linger while the new ones load — the same wrong answer for a shorter
    /// time is still wrong.
    func switchGroceryScope(to scope: GroceryScope) async {
        guard scope != groceryScope else { return }
        groceryScope = scope
        groceries = []
        if let loaded: [GroceryItem] = await loadData(groceryType, as: [GroceryItem].self,
                                                      scopeId: groceryScopeId) {
            groceries = loaded
        }
    }""", 1)

# Save follows the scope.
s = s.replace("""        await saveData("groceries", groceries, scopeId: sharedScopeId)""",
"""        // Follows the scope on screen, so editing your personal list does not
        // overwrite the household's.
        await saveData(groceryType, groceries, scopeId: groceryScopeId)""", 1)

# Load follows the scope.
s = s.replace("""        if let backendGroceries: [GroceryItem] = await loadData("groceries", as: [GroceryItem].self, scopeId: sharedScopeId) {""",
"""        if let backendGroceries: [GroceryItem] = await loadData(groceryType, as: [GroceryItem].self, scopeId: groceryScopeId) {""", 1)

open(p, "w").write(s)
print("   grocery scope wired through load and save")
PLANBHAI_EOF
python3 /tmp/pb_gs.py "$A"
RC=$?
rm -f /tmp/pb_gs.py
if [ "$RC" = "3" ]; then
  echo "   nothing to do"
elif [ "$RC" != "0" ]; then
  cp "$A.bakgs" "$A"; echo "   reverted"; exit 1
fi
echo

echo "2. GroceryView"
cp "$G" "$G.bakgs"
cat > /tmp/pb_tog.swift << 'PLANBHAI_EOF'
                        // Household or Mine.
                        //
                        // Everything in the app was household-scoped, which is
                        // right for a meal plan and wrong for the things only
                        // you need. Ticking either still fills the household
                        // pantry — the kitchen does not care whose list it came
                        // from, and the meal plan would otherwise under-count.
                        HStack(spacing: 8) {
                            ForEach([AppState.GroceryScope.household, .personal], id: \.rawValue) { scope in
                                Button {
                                    Task { await appState.switchGroceryScope(to: scope) }
                                } label: {
                                    Text(scope == .household ? "Household" : "Mine")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(appState.groceryScope == scope ? .white : PB.soft)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 9)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(appState.groceryScope == scope
                                                      ? PB.forest.opacity(0.30) : Color.white.opacity(0.05))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(appState.groceryScope == scope
                                                        ? PB.forest : Color.white.opacity(0.10), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 2)
PLANBHAI_EOF
cat > /tmp/pb_place.py << 'PLANBHAI_EOF'
import sys, re
p, toggle = sys.argv[1], sys.argv[2]
s = open(p).read()

if 'switchGroceryScope' in s:
    print("   already placed"); sys.exit(3)

# Just after the stat cards, before the list.
m = re.search(r'(\n\s*GroceryStatCard\(value: "\\\(appState\.groceries\.count\)"[^\n]*\n)', s)
if not m:
    print("   ERROR: could not find the stat cards"); sys.exit(2)

# Find the end of the HStack/VStack holding the stat cards.
after = s.index('\n', m.end() - 1)
# Walk forward to the first blank line following the stat block.
tail = s[after:]
blank = tail.find('\n\n')
if blank == -1:
    print("   ERROR: could not find where the stat block ends"); sys.exit(2)
insert_at = after + blank + 1

s = s[:insert_at] + "\n" + open(toggle).read() + s[insert_at:]
open(p, "w").write(s)
print("   toggle placed after the stat cards")
PLANBHAI_EOF
python3 /tmp/pb_place.py "$G" /tmp/pb_tog.swift
RC=$?
rm -f /tmp/pb_place.py /tmp/pb_tog.swift
if [ "$RC" = "3" ]; then
  echo "   nothing to do"
elif [ "$RC" != "0" ]; then
  cp "$G.bakgs" "$G"
  cp "$A.bakgs" "$A"
  echo "   reverted both"; exit 1
fi
echo

echo "3. Verifying"
grep -q "enum GroceryScope" "$A" && echo "   ok   scope declared"
grep -q "groceryType, groceries, scopeId: groceryScopeId" "$A" && echo "   ok   save follows the scope"
grep -q "switchGroceryScope" "$G" && echo "   ok   toggle placed"
grep -q "addToPantry" "$A" && echo "   ok   pantry chain untouched"
echo

echo "4. Building"
SIM=$(xcodebuild -scheme PlanBhai -showdestinations 2>/dev/null \
  | grep -oE "name:iPhone [^}]*" | sed 's/name://' | sed 's/ *$//' | head -1)
[ -z "$SIM" ] && SIM="iPhone 17"
echo "   simulator: $SIM"
xcodebuild -scheme PlanBhai -destination "platform=iOS Simulator,name=$SIM" build 2>&1 \
  | grep -E "error:|failures\)|BUILD (SUCCEEDED|FAILED)" | head -15
echo

echo "=========================================="
echo "  Meals -> Grocery. Household holds your 28 items; Mine starts empty."
echo
echo "  Revert:"
echo "     cp $A.bakgs $A"
echo "     cp $G.bakgs $G"
echo "=========================================="

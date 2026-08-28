#!/usr/bin/env bash
#
# Adds `checked` to grocery items, and closes the loop.
#
# THE GAP
#   Grocery items had no completed state. Nothing recorded what had been bought,
#   so "29 items to buy" stayed 29 forever and the app could never tell what was
#   actually outstanding.
#
# WHAT CHANGES
#   GroceryItem.checked      defaulted false, so existing records decode and all
#                            three GroceryItem(...) call sites keep compiling
#   toggleGroceryChecked     tap to tick — AND adds the item to the pantry
#   confirmReceipt           ticks matched items instead of DELETING them
#   clearCheckedGroceries    clears the bought ones when starting a fresh shop
#   uncheckedGroceryCount    what is genuinely still outstanding
#
# WHY TICKING FILLS THE PANTRY
#   Saying "I bought the milk" by hand is the same statement as a receipt with
#   milk on it — both mean *I have this now*. This matters more than the
#   checkbox: most people will never photograph a receipt, and without it the
#   pantry only ever fills for the ones who do.
#
#   Un-ticking does NOT remove from the pantry. A mis-tap on a list is not
#   evidence that food left the kitchen, and silently deleting pantry contents
#   is how the app would start lying about what you have.
#
# WHY RECEIPTS TICK RATHER THAN DELETE
#   Deleting meant you could not see what the trip actually got, and a mis-scan
#   was unrecoverable.
#
# Only Models.swift and AppState.swift change. GroceryView still needs a tap
# target adding — see the note at the end.
#
# Usage:
#   bash ~/Downloads/grocery-checked.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
D="PlanBhai/ios/PlanBhai"
[ -f "$D/Models.swift" ] || { echo "ERROR: $D/Models.swift not found"; exit 1; }
[ -f "$D/AppState.swift" ] || { echo "ERROR: $D/AppState.swift not found"; exit 1; }

echo "PlanBhai — grocery checked state"
echo

echo "1. Prerequisite"
grep -q "func addToPantry" "$D/AppState.swift" \
  && echo "   ok   addToPantry exists" \
  || { echo "   MISSING addToPantry — run receipt-to-pantry.sh first"; exit 1; }
echo

echo "2. GroceryItem"
if grep -q "var checked: Bool" "$D/Models.swift"; then
  echo "   already present"
else
  cp "$D/Models.swift" "$D/Models.swift.bakcheck"
  cat > /tmp/pb_gitem.txt << 'PLANBHAI_EOF'
struct GroceryItem: Codable, Identifiable {
    var id = UUID()
    let item: String
    let quantity: String
    let category: String
    let estimatedPrice: Double?

    /// Has this been bought?
    ///
    /// Without it the list could never tell what was outstanding — "29 items to
    /// buy" stayed 29 forever, and the grocery loop never closed.
    ///
    /// Defaulted so records written before this field decode unchanged, and so
    /// the three existing GroceryItem(...) call sites keep compiling.
    var checked: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, item, quantity, category, estimatedPrice, checked
    }
}
PLANBHAI_EOF
  python3 - "$D/Models.swift" /tmp/pb_gitem.txt << 'PY_EOF'
import sys, re
path, newfile = sys.argv[1], sys.argv[2]
s = open(path).read()
new = open(newfile).read()
m = re.search(r"struct GroceryItem: Codable, Identifiable \{.*?\n\}", s, re.S)
if not m:
    print("   ERROR: GroceryItem is not in the expected shape"); sys.exit(2)
s = s[:m.start()] + new.rstrip() + s[m.end():]
open(path, "w").write(s)
print("   added checked")
PY_EOF
  if [ $? -ne 0 ]; then cp "$D/Models.swift.bakcheck" "$D/Models.swift"; echo "   reverted"; exit 1; fi
  rm -f /tmp/pb_gitem.txt
fi
echo

echo "3. Grocery functions"
if grep -q "func toggleGroceryChecked" "$D/AppState.swift"; then
  echo "   already present"
else
  cp "$D/AppState.swift" "$D/AppState.swift.bakcheck"
  cat > /tmp/pb_gfuncs.txt << 'PLANBHAI_EOF'
    func addGroceryItem(item: String, quantity: String, category: String, estimatedPrice: Double? = nil) {
        guard !item.isEmpty else { return }
        groceries.append(GroceryItem(item: item, quantity: quantity.isEmpty ? "1" : quantity, category: category, estimatedPrice: estimatedPrice))
    }

    func deleteGroceryItem(_ item: GroceryItem) {
        groceries.removeAll { $0.id == item.id }
    }

    /// Ticks or un-ticks a grocery item.
    ///
    /// Ticking also adds it to the pantry. Saying "I bought the milk" by hand is
    /// the same statement as a receipt with milk on it — both mean *I have this
    /// now*. That matters more than the checkbox itself, because most people
    /// will never photograph a receipt, and without this the pantry only fills
    /// for the ones who do.
    ///
    /// Un-ticking does NOT remove it from the pantry. A mis-tap on a list is not
    /// evidence that the food left the kitchen, and quietly deleting pantry
    /// contents is how the app would start lying about what you have.
    func toggleGroceryChecked(_ item: GroceryItem) {
        guard let idx = groceries.firstIndex(where: { $0.id == item.id }) else { return }
        groceries[idx].checked.toggle()

        if groceries[idx].checked {
            addToPantry(name: groceries[idx].item, quantity: groceries[idx].quantity)
        }

        Task { await saveAllLocalData() }
    }

    /// Clears everything already bought. Called when starting a fresh shop —
    /// per-item deletion stays manual so a mis-tick is always recoverable.
    func clearCheckedGroceries() {
        groceries.removeAll { $0.checked }
        Task { await saveAllLocalData() }
    }

    /// Outstanding count, for the Brief and the badge.
    var uncheckedGroceryCount: Int {
        groceries.filter { !$0.checked }.count
    }
PLANBHAI_EOF
  python3 - "$D/AppState.swift" /tmp/pb_gfuncs.txt << 'PY_EOF'
import sys, re
path, newfile = sys.argv[1], sys.argv[2]
s = open(path).read()
new = open(newfile).read()
m = re.search(
    r"    func addGroceryItem\(item: String, quantity: String, category: String, estimatedPrice: Double\? = nil\) \{.*?\n    func deleteGroceryItem\(_ item: GroceryItem\) \{.*?\n    \}\n",
    s, re.S)
if not m:
    print("   ERROR: the grocery functions are not in the expected shape"); sys.exit(2)
s = s[:m.start()] + new + s[m.end():]
open(path, "w").write(s)
print("   replaced add/delete, added toggle + clear + count")
PY_EOF
  if [ $? -ne 0 ]; then cp "$D/AppState.swift.bakcheck" "$D/AppState.swift"; echo "   reverted"; exit 1; fi
  rm -f /tmp/pb_gfuncs.txt
fi
echo

echo "4. confirmReceipt — tick, do not delete"
if grep -q "groceries\[idx\].checked = true" "$D/AppState.swift"; then
  echo "   already ticking"
else
  cat > /tmp/pb_confirm.txt << 'PLANBHAI_EOF'
    // MARK: - Item name matching
    //
    // One matcher, used everywhere. Pantry items use `name`, groceries use
    // `item`, receipts use `name` — three field names for the same concept.
    // Keeping the comparison in one place is what stops "have paneer" and
    // "need paneer" from disagreeing.
    //
    // Substring in both directions, because a receipt says "PANEER 500G MALAI"
    // where the grocery list says "Paneer".
    static func itemsMatch(_ a: String, _ b: String) -> Bool {
        let x = a.lowercased().trimmingCharacters(in: .whitespaces)
        let y = b.lowercased().trimmingCharacters(in: .whitespaces)
        guard !x.isEmpty, !y.isEmpty else { return false }
        // Two characters would match almost anything; three is the shortest
        // real grocery word ("egg", "oil", "tea").
        guard x.count >= 3, y.count >= 3 else { return x == y }
        return x.contains(y) || y.contains(x)
    }

    /// Is this item on hand right now?
    func pantryHas(_ itemName: String) -> Bool {
        pantryItems.contains { Self.itemsMatch($0.name, itemName) }
    }

    /// Adds every line item from a scanned receipt as its own budget entry, tagged
    /// with the store name, moves what was bought into the pantry, and reconciles
    /// matched items off the grocery list.
    ///
    /// The pantry step is what makes "you're missing tomatoes for dinner"
    /// possible: without a record of what you have, the app can only ever tell
    /// you what you typed. Nobody fills a pantry by hand — a receipt photo is
    /// the one moment that data is free to collect.
    ///
    /// Returns the number of grocery items matched and removed.
    @discardableResult
    func confirmReceipt(_ receipt: ImportedReceipt) -> Int {
        for item in receipt.items {
            addBudgetItem(title: "\(receipt.storeName): \(item.name)", amount: item.price, category: item.category)
        }

        var matchedCount = 0

        for receiptItem in receipt.items {
            // Tick it off rather than deleting it. Deleting meant you couldn't
            // see what this trip actually got, and a mis-scan was unrecoverable.
            if let idx = groceries.firstIndex(where: {
                Self.itemsMatch($0.item, receiptItem.name) && !$0.checked
            }) {
                // Carry the quantity the user asked for — a receipt line reads
                // "PANEER 500G MALAI FRESH", the list says "500g".
                let quantity = groceries[idx].quantity
                groceries[idx].checked = true
                matchedCount += 1
                addToPantry(name: receiptItem.name, quantity: quantity)
            } else {
                addToPantry(name: receiptItem.name, quantity: "")
            }
        }

        importedReceipt = nil

        Task { await saveAllLocalData() }
        return matchedCount
    }

    /// Adds to the pantry, or refreshes what is already there.
    ///
    /// Buying paneer twice should not leave two paneers — the pantry answers
    /// "do I have this", not "how many times have I bought it".
    func addToPantry(name: String, quantity: String) {
        let clean = name.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty else { return }

        if let idx = pantryItems.firstIndex(where: { Self.itemsMatch($0.name, clean) }) {
            if !quantity.isEmpty { pantryItems[idx].quantity = quantity }
            return
        }

        pantryItems.append(PantryItem(
            id: UUID(),
            name: clean,
            quantity: quantity,
            expiryDate: nil
        ))
    }
PLANBHAI_EOF
  python3 - "$D/AppState.swift" /tmp/pb_confirm.txt << 'PY_EOF'
import sys, re
path, newfile = sys.argv[1], sys.argv[2]
s = open(path).read()
new = open(newfile).read()
m = re.search(
    r"    // MARK: - Item name matching\n.*?\n    func addToPantry\(name: String, quantity: String\) \{.*?\n    \}\n",
    s, re.S)
if not m:
    print("   ERROR: could not locate the receipt block"); sys.exit(2)
s = s[:m.start()] + new + s[m.end():]
open(path, "w").write(s)
print("   confirmReceipt now ticks matched items")
PY_EOF
  [ $? -ne 0 ] && echo "   left as-is — receipts still delete matched items"
  rm -f /tmp/pb_confirm.txt
fi
echo

echo "5. Building"
SIM=$(xcodebuild -scheme PlanBhai -showdestinations 2>/dev/null \
  | grep -oE "name:iPhone [^}]*" | sed 's/name://' | sed 's/ *$//' | head -1)
[ -z "$SIM" ] && SIM="iPhone 17"
echo "   simulator: $SIM"
xcodebuild -scheme PlanBhai -destination "platform=iOS Simulator,name=$SIM" build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head -15
echo

echo "=========================================="
echo "  STILL TO DO — GroceryView has no tap target yet."
echo "  In the row at GroceryView.swift:186, add ahead of the label:"
echo
echo "      Button { appState.toggleGroceryChecked(item) } label: {"
echo "          Image(systemName: item.checked ? \"checkmark.circle.fill\" : \"circle\")"
echo "              .foregroundStyle(item.checked ? PB.forest : PB.muted)"
echo "      }"
echo "      .buttonStyle(.plain)"
echo
echo "  I have not edited that view — I cannot see its row layout, and guessing"
echo "  at SwiftUI I have not read is how three patches went wrong today."
echo
echo "  Revert:"
echo "     cp $D/Models.swift.bakcheck $D/Models.swift"
echo "     cp $D/AppState.swift.bakcheck $D/AppState.swift"
echo "=========================================="

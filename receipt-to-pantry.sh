#!/usr/bin/env bash
#
# Receipt -> pantry. The wire that makes "you're missing tomatoes" possible.
#
# THE PROBLEM
#   pantry is EMPTY in every account in your database. That is not a bug — it
#   is what happens when you ask people to type an inventory of their kitchen.
#
#   Because pantry is empty, meal.haveRatio is always null, and the grocery_gap
#   rule — the flagship suggestion from the original vision — can never fire.
#
# THE FIX
#   importReceiptFromImage already extracts { name, price, category } per line
#   and confirmReceipt already iterates those items to reconcile the grocery
#   list. This adds one step to that same loop: what was bought goes INTO the
#   pantry instead of simply vanishing off the list.
#
#   One photo after a shop populates the pantry, at the one moment that data is
#   free to collect.
#
# ALSO ADDED
#   itemsMatch() — a single matcher used for pantry, groceries and receipts.
#   Pantry items use `name`, groceries use `item`, receipts use `name`: three
#   field names for one concept. Keeping the comparison in one place is what
#   stops "have paneer" and "need paneer" from disagreeing — the same class of
#   split that turned four habits into nulls earlier today.
#
# KNOWN LIMITATION, deliberate
#   Substring matching means "Butter" matches "Peanut Butter", so haveRatio can
#   read optimistic. Your existing grocery reconciliation already behaves this
#   way. The real fix is a curated alias list, not a cleverer regex, and it is
#   only worth building if it actually bites.
#
#   Pantry contents are also never consumed — cooking Tuesday's dinner does not
#   decrement its ingredients, so the pantry drifts optimistic over time. Worth
#   watching; correcting it properly means tying meals to consumption.
#
# Only AppState.swift changes.
#
# Usage:
#   bash ~/Downloads/receipt-to-pantry.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
F="PlanBhai/ios/PlanBhai/AppState.swift"
[ -f "$F" ] || { echo "ERROR: $F not found"; exit 1; }

echo "PlanBhai — receipt to pantry"
echo

echo "1. Checking what this depends on"
grep -q "struct PantryItem" PlanBhai/ios/PlanBhai/Models.swift \
  && echo "   ok   PantryItem exists" \
  || { echo "   MISSING PantryItem"; exit 1; }
grep -q "pantryItems" "$F" \
  && echo "   ok   pantryItems on AppState" \
  || { echo "   MISSING pantryItems"; exit 1; }
grep -q "func addBudgetItem" "$F" \
  && echo "   ok   addBudgetItem" \
  || { echo "   MISSING addBudgetItem"; exit 1; }
echo

if grep -q "func addToPantry" "$F"; then
  echo "2. Already applied"
  exit 0
fi

echo "2. Replacing confirmReceipt"
cp "$F" "$F.bakpantry"
cat > /tmp/pb_pantry.txt << 'PLANBHAI_EOF'
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
            // 1. Take it off the grocery list if it was on there.
            if let idx = groceries.firstIndex(where: { Self.itemsMatch($0.item, receiptItem.name) }) {
                // Carry the quantity the user actually asked for — a receipt
                // line reads "PANEER 500G MALAI FRESH", the list says "500g".
                let quantity = groceries[idx].quantity
                groceries.remove(at: idx)
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

python3 - "$F" /tmp/pb_pantry.txt << 'PY_EOF'
import sys, re
path, snipfile = sys.argv[1], sys.argv[2]
s = open(path).read()
snip = open(snipfile).read()

# Replace the whole confirmReceipt, including its doc comment and @discardableResult.
m = re.search(
    r"    /// Adds every line item from a scanned receipt.*?\n    func confirmReceipt\(_ receipt: ImportedReceipt\) -> Int \{.*?\n    \}\n",
    s, re.S)
if not m:
    m = re.search(
        r"    @discardableResult\n    func confirmReceipt\(_ receipt: ImportedReceipt\) -> Int \{.*?\n    \}\n",
        s, re.S)
if not m:
    print("   ERROR: confirmReceipt is not in the expected shape")
    sys.exit(2)

s = s[:m.start()] + snip + s[m.end():]
open(path, "w").write(s)
print("   replaced, and added itemsMatch / pantryHas / addToPantry")
PY_EOF
if [ $? -ne 0 ]; then
  cp "$F.bakpantry" "$F"
  echo "   reverted — no changes made"
  exit 1
fi
rm -f /tmp/pb_pantry.txt
echo

echo "3. Verifying"
for k in "func itemsMatch" "func pantryHas" "func addToPantry" "func confirmReceipt"; do
  grep -q "$k" "$F" && echo "   ok   $k" || { echo "   MISSING $k — reverting"; cp "$F.bakpantry" "$F"; exit 1; }
done
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
echo "  Scan a grocery receipt, then check the pantry filled:"
echo
echo "     cd backend && node -e 'require(\"dotenv\").config();const m=require(\"mongoose\");(async()=>{await m.connect(process.env.MONGODB_URI);const A=require(\"./models/AppData\");(await A.find({type:\"pantry\"}).lean()).forEach(r=>console.log(r.userId.slice(-6),(r.data||[]).length+\" items\",JSON.stringify((r.data||[]).slice(0,4))));await m.disconnect()})()'"
echo
echo "  Revert:  cp $F.bakpantry $F"
echo "=========================================="

#!/usr/bin/env bash
#
# Splits the old DashboardView "Smart Scan" card in two:
#
#   recipes  -> MealPlannerView   (PantryView owns the picker)
#   receipts -> HouseholdView     (BudgetPlannerView owns the picker)
#
# Receipts are about spending, not cooking, so they belong with Household.
#
# NAVIGATION IS UNCHANGED. Both cards point where they always did — PantryView
# calls importRecipeFromImage, BudgetPlannerView calls importReceiptFromImage.
# Only the cards' location moves. The premium gate on receipts, including its
# locked variant routing to PremiumView, is preserved exactly.
#
# DashboardView is left alone. It is already unreferenced since Brief became
# home, so nothing is lost by not editing it.
#
# Usage:
#   bash ~/Downloads/split-smart-scan.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
D="PlanBhai/ios/PlanBhai/Views"
[ -d "$D" ] || { echo "ERROR: $D not found"; exit 1; }

echo "PlanBhai — splitting Smart Scan"
echo

echo "1. Checking destinations exist"
for v in PantryView BudgetPlannerView PremiumView; do
  [ -f "$D/$v.swift" ] && echo "   ok   $v" || { echo "   MISSING $v.swift"; exit 1; }
done
grep -q "effectivePremium" "$D/../AppState.swift" \
  && echo "   ok   effectivePremium" \
  || echo "   warn effectivePremium not found in AppState — the receipt gate may not compile"
echo

# ---------------------------------------------------------------------------
echo "2. Recipe card -> MealPlannerView"
M="$D/MealPlannerView.swift"
if grep -q "recipeScanCard" "$M"; then
  echo "   already present"
else
  cp "$M" "$M.bakscan"
  cat > /tmp/pb_recipe_card.txt << 'PLANBHAI_EOF'
    // MARK: - Recipe Scan
    //
    // Moved here from the old DashboardView's "Smart Scan" card. PantryView owns
    // the photo picker and calls appState.importRecipeFromImage, so the
    // destination is unchanged — only its home is.
    var recipeScanCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "camera.viewfinder").font(.system(size: 11)).foregroundStyle(PB.mauve)
                Text("SMART SCAN").font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45)).tracking(1.2)
            }

            NavigationLink { PantryView() } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(PB.orange.opacity(0.20)).frame(width: 40, height: 40)
                        Image(systemName: "camera.viewfinder").font(.system(size: 16, weight: .semibold)).foregroundStyle(PB.orange)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Import Recipe from Photo").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        Text("Snap a recipe card, get ingredients & steps").font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(.white.opacity(0.30))
                }
                .padding(12).background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(PB.orange.opacity(0.20), lineWidth: 1))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.10), lineWidth: 1))
    }
PLANBHAI_EOF

  python3 - "$M" /tmp/pb_recipe_card.txt << 'PY_EOF'
import sys
path, cardfile = sys.argv[1], sys.argv[2]
s = open(path).read()
card = open(cardfile).read()

# 1. Render it directly under the page header.
anchor = 'PageHeader(icon: "fork.knife.circle.fill", title: "MealBhAI.",'
i = s.find(anchor)
if i == -1:
    print("   ERROR: MealBhAI PageHeader not found"); sys.exit(2)

# The header call spans several lines — find the end of that statement, then
# the end of any trailing modifiers, and insert after the blank line.
j = s.find("\n\n", i)
if j == -1:
    print("   ERROR: could not find the end of the header block"); sys.exit(2)
s = s[:j] + "\n\n                        recipeScanCard" + s[j:]

# 2. Add the computed property. Placed before the first `var body` so it sits
#    with the other view fragments rather than inside one.
k = s.find("    var body: some View {")
if k == -1:
    print("   ERROR: var body not found"); sys.exit(2)
s = s[:k] + card + "\n" + s[k:]

open(path, "w").write(s)
print("   inserted card + property")
PY_EOF
  if [ $? -ne 0 ]; then
    cp "$M.bakscan" "$M"
    echo "   reverted — no changes made"
    exit 1
  fi
fi
rm -f /tmp/pb_recipe_card.txt
echo

# ---------------------------------------------------------------------------
echo "3. Receipt card -> HouseholdView"
H="$D/HouseholdView.swift"
if [ ! -f "$H" ]; then
  echo "   HouseholdView.swift not found — skipping."
  echo "   The snippet is saved at /tmp/pb_receipt_card.txt to paste manually."
else
  if grep -q "receiptScanCard" "$H"; then
    echo "   already present"
  else
    cp "$H" "$H.bakscan"
    cat > /tmp/pb_receipt_card.txt << 'PLANBHAI_EOF'
    // MARK: - Receipt Scan
    //
    // Moved here from the old DashboardView's "Smart Scan" card. Receipts are
    // about spending, not cooking, so this half lives with Household rather
    // than Meals. BudgetPlannerView owns the picker and calls
    // appState.importReceiptFromImage — destination unchanged.
    //
    // The premium gate and its locked variant are preserved exactly as they
    // were; effectivePremium already handles trial users.
    var receiptScanCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text.viewfinder").font(.system(size: 11)).foregroundStyle(PB.sky)
                Text("SMART SCAN").font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45)).tracking(1.2)
            }

            if appState.effectivePremium {
                NavigationLink { BudgetPlannerView() } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12).fill(PB.sky.opacity(0.20)).frame(width: 40, height: 40)
                            Image(systemName: "doc.text.viewfinder").font(.system(size: 16, weight: .semibold)).foregroundStyle(PB.sky)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Scan Receipt").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                            Text("Auto-log spending & check off groceries").font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(.white.opacity(0.30))
                    }
                    .padding(12).background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(PB.sky.opacity(0.20), lineWidth: 1))
                }
            } else {
                NavigationLink { PremiumView() } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12).fill(Color(hex:"C9941A").opacity(0.20)).frame(width: 40, height: 40)
                            Image(systemName: "lock.fill").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color(hex:"C9941A"))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Scan Receipt").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                            Text("Premium — auto-log spending & sync groceries").font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
                        }
                        Spacer()
                        Image(systemName: "crown.fill").font(.system(size: 12)).foregroundStyle(Color(hex:"C9941A"))
                    }
                    .padding(12).background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex:"C9941A").opacity(0.25), lineWidth: 1))
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.10), lineWidth: 1))
    }
PLANBHAI_EOF
    python3 - "$H" /tmp/pb_receipt_card.txt << 'PY_EOF'
import sys, re
path, cardfile = sys.argv[1], sys.argv[2]
s = open(path).read()
card = open(cardfile).read()

m = re.search(r"\n(\s*)PageHeader\(", s)
if not m:
    print("   ERROR: no PageHeader in HouseholdView — insert by hand"); sys.exit(2)

j = s.find("\n\n", m.end())
if j == -1:
    print("   ERROR: could not find the end of the header block"); sys.exit(2)
indent = m.group(1)
s = s[:j] + "\n\n" + indent + "receiptScanCard" + s[j:]

k = s.find("    var body: some View {")
if k == -1:
    print("   ERROR: var body not found"); sys.exit(2)
s = s[:k] + card + "\n" + s[k:]

open(path, "w").write(s)
print("   inserted card + property")
PY_EOF
    if [ $? -ne 0 ]; then
      cp "$H.bakscan" "$H"
      echo "   reverted — snippet left at /tmp/pb_receipt_card.txt"
    fi
  fi
fi
echo

echo "4. Building"
SIM=$(xcodebuild -scheme PlanBhai -showdestinations 2>/dev/null \
  | grep -oE "name:iPhone [^}]*" | sed 's/name://' | sed 's/ *$//' | head -1)
[ -z "$SIM" ] && SIM="iPhone 17"
echo "   simulator: $SIM"
xcodebuild -scheme PlanBhai -destination "platform=iOS Simulator,name=$SIM" build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head -20
echo

echo "=========================================="
echo "  Revert:"
echo "     cp $M.bakscan $M"
echo "     cp $H.bakscan $H"
echo "=========================================="

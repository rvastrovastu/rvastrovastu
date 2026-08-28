#!/usr/bin/env bash
#
# Moves the Family Memories card from the old DashboardView to HouseholdView.
#
# Unchanged. It reads appState.familyPhotos and navigates to
# FamilyMemoriesView; both work identically from Household. The empty state
# ("Share your first family moment") is preserved — it invites rather than
# sitting blank, which is why the card is worth keeping at all.
#
# Inserted after the receipt scan card if that is present, so the two additions
# sit together rather than one landing above the page header.
#
# Usage:
#   bash ~/Downloads/move-memories.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
H="PlanBhai/ios/PlanBhai/Views/HouseholdView.swift"
[ -f "$H" ] || { echo "ERROR: $H not found"; exit 1; }

echo "PlanBhai — moving Family Memories"
echo

echo "1. Checking what it depends on"
[ -f "PlanBhai/ios/PlanBhai/Views/FamilyMemoriesView.swift" ] \
  && echo "   ok   FamilyMemoriesView" \
  || { echo "   MISSING FamilyMemoriesView.swift"; exit 1; }
grep -q "loadFamilyPhotoData" PlanBhai/ios/PlanBhai/AppState.swift \
  && echo "   ok   loadFamilyPhotoData" \
  || { echo "   MISSING loadFamilyPhotoData in AppState"; exit 1; }
grep -q "familyPhotos" PlanBhai/ios/PlanBhai/AppState.swift \
  && echo "   ok   familyPhotos" \
  || { echo "   MISSING familyPhotos in AppState"; exit 1; }
echo

if grep -q "memoriesCard" "$H"; then
  echo "2. Already present — nothing to do"
  exit 0
fi

echo "2. Inserting"
cp "$H" "$H.bakmem"
cat > /tmp/pb_memories.txt << 'PLANBHAI_EOF'
    // MARK: - Family Memories
    //
    // Moved here from the old DashboardView. Unchanged — it reads
    // appState.familyPhotos and navigates to FamilyMemoriesView, both of which
    // work identically from Household.
    var memoriesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle.angled").font(.system(size: 11)).foregroundStyle(PB.pink)
                    Text("FAMILY MEMORIES").font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.45)).tracking(1.2)
                }
                Spacer()
                NavigationLink { FamilyMemoriesView() } label: {
                    Text("View All").font(.system(size: 11, weight: .semibold)).foregroundStyle(PB.pink)
                }
            }

            if appState.familyPhotos.isEmpty {
                NavigationLink { FamilyMemoriesView() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "camera.fill").foregroundStyle(PB.pink)
                        Text("Share your first family moment").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.70))
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.white.opacity(0.30))
                    }
                    .padding(14).background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 14))
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(appState.familyPhotos.prefix(6)) { photo in
                            NavigationLink { FamilyMemoriesView() } label: {
                                ZStack(alignment: .bottomLeading) {
                                    if let data = appState.loadFamilyPhotoData(fileName: photo.imageFileName),
                                       let uiImage = UIImage(data: data) {
                                        Image(uiImage: uiImage)
                                            .resizable().scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipped()
                                    } else {
                                        Rectangle().fill(Color.white.opacity(0.08)).frame(width: 100, height: 100)
                                    }
                                    if photo.likeCount > 0 {
                                        HStack(spacing: 2) {
                                            Image(systemName: "heart.fill").font(.system(size: 8)).foregroundStyle(PB.rose)
                                            Text("\(photo.likeCount)").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                                        }
                                        .padding(.horizontal, 6).padding(.vertical, 3)
                                        .background(.black.opacity(0.5))
                                        .clipShape(Capsule())
                                        .padding(6)
                                    }
                                }
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.12), lineWidth: 1))
                            }
                        }
                        NavigationLink { FamilyMemoriesView() } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundStyle(PB.pink)
                                Text("Add").font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.60))
                            }
                            .frame(width: 100, height: 100)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(PB.pink.opacity(0.25), lineWidth: 1))
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(PB.pink.opacity(0.15), lineWidth: 1))
    }
PLANBHAI_EOF

python3 - "$H" /tmp/pb_memories.txt << 'PY_EOF'
import sys, re
path, cardfile = sys.argv[1], sys.argv[2]
s = open(path).read()
card = open(cardfile).read()

# Render it after receiptScanCard when that exists, otherwise after the header.
m = re.search(r"\n(\s*)receiptScanCard\b", s)
if m:
    indent = m.group(1)
    insert_at = m.end()
    where = "after receiptScanCard"
else:
    m = re.search(r"\n(\s*)PageHeader\(", s)
    if not m:
        print("   ERROR: no anchor found — insert by hand"); sys.exit(2)
    indent = m.group(1)
    insert_at = s.find("\n\n", m.end())
    if insert_at == -1:
        print("   ERROR: could not find the end of the header block"); sys.exit(2)
    where = "after the page header"

s = s[:insert_at] + "\n\n" + indent + "memoriesCard" + s[insert_at:]

k = s.find("    var body: some View {")
if k == -1:
    print("   ERROR: var body not found"); sys.exit(2)
s = s[:k] + card + "\n" + s[k:]

open(path, "w").write(s)
print("   inserted " + where)
PY_EOF
if [ $? -ne 0 ]; then
  cp "$H.bakmem" "$H"
  echo "   reverted — snippet left at /tmp/pb_memories.txt"
  exit 1
fi
rm -f /tmp/pb_memories.txt
echo

echo "3. Building"
SIM=$(xcodebuild -scheme PlanBhai -showdestinations 2>/dev/null \
  | grep -oE "name:iPhone [^}]*" | sed 's/name://' | sed 's/ *$//' | head -1)
[ -z "$SIM" ] && SIM="iPhone 17"
echo "   simulator: $SIM"
xcodebuild -scheme PlanBhai -destination "platform=iOS Simulator,name=$SIM" build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head -15
echo

echo "=========================================="
echo "  Revert:  cp $H.bakmem $H"
echo "=========================================="

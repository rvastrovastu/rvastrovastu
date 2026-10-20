#!/usr/bin/env bash
#
# Household page: Memories, Wall, Activity, then Jump to — plus a Clear button.
#
# 1. ORDER
#    Was: Jump to · Wall · Activity
#    Now: Memories · Wall · Activity · Jump to
#
#    Jump to was first — a grid of navigation sitting above the things people
#    actually open the page to see. Shortcuts belong under the content they
#    shortcut past.
#
# 2. MEMORIES IS NEW
#    It existed only as one tile inside Jump to, which buried the most human
#    thing on the page under a navigation grid. Now a photo strip with an empty
#    state that invites rather than sitting blank.
#
# 3. CLEAR ACTIVITY — PER PERSON, NOT DELETED
#    The feed is shared household data. One member clearing it for everyone is
#    destructive in a way the word "clear" does not suggest, so the ids on
#    screen are remembered on this device and filtered out of your view only.
#    The alert says so plainly.
#
#    Ids rather than a timestamp, because that relies only on Identifiable — no
#    assumption about what date fields the model carries. Guessing at fields I
#    had not read is what broke three files earlier tonight.
#
# NOT DONE: moving the household list to the Home page. That touches two more
# screens and is better done with a fresh read than at the end of this session.
#
# Only HouseholdView.swift changes.
#
# Usage:
#   bash ~/Downloads/household-reorder.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
H="PlanBhai/ios/PlanBhai/Views/HouseholdView.swift"
[ -f "$H" ] || { echo "ERROR: $H not found"; exit 1; }

echo "PlanBhai — household page order"
echo

echo "1. Checking what Memories needs"
grep -q "familyPhotos" PlanBhai/ios/PlanBhai/AppState.swift \
  && echo "   ok   familyPhotos" || { echo "   MISSING familyPhotos"; exit 1; }
grep -q "loadFamilyPhotoData" PlanBhai/ios/PlanBhai/AppState.swift \
  && echo "   ok   loadFamilyPhotoData" || { echo "   MISSING loadFamilyPhotoData"; exit 1; }
[ -f "PlanBhai/ios/PlanBhai/Views/FamilyMemoriesView.swift" ] \
  && echo "   ok   FamilyMemoriesView" || { echo "   MISSING FamilyMemoriesView"; exit 1; }
echo

echo "2. Patching"
cp "$H" "$H.bakorder"
cat > /tmp/pb_order.swift << 'PLANBHAI_EOF'
                    if isActive {
                        // Memories, Wall, then Jump to.
                        //
                        // Jump to was first — a grid of navigation above the
                        // things people actually come here to see. Shortcuts
                        // belong under the content they shortcut past.
                        HouseholdMemoriesSection(household: household)
                        HouseholdWallSection(household: household)
                        HouseholdActivitySection(household: household)
                        jumpToSection
                    } else {
                        Text("Switch to this household to see its wall, activity and shared features.")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.55))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
PLANBHAI_EOF
cat > /tmp/pb_mem.swift << 'PLANBHAI_EOF'
// MARK: - Household Memories — a strip of recent photos, above the wall
//
// Previously reachable only as one tile inside "Jump to", which buried the most
// human thing on the page under a navigation grid.
struct HouseholdMemoriesSection: View {
    let household: Household
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("MEMORIES").font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45)).tracking(1.2)
                Spacer()
                NavigationLink { FamilyMemoriesView() } label: {
                    Text("View all").font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PB.pink)
                }
            }

            if appState.familyPhotos.isEmpty {
                NavigationLink { FamilyMemoriesView() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "camera.fill").foregroundStyle(PB.pink)
                        Text("Share your first moment together")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.70))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption).foregroundStyle(.white.opacity(0.30))
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(appState.familyPhotos.prefix(8)) { photo in
                            NavigationLink { FamilyMemoriesView() } label: {
                                ZStack(alignment: .bottomLeading) {
                                    if let data = appState.loadFamilyPhotoData(fileName: photo.imageFileName),
                                       let ui = UIImage(data: data) {
                                        Image(uiImage: ui)
                                            .resizable().scaledToFill()
                                            .frame(width: 92, height: 92)
                                            .clipped()
                                    } else {
                                        Rectangle().fill(Color.white.opacity(0.08))
                                            .frame(width: 92, height: 92)
                                    }
                                    if photo.likeCount > 0 {
                                        HStack(spacing: 2) {
                                            Image(systemName: "heart.fill")
                                                .font(.system(size: 8)).foregroundStyle(PB.rose)
                                            Text("\(photo.likeCount)")
                                                .font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                                        }
                                        .padding(.horizontal, 6).padding(.vertical, 3)
                                        .background(.black.opacity(0.5))
                                        .clipShape(Capsule())
                                        .padding(5)
                                    }
                                }
                                .frame(width: 92, height: 92)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14)
                                    .stroke(.white.opacity(0.12), lineWidth: 1))
                            }
                        }

                        NavigationLink { FamilyMemoriesView() } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20)).foregroundStyle(PB.pink)
                                Text("Add").font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.60))
                            }
                            .frame(width: 92, height: 92)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .stroke(PB.pink.opacity(0.25), lineWidth: 1))
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
PLANBHAI_EOF
cat > /tmp/pb_act.swift << 'PLANBHAI_EOF'
// MARK: - Household Activity — auto-generated feed of joins, leaves, removals, and future actions
struct HouseholdActivitySection: View {
    let household: Household
    @EnvironmentObject var appState: AppState
    @State private var confirmClear = false

    /// Hidden per person, not deleted.
    ///
    /// The feed is shared household data — one member clearing it for everyone
    /// is destructive in a way the word "clear" does not suggest. The ids that
    /// were on screen at clear time are remembered on this device, so your view
    /// tidies without touching anyone else's.
    ///
    /// Ids rather than a timestamp, because that only relies on Identifiable —
    /// no assumption about what date fields the model happens to carry.
    private var clearedKey: String { "activityCleared_\(household.id)" }

    private var clearedIds: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: clearedKey) ?? [])
    }

    private var visible: [HouseholdActivity] {
        let hidden = clearedIds
        return appState.householdActivities.filter { !hidden.contains(String(describing: $0.id)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("RECENT ACTIVITY").font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45)).tracking(1.2)
                Spacer()
                if !visible.isEmpty {
                    Button { confirmClear = true } label: {
                        Text("Clear").font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
            }

            if visible.isEmpty {
                Text("No activity yet.")
                    .font(.caption).foregroundStyle(.white.opacity(0.40))
            } else {
                VStack(spacing: 8) {
                    ForEach(visible) { activity in
                        HStack(spacing: 10) {
                            ZStack {
                                Circle().fill(household.categoryEnum.color.opacity(0.20)).frame(width: 26, height: 26)
                                Text(String(activity.actorName.prefix(1)).uppercased())
                                    .font(.system(size: 11, weight: .bold)).foregroundStyle(household.categoryEnum.color)
                            }
                            Text(activity.displayText)
                                .font(.system(size: 13)).foregroundStyle(.white.opacity(0.85))
                            Spacer()
                        }
                        .padding(10).background(Color.white.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding(16).background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 18))
        .alert("Clear this activity?", isPresented: $confirmClear) {
            Button("Cancel", role: .cancel) { }
            Button("Clear") {
                let ids = appState.householdActivities.map { String(describing: $0.id) }
                UserDefaults.standard.set(Array(clearedIds.union(ids)), forKey: clearedKey)
            }
        } message: {
            Text("It disappears from your view only. Other members keep theirs.")
        }
    }
}
PLANBHAI_EOF
cat > /tmp/pb_hh.py << 'PLANBHAI_EOF'
import sys, re
path, order, memories, activity = sys.argv[1:5]
s = open(path).read()

if 'HouseholdMemoriesSection' in s:
    print("   already applied"); sys.exit(3)

# 1. Reorder: Memories, Wall, Activity, then Jump to.
old_order = """                    if isActive {
                        jumpToSection
                        HouseholdWallSection(household: household)
                        HouseholdActivitySection(household: household)
                    } else {"""
if old_order not in s:
    m = re.search(r"                    if isActive \{\n.*?\n                    \} else \{", s, re.S)
    print("   ERROR: section order is not in the expected shape")
    if m: print("   found instead:\n" + m.group(0)[:300])
    sys.exit(2)
s = s.replace(old_order, open(order).read().rstrip() + "\n", 1)
# The replacement carries its own else-branch, so drop the original's.
s = re.sub(r"\n                    \} else \{\n                        Text\(\"Switch to this household[^}]*?\n                    \}\n",
           "\n", s, count=1, flags=re.S)

# 2. Replace the activity section with the clearable one.
m = re.search(r"// MARK: - Household Activity.*?\nstruct HouseholdActivitySection: View \{.*?\n\}\n", s, re.S)
if not m:
    print("   ERROR: HouseholdActivitySection not found"); sys.exit(2)
s = s[:m.start()] + open(activity).read() + s[m.end():]

# 3. Append the memories section.
s = s.rstrip() + "\n\n" + open(memories).read()

open(path, "w").write(s)
print("   reordered, activity clearable, memories added")
PLANBHAI_EOF

python3 /tmp/pb_hh.py "$H" /tmp/pb_order.swift /tmp/pb_mem.swift /tmp/pb_act.swift
RC=$?
rm -f /tmp/pb_hh.py /tmp/pb_order.swift /tmp/pb_mem.swift /tmp/pb_act.swift
if [ "$RC" = "3" ]; then
  echo "   nothing to do"
elif [ "$RC" != "0" ]; then
  cp "$H.bakorder" "$H"
  echo "   reverted — no changes made"
  exit 1
fi
echo

echo "3. Verifying"
grep -q "struct HouseholdMemoriesSection" "$H" && echo "   ok   memories section" \
  || { echo "   MISSING — reverting"; cp "$H.bakorder" "$H"; exit 1; }
n=$(grep -c "struct HouseholdActivitySection" "$H")
[ "$n" = "1" ] && echo "   ok   one activity section" \
  || { echo "   $n copies — reverting"; cp "$H.bakorder" "$H"; exit 1; }
grep -q "Clear this activity?" "$H" && echo "   ok   clear button"
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
echo "  Revert:  cp $H.bakorder $H"
echo "=========================================="

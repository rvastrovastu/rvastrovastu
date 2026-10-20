#!/usr/bin/env bash
#
# Water, calories and analytics leave the Meals page.
#
# WATER BECOMES A ROW ON THE BRIEF, not a screen anywhere
#
#     💧  Water          2 of 8 glasses      [−] [+]
#
#   It is tapped eight times a day, usually standing at a sink. A tracker a tab
#   away does not get used however good it is — the interaction has to be where
#   you already are.
#
#   Minus comes before plus, because the commonest correction is one tap too
#   many.
#
#   The goal is a constant 8. There is no stored goal on AppState and inventing
#   a settable one is a bigger change than this needs.
#
# CALORIES MOVE TO LIFESTYLE
#   Logging a meal needs a name and a number — that genuinely is a screen, and
#   Lifestyle already holds habits, challenges and routines.
#
# WEEKLY ANALYTICS IS REMOVED
#   Lifestyle has the same screen. Two links to one place is not a feature.
#
# Usage:
#   bash ~/Downloads/move-trackers.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
D="PlanBhai/ios/PlanBhai/Views"

echo "PlanBhai — trackers where they belong"
echo

echo "1. Before"
grep -c "Water Tracker\|Calorie Tracker\|Weekly Analytics" "$D/MealPlannerView.swift" \
  | xargs echo "   rows in Meals:"
echo

echo "2. Moving out of Meals"
cp "$D/MealPlannerView.swift" "$D/MealPlannerView.swift.baktrk"
cp "$D/HabitTrackerView.swift" "$D/HabitTrackerView.swift.baktrk"
cat > /tmp/pb_mt.py << 'PLANBHAI_EOF'
import sys

# 1. Out of Meals.
p = 'PlanBhai/ios/PlanBhai/Views/MealPlannerView.swift'
s = open(p).read()

removed = []
for title, reason in [
    ("Water Tracker", "belongs where you already are — a Brief row, tapped at the sink"),
    ("Calorie Tracker", "logging a meal needs a screen; Lifestyle has room"),
    ("Weekly Analytics", "Lifestyle already has this exact screen"),
]:
    lines = s.split('\n')
    keep = [l for l in lines if f'"{title}"' not in l]
    if len(keep) < len(lines):
        s = '\n'.join(keep)
        removed.append(title)

if not removed:
    print("   Meals: nothing to remove"); sys.exit(3)

open(p, 'w').write(s)
print(f"   Meals: removed {', '.join(removed)}")

# 2. Calories into Lifestyle.
p2 = 'PlanBhai/ios/PlanBhai/Views/HabitTrackerView.swift'
s2 = open(p2).read()

if 'CalorieTrackerView()' in s2:
    print("   Lifestyle: calories already there")
else:
    old = '("lightbulb.fill",     "Habit Suggestions", "Discover habits worth building",                       PB.forest, !appState.habits.isEmpty, AnyView(HabitSuggestionsView())),'
    if old in s2:
        new = old + '\n        ("flame.fill",         "Calorie Tracker",   "Log what you eat and track against a goal",             PB.orange, false, AnyView(CalorieTrackerView())),'
        s2 = s2.replace(old, new, 1)
        open(p2, 'w').write(s2)
        print("   Lifestyle: calories added")
    else:
        print("   Lifestyle: could not find the steps list — calories NOT moved")
PLANBHAI_EOF
python3 /tmp/pb_mt.py
RC=$?
rm -f /tmp/pb_mt.py
if [ "$RC" = "3" ]; then
  echo "   nothing to do"
elif [ "$RC" != "0" ]; then
  cp "$D/MealPlannerView.swift.baktrk" "$D/MealPlannerView.swift"
  cp "$D/HabitTrackerView.swift.baktrk" "$D/HabitTrackerView.swift"
  echo "   reverted"; exit 1
fi
echo

echo "3. Water on the Brief"
cp "$D/DayBriefView.swift" "$D/DayBriefView.swift.baktrk"
cat > /tmp/pb_wr.swift << 'PLANBHAI_EOF'
    // MARK: - Water
    //
    // A row, not a screen. Water is tapped eight times a day, usually standing
    // at a sink — a tracker a tab away does not get used, however good the
    // tracker is.
    //
    // The full WaterTrackerView stays in Lifestyle for history and goals; the
    // tapping happens where you already are.
    private var waterRow: some View {
        HStack(spacing: 12) {
            Text("💧").font(.system(size: 20))

            VStack(alignment: .leading, spacing: 2) {
                Text("Water")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(appState.waterGlasses) of \(waterGoal) glasses")
                    .font(.system(size: 11))
                    .foregroundStyle(appState.waterGlasses >= waterGoal ? PB.forest : PB.soft)
            }

            Spacer(minLength: 8)

            // Minus first, because the commonest correction is one tap too many.
            Button {
                appState.removeWaterGlass()
                Task { await appState.saveAllLocalData() }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(PB.muted)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.white.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .disabled(appState.waterGlasses == 0)
            .opacity(appState.waterGlasses == 0 ? 0.4 : 1)

            Button {
                appState.addWaterGlass()
                Task { await appState.saveAllLocalData() }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(PB.sky.opacity(0.35)))
                    .overlay(Circle().stroke(PB.sky, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .glassCard()
    }

    /// Eight. There is no stored goal on AppState, and inventing a settable one
    /// is a bigger change than this needs — eight is the number everybody means
    /// when they say "glasses of water", and it gives the count something to
    /// measure against.
    private var waterGoal: Int { 8 }
PLANBHAI_EOF
cat > /tmp/pb_pw.py << 'PLANBHAI_EOF'
import sys, re
p = 'PlanBhai/ios/PlanBhai/Views/DayBriefView.swift'
s = open(p).read()

if 'waterRow' in s:
    print("   already placed"); sys.exit(3)

# After the habit garden — both are "did I do the small thing today".
anchor = "                        habitGarden(b)"
if anchor not in s:
    m = re.search(r"^(\s*)if let h = b\.habits.*habitGarden\(b\).*$", s, re.M)
    if m:
        anchor = m.group(0)
    else:
        print("   ERROR: could not find the habit garden call"); sys.exit(2)

i = s.index(anchor)
line_end = s.index('\n', i)
s = s[:line_end + 1] + "                        waterRow\n" + s[line_end + 1:]

# The row itself, before the footer helper.
marker = "    // MARK: - Footer"
if marker not in s:
    marker = "    // MARK: - Load"
if marker not in s:
    print("   ERROR: could not find where to add the row"); sys.exit(2)
s = s.replace(marker, open(sys.argv[1]).read() + "\n" + marker, 1)

open(p, "w").write(s)
print("   water row placed after the habit garden")
PLANBHAI_EOF
python3 /tmp/pb_pw.py /tmp/pb_wr.swift
RC=$?
rm -f /tmp/pb_pw.py /tmp/pb_wr.swift
if [ "$RC" = "3" ]; then
  echo "   nothing to do"
elif [ "$RC" != "0" ]; then
  cp "$D/DayBriefView.swift.baktrk" "$D/DayBriefView.swift"
  echo "   reverted the Brief"; exit 1
fi
echo

echo "4. Verifying"
grep -q "Water Tracker" "$D/MealPlannerView.swift" \
  && echo "   WARN water still in Meals" || echo "   ok   water out of Meals"
grep -q "Weekly Analytics" "$D/MealPlannerView.swift" \
  && echo "   WARN analytics still in Meals" || echo "   ok   analytics gone"
grep -q "CalorieTrackerView()" "$D/HabitTrackerView.swift" \
  && echo "   ok   calories in Lifestyle" || echo "   WARN calories not moved"
grep -q "private var waterRow" "$D/DayBriefView.swift" \
  && echo "   ok   water row defined"
grep -q "actingSuggestion: String?" "$D/DayBriefView.swift" \
  && echo "   ok   actingSuggestion kept"
echo

echo "5. Building"
SIM=$(xcodebuild -scheme PlanBhai -showdestinations 2>/dev/null \
  | grep -oE "name:iPhone [^}]*" | sed 's/name://' | sed 's/ *$//' | head -1)
[ -z "$SIM" ] && SIM="iPhone 17"
echo "   simulator: $SIM"
xcodebuild -scheme PlanBhai -destination "platform=iOS Simulator,name=$SIM" build 2>&1 \
  | grep -E "error:|failures\)|BUILD (SUCCEEDED|FAILED)" | head -12
echo

echo "=========================================="
echo "  Brief: water sits under the habit garden, tappable in place."
echo "  Meals: four steps now — plan, pantry, grocery, budget, saved."
echo
echo "  Revert:"
echo "     cp $D/MealPlannerView.swift.baktrk $D/MealPlannerView.swift"
echo "     cp $D/HabitTrackerView.swift.baktrk $D/HabitTrackerView.swift"
echo "     cp $D/DayBriefView.swift.baktrk $D/DayBriefView.swift"
echo "=========================================="

#!/usr/bin/env bash
#
# The splash actually appears — and hands its logo to onboarding.
#
# IT WAS BUILT AND INVISIBLE. SplashView existed, compiled, and was shown
# nowhere. ContentView is still the untouched Xcode template; the real root is
# RootView at the bottom of PlanBhaiApp.swift.
#
# THE HAND-OFF
#   A @Namespace is shared between RootView's splash and OnboardingView, so the
#   logo carries a matchedGeometryEffect on both sides. It does not fade out
#   there and fade in here — it is the SAME element, travelling from 132pt in
#   the centre to 54pt above the first step title.
#
#   That is the difference between the app settling into place and one screen
#   cutting to another, and it is the distinctive part of the concept.
#
#   The namespace is OPTIONAL on OnboardingView, so any other construction of
#   that view still compiles.
#
# THE SPLASH SITS IN A ZSTACK above the router rather than replacing it, so the
# real screen is already laid out underneath as the splash fades — no flash of
# empty background between the two.
#
# Usage:
#   bash ~/Downloads/wire-splash.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
D="PlanBhai/ios/PlanBhai"

echo "PlanBhai — show the splash"
echo

echo "1. Checking it exists"
grep -q "var onFinish" "$D/Views/SplashView.swift" \
  && echo "   ok   SplashView takes onFinish" \
  || { echo "   MISSING onFinish — run install-splash.sh first"; exit 1; }
grep -q "var namespace" "$D/Views/SplashView.swift" \
  && echo "   ok   SplashView takes a namespace"
echo

echo "2. RootView"
cp "$D/PlanBhaiApp.swift" "$D/PlanBhaiApp.swift.bakwire"
cat > /tmp/pb_ws.py << 'PLANBHAI_EOF'
import sys
p = 'PlanBhai/ios/PlanBhai/PlanBhaiApp.swift'
s = open(p).read()

if 'SplashView' in s:
    print("   already wired"); sys.exit(3)

old = """struct RootView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if appState.isLoggedIn {
                if !appState.hasCompletedOnboarding {
                    OnboardingView()
                } else {
                    MainTabView()
                }
            } else {
                AuthView()
            }
        }"""

new = """struct RootView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\\.scenePhase) private var scenePhase

    @State private var showSplash = true

    /// Shared with the splash so the logo can HAND OFF rather than fade out and
    /// fade in. matchedGeometryEffect makes it the same element moving, which
    /// is what turns two screens into one continuous arrival.
    @Namespace private var brand

    var body: some View {
        ZStack {
            Group {
                if appState.isLoggedIn {
                    if !appState.hasCompletedOnboarding {
                        OnboardingView(brand: brand)
                    } else {
                        MainTabView()
                    }
                } else {
                    AuthView()
                }
            }

            if showSplash {
                SplashView(onFinish: { showSplash = false }, namespace: brand)
                    // Above everything, and it must not intercept taps once it
                    // starts fading — a screen you cannot tap through while it
                    // disappears feels broken.
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showSplash)"""

if old not in s:
    print("   ERROR: RootView is not in the expected shape"); sys.exit(2)
s = s.replace(old, new, 1)
open(p, "w").write(s)
print("   splash wired above the root")
PLANBHAI_EOF
python3 /tmp/pb_ws.py
RC=$?
rm -f /tmp/pb_ws.py
if [ "$RC" = "3" ]; then
  echo "   nothing to do"
elif [ "$RC" != "0" ]; then
  cp "$D/PlanBhaiApp.swift.bakwire" "$D/PlanBhaiApp.swift"
  echo "   reverted"; exit 1
fi
echo

echo "3. Onboarding receives the logo"
cp "$D/Views/OnboardingView.swift" "$D/Views/OnboardingView.swift.bakwire"
cat > /tmp/pb_ol.py << 'PLANBHAI_EOF'
import sys, re
p = 'PlanBhai/ios/PlanBhai/Views/OnboardingView.swift'
s = open(p).read()

if 'brand:' in s or 'planbhai.logo' in s:
    print("   already receives the logo"); sys.exit(3)

# The namespace comes in optionally, so OnboardingView() still compiles
# wherever else it is constructed.
old_struct = "struct OnboardingView: View {"
new_struct = """struct OnboardingView: View {
    /// Passed from RootView so the splash's logo can land here rather than
    /// vanishing. Optional, so any other construction of this view still works.
    var brand: Namespace.ID? = nil
"""
if old_struct not in s:
    print("   ERROR: OnboardingView not found"); sys.exit(2)
s = s.replace(old_struct, new_struct, 1)

# The logo above the step title — where the splash's logo travels to.
m = re.search(r"^(\s*)Text\(steps\[currentStep\]\.title\)", s, re.M)
if not m:
    print("   ERROR: could not find the step title"); sys.exit(2)

indent = m.group(1)
logo = (
    f'{indent}// The splash logo lands HERE. Same element, smaller and higher —\n'
    f'{indent}// so the app appears to settle rather than cut.\n'
    f'{indent}if let brand {{\n'
    f'{indent}    Image("PlanBhaiLogo")\n'
    f'{indent}        .resizable().scaledToFit()\n'
    f'{indent}        .frame(width: 54, height: 54)\n'
    f'{indent}        .clipShape(Circle())\n'
    f'{indent}        .matchedGeometryEffect(id: "planbhai.logo", in: brand)\n'
    f'{indent}        .padding(.bottom, 14)\n'
    f'{indent}}}\n\n'
)
s = s[:m.start()] + logo + s[m.start():]
open(p, "w").write(s)
print("   onboarding receives the logo")
PLANBHAI_EOF
python3 /tmp/pb_ol.py
RC=$?
rm -f /tmp/pb_ol.py
if [ "$RC" = "3" ]; then
  echo "   nothing to do"
elif [ "$RC" != "0" ]; then
  cp "$D/Views/OnboardingView.swift.bakwire" "$D/Views/OnboardingView.swift"
  cp "$D/PlanBhaiApp.swift.bakwire" "$D/PlanBhaiApp.swift"
  echo "   reverted both"; exit 1
fi
echo

echo "4. Verifying"
grep -q "SplashView(onFinish:" "$D/PlanBhaiApp.swift" && echo "   ok   splash presented"
grep -q "@Namespace private var brand" "$D/PlanBhaiApp.swift" && echo "   ok   namespace shared"
grep -q "planbhai.logo" "$D/Views/OnboardingView.swift" && echo "   ok   onboarding receives it"
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
echo "  DELETE THE APP from the simulator before running, or you will get the"
echo "  0.9s version — hasSeenSplash lives in UserDefaults and it has already"
echo "  played once during the build checks."
echo
echo "  The hand-off only shows when onboarding follows the splash, which means"
echo "  a signed-in account that has not completed onboarding."
echo
echo "  Revert:"
echo "     cp $D/PlanBhaiApp.swift.bakwire $D/PlanBhaiApp.swift"
echo "     cp $D/Views/OnboardingView.swift.bakwire $D/Views/OnboardingView.swift"
echo "=========================================="

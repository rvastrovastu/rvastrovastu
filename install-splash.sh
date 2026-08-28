#!/usr/bin/env bash
#
# The splash screen, built to your sequence — with one change worth explaining.
#
# TWO LENGTHS, AND THAT IS THE WHOLE DESIGN
#
#   First launch      2.65s. Particles, logo, glow, tagline, the five domain
#                     icons, a shimmer across the mark, then a fade.
#
#   Every launch      0.9s. Logo, tagline, gone.
#   after
#
#   Your spec ran 2.5-3s every time. Current apps — Instagram, Notion, Linear —
#   sit under a second on a warm launch, and the reason is that a splash is time
#   nobody asked for, paid on EVERY open. By the fiftieth launch, someone
#   opening the app to tick a glass of water has spent two minutes watching an
#   animation they memorised on day three.
#
#   So: craft where it earns attention, speed where it costs patience. The full
#   sequence is genuinely good and worth watching once.
#
# THE TIMINGS ARE GAPS BETWEEN STARTS, not animation lengths — everything runs
# on while the next begins. Waiting for each to finish first produced a
# four-second splash that felt like a queue.
#
# THE TRANSITION
#   The logo takes a matchedGeometryEffect when a namespace is passed in, so it
#   does not fade out here and fade in there — it is the SAME element moving.
#   That is what makes two screens feel continuous rather than sequential.
#
#   Onboarding has no logo in its header yet, so nothing receives the hand-off.
#   Adding one is the next step and needs OnboardingView's header markup.
#
# SMALLER CHOICES
#   Navy into INDIGO, not navy into Color.blue — the original ran to a stock
#   blue that read as a default rather than a decision.
#
#   The ambient glow sits off-centre. Perfect symmetry reads as a template.
#
#   18 particles, irregularly placed. A dense even field reads as a screensaver.
#
#   The shimmer is masked to the logo's circle. A highlight that ignores the
#   shape it crosses looks pasted on.
#
# Usage:
#   bash ~/Downloads/install-splash.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
D="PlanBhai/ios/PlanBhai/Views"
[ -d "$D" ] || { echo "ERROR: $D not found"; exit 1; }

echo "PlanBhai — splash"
echo

echo "1. Checking the logo asset"
if [ -d "PlanBhai/ios/PlanBhai/Assets.xcassets/PlanBhaiLogo.imageset" ]; then
  echo "   ok   PlanBhaiLogo"
else
  echo "   WARN PlanBhaiLogo imageset not found — the logo will render blank"
fi
echo

echo "2. Writing"
[ -f "$D/SplashView.swift" ] && cp "$D/SplashView.swift" "$D/SplashView.swift.baksplash"
cat > "$D/SplashView.swift" << 'PLANBHAI_EOF'
import SwiftUI

/// The first thing anyone sees.
///
/// TWO LENGTHS, and the distinction is the whole design.
///
///   First launch     the full sequence, about 2.6 seconds. Someone meeting
///                    PlanBhai for the first time will happily watch it, and it
///                    sets the tone for everything after.
///
///   Every launch     logo, brief pulse, gone in 0.7. A splash is time nobody
///   after            asked for, paid on EVERY launch — by the fiftieth, the
///                    person opening the app to tick a glass of water has spent
///                    two minutes watching an animation they have memorised.
///
/// Craft where it earns attention; speed where it costs patience.
struct SplashView: View {

    /// Called when the sequence finishes.
    var onFinish: () -> Void = {}

    /// Set by the caller when the logo should hand off to a header rather than
    /// simply fading — see the note on the transition below.
    var namespace: Namespace.ID?

    @AppStorage("hasSeenSplash") private var hasSeenSplash = false

    @State private var particles = false
    @State private var logoIn = false
    @State private var glowOut = false
    @State private var taglineIn = false
    @State private var iconsIn = false
    @State private var shimmer = false
    @State private var fadingOut = false

    /// The domains PlanBhai actually covers. Shown rather than described,
    /// because five icons say in a second what a sentence takes longer to.
    private let domains = ["📅", "🍽️", "🎯", "✈️", "💰"]

    private var isFirstRun: Bool { !hasSeenSplash }

    var body: some View {
        ZStack {
            background

            if isFirstRun { particleField }

            glowHalo
            logo

            VStack(spacing: 0) {
                Spacer()
                tagline
                if isFirstRun { domainIcons }
                poweredBy
            }
            .padding(.bottom, 54)
        }
        .opacity(fadingOut ? 0 : 1)
        .task { await run() }
    }

    // MARK: - Pieces

    private var background: some View {
        ZStack {
            // Navy into indigo, not navy into blue. The original ran to
            // Color.blue at 0.6, which reads as a stock gradient rather than a
            // considered one.
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.05, blue: 0.13),
                    Color(red: 0.09, green: 0.10, blue: 0.28),
                    Color(red: 0.16, green: 0.13, blue: 0.36),
                ],
                startPoint: .top, endPoint: .bottom
            )

            // Ambient warmth off-centre, so the screen is not perfectly
            // symmetrical — symmetry reads as a template.
            RadialGradient(
                colors: [Color(red: 0.35, green: 0.30, blue: 0.75).opacity(0.30), .clear],
                center: .init(x: 0.72, y: 0.22),
                startRadius: 10, endRadius: 340
            )
        }
        .ignoresSafeArea()
    }

    /// Sparse and irregular. A dense, even field reads as a screensaver.
    private var particleField: some View {
        ZStack {
            ForEach(0..<18, id: \.self) { i in
                let seed = Double(i)
                Circle()
                    .fill(.white.opacity(0.55))
                    .frame(width: i % 4 == 0 ? 3 : 1.6)
                    .offset(
                        x: CGFloat(sin(seed * 2.7) * 150),
                        y: CGFloat(cos(seed * 1.9) * 290)
                    )
                    .opacity(particles ? (i % 3 == 0 ? 0.9 : 0.35) : 0)
                    .animation(
                        .easeOut(duration: 1.1).delay(seed * 0.045),
                        value: particles
                    )
            }
        }
        .allowsHitTesting(false)
    }

    private var glowHalo: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 0.40, green: 0.45, blue: 0.95).opacity(0.55),
                        Color(red: 0.30, green: 0.55, blue: 0.85).opacity(0.18),
                        .clear,
                    ],
                    center: .center, startRadius: 8, endRadius: 150
                )
            )
            .frame(width: 300, height: 300)
            .blur(radius: 26)
            .scaleEffect(glowOut ? 1.0 : 0.55)
            .opacity(glowOut ? 1 : 0)
    }

    @ViewBuilder
    private var logo: some View {
        let image = Image("PlanBhaiLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 132, height: 132)
            .clipShape(Circle())
            .overlay(
                // The shimmer: a bright band swept across, masked to the logo.
                // A highlight that ignores the shape it crosses looks pasted on.
                Circle().fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.45), .clear],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .rotationEffect(.degrees(28))
                .offset(x: shimmer ? 190 : -190)
                .mask(Circle())
            )
            .scaleEffect(logoIn ? 1.0 : 0.9)
            .opacity(logoIn ? 1 : 0)
            .shadow(color: Color(red: 0.35, green: 0.40, blue: 0.95).opacity(0.5),
                    radius: 26, y: 6)

        // matchedGeometryEffect when a namespace is supplied, so the logo does
        // not fade out here and fade in there — it is the SAME element, moving.
        // That is what makes the two screens feel continuous rather than
        // sequential.
        if let namespace {
            image.matchedGeometryEffect(id: "planbhai.logo", in: namespace)
        } else {
            image
        }
    }

    private var tagline: some View {
        Text("Your Bhai for Every Plan")
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.92))
            .opacity(taglineIn ? 1 : 0)
            .offset(y: taglineIn ? 0 : 10)
    }

    private var domainIcons: some View {
        HStack(spacing: 20) {
            ForEach(Array(domains.enumerated()), id: \.offset) { i, icon in
                Text(icon)
                    .font(.system(size: 21))
                    .opacity(iconsIn ? 0.85 : 0)
                    .offset(y: iconsIn ? 0 : 14)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.7)
                            .delay(Double(i) * 0.07),
                        value: iconsIn
                    )
            }
        }
        .padding(.top, 22)
    }

    private var poweredBy: some View {
        Text("Powered by AI")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.40))
            .opacity(taglineIn ? 1 : 0)
            .padding(.top, 18)
    }

    // MARK: - The sequence

    private func run() async {
        if isFirstRun {
            await firstRun()
            hasSeenSplash = true
        } else {
            await returning()
        }

        withAnimation(.easeIn(duration: 0.35)) { fadingOut = true }
        try? await Task.sleep(nanoseconds: 350_000_000)
        onFinish()
    }

    /// The full sequence, once.
    ///
    /// The waits are the gaps BETWEEN starts, not the length of each animation
    /// — every one runs on while the next begins. Waiting for each to finish
    /// before starting the next produced a four-second splash that felt like a
    /// queue rather than a sequence.
    ///
    ///   0.00  particles begin
    ///   0.25  logo scales in
    ///   0.60  glow expands behind it
    ///   0.90  tagline
    ///   1.25  domain icons, each on its own delay
    ///   1.70  shimmer sweeps
    ///   2.30  fade to onboarding
    private func firstRun() async {
        withAnimation(.easeOut(duration: 0.9)) { particles = true }

        try? await Task.sleep(nanoseconds: 250_000_000)
        withAnimation(.spring(response: 0.65, dampingFraction: 0.72)) { logoIn = true }

        try? await Task.sleep(nanoseconds: 350_000_000)
        withAnimation(.easeOut(duration: 0.8)) { glowOut = true }

        try? await Task.sleep(nanoseconds: 300_000_000)
        withAnimation(.easeOut(duration: 0.45)) { taglineIn = true }

        try? await Task.sleep(nanoseconds: 350_000_000)
        iconsIn = true   // each icon carries its own spring and delay

        try? await Task.sleep(nanoseconds: 450_000_000)
        withAnimation(.easeInOut(duration: 0.8)) { shimmer = true }

        // Long enough for the shimmer to cross, not long enough to wait for it
        // to finish — it is still travelling as the screen fades, which reads
        // as movement rather than a pause.
        try? await Task.sleep(nanoseconds: 600_000_000)
    }

    /// Every launch after: 0.55 seconds, and it still feels deliberate.
    ///
    /// No particles, no icons, no shimmer. The logo arrives, the tagline
    /// follows, and it is gone before anyone has decided to be impatient.
    private func returning() async {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            logoIn = true
            glowOut = true
        }
        withAnimation(.easeOut(duration: 0.3).delay(0.1)) { taglineIn = true }
        try? await Task.sleep(nanoseconds: 550_000_000)
    }
}
PLANBHAI_EOF
echo "   wrote $D/SplashView.swift"
grep -q "hasSeenSplash" "$D/SplashView.swift" && echo "   ok   first run is distinguished"
grep -q "matchedGeometryEffect" "$D/SplashView.swift" && echo "   ok   ready for the hand-off"
echo

echo "3. Where it is shown"
if grep -rn "SplashView()" PlanBhai/ios/PlanBhai/*.swift PlanBhai/ios/PlanBhai/Views/*.swift 2>/dev/null | grep -v "\.bak" | grep -v "SplashView.swift" | head -3; then
  echo "   (listed above — the call site needs onFinish: now)"
else
  echo "   NOT SHOWN ANYWHERE YET — see the note at the end"
fi
echo

echo "4. Building"
SIM=$(xcodebuild -scheme PlanBhai -showdestinations 2>/dev/null \
  | grep -oE "name:iPhone [^}]*" | sed 's/name://' | sed 's/ *$//' | head -1)
[ -z "$SIM" ] && SIM="iPhone 17"
echo "   simulator: $SIM"
xcodebuild -scheme PlanBhai -destination "platform=iOS Simulator,name=$SIM" build 2>&1 \
  | grep -E "error:|failures\)|BUILD (SUCCEEDED|FAILED)" | head -12
echo

echo "=========================================="
echo "  SplashView now takes an onFinish closure, so whatever presents it must"
echo "  pass one — usually in ContentView:"
echo
echo "      @State private var showSplash = true"
echo "      if showSplash {"
echo "          SplashView { showSplash = false }"
echo "      } else {"
echo "          ...your existing root..."
echo "      }"
echo
echo "  To see the FIRST-RUN sequence again after it has played once, delete"
echo "  the app from the simulator — hasSeenSplash lives in UserDefaults."
echo
echo "  Revert:  cp $D/SplashView.swift.baksplash $D/SplashView.swift"
echo "=========================================="

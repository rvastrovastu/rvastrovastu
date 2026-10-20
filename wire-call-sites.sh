#!/usr/bin/env bash
#
# Wires the calendar sync call sites.
#
#   1. RootView: sync after households load, and again on foreground.
#      activeHouseholdId doesn't exist until fetchMyHouseholds() completes, so
#      syncing alongside it would silently no-op on every launch.
#   2. Adds CalendarSyncSection — a standalone Settings control that shows an
#      explanation before the one-shot system permission prompt.
#
# Uses .task(id: scenePhase) rather than .onChange because your code has
# #available(iOS 17.0, *) checks, meaning the deployment target is below 17 where
# two-parameter onChange doesn't exist.
#
# Usage:
#   bash ~/Downloads/wire-call-sites.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
D="PlanBhai/ios/PlanBhai"
[ -d "$D" ] || { echo "ERROR: $D not found"; exit 1; }

echo "PlanBhai — wiring call sites"
echo

echo "1. Patching RootView in PlanBhaiApp.swift"
APP="$D/PlanBhaiApp.swift"
if grep -q "syncCalendarIfPossible" "$APP"; then
  echo "   already wired, skipping"
else
  cp "$APP" "$APP.bakwire"
  python3 - "$APP" << 'PY_EOF'
import sys, re
p = sys.argv[1]
s = open(p).read()

# scenePhase on RootView
old_decl = """struct RootView: View {
    @EnvironmentObject var appState: AppState
"""
new_decl = """struct RootView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\\.scenePhase) private var scenePhase
"""
if old_decl not in s:
    print("   ERROR: RootView declaration not in the expected shape"); sys.exit(1)
s = s.replace(old_decl, new_decl, 1)

# sync AFTER households load, plus a foreground hook
old_task = "                Task { await appState.fetchMyHouseholds() }"
new_task = """                Task {
                    await appState.fetchMyHouseholds()
                    // Households must exist first — activeHouseholdId is nil
                    // until fetchMyHouseholds() returns, and the sync needs it.
                    await appState.syncCalendarIfPossible()
                }"""
if old_task not in s:
    print("   ERROR: fetchMyHouseholds call not in the expected shape"); sys.exit(1)
s = s.replace(old_task, new_task, 1)

# foreground refresh; .task(id:) works on iOS 15+ and is async-native
old_tail = """            }
        }
    }
}

// MARK: - Notification Manager"""
new_tail = """            }
        }
        .task(id: scenePhase) {
            if scenePhase == .active {
                await appState.syncCalendarIfPossible()
            }
        }
    }
}

// MARK: - Notification Manager"""
if old_tail in s:
    s = s.replace(old_tail, new_tail, 1)
else:
    # RootView is last in the file
    s = re.sub(r"(\.onAppear \{[\s\S]*?\n        \}\n    \}\n\})\s*$",
               lambda m: m.group(1).replace("\n    }\n}",
                 "\n        .task(id: scenePhase) {\n            if scenePhase == .active {\n                await appState.syncCalendarIfPossible()\n            }\n        }\n    }\n}"),
               s)

open(p, "w").write(s)
print("   patched")
PY_EOF
  [ $? -ne 0 ] && { cp "$APP.bakwire" "$APP"; echo "   reverted — no changes made"; exit 1; }
fi
echo

echo "2. Adding CalendarSyncSection"
SEC="$D/Views/CalendarSyncSection.swift"
mkdir -p "$D/Views"
[ -f "$SEC" ] && cp "$SEC" "$SEC.bakwire"
cat > "$SEC" << 'PLANBHAI_EOF'
import SwiftUI

/// Drop-in calendar sync control. Standalone so it can sit anywhere in Settings
/// without assuming a Form or List container.
///
/// Shows the explanation BEFORE the system prompt. That prompt fires once — if
/// it's denied, the only way back is the Settings app, and almost nobody goes.
/// Earning the yes first matters more here than for most permissions.
struct CalendarSyncSection: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var sync = CalendarSyncManager.shared

    @State private var showExplainer = false
    @State private var isWorking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                Text("Calendar Sync")
                    .font(.headline)
                Spacer()
                if isWorking {
                    ProgressView()
                } else {
                    Toggle("", isOn: Binding(
                        get: { sync.hasAccess },
                        set: { wantsOn in
                            if wantsOn { showExplainer = true } else { turnOff() }
                        }
                    ))
                    .labelsHidden()
                }
            }

            Text(sync.hasAccess
                 ? appState.calendarSyncStatus
                 : "Show your calendar events alongside your meals and plans.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let error = sync.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .alert("Connect your calendar?", isPresented: $showExplainer) {
            Button("Not now", role: .cancel) { }
            Button("Continue") { turnOn() }
        } message: {
            Text("PlanBhai will read your calendar so your whole day appears in one place, and stays in sync on the web app.\n\nOnly event titles and times are stored. Notes, attendees and locations are never read.")
        }
    }

    private func turnOn() {
        isWorking = true
        Task {
            await appState.enableCalendarSync()
            isWorking = false
        }
    }

    private func turnOff() {
        isWorking = true
        Task {
            await appState.disableCalendarSync()
            isWorking = false
        }
    }
}
PLANBHAI_EOF
echo "   wrote $SEC"
echo

echo "3. Where to place it in SettingsView"
SET="$D/Views/SettingsView.swift"
if grep -q "CalendarSyncSection" "$SET"; then
  echo "   already referenced"
else
  echo "   NOT inserted automatically — SettingsView uses a custom layout"
  echo "   (no Form/Section), so guessing an anchor risks breaking it."
  echo
  echo "   Its top-level container:"
  sed -n '13,32p' "$SET" | sed 's/^/      /'
  echo
  echo "   Add this one line inside that container, wherever you want it:"
  echo "      CalendarSyncSection()"
fi
echo

echo "4. Building"
SIM=$(xcrun simctl list devices available 2>/dev/null | grep -oE "iPhone [0-9]+" | head -1)
[ -z "$SIM" ] && SIM="iPhone 17"
echo "   simulator: $SIM"
xcodebuild -scheme PlanBhai -destination "platform=iOS Simulator,name=$SIM" build 2>&1 \
  | grep -E "error:|warning: .*Calendar|BUILD (SUCCEEDED|FAILED)" | head -20
echo

echo "=========================================="
echo "  If the build failed, restore with:"
echo "     cp $APP.bakwire $APP"
echo "=========================================="

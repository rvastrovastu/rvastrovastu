#!/usr/bin/env bash
#
# Adds the calendar sync wiring as an AppState extension.
#
# Deliberately a separate file rather than an edit to AppState.swift — that file
# is 1000+ lines and patching it programmatically risks breaking working code.
# `path = PlanBhai` is a synchronized root, so a new file compiles automatically
# with no Xcode step.
#
# Usage:
#   bash ~/Downloads/wire-ios-sync.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }

DEST_DIR="PlanBhai/ios/PlanBhai"
[ -d "$DEST_DIR" ] || { echo "ERROR: $DEST_DIR not found"; exit 1; }

echo "PlanBhai — wiring calendar sync"
echo

echo "1. Confirming the properties this depends on"
for pair in "authToken:AppState.swift" "activeHouseholdId:AppState.swift"; do
  name="${pair%%:*}"; file="${pair##*:}"
  if grep -q "$name" "$DEST_DIR/$file"; then
    echo "   ok   $name"
  else
    echo "   MISSING $name in $file — stopping"
    exit 1
  fi
done
echo

echo "2. Writing the extension"
DEST="$DEST_DIR/AppState+CalendarSync.swift"
[ -f "$DEST" ] && cp "$DEST" "$DEST.bakios"
cat > "$DEST" << 'PLANBHAI_EOF'
import Foundation
import SwiftUI

/// Calendar sync wiring, kept in an extension so AppState.swift stays untouched.
///
/// Everything here is a no-op unless the user has signed in, picked a household,
/// AND granted calendar access — so it's safe to call from app launch or
/// foreground without checking anything at the call site.
@MainActor
extension AppState {

    /// Call on launch and on foreground. Silent when sync isn't set up.
    func syncCalendarIfPossible() async {
        guard
            CalendarSyncManager.shared.hasAccess,
            let token = authToken,
            let householdId = activeHouseholdId
        else { return }

        await CalendarSyncManager.shared.sync(householdId: householdId, token: token)
        CalendarSyncManager.shared.startObserving(householdId: householdId, token: token)
    }

    /// Call from a Settings toggle, AFTER your own explanation screen.
    ///
    /// The system permission prompt is one-shot: once denied, the only way back
    /// is Settings, and almost nobody goes. Earning the yes beforehand matters
    /// more here than for most permissions.
    @discardableResult
    func enableCalendarSync() async -> Bool {
        guard let token = authToken, let householdId = activeHouseholdId else {
            return false
        }

        if !CalendarSyncManager.shared.hasAccess {
            let granted = await CalendarSyncManager.shared.requestAccess()
            guard granted else { return false }
        }

        let ok = await CalendarSyncManager.shared.sync(householdId: householdId, token: token)
        if ok {
            CalendarSyncManager.shared.startObserving(householdId: householdId, token: token)
        }
        return ok
    }

    /// Call from the Settings toggle when switching sync off.
    ///
    /// This deletes the server-side copies, not just the local link. "Stop
    /// syncing" that leaves the data on a server isn't a disconnect, and the
    /// App Store privacy commitment requires the deletion to actually happen.
    func disableCalendarSync() async {
        guard let token = authToken, let householdId = activeHouseholdId else {
            CalendarSyncManager.shared.stopObserving()
            return
        }
        await CalendarSyncManager.shared.disconnect(householdId: householdId, token: token)
    }

    /// For a "Calendar synced 20m ago" line. Web's timeline is only as fresh as
    /// the last iOS sync, so showing staleness is more honest than hiding it.
    var calendarSyncStatus: String {
        if !CalendarSyncManager.shared.hasAccess { return "Not connected" }
        guard let at = CalendarSyncManager.shared.lastSyncedAt else { return "Not synced yet" }

        let mins = Int(Date().timeIntervalSince(at) / 60)
        if mins < 1 { return "Synced just now" }
        if mins < 60 { return "Synced \(mins)m ago" }
        return "Synced \(mins / 60)h ago"
    }
}
PLANBHAI_EOF
echo "   wrote $DEST"
echo

echo "3. Parsing"
if command -v swiftc >/dev/null 2>&1; then
  swiftc -parse "$DEST" 2>&1 | head -5
  echo "   parsed (type errors only show up in a full build)"
fi
echo

echo "4. A simulator that actually exists on this machine"
SIM=$(xcrun simctl list devices available 2>/dev/null \
  | grep -oE "iPhone [0-9]+( Pro)?" | head -1)
[ -z "$SIM" ] && SIM="iPhone 17"
echo "   using: $SIM"
echo

echo "=========================================="
echo "  Build it:"
echo
echo "    xcodebuild -scheme PlanBhai \\"
echo "      -destination 'platform=iOS Simulator,name=$SIM' build 2>&1 | tail -20"
echo "=========================================="

#!/usr/bin/env bash
#
# Fixes the iOS calendar sync.
#
# Three problems with what was installed earlier:
#   1. It called APIClient.shared.post(...) — your networking layer is APIService.
#      There is no APIClient, so the file does not compile.
#   2. It landed in PlanBhai/Services/, but your real sources live in
#      PlanBhai/ios/PlanBhai/ alongside APIService.swift.
#   3. It sent Swift `Date` values. The default JSONEncoder serialises those as
#      seconds-since-2001, which Express parses as 1970 — silently. This version
#      sends ISO-8601 strings so the encoder's behaviour is irrelevant.
#
# `path = PlanBhai` is a synchronized root, so the broken file is being compiled
# right now. Removing it should fix your build.
#
# Usage:
#   bash ~/Downloads/fix-ios-calendar.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }

DEST_DIR="PlanBhai/ios/PlanBhai"
[ -d "$DEST_DIR" ] || { echo "ERROR: $DEST_DIR not found"; exit 1; }

echo "PlanBhai — iOS calendar sync fix"
echo

echo "1. Removing the broken copy"
OLD="PlanBhai/Services/CalendarSyncManager.swift"
if [ -f "$OLD" ]; then
  rm -f "$OLD"
  echo "   deleted $OLD"
  rmdir PlanBhai/Services 2>/dev/null && echo "   removed the now-empty PlanBhai/Services/"
else
  echo "   not present, nothing to remove"
fi
echo

echo "2. Writing the corrected file"
DEST="$DEST_DIR/CalendarSyncManager.swift"
[ -f "$DEST" ] && cp "$DEST" "$DEST.bakios"
cat > "$DEST" << 'PLANBHAI_EOF'
import Foundation
import EventKit
import Combine

/// Syncs a rolling window of the device calendar to the PlanBhai backend so the
/// web app can render the same timeline. EventKit is Apple-only, so iOS is the
/// ingestion source until Google Calendar OAuth lands.
///
/// PRIVACY: only title, start, end, allDay and calendar name leave the device.
/// Notes, attendees, location, URL and attachments are never read or transmitted.
/// Calendar entries contain other people's information, not just the user's.
///
/// DATES GO OVER THE WIRE AS STRINGS, NOT `Date`. Swift's default JSONEncoder
/// serialises Date as seconds-since-2001, which Express parses as 1970 — silently,
/// with no error anywhere. APIService creates a fresh JSONEncoder per call, so
/// setting a global date strategy would ripple into every other endpoint.
/// Formatting ISO-8601 here makes the encoder's behaviour irrelevant.
@MainActor
final class CalendarSyncManager: ObservableObject {

    static let shared = CalendarSyncManager()

    /// Must match APIService.baseURL. It's `private` there, so it's repeated
    /// here — if you change one, change both.
    private let baseURL = "https://planbhai.onrender.com"

    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var isSyncing = false
    @Published private(set) var lastError: String?

    private let store = EKEventStore()
    private var observer: NSObjectProtocol?
    private var debounceTask: Task<Void, Never>?

    /// Yesterday gives "what just happened" context; +14 days covers Upcoming
    /// without uploading the user's entire year.
    private let daysBack = 1
    private let daysForward = 14

    private init() {}

    // MARK: - Permission

    var hasAccess: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) { return status == .fullAccess }
        return status == .authorized
    }

    /// Call only AFTER showing your own explanation screen. The system prompt is
    /// one-shot — a denial sends the user to Settings, and almost nobody goes.
    func requestAccess() async -> Bool {
        do {
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = try await store.requestFullAccessToEvents()
            } else {
                granted = try await store.requestAccess(to: .event)
            }
            return granted
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    // MARK: - Change observation

    func startObserving(householdId: String, token: String) {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            // EventKit fires this repeatedly during a bulk edit — debounce so we
            // don't hammer the backend with a dozen full-window syncs.
            Task { @MainActor in
                self?.debounce(householdId: householdId, token: token)
            }
        }
    }

    func stopObserving() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        debounceTask?.cancel()
    }

    private func debounce(householdId: String, token: String, seconds: UInt64 = 3) {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await self?.sync(householdId: householdId, token: token)
        }
    }

    // MARK: - Sync

    @discardableResult
    func sync(householdId: String, token: String) async -> Bool {
        guard hasAccess, !isSyncing else { return false }
        isSyncing = true
        lastError = nil
        defer { isSyncing = false }

        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        guard
            let windowStart = cal.date(byAdding: .day, value: -daysBack, to: startOfToday),
            let windowEnd = cal.date(byAdding: .day, value: daysForward, to: startOfToday)
        else { return false }

        let predicate = store.predicateForEvents(withStart: windowStart, end: windowEnd, calendars: nil)
        let events = store.events(matching: predicate).compactMap { Self.encode($0) }

        // The device sends its FULL window every time, not a delta. Anything in
        // the window absent from the payload is treated as deleted — the only
        // reliable way to handle recurring-event edits and deletions without
        // tracking tombstones on device.
        let payload: [String: Any] = [
            "scopeId": householdId,
            "windowStart": Self.iso.string(from: windowStart),
            "windowEnd": Self.iso.string(from: windowEnd),
            "events": events.map { $0.dictionary }
        ]

        guard let url = URL(string: "\(baseURL)/api/calendar/sync") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }

            guard (200...299).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                lastError = "Sync failed (\(http.statusCode)): \(body.prefix(200))"
                print("[CalendarSync] \(lastError ?? "")")
                return false
            }

            lastSyncedAt = Date()
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("[CalendarSync] sent \(events.count), upserted \(json["upserted"] ?? 0), removed \(json["removed"] ?? 0)")
            }
            return true
        } catch {
            lastError = error.localizedDescription
            print("[CalendarSync] \(error.localizedDescription)")
            return false
        }
    }

    /// Settings toggle. Deletes the server-side copies — required for the App
    /// Store privacy commitment. "Stop syncing" without deleting isn't a
    /// disconnect.
    @discardableResult
    func disconnect(householdId: String, token: String) async -> Bool {
        stopObserving()
        lastSyncedAt = nil

        guard let url = URL(string: "\(baseURL)/api/calendar/disconnect?scopeId=\(householdId)")
        else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse
        else { return false }
        return (200...299).contains(http.statusCode)
    }

    // MARK: - Encoding

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let occurrenceFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private struct SyncEvent {
        let externalId: String
        let occurrenceDate: String
        let title: String
        let startUtc: String
        let endUtc: String
        let sourceTz: String
        let allDay: Bool
        let calendarName: String?

        var dictionary: [String: Any] {
            var d: [String: Any] = [
                "externalId": externalId,
                "occurrenceDate": occurrenceDate,
                "title": title,
                "startUtc": startUtc,
                "endUtc": endUtc,
                "sourceTz": sourceTz,
                "allDay": allDay
            ]
            if let calendarName { d["calendarName"] = calendarName }
            return d
        }
    }

    private static func encode(_ event: EKEvent) -> SyncEvent? {
        guard
            let id = event.eventIdentifier,
            let start = event.startDate,
            let end = event.endDate
        else { return nil }

        // CRITICAL: every occurrence of a recurring series shares one
        // eventIdentifier. Without occurrenceDate in the key, a weekly soccer
        // practice collapses into a single row and the timeline silently loses
        // eleven of its twelve entries, with no error to tell you why.
        let tz = event.timeZone ?? TimeZone.current
        occurrenceFormatter.timeZone = tz

        return SyncEvent(
            externalId: id,
            occurrenceDate: occurrenceFormatter.string(from: start),
            title: event.title ?? "Busy",
            startUtc: iso.string(from: start),
            endUtc: iso.string(from: end),
            sourceTz: tz.identifier,
            allDay: event.isAllDay,
            calendarName: event.calendar?.title
            // Deliberately omitted: notes, attendees, location, url, attachments.
        )
    }
}
PLANBHAI_EOF
echo "   wrote $DEST"
echo

echo "3. Checking it compiles standalone"
if command -v swiftc >/dev/null 2>&1; then
  swiftc -parse "$DEST" 2>&1 | head -10 && echo "   parses"
else
  echo "   swiftc not on PATH — skipping (xcodebuild will catch it)"
fi
echo

echo "4. Current calendar permission text"
grep -o 'INFOPLIST_KEY_NSCalendarsFullAccessUsageDescription = "[^"]*"' \
  PlanBhai.xcodeproj/project.pbxproj | head -1 | sed 's/^/   /'
echo
echo "   NOTE: that string describes WRITING to the calendar. This feature READS"
echo "   the calendar and uploads titles and times to your server. Apple compares"
echo "   the string against actual behaviour during review, and more importantly"
echo "   it is not what the user is agreeing to. Suggested replacement:"
echo
echo "     PlanBhai reads your calendar so your whole day appears in one place,"
echo "     and stays in sync on the web app. Only event titles and times are stored."
echo
echo "   Change it in Xcode: target PlanBhai -> Build Settings -> search"
echo "   \"Calendars Full Access\" -> edit the value."
echo

echo "=========================================="
echo "  Next: build to confirm the break is fixed"
echo "     xcodebuild -scheme PlanBhai \\"
echo "       -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -20"
echo "=========================================="

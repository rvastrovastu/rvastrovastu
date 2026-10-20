#!/usr/bin/env bash
#
# Fixes: "value of type 'DayBrief.Habits' has no member 'household'".
#
# install-habit-tap.sh wrote DayBriefView (which reads habits.household and
# constructs Habit with lastCompletedDate) but DayBriefModels.swift did not get
# the matching declarations — so the view compiled against a model that never
# gained the fields.
#
# This writes the correct models file wholesale rather than patching, since the
# patch is what went wrong.
#
# Adds:
#   Habits.household        household-wide totals, shown beside your own
#   Habit.lastCompletedDate the date that makes completion derivable
#   DayBriefService.completeHabit(name:done:token:)
#
# Usage:
#   bash ~/Downloads/fix-habit-models.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
DEST="PlanBhai/ios/PlanBhai/DayBriefModels.swift"
[ -f "$DEST" ] || { echo "ERROR: $DEST not found"; exit 1; }

echo "PlanBhai — fixing the habit models"
echo

echo "1. Before"
for k in "HouseholdSummary" "let household:" "lastCompletedDate" "func completeHabit"; do
  n=$(grep -c "$k" "$DEST" || true)
  echo "   $k: $n"
done
echo

echo "2. Writing"
cp "$DEST" "$DEST.bakmodels"
cat > "$DEST" << 'PLANBHAI_EOF'
import Foundation

// MARK: - Wire models
//
// Mirrors GET /api/dashboard/today. Every field the server may omit or null is
// optional here — `readiness` is genuinely null for a household with nothing
// plannable yet, and treating that as an error would break the empty state.

struct DayBrief: Codable {
    let localDate: String
    let tz: String
    let state: String              // "empty" | "sparse" | "rich"
    let greeting: Greeting?
    let readiness: Readiness?      // null when no domain applies
    let signals: [Signal]?
    let suggestions: [Suggestion]?
    let timeline: [TimelineRow]?
    let meal: Meal?
    let family: [FamilyRow]?
    let upcoming: [UpcomingRow]?
    let habits: Habits?
    let counts: Counts?
    let calendarSyncedAt: String?

    struct Habits: Codable {
        // Your own habits — these are what the garden shows and what you can tap.
        let total: Int?
        let completedToday: Int?
        let longestStreak: Int?
        let all: [Habit]?
        // Household-wide totals, so a shared dashboard doesn't feel solitary.
        let household: HouseholdSummary?

        struct Habit: Codable, Identifiable {
            let name: String
            let streak: Int?
            let completedToday: Bool?
            let lastCompletedDate: String?
            var id: String { name }
        }

        /// Household-wide totals, shown alongside your own so a shared
        /// dashboard doesn't feel solitary.
        struct HouseholdSummary: Codable {
            let total: Int?
            let completedToday: Int?
        }
    }

    struct Counts: Codable {
        let events: Int?
        let meals: Int?
        let choresOpen: Int?
        let choresDone: Int?
        let groceries: Int?
        let upcoming: Int?
        let notes: Int?
    }

    struct Greeting: Codable {
        let timeOfDay: String      // morning | afternoon | evening | night
        let line: String
    }

    struct Readiness: Codable {
        let score: Int
        let label: String
        let breakdown: [Domain]?

        struct Domain: Codable {
            let domain: String
            let score: Int
            let applicable: Bool
            let reason: String?
        }

        /// Lowest-scoring applicable domain — the one thing most worth surfacing.
        var weakest: Domain? {
            (breakdown ?? []).filter { $0.applicable }.min { $0.score < $1.score }
        }
    }

    struct Suggestion: Codable, Identifiable {
        let id: String
        let kind: String?
        let icon: String?
        let title: String
        let subtitle: String?
        let cta: String?
        let deeplink: String?
        let webPath: String?
        let locked: Bool?
    }

    struct Signal: Codable, Identifiable {
        let icon: String?
        let text: String
        let kind: String?
        let priority: Int?
        var id: String { (kind ?? "") + text }
    }

    struct TimelineRow: Codable, Identifiable {
        let start: String          // "HH:mm"
        let end: String?
        let title: String
        let kind: String?          // habit | event | meal | task | routine
        let source: String?
        let sourceId: String?
        let icon: String?
        let isNow: Bool?
        var id: String { start + title }
    }

    struct Meal: Codable {
        let slot: String?
        let title: String
        let haveRatio: Double?
        let missing: [String]?
    }

    struct FamilyRow: Codable, Identifiable {
        let memberId: String?
        let name: String
        let status: String?
        let state: String?         // done | pending | upcoming
        let icon: String?
        var id: String { (memberId ?? "") + name }
    }

    struct UpcomingRow: Codable, Identifiable {
        let day: String
        let date: String
        let title: String
        let icon: String?
        var id: String { date + title }
    }
}

// MARK: - Service

enum DayBriefError: LocalizedError {
    case noHousehold
    case notSignedIn
    case server(Int, String)

    var errorDescription: String? {
        switch self {
        case .noHousehold: return "No household selected yet."
        case .notSignedIn: return "You need to sign in."
        case .server(let code, let body):
            return "Couldn't load your day (\(code)). \(body)"
        }
    }
}

@MainActor
final class DayBriefService {
    static let shared = DayBriefService()

    /// Must match APIService.baseURL — it's private there, so it's repeated.
    private let baseURL = "https://planbhai.onrender.com"

    private init() {}

    func fetch(householdId: String, token: String) async throws -> DayBrief {
        // The server keys its cache on timezone, so the device reports its own
        // rather than assuming one.
        let tz = TimeZone.current.identifier
        var comps = URLComponents(string: "\(baseURL)/api/dashboard/today")!
        comps.queryItems = [
            URLQueryItem(name: "scopeId", value: householdId),
            URLQueryItem(name: "tz", value: tz)
        ]

        var request = URLRequest(url: comps.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw DayBriefError.server(0, "No response")
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw DayBriefError.server(http.statusCode, String(body.prefix(140)))
        }

        return try JSONDecoder().decode(DayBrief.self, from: data)
    }

    /// Toggles one of the caller's own habits.
    ///
    /// Streak arithmetic lives on the server so iOS and web agree: only
    /// today's completion is reversible, and un-checking tomorrow no longer
    /// removes a day that was legitimately earned.
    @discardableResult
    func completeHabit(name: String, done: Bool, token: String) async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/api/habits/complete") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "name": name,
            "done": done,
            "tz": TimeZone.current.identifier
        ])
        request.timeoutInterval = 15

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { return false }
        return (200...299).contains(http.statusCode)
    }
}
PLANBHAI_EOF
echo "   wrote $DEST"
echo

echo "3. After"
for k in "HouseholdSummary" "let household:" "lastCompletedDate" "func completeHabit"; do
  n=$(grep -c "$k" "$DEST" || true)
  if [ "$n" = "0" ]; then
    echo "   MISSING $k — reverting"
    cp "$DEST.bakmodels" "$DEST"
    exit 1
  fi
  echo "   ok   $k ($n)"
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
echo "  Revert:  cp $DEST.bakmodels $DEST"
echo "=========================================="

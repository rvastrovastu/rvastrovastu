#!/usr/bin/env bash
#
# "Add this plan" — on both platforms, through one endpoint.
#
# TWO BUGS IN THE WEB VERSION, both worth not copying to iOS:
#
#   1. RACE. It wrote the event, RE-FETCHED party_events, and assumed the last
#      item was the one it had just created. Another member saving in between
#      and this plan's menu attaches to THEIR event.
#
#   2. WRONG FIELD NAMES. Grocery items were written as { name, amount }. The
#      rest of the app — GroceryView, the pantry matcher, the meal diff — reads
#      { item, quantity }. So every grocery ever saved from a Bhai plan renders
#      BLANK and matches nothing. Silent, and shipping.
#
# THE FIX
#   POST /api/ai/bhai/save does it server-side: the event id is kept from the
#   write instead of re-read, groceries use the right field names, and items
#   already on the list are skipped — including ticked ones, because a second
#   "Milk" is worse than doing nothing.
#
#   Web switches to the endpoint. iOS gains the button it never had.
#
# EXISTING BAD DATA IS NOT REPAIRED. Any grocery rows already written as
# { name, amount } stay broken. Section 5 counts them so you know the scale.
#
# Usage:
#   bash ~/Downloads/install-bhai-save.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }

echo "PlanBhai — saving Ask BhAI plans"
echo

echo "1. Backend"
write() {
  local dest="$1"
  [ -f "$dest" ] && cp "$dest" "$dest.baksave"
  cat > "$dest"
  echo "   wrote $dest"
}
write 'backend/routes/bhaiSave.routes.js' << 'PLANBHAI_EOF'
const express = require('express');
const AppData = require('../models/AppData');
const { bustDayBrief } = require('../services/daybrief/daybrief.service');
const { randomUUID } = require('crypto');

const router = express.Router();

// >>> EDIT if your middleware is named differently.
const requireAuth = require('../middleware/requireAuth');
const requireHouseholdMember = require('../middleware/requireHouseholdMember');

/**
 * Saves an Ask BhAI plan.
 *
 * WHY THIS IS SERVER-SIDE
 *   The web client did this itself, and had two bugs worth not copying to iOS:
 *
 *   1. It wrote the event, RE-FETCHED the list, and assumed the last item was
 *      the one it just created — so if another member saved a plan in between,
 *      the menu attached to their event.
 *
 *   2. It wrote grocery items as { name, amount } when every other part of the
 *      app reads { item, quantity }. Those rows render blank in GroceryView and
 *      match nothing in the pantry diff. Silent, and shipping.
 *
 *   One endpoint means one implementation, no race (the event id is kept from
 *   the write rather than re-read), and both platforms behave identically.
 */

const newId = () => randomUUID().toUpperCase();

/** Mirrors the matcher used for the pantry diff, so "have" and "need" agree. */
function itemsMatch(a, b) {
  const x = String(a || '').toLowerCase().trim();
  const y = String(b || '').toLowerCase().trim();
  if (!x || !y) return false;
  if (x.length < 3 || y.length < 3) return x === y;
  return x.includes(y) || y.includes(x);
}

async function readList(userId, type) {
  const row = await AppData.findOne({ userId, type }).lean();
  return Array.isArray(row && row.data) ? row.data : [];
}

async function writeList(userId, type, data) {
  return AppData.findOneAndUpdate({ userId, type }, { userId, type, data }, { upsert: true });
}

/** POST /api/ai/bhai/save   { plan } */
router.post('/save', requireAuth, requireHouseholdMember, async (req, res) => {
  const plan = req.body && req.body.plan;
  if (!plan || typeof plan !== 'object') {
    return res.status(400).json({ success: false, message: 'No plan to save' });
  }

  const scopeId = String(req.scopeId);
  const hostName = req.user.name || '';
  const saved = { event: false, menu: 0, groceries: 0, groceriesSkipped: 0 };

  try {
    // ---- event ----------------------------------------------------------
    let eventId = null;
    if (plan.event && plan.event.name) {
      eventId = newId();
      const events = await readList(scopeId, 'party_events');
      events.push({
        id: eventId,
        name: plan.event.name,
        venue: plan.event.venue || '',
        dateText: plan.event.dateText || '',
        date: '',
        hostName,
        category: "I'm Hosting",
        description: plan.summary || '',
      });
      await writeList(scopeId, 'party_events', events);
      saved.event = true;
    }

    // ---- menu -----------------------------------------------------------
    // Uses the id we generated, NOT a re-read of the last event. That is the
    // race the client version had.
    if (eventId && Array.isArray(plan.menu) && plan.menu.length > 0) {
      const menu = await readList(scopeId, 'party_menu_items');
      for (const m of plan.menu.slice(0, 40)) {
        if (!m || !m.name) continue;
        menu.push({
          id: newId(),
          eventId,
          name: m.name,
          assignedTo: 'Unassigned',
          confirmed: false,
        });
        saved.menu += 1;
      }
      await writeList(scopeId, 'party_menu_items', menu);
    }

    // ---- groceries ------------------------------------------------------
    if (Array.isArray(plan.groceryList) && plan.groceryList.length > 0) {
      const groceries = await readList(scopeId, 'groceries');
      for (const g of plan.groceryList.slice(0, 60)) {
        const name = String((g && (g.item || g.name)) || '').trim();
        if (!name) continue;

        // Skip what is already on the list, ticked or not. A second "Milk"
        // because the first is checked is worse than doing nothing.
        if (groceries.some((x) => itemsMatch(x.item, name))) {
          saved.groceriesSkipped += 1;
          continue;
        }

        groceries.push({
          id: newId(),
          // `item` and `quantity` — the names the rest of the app reads. The
          // client wrote `name`/`amount`, so those rows showed blank and
          // matched nothing in the pantry diff.
          item: name,
          quantity: String((g && (g.quantity || g.amount)) || '1'),
          category: (g && g.category) || 'Other',
          estimatedPrice: null,
          checked: false,
        });
        saved.groceries += 1;
      }
      await writeList(scopeId, 'groceries', groceries);
    }

    // The brief caches grocery counts and the gap suggestion.
    await bustDayBrief(req.scopeId).catch(() => {});

    res.json({ success: true, saved });
  } catch (err) {
    console.error('[bhai/save]', err);
    res.status(500).json({ success: false, message: 'Could not save that plan' });
  }
});

module.exports = router;
PLANBHAI_EOF

node --check backend/routes/bhaiSave.routes.js || exit 1
echo "   parses"

if grep -q "bhaiSave.routes" backend/server.js; then
  echo "   already mounted"
else
  cp backend/server.js backend/server.js.baksave
  python3 - backend/server.js << 'PY_EOF'
import sys, re
p = sys.argv[1]
s = open(p).read()
m = None
for m in re.finditer(r"app\.use\(\s*['\"]/api[^\n]*\n", s): pass
if not m:
    print("   ERROR: no /api mounts found"); sys.exit(2)
s = s[:m.end()] + "app.use('/api/ai/bhai', require('./routes/bhaiSave.routes'));\n" + s[m.end():]
open(p, "w").write(s)
print("   mounted /api/ai/bhai/save")
PY_EOF
  [ $? -ne 0 ] && { cp backend/server.js.baksave backend/server.js; exit 1; }
  node --check backend/server.js && echo "   server.js parses"
fi
echo

echo "2. iOS"
D="PlanBhai/ios/PlanBhai"
write "$D/AskBhaiService.swift" << 'PLANBHAI_EOF'
import Foundation

// MARK: - Ask BhAI
//
// Calls /api/ai/bhai. The response decodes into AIBhaiPlan, which ALREADY
// EXISTS in Models.swift along with BhaiEvent, BhaiMenuItem, BhaiGroceryItem,
// BhaiBudget, BhaiTimelineItem and BhaiChecklistItem — this file deliberately
// declares no types of its own.
//
// Web has had this composer for a while; iOS only had chips that switched tabs
// under the same name.

/// Example prompts: (short label, full prompt).
///
/// Tapping fills the field rather than sending, so the ask can be edited first
/// — that is how someone learns the shape of a request that works. All event
/// and meal shaped, matching what the endpoint actually returns.
let bhaiExamples: [(String, String)] = [
    ("a dinner party", "Dinner for 8 this Saturday, vegetarian"),
    ("a birthday", "Birthday party for 20 kids next Friday"),
    ("this week's meals", "A week of quick weeknight dinners for 4"),
]

/// Does this plan contain anything worth rendering?
extension AIBhaiPlan {
    var hasContent: Bool {
        (menu?.isEmpty == false) || (groceryList?.isEmpty == false)
            || (timeline?.isEmpty == false) || (checklist?.isEmpty == false)
            || event != nil || budget != nil
    }
}

@MainActor
final class AskBhaiService {
    static let shared = AskBhaiService()
    private let baseURL = "https://planbhai.onrender.com"
    private init() {}

    func plan(prompt: String, token: String) async throws -> AIBhaiPlan {
        guard let url = URL(string: "\(baseURL)/api/ai/bhai") else {
            throw DayBriefError.server(0, "Bad URL")
        }
        var r = URLRequest(url: url)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        r.httpBody = try? JSONSerialization.data(withJSONObject: ["prompt": prompt])
        // Generation is slow; 60s is not generous enough here.
        r.timeoutInterval = 90

        let (data, response) = try await URLSession.shared.data(for: r)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 500

        guard (200...299).contains(code) else {
            // The endpoint returns { error } on failure. Surfacing it beats a
            // generic message, because it usually says what to change.
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw DayBriefError.server(code, msg ?? "Couldn't build a plan from that.")
        }

        return try JSONDecoder().decode(AIBhaiPlan.self, from: data)
    }

    /// Writes the plan into party events, menu items and groceries.
    ///
    /// Server-side deliberately: the web client re-reads the event list after
    /// writing and assumes the last row is its own, which breaks when two
    /// members save at once.
    func save(plan: AIBhaiPlan, householdId: String, token: String) async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/api/ai/bhai/save?scopeId=\(householdId)") else {
            return false
        }
        var r = URLRequest(url: url)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        r.httpBody = try JSONEncoder().encode(["plan": plan])
        r.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: r)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 500
        guard (200...299).contains(code) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
            throw DayBriefError.server(code, msg ?? "Couldn't save that plan.")
        }
        return true
    }
}
PLANBHAI_EOF
write "$D/Views/DayBriefView.swift" << 'PLANBHAI_EOF'
import SwiftUI

/// The Brief — "this app already understands my day".
///
/// Row order: hero, score, suggestions, timeline, Ask BhAI, upcoming, family,
/// meal, habit garden, achievements.
///
/// The vision's "Smart Life Categories" row was removed. It navigated to the
/// same tabs Ask BhAI already reaches, and a screen with a tab bar, a category
/// grid AND a prompt grid is three navigation systems competing for the same
/// taps. Ask BhAI won because verb phrases ("Plan dinner") read as things the
/// app does for you, which is the premise; noun tiles ("Meals") just restate
/// the tab bar.
///
/// Two honesty rules run through this file:
///   1. A section that has no data does not render. An empty shell implies the
///      app knows something it doesn't, and users catch that fast.
///   2. Nothing is invented client-side. Every number comes from the brief.
struct DayBriefView: View {
    @EnvironmentObject var appState: AppState
    var selectedTab: Binding<Int>? = nil      // lets the category row switch tabs

    @State private var brief: DayBrief?
    @State private var isLoading = true
    @State private var errorText: String?
    @State private var showBreakdown = false
    @State private var heroAppeared = false
    @State private var togglingHabit: String?
    @State private var showSchedule = false
    @State private var showCalendar = false
    @State private var bhaiPrompt = ""
    @State private var bhaiPlan: AIBhaiPlan?
    @State private var bhaiLoading = false
    @State private var bhaiError: String?
    @State private var bhaiSaving = false
    @State private var bhaiSaved = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0F0F1A"), Color(hex: "0F172A"), Color(hex: "111827")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()

            blob(PB.navy, 320, x: 160, y: -170, blur: 80, op: 0.20)
            blob(PB.teal, 250, x: -130, y: 260, blur: 65, op: 0.11)
            blob(PB.mauve, 220, x: 140, y: 620, blur: 70, op: 0.08)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    if isLoading && brief == nil {
                        ProgressView().tint(.white).padding(.top, 120)
                    } else if let errorText {
                        errorCard(errorText)
                    } else if let b = brief {
                        heroCard(b)                                   // Hero
                        if let r = b.readiness { scoreCard(r) }        // 1 — Today's Focus
                        suggestionsRow(b)                              // 2 — AI suggestions
                        if let t = b.timeline, !t.isEmpty { timelineCard(t) }   // 3
                        myDayRow(b)
                        if let u = b.upcoming, !u.isEmpty { upcomingCard(u) }   // 5
                        if let f = b.family, !f.isEmpty { familyCard(f) }       // 6
                        if let m = b.meal { mealCard(m) }              // 7
                        habitGarden(b)                                 // 8
                        achievements(b)                                // 9
                        syncFooter(b)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120)
            }
            .refreshable { await load() }
        }
        .task { await load() }
        .sheet(isPresented: $showSchedule, onDismiss: { Task { await load() } }) {
            ScheduleView().environmentObject(appState)
        }
        .sheet(isPresented: $showCalendar) {
            CalendarRangeView().environmentObject(appState)
        }
        // If the household changes — first load, or the user switches — refresh.
        .onChange(of: appState.activeHouseholdId) { _ in
            Task { await load() }
        }
    }

    // MARK: - Hero

    private func heroCard(_ b: DayBrief) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    // Day and date first. It anchors everything below it in
                    // "today" — without it a dashboard could be showing any day.
                    Text(dayAndDate)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PB.soft)
                        .tracking(0.9)

                    HStack(spacing: 7) {
                        Text(salutation)
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text(timeEmoji).font(.system(size: 20))
                    }

                    Text(b.greeting?.line ?? "Here's your day.")
                        .font(.system(size: 13))
                        .foregroundStyle(PB.mid)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 1)

                    if !countsLine(b).isEmpty {
                        Text(countsLine(b))
                            .font(.system(size: 12))
                            .foregroundStyle(PB.soft)
                            .padding(.top, 3)
                    }
                }
                Spacer(minLength: 8)

                // Same treatment as PageHeader and the old dashboard: 44pt,
                // circle-clipped, gradient stroke. Sits in the hero rather than
                // above it — a PageHeader here would stack a third heading over
                // the date and greeting.
                //
                // The old version carried an ellipsis badge opening All
                // Features. That sheet lives in DashboardView, so this is
                // non-interactive for now; a logo that looks tappable and
                // isn't is worse than one that plainly isn't.
                // The mascot has moved down beside the Ask BhAI input, where he
                // reads as the person you're asking rather than branding in the
                // corner. Only the calendar button stays up here — web reaches
                // its calendar from the nav bar, so iOS needs this entry point
                // and the two heroes cannot be pixel-identical.
                VStack(spacing: 10) {
                    Button { showCalendar = true } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(PB.mauve)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(PB.mauve.opacity(0.14)))
                            .overlay(Circle().stroke(PB.mauve.opacity(0.30), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            // The checkmark list is gone. countsLine above says the same thing
            // in one scannable row, and having both meant the hero stated the
            // day's contents twice — the same duplication web had.
            Rectangle()
                .fill(LinearGradient(colors: [PB.navy.opacity(0.5), PB.teal.opacity(0.25), .clear],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)

            // Ask BhAI lives INSIDE the hero, as on web — it is the thing you
            // do from here, not a separate card further down the page.
            askBhaiRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(colors: [PB.navy.opacity(0.22), PB.teal.opacity(0.10)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(PB.glassBorder, lineWidth: 1))
        .padding(.top, 14)
        .onAppear { heroAppeared = true }
    }


    // MARK: - 1. Today's Focus

    private func scoreCard(_ r: DayBrief.Readiness) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Today's Focus", icon: "target", color: PB.forest)

            HStack(spacing: 20) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.07), lineWidth: 11)
                    Circle()
                        .trim(from: 0, to: CGFloat(max(0, min(100, r.score))) / 100)
                        .stroke(AngularGradient(colors: [ringColor(r.score),
                                                         ringColor(r.score).opacity(0.5)],
                                                center: .center),
                                style: StrokeStyle(lineWidth: 11, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.9), value: r.score)
                    VStack(spacing: -2) {
                        Text("\(r.score)")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("%").font(.system(size: 11, weight: .bold)).foregroundStyle(PB.soft)
                    }
                }
                .frame(width: 94, height: 94)

                VStack(alignment: .leading, spacing: 7) {
                    Text(r.label)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    // A score with no explanation is anxiety with a percentage
                    // attached — always pair it with the weakest domain.
                    if let w = r.weakest, let reason = w.reason, !reason.isEmpty {
                        Text(reason)
                            .font(.system(size: 12))
                            .foregroundStyle(PB.soft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }

            if let breakdown = r.breakdown, !breakdown.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) { showBreakdown.toggle() }
                } label: {
                    HStack(spacing: 5) {
                        Text(showBreakdown ? "Hide detail" : "Why this score?")
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: showBreakdown ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(PB.sky)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 14)
                }
                .buttonStyle(.plain)

                if showBreakdown {
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(breakdown.filter { $0.applicable }, id: \.domain) { d in
                            HStack(alignment: .top, spacing: 10) {
                                Text(d.domain.capitalized)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(PB.mid)
                                    .frame(width: 72, alignment: .leading)
                                Text("\(d.score)")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(ringColor(d.score))
                                    .frame(width: 26, alignment: .trailing)
                                Text(d.reason ?? "")
                                    .font(.system(size: 11))
                                    .foregroundStyle(PB.soft)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                        }
                        if !notCounted(breakdown).isEmpty {
                            Text("Not counted: \(notCounted(breakdown))")
                                .font(.system(size: 10))
                                .foregroundStyle(PB.muted)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.top, 12)
                }
            }
        }
        .padding(18)
        .glassCard()
    }

    // MARK: - 2. AI suggestions

    @ViewBuilder
    private func suggestionsRow(_ b: DayBrief) -> some View {
        // Never an empty shell — the card only exists when there is something
        // real to suggest. "No suggestions right now" is a box that costs
        // attention and returns nothing.
        if let items = b.suggestions, !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("Bhai suggests", icon: "lightbulb.fill", color: PB.amber)

                ForEach(items) { s in
                    Button {
                        open(s)
                    } label: {
                        HStack(spacing: 12) {
                            Text(s.icon ?? "💡").font(.system(size: 20))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(s.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                if let sub = s.subtitle, !sub.isEmpty {
                                    Text(sub)
                                        .font(.system(size: 11))
                                        .foregroundStyle(PB.soft)
                                }
                            }

                            Spacer(minLength: 6)

                            if s.locked == true {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(PB.muted)
                            } else if let cta = s.cta {
                                Text(cta)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(PB.amber)
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(PB.amber.opacity(0.14)))
                            }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(PB.glass))
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .stroke(PB.glassBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .glassCard()
        }
    }

    /// Routes a suggestion to the right tab. Deliberately maps known
    /// destinations rather than opening the deeplink URL — a suggestion that
    /// goes nowhere is worse than one that was never shown.
    private func open(_ s: DayBrief.Suggestion) {
        guard s.locked != true, let path = s.deeplink else { return }
        let tab: Int?
        switch true {
        case path.contains("meals"):     tab = 1
        case path.contains("habits"):    tab = 2
        case path.contains("party"):     tab = 3
        case path.contains("household"), path.contains("grocery"): tab = 4
        case path.contains("planner"):   tab = 0
        default:                         tab = nil
        }
        if let tab { selectedTab?.wrappedValue = tab }
    }

    // MARK: - 3. Timeline

    private func timelineCard(_ rows: [DayBrief.TimelineRow]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Today's Timeline", icon: "clock.fill", color: PB.sky)

            scrollSection(maxHeight: 220) {
              VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                HStack(alignment: .top, spacing: 12) {
                    Text(displayTime(row.start))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(row.isNow == true ? PB.teal : PB.muted)
                        .frame(width: 52, alignment: .leading)

                    VStack(spacing: 0) {
                        ZStack {
                            if row.isNow == true {
                                Circle().fill(PB.teal.opacity(0.25)).frame(width: 16, height: 16)
                            }
                            Circle()
                                .fill(row.isNow == true ? PB.teal : kindColor(row.kind))
                                .frame(width: 8, height: 8)
                        }
                        .frame(width: 16, height: 16)
                        if idx < rows.count - 1 {
                            Rectangle().fill(Color.white.opacity(0.09))
                                .frame(width: 1.5).frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: 16)

                    HStack(spacing: 7) {
                        if let icon = row.icon { Text(icon).font(.system(size: 13)) }
                        Text(row.title)
                            .font(.system(size: 14, weight: row.isNow == true ? .bold : .medium))
                            .foregroundStyle(row.isNow == true ? .white : PB.mid)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.bottom, 18)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                }
              }
            }
        }
        .padding(18)
        .glassCard()
    }

    // MARK: - My Day
    //
    // Sits under the timeline because that is what it edits. Presented as a
    // sheet rather than pushed: editing a schedule is "step aside, do a thing,
    // come back", and a sheet cannot strand you three screens from home.
    private func myDayRow(_ b: DayBrief) -> some View {
        Button { showSchedule = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "calendar.day.timeline.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PB.forest)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(PB.forest.opacity(0.14)))

                VStack(alignment: .leading, spacing: 2) {
                    Text("My Day")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(scheduleSummary(b))
                        .font(.system(size: 11))
                        .foregroundStyle(PB.soft)
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11)).foregroundStyle(PB.muted)
            }
            .padding(14)
            .glassCard()
        }
        .buttonStyle(.plain)
    }

    /// Counts only schedule rows, so the label describes what tapping edits.
    private func scheduleSummary(_ b: DayBrief) -> String {
        let n = (b.timeline ?? []).filter { $0.source == "schedule" }.count
        if n == 0 { return "Set up the shape of your day" }
        return "\(n) block\(n == 1 ? "" : "s") today · edit"
    }

    // MARK: - 4. Ask BhAI
    //
    // A real composer calling /api/ai/bhai, matching web. Previously this was a
    // grid of chips that only switched tabs — the label promised something the
    // card never did.
    private var askBhaiRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 6) {
                    Image("PlanBhaiLogo")
                        .resizable().scaledToFill()
                        .frame(width: 46, height: 46)
                        .clipShape(Circle())
                    Text("Ask BhAI.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PB.mid)
                        .fixedSize()
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        TextField("", text: $bhaiPrompt,
                                  prompt: Text("Dinner for 8 this Saturday, vegetarian")
                                    .foregroundStyle(PB.muted))
                            .font(.system(size: 13))
                            .foregroundStyle(.white)
                            .submitLabel(.go)
                            .onSubmit { Task { await askBhai() } }
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(PB.glass))
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .stroke(PB.glassBorder, lineWidth: 1))

                        Button { Task { await askBhai() } } label: {
                            if bhaiLoading {
                                ProgressView().tint(.white).frame(width: 22)
                            } else {
                                Text("Plan it")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 10).fill(PB.rose))
                        .disabled(bhaiLoading || bhaiPrompt.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity(bhaiPrompt.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                    }

                    // Tapping fills the field rather than sending, so the ask can
                    // be edited first — that is how the shape of a good request
                    // gets learned.
                    if bhaiPlan == nil {
                        HStack(spacing: 4) {
                            Text("Try").font(.system(size: 12)).foregroundStyle(PB.soft)
                            ForEach(Array(bhaiExamples.enumerated()), id: \.offset) { i, ex in
                                if i > 0 {
                                    Text("·").font(.system(size: 12)).foregroundStyle(PB.muted)
                                }
                                Button { bhaiPrompt = ex.1 } label: {
                                    Text(ex.0)
                                        .font(.system(size: 12))
                                        .foregroundStyle(PB.forest)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            if let bhaiError {
                Text(bhaiError)
                    .font(.system(size: 12))
                    .foregroundStyle(PB.error)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let plan = bhaiPlan, plan.hasContent {
                bhaiResult(plan)
            }
        }
    }

    @ViewBuilder
    private func bhaiResult(_ p: AIBhaiPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let summary = p.summary {
                Text(summary)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let e = p.event, let name = e.name {
                planSection("Event") {
                    Text([name, e.dateText, e.venue].compactMap { $0 }.filter { !$0.isEmpty }
                            .joined(separator: " · "))
                        .font(.system(size: 12)).foregroundStyle(PB.mid)
                }
            }

            if let menu = p.menu, !menu.isEmpty {
                planSection("Menu") {
                    ForEach(menu) { m in
                        Text("• \(m.name ?? "")").font(.system(size: 12)).foregroundStyle(PB.mid)
                    }
                }
            }

            if let g = p.groceryList, !g.isEmpty {
                planSection("Grocery list") {
                    ForEach(g) { item in
                        Text("• \(item.item ?? "")\(item.quantity.map { " (\($0))" } ?? "")")
                            .font(.system(size: 12)).foregroundStyle(PB.mid)
                    }
                }
            }

            if let b = p.budget, let total = b.estimatedTotal {
                planSection("Budget") {
                    Text("Estimated $\(Int(total))\(b.notes.map { " — \($0)" } ?? "")")
                        .font(.system(size: 12)).foregroundStyle(PB.mid)
                }
            }

            if let t = p.timeline, !t.isEmpty {
                planSection("Timeline") {
                    ForEach(t) { row in
                        Text("\(row.time ?? "") — \(row.task ?? "")")
                            .font(.system(size: 12)).foregroundStyle(PB.mid)
                    }
                }
            }

            if let c = p.checklist, !c.isEmpty {
                planSection("Checklist") {
                    ForEach(c) { row in
                        Text("☐ \(row.task ?? "")").font(.system(size: 12)).foregroundStyle(PB.mid)
                    }
                }
            }

            HStack(spacing: 12) {
                if bhaiSaved {
                    Text("✓ Added to your plan")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PB.forest)
                } else {
                    Button { Task { await saveBhaiPlan() } } label: {
                        Text(bhaiSaving ? "Adding…" : "Add this plan")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Capsule().fill(PB.forest))
                    }
                    .buttonStyle(.plain)
                    .disabled(bhaiSaving)
                }

                Button {
                    bhaiPlan = nil
                    bhaiPrompt = ""
                    bhaiSaved = false
                } label: {
                    Text("Clear")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PB.soft)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
            .padding(.top, 4)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(PB.glassBorder, lineWidth: 1))
    }

    @ViewBuilder
    private func planSection<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(PB.soft).tracking(0.8)
            content()
        }
    }

    /// Saves the plan through the server, which writes the event, its menu and
    /// the grocery list in one place. Doing it client-side — as web does —
    /// re-reads the event list and assumes the last item is yours, so a member
    /// saving at the same moment gets your menu.
    private func saveBhaiPlan() async {
        guard let plan = bhaiPlan, !bhaiSaving,
              let token = appState.authToken,
              let household = appState.activeHouseholdId else { return }

        bhaiSaving = true
        bhaiError = nil
        do {
            let ok = try await AskBhaiService.shared.save(
                plan: plan, householdId: household, token: token)
            bhaiSaved = ok
            if ok { await load() }   // grocery counts and the gap suggestion change
        } catch let DayBriefError.server(_, msg) {
            bhaiError = msg
        } catch {
            bhaiError = "Couldn't save that plan."
        }
        bhaiSaving = false
    }

    private func askBhai() async {
        let text = bhaiPrompt.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !bhaiLoading, let token = appState.authToken else { return }

        bhaiLoading = true
        bhaiError = nil
        bhaiPlan = nil
        bhaiSaved = false
        do {
            bhaiPlan = try await AskBhaiService.shared.plan(prompt: text, token: token)
        } catch let DayBriefError.server(_, msg) {
            bhaiError = msg
        } catch {
            bhaiError = "Couldn't reach BhAI. Check your connection and try again."
        }
        bhaiLoading = false
    }

    // MARK: - 5. Upcoming

    private func upcomingCard(_ rows: [DayBrief.UpcomingRow]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Upcoming", icon: "calendar", color: PB.navyLight)
            scrollSection(maxHeight: 108) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(rows) { r in
                        HStack(spacing: 12) {
                            Text(r.day)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(PB.soft)
                                .frame(width: 76, alignment: .leading)
                            if let icon = r.icon { Text(icon).font(.system(size: 13)) }
                            Text(r.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(PB.mid)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard()
    }

    // MARK: - 6. Family snapshot

    private func familyCard(_ rows: [DayBrief.FamilyRow]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Family", icon: "person.3.fill", color: PB.mauve)
            scrollSection(maxHeight: 156) {
              VStack(alignment: .leading, spacing: 12) {
                ForEach(rows) { m in
                HStack(spacing: 12) {
                    Text(String(m.name.prefix(1)).uppercased())
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(memberColor(m.name).opacity(0.30)))
                        .overlay(Circle().stroke(memberColor(m.name).opacity(0.55), lineWidth: 1))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(m.status ?? "")
                            .font(.system(size: 11))
                            .foregroundStyle(PB.soft)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: m.state == "done" ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 15))
                        .foregroundStyle(m.state == "done" ? PB.forest : PB.muted)
                }
                }
              }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard()
    }

    private func memberColor(_ name: String) -> Color {
        PB.memberColors[abs(name.hashValue) % PB.memberColors.count]
    }

    // MARK: - 7. Meal

    private func mealCard(_ meal: DayBrief.Meal) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionLabel("Today's \(meal.slot?.capitalized ?? "Dinner")",
                         icon: "fork.knife", color: PB.amber)

            Text(meal.title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            if let ratio = meal.haveRatio {
                HStack(spacing: 9) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08))
                            Capsule().fill(PB.forest)
                                .frame(width: geo.size.width * CGFloat(max(0, min(1, ratio))))
                        }
                    }
                    .frame(height: 6)
                    Text("\(Int(ratio * 100))% available")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PB.forest)
                }
            }

            if let missing = meal.missing, !missing.isEmpty {
                Text("Need: \(missing.joined(separator: ", "))")
                    .font(.system(size: 12))
                    .foregroundStyle(PB.warning)
            }
            // When haveRatio is nil the pantry is empty, so coverage is genuinely
            // unknown. Saying nothing beats implying everything's on hand.
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard()
    }

    // MARK: - 8. Habit garden

    @ViewBuilder
    private func habitGarden(_ b: DayBrief) -> some View {
        if let h = b.habits, let total = h.total, total > 0 {
            VStack(alignment: .leading, spacing: 14) {
                sectionLabel("Habit Garden", icon: "leaf.fill", color: PB.forest)

                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(h.all ?? []) { habit in
                          Button {
                              Task { await toggleHabit(habit) }
                          } label: {
                            VStack(spacing: 4) {
                                Text(habit.completedToday == true ? "🌸" : "🌱")
                                    .font(.system(size: 26))
                                    .opacity(habit.completedToday == true ? 1 : 0.45)
                                // The habit name matters more than a streak of 0 —
                                // a row of bare zeros reads as failure rather than
                                // as "not yet today".
                                Text(habit.name)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(habit.completedToday == true ? PB.mid : PB.muted)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .frame(width: 58)
                                if let st = habit.streak, st > 0 {
                                    Text("\(st)d")
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .foregroundStyle(PB.forest)
                                }
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 4)
                            .contentShape(Rectangle())
                          }
                          .buttonStyle(.plain)
                          .disabled(togglingHabit != nil)
                          .opacity(togglingHabit == habit.name ? 0.5 : 1)
                        }
                    }
                    .padding(.bottom, 4)
                }

                HStack(spacing: 5) {
                    Text("\(h.completedToday ?? 0) of \(total) blooming today")
                        .font(.system(size: 12))
                        .foregroundStyle(PB.soft)
                    if let hh = h.household, let ht = hh.total, ht > total {
                        Text("· household \(hh.completedToday ?? 0)/\(ht)")
                            .font(.system(size: 12))
                            .foregroundStyle(PB.muted)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .glassCard()
        }
    }

    // MARK: - 9. Achievements

    @ViewBuilder
    private func achievements(_ b: DayBrief) -> some View {
        // Only badges backed by real data. A trophy case full of things the user
        // hasn't done is the opposite of motivating.
        if !earned(b).isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Achievements", icon: "trophy.fill", color: PB.amber)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(earned(b), id: \.title) { a in
                            VStack(spacing: 6) {
                                Text(a.emoji).font(.system(size: 24))
                                Text(a.title)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(PB.mid)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(width: 84, height: 76)
                            .background(RoundedRectangle(cornerRadius: 14).fill(PB.amber.opacity(0.10)))
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .stroke(PB.amber.opacity(0.25), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .glassCard()
        }
    }

    private func earned(_ b: DayBrief) -> [(emoji: String, title: String)] {
        var out: [(emoji: String, title: String)] = []
        if let streak = b.habits?.longestStreak, streak >= 3 {
            out.append(("🔥", "\(streak) day streak"))
        }
        if let h = b.habits, let t = h.total, t > 0, h.completedToday == t {
            out.append(("💪", "All habits done"))
        }
        if let done = b.counts?.choresDone, done > 0 {
            out.append(("🏆", "\(done) chores done"))
        }
        if let r = b.readiness, r.score >= 90 {
            out.append(("✨", "Day under control"))
        }
        return out
    }

    // MARK: - Footer / states

    @ViewBuilder
    private func syncFooter(_ b: DayBrief) -> some View {
        if let synced = b.calendarSyncedAt {
            Text("Calendar synced \(relativeSync(synced))")
                .font(.system(size: 10))
                .foregroundStyle(PB.muted)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func errorCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Couldn't load your day")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(PB.soft)
                .fixedSize(horizontal: false, vertical: true)
            Button { Task { await load() } } label: {
                Text("Try again")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PB.sky)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard()
        .padding(.top, 60)
    }

    // MARK: - Helpers

    private var salutation: String {
        let part = brief?.greeting?.timeOfDay ?? currentTimeOfDay
        let name = appState.currentUser?.name
            ?? UserDefaults.standard.string(forKey: "userName") ?? ""
        let base = "Good \(part.capitalized)"
        return name.isEmpty ? base : "\(base), \(name)"
    }

    /// One scannable line, matching web. A stacked checklist competed with the
    /// timeline below it, which is also a list.
    private func countsLine(_ b: DayBrief) -> String {
        var parts: [String] = []
        if let c = b.counts {
            if let e = c.events, e > 0 { parts.append("\(e) event\(e == 1 ? "" : "s")") }
            if let m = c.meals, m > 0 { parts.append("\(m) meals") }
        }
        if let h = b.habits, let total = h.total, total > 0 {
            parts.append("\(h.completedToday ?? 0) of \(total) habits")
        }
        if let c = b.counts, let ch = c.choresOpen, ch > 0 {
            parts.append("\(ch) chore\(ch == 1 ? "" : "s")")
        }
        return parts.joined(separator: " · ")
    }

    /// "FRIDAY, JULY 31" — taken from the brief's localDate, not the device
    /// clock. Those disagree around midnight and while travelling, and showing
    /// a date that doesn't match the data underneath it is worse than showing none.
    private var dayAndDate: String {
        let iso = DateFormatter()
        iso.dateFormat = "yyyy-MM-dd"
        iso.locale = Locale(identifier: "en_US_POSIX")
        iso.timeZone = TimeZone(identifier: brief?.tz ?? TimeZone.current.identifier)

        let date = brief.flatMap { iso.date(from: $0.localDate) } ?? Date()

        let out = DateFormatter()
        out.dateFormat = "EEEE, MMMM d"
        out.timeZone = iso.timeZone
        return out.string(from: date).uppercased()
    }

    private var timeEmoji: String {
        switch brief?.greeting?.timeOfDay ?? currentTimeOfDay {
        case "morning":   return "☀️"
        case "afternoon": return "🌤"
        case "evening":   return "🌆"
        default:          return "🌙"
        }
    }

    private var currentTimeOfDay: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case ..<12: return "morning"
        case ..<17: return "afternoon"
        case ..<21: return "evening"
        default:    return "night"
        }
    }

    /// "19:00" -> "7 PM". The server sends 24h; people read 12h.
    private func displayTime(_ hhmm: String) -> String {
        let parts = hhmm.split(separator: ":")
        guard let h = Int(parts.first ?? "") else { return hhmm }
        let m = parts.count > 1 ? String(parts[1]) : "00"
        let suffix = h < 12 ? "AM" : "PM"
        let h12 = h % 12 == 0 ? 12 : h % 12
        return m == "00" ? "\(h12) \(suffix)" : "\(h12):\(m) \(suffix)"
    }

    private func relativeSync(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let date else { return "recently" }
        let mins = Int(Date().timeIntervalSince(date) / 60)
        if mins < 1 { return "just now" }
        if mins < 60 { return "\(mins)m ago" }
        return "\(mins / 60)h ago"
    }

    private func notCounted(_ b: [DayBrief.Readiness.Domain]) -> String {
        b.filter { !$0.applicable }.map { $0.domain }.joined(separator: ", ")
    }

    private func ringColor(_ score: Int) -> Color {
        switch score {
        case 80...:   return PB.success
        case 60..<80: return PB.sky
        case 40..<60: return PB.warning
        default:      return PB.error
        }
    }

    private func kindColor(_ kind: String?) -> Color {
        switch kind {
        case "meal":  return PB.amber
        case "habit": return PB.forest
        case "event": return PB.navyLight
        case "task":  return PB.mauve
        default:      return PB.soft
        }
    }

    /// Caps a section at roughly three rows and scrolls the rest.
    ///
    /// Indicators stay visible even when everything fits — otherwise a section
    /// with exactly four items looks complete at three, and the user never
    /// learns there's more.
    private func scrollSection<C: View>(maxHeight: CGFloat, @ViewBuilder _ content: () -> C) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            content()
        }
        .frame(maxHeight: maxHeight)
    }

    private func sectionLabel(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(PB.soft)
                .tracking(0.9)
        }
        .padding(.bottom, 14)
    }

    private func blob(_ c: Color, _ s: CGFloat, x: CGFloat, y: CGFloat, blur: CGFloat, op: Double) -> some View {
        Circle().fill(c.opacity(op)).frame(width: s, height: s)
            .offset(x: x, y: y).blur(radius: blur).allowsHitTesting(false)
    }

    /// Toggles one of your own habits.
    ///
    /// Optimistic — the flower changes immediately and reverts on failure. A tap
    /// that appears to do nothing for 300ms feels broken. The streak arithmetic
    /// is the server's, so iOS and web can't drift apart on what a streak means.
    private func toggleHabit(_ habit: DayBrief.Habits.Habit) async {
        guard togglingHabit == nil, let token = appState.authToken else { return }
        let next = !(habit.completedToday ?? false)
        togglingHabit = habit.name

        applyHabit(named: habit.name, completed: next,
                   streak: max((habit.streak ?? 0) + (next ? 1 : -1), 0))

        do {
            let ok = try await DayBriefService.shared.completeHabit(
                name: habit.name, done: next, token: token)
            if !ok { throw DayBriefError.server(0, "rejected") }
        } catch {
            // Put it back rather than leaving a flower that lies.
            applyHabit(named: habit.name,
                       completed: habit.completedToday ?? false,
                       streak: habit.streak ?? 0)
        }
        togglingHabit = nil
    }

    private func applyHabit(named name: String, completed: Bool, streak: Int) {
        guard let b = brief, let h = b.habits, let all = h.all else { return }
        let updated = all.map { item -> DayBrief.Habits.Habit in
            guard item.name == name else { return item }
            return .init(name: item.name, streak: streak,
                         completedToday: completed,
                         lastCompletedDate: item.lastCompletedDate)
        }
        brief = DayBrief(
            localDate: b.localDate, tz: b.tz, state: b.state, greeting: b.greeting,
            readiness: b.readiness, signals: b.signals, suggestions: b.suggestions,
            timeline: b.timeline, meal: b.meal, family: b.family, upcoming: b.upcoming,
            habits: .init(total: h.total,
                          completedToday: updated.filter { $0.completedToday == true }.count,
                          longestStreak: h.longestStreak, all: updated,
                          household: h.household),
            counts: b.counts, calendarSyncedAt: b.calendarSyncedAt)
    }

    // MARK: - Load

    private func load() async {
        guard let token = appState.authToken else {
            errorText = "You need to sign in."; isLoading = false; return
        }

        // RootView sets activeHouseholdId inside fetchMyHouseholds(), which runs
        // in its own Task. This view's .task fires when it appears — concurrently
        // with that chain, not after it. Checking once loses the race whenever
        // the households call is slow, which showed up as an intermittent
        // "No household selected yet." Wait briefly instead of guessing.
        var household = appState.activeHouseholdId
        var waited = 0
        while household == nil && waited < 6000 {
            try? await Task.sleep(nanoseconds: 200_000_000)
            waited += 200
            household = appState.activeHouseholdId
        }

        guard let household else {
            errorText = "No household selected yet. Pull down to retry."
            isLoading = false
            return
        }
        isLoading = true
        errorText = nil
        do {
            brief = try await DayBriefService.shared.fetch(householdId: household, token: token)
        } catch {
            errorText = error.localizedDescription
        }
        isLoading = false
    }
}

private extension View {
    func glassCard() -> some View {
        self
            .background(RoundedRectangle(cornerRadius: 20).fill(PB.glass))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(PB.glassBorder, lineWidth: 1))
    }
}
PLANBHAI_EOF

grep -q "func save(plan:" "$D/AskBhaiService.swift" && echo "   ok   save method"
grep -q "Add this plan" "$D/Views/DayBriefView.swift" && echo "   ok   save button"
echo

echo "3. Web"
W=web/src/pages/Dashboard.jsx
cp "$W" "$W.baksave"
cat > /tmp/pb_websave.py << 'PLANBHAI_EOF'
import sys
path = sys.argv[1]
s = open(path).read()

if 'saveBhaiPlan(' in s:
    print("   already using the endpoint"); sys.exit(3)

start = s.find("  async function handleSaveBhaiPlan() {")
if start == -1:
    print("   ERROR: handleSaveBhaiPlan not found"); sys.exit(2)
end = s.find("\n  const hour = new Date().getHours();", start)
if end == -1:
    print("   ERROR: could not bound the function"); sys.exit(2)

replacement = '''  /**
   * Saves through the server rather than writing AppData directly.
   *
   * The previous version had two bugs. It wrote the event, re-fetched the list,
   * and assumed the LAST item was its own — so a member saving at the same
   * moment got this menu attached to their event. And it wrote grocery items as
   * { name, amount } when the rest of the app reads { item, quantity }, so
   * those rows rendered blank and matched nothing in the pantry diff.
   *
   * One endpoint means one implementation and identical behaviour on iOS.
   */
  async function handleSaveBhaiPlan() {
    if (!bhaiPlan || !scopeId) return;
    setBhaiSaving(true);
    try {
      await api.saveBhaiPlan(scopeId, bhaiPlan);
      setBhaiSaved(true);
    } catch (err) {
      setBhaiError(err.message);
    } finally {
      setBhaiSaving(false);
    }
  }
'''

s = s[:start] + replacement + s[end:]
open(path, "w").write(s)
print("   web now calls the endpoint")
PLANBHAI_EOF
python3 /tmp/pb_websave.py "$W"
RC=$?
rm -f /tmp/pb_websave.py
if [ "$RC" != "0" ] && [ "$RC" != "3" ]; then
  cp "$W.baksave" "$W"; echo "   reverted"; exit 1
fi

if grep -q "saveBhaiPlan:" web/src/api.js; then
  echo "   api method already present"
else
  cp web/src/api.js web/src/api.js.baksave
  python3 - web/src/api.js << 'PY_EOF'
import sys
p = sys.argv[1]
s = open(p).read()
anchor = "  // ---- Auth ----"
if anchor not in s:
    print("   ERROR: Auth section not found"); sys.exit(2)
add = """  // ---- Ask BhAI ----
  saveBhaiPlan: (scopeId, plan) =>
    request(`/api/ai/bhai/save?scopeId=${scopeId}`, { method: 'POST', auth: true, body: { plan } }),

"""
s = s.replace(anchor, add + anchor, 1)
open(p, "w").write(s)
print("   added api.saveBhaiPlan")
PY_EOF
  [ $? -ne 0 ] && { cp web/src/api.js.baksave web/src/api.js; exit 1; }
fi
echo

echo "4. Builds"
SIM=$(xcodebuild -scheme PlanBhai -showdestinations 2>/dev/null \
  | grep -oE "name:iPhone [^}]*" | sed 's/name://' | sed 's/ *$//' | head -1)
[ -z "$SIM" ] && SIM="iPhone 17"
xcodebuild -scheme PlanBhai -destination "platform=iOS Simulator,name=$SIM" build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head -12
(cd web && npm run build 2>&1 | grep -E "ERROR|error during|✓ built" | head -4)
echo

echo "5. Existing damage"
cd backend
cat > ./.pb_bad.js << 'BAD_EOF'
require("dotenv").config();
const m = require("mongoose");
(async () => {
  await m.connect(process.env.MONGODB_URI);
  const A = require("./models/AppData");
  let bad = 0, total = 0;
  for (const r of await A.find({ type: "groceries" }).lean()) {
    for (const g of r.data || []) {
      total += 1;
      if (!g.item && g.name) bad += 1;
    }
  }
  console.log("   grocery rows: " + total + ", written with the wrong field names: " + bad);
  if (bad) console.log("   those render blank — say the word and I will write a repair script");
  await m.disconnect();
})().catch(e => { console.error("   " + e.message); process.exit(0); });
BAD_EOF
node ./.pb_bad.js
rm -f ./.pb_bad.js
cd ..
echo

echo "=========================================="
echo "  Deploy BOTH — the endpoint is new:"
echo "     git add -A && git commit -m 'Save Ask BhAI plans server-side' && git push"
echo "     (Render: Manual Deploy)   then   cd web && vercel --prod"
echo "=========================================="

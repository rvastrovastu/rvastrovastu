// Today's Panchang home-screen widget.
//
// Copy this file's contents over the TodayWidget.swift that Xcode creates
// for the "TodayWidget" Widget Extension target (see SETUP below or the
// project notes). The app writes a week of days, already in the user's
// language, to the shared App Group; the widget shows each day at its
// midnight, so it stays right for a week without opening the app.

import SwiftUI
import WidgetKit

private let appGroup = "group.com.rvastrovastu.rvAstroVastu"

struct DayEntry: TimelineEntry {
    let date: Date
    let title: String
    let detail: String
    let rahu: String
    let rashifal: String?
}

private struct DayData: Decodable {
    let date: String
    let title: String
    let detail: String
    let rahu: String
    let rashifal: String?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> DayEntry {
        DayEntry(
            date: Date(),
            title: "Shukla Ekadashi",
            detail: "Shatabhisha",
            rahu: "Rahu Kaal 1:30 PM – 2:55 PM",
            rashifal: "Leo ★★★★☆"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) {
        completion(entries().first ?? (context.isPreview ? placeholder(in: context) : emptyEntry()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
        let list = entries()
        completion(Timeline(entries: list.isEmpty ? [emptyEntry()] : list, policy: .atEnd))
    }

    /// Today and the days after it, each starting at its local midnight.
    private func entries() -> [DayEntry] {
        let prefs = UserDefaults(suiteName: appGroup)
        guard
            let json = prefs?.string(forKey: "days"),
            let data = json.data(using: .utf8),
            let days = try? JSONDecoder().decode([DayData].self, from: data)
        else { return [] }

        let label = prefs?.string(forKey: "rahuLabel") ?? "Rahu Kaal"
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        let today = Calendar.current.startOfDay(for: Date())

        return days.compactMap { day -> DayEntry? in
            guard let date = formatter.date(from: day.date), date >= today else { return nil }
            let stars = day.rashifal?.isEmpty == false ? day.rashifal : nil
            return DayEntry(
                date: date,
                title: day.title,
                detail: day.detail,
                rahu: "\(label) \(day.rahu)",
                rashifal: stars
            )
        }
    }

    private func emptyEntry() -> DayEntry {
        let text = UserDefaults(suiteName: appGroup)?.string(forKey: "emptyText")
            ?? "Open RV Astro Vastu to load today's Panchang."
        return DayEntry(date: Date(), title: text, detail: "", rahu: "", rashifal: nil)
    }
}

private let background = Color(red: 13 / 255, green: 16 / 255, blue: 51 / 255)
private let gold = Color(red: 240 / 255, green: 180 / 255, blue: 60 / 255)
private let goldLight = Color(red: 247 / 255, green: 207 / 255, blue: 120 / 255)
private let ink = Color(red: 244 / 255, green: 239 / 255, blue: 226 / 255)
private let quiet = Color(red: 180 / 255, green: 177 / 255, blue: 211 / 255)

struct TodayWidgetView: View {
    var entry: DayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.title)
                .font(.headline)
                .foregroundColor(gold)
                .lineLimit(2)
            if !entry.detail.isEmpty {
                Text(entry.detail)
                    .font(.subheadline)
                    .foregroundColor(ink)
                    .lineLimit(1)
            }
            Spacer(minLength: 2)
            if !entry.rahu.isEmpty {
                Text(entry.rahu)
                    .font(.caption)
                    .foregroundColor(quiet)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            if let rashifal = entry.rashifal {
                Text(rashifal)
                    .font(.caption)
                    .foregroundColor(goldLight)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetBackground(background)
    }
}

private extension View {
    @ViewBuilder
    func widgetBackground(_ color: Color) -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(color, for: .widget)
        } else {
            padding().background(color)
        }
    }
}

struct TodayWidget: Widget {
    let kind = "TodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's Panchang")
        .description("Tithi, festival, Rahu Kaal and your Rashifal for today.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

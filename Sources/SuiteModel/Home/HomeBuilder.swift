// HomeBuilder.swift: the live HomeBuilding (UC-16, HM-1a), pure. FakeHome's
// rule (tiles in the chosen order, filtered cards with their Missing state,
// the empty or no-match message) with each card's age by the locale and
// calendar: "Today", "Yesterday", the weekday name within 6 days, else the
// date in the medium style. Locale weekday names and date formats live in
// FoundationInternationalization on Linux, so this file imports it beside
// FoundationEssentials; elsewhere it imports Foundation.
#if canImport(FoundationInternationalization)
import FoundationEssentials
import FoundationInternationalization
#else
import Foundation
#endif

public struct HomeBuilder: HomeBuilding {
    let creating: any DocumentCreating
    let calendar: Calendar
    let weekdays: [String]                 // the locale's weekday names, Sunday first
    let medium: Date.FormatStyle           // the locale's medium date ("Oct 4, 2026")

    public init(creating: any DocumentCreating, locale: Locale, calendar: Calendar) {
        var localized = calendar
        localized.locale = locale
        self.creating = creating
        self.calendar = localized
        self.weekdays = localized.weekdaySymbols
        self.medium = Date.FormatStyle(date: .abbreviated, time: .omitted, locale: locale, calendar: localized,
                                       timeZone: localized.timeZone)
    }

    public func home(recents: RecentsList, running: [SuiteApp], query: String, filter: SuiteApp?,
                     order: [SuiteApp], missingApps: Set<SuiteApp>, missingFiles: Set<String>, now: Date) -> HomeState {
        let tiles = creating.tiles(missing: missingApps)
        let ordered = order.compactMap { app in tiles.first { $0.app == app } }
        let cards = recents.filtered(app: filter, query: query).map {
            RecentCard(item: $0, age: age(of: $0.lastUsed, now: now), isMissing: missingFiles.contains($0.ref.fileID))
        }
        let empty: String?
        if !cards.isEmpty { empty = nil }
        else if recents.items.isEmpty { empty = "No recent work yet. Start something new above, or open a file." }
        else { empty = "Nothing matches \u{201C}\(query)\u{201D}." }
        return HomeState(tiles: ordered, cards: cards, running: running.filter { $0 != .launcher }, emptyMessage: empty)
    }

    /// Calendar days from `date` to `now`: 0 (or a future date) "Today", 1 "Yesterday",
    /// 2…6 the weekday name, else the medium date.
    func age(of date: Date, now: Date) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        if days <= 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        if days <= 6 {
            let index = calendar.component(.weekday, from: date) - 1
            if weekdays.indices.contains(index) { return weekdays[index] }
        }
        return medium.format(date)
    }
}

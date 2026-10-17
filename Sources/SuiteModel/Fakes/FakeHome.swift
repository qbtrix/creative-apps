// FakeHome.swift: the reference HomeBuilding (UC-16), pure. Tiles in the
// chosen order, filtered cards with their age and Missing state, and the
// empty or no-match message when there are no cards.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct FakeHome: HomeBuilding {
    let creating: any DocumentCreating
    public init(creating: any DocumentCreating = FakeCreating()) { self.creating = creating }

    public func home(recents: RecentsList, running: [SuiteApp], query: String, filter: SuiteApp?,
                     order: [SuiteApp], missingApps: Set<SuiteApp>, missingFiles: Set<String>, now: Date) -> HomeState {
        let tiles = creating.tiles(missing: missingApps)
        let ordered = order.compactMap { app in tiles.first { $0.app == app } }
        let cards = recents.filtered(app: filter, query: query).map {
            RecentCard(item: $0, age: Self.age(of: $0.lastUsed, now: now), isMissing: missingFiles.contains($0.ref.fileID))
        }
        let empty: String?
        if !cards.isEmpty { empty = nil }
        else if recents.items.isEmpty { empty = "No recent work yet. Start something new above, or open a file." }
        else { empty = "Nothing matches \u{201C}\(query)\u{201D}." }
        return HomeState(tiles: ordered, cards: cards, running: running.filter { $0 != .launcher }, emptyMessage: empty)
    }

    /// "Today", "Yesterday", else days ago; the live type formats weekday and date with the locale.
    static func age(of date: Date, now: Date) -> String {
        let days = Int(now.timeIntervalSince(date) / 86_400)
        return days <= 0 ? "Today" : days == 1 ? "Yesterday" : "\(days) days ago"
    }
}

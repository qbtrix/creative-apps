// HomeValues.swift: what the home window shows: the new-document tiles, the
// recents cards and the running apps. Its column math is `HomeLayout`
// (Home/). Foundation free, Linux-safe, Sendable.

/// One "New ..." tile in the home's tile row.
public struct NewTile: Equatable, Sendable {
    public var app: SuiteApp
    public var title: String                 // "New Animation"
    public var presets: [NewDocumentPreset]
    public var disabledReason: String?
    public init(app: SuiteApp, title: String, presets: [NewDocumentPreset], disabledReason: String? = nil) {
        self.app = app; self.title = title; self.presets = presets; self.disabledReason = disabledReason
    }
}

/// One recents entry as the home grid shows it.
public struct RecentCard: Equatable, Sendable {
    public var item: RecentItem
    public var age: String                   // "Today", "Yesterday", "Monday", "3 Oct"
    public var isMissing: Bool
    public init(item: RecentItem, age: String, isMissing: Bool) { self.item = item; self.age = age; self.isMissing = isMissing }
}

/// Everything the home window draws.
public struct HomeState: Equatable, Sendable {
    public var tiles: [NewTile]
    public var cards: [RecentCard]
    public var running: [SuiteApp]
    public var emptyMessage: String?          // set when there are no cards
    public init(tiles: [NewTile], cards: [RecentCard], running: [SuiteApp], emptyMessage: String?) {
        self.tiles = tiles; self.cards = cards; self.running = running; self.emptyMessage = emptyMessage
    }
}

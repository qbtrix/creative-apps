// HomeMenu.swift: what the launcher's File, Edit and View menus show (HM-2c,
// blueprint suite.md 6.2): each item's title, and the sentence that says why
// it can't act (nil: it acts). LauncherCommandsHome renders it and calls
// HomeModel. With no window, New and Open… open it and the rest wait for it.
// Foundation free, Linux-safe.

/// The page the home window shows; Edit > Delete acts on its selection.
public enum HomePage: Sendable { case home, assets }

public struct HomeMenu: Equatable, Sendable {
    /// One menu item: its title and why it can't act (nil: it acts).
    public struct Item: Equatable, Sendable {
        public var title: String
        public var reason: String?
        public var isEnabled: Bool { reason == nil }
        public init(_ title: String, reason: String? = nil) { self.title = title; self.reason = reason }
    }

    /// One File > New ▸ item and the preset it starts.
    public struct New: Equatable, Sendable {
        public var app: SuiteApp
        public var preset: NewDocumentPreset?
        public var item: Item
    }

    /// One File > Open Recent ▸ item.
    public struct Recent: Equatable, Sendable {
        public var fileID: String
        public var item: Item
    }

    public static let noWindow = "Open the AfterGlow window first."
    public static let noSelection = "Select a recent item first."
    public static let nothingToUndo = "Nothing to undo yet."
    public static let largest = "Thumbnails are at their largest."
    public static let smallest = "Thumbnails are at their smallest."
    /// Open Recent shows this many of the newest recents.
    public static let recentCount = 20

    public var new: [New]
    public var open: Item
    public var recents: [Recent]
    public var clearMenu: Item
    public var undo: Item
    public var delete: Item
    public var showSidebar: Item
    public var showInspector: Item
    public var larger: Item
    public var smaller: Item

    /// `tiles` are the home's New tiles (empty: each app's tile, none missing);
    /// `pending` is the services' not-connected reasons.
    public static func make(recents: RecentsList, selection: String?, thumbnailStep: Int, page: HomePage,
                            hasWindow: Bool, canUndoRemove: Bool = false, tiles: [NewTile] = [],
                            pending: [String: String] = [:]) -> HomeMenu {
        let blocked = hasWindow ? nil : noWindow
        let tiles = tiles.isEmpty ? SuiteCreating().tiles(missing: []) : tiles
        let new = tiles.map { tile in
            let reason = tile.disabledReason ?? (tile.presets.isEmpty ? SuiteIdentity.notConnected("home") : nil)
            return New(app: tile.app, preset: tile.presets.first, item: Item(tile.title, reason: hasWindow ? reason : nil))
        }
        // As the window's Open…: no open panel until a chosen file can be routed.
        let openReason = pending["routing"] ?? pending["sending"] ?? SuiteServices.notConnected("routing")
        let recent = recents.items.prefix(recentCount).map {
            Recent(fileID: $0.ref.fileID, item: Item($0.ref.displayName, reason: blocked ?? pending["sending"]))
        }
        let selected = selection.map { id in recents.items.contains { $0.ref.fileID == id } } ?? false
        let delete = switch page {
        case .home: Item("Remove from Recents", reason: blocked ?? (selected ? nil : noSelection))
        case .assets: Item("Remove Asset", reason: blocked ?? SuiteIdentity.notConnected("shared-assets"))
        }
        return HomeMenu(
            new: new, open: Item("Open…", reason: hasWindow ? openReason : nil), recents: recent,
            clearMenu: Item("Clear Menu", reason: blocked ?? SuiteIdentity.notConnected("recents-open-in")),
            undo: Item("Undo Remove from Recents", reason: blocked ?? (canUndoRemove ? nil : nothingToUndo)),
            delete: delete,
            // The sidebar and inspector are window state HomeModel doesn't own yet.
            showSidebar: Item("Show Sidebar", reason: blocked ?? SuiteIdentity.notConnected("home")),
            showInspector: Item("Show Inspector", reason: blocked ?? SuiteIdentity.notConnected("home")),
            larger: Item("Larger Thumbnails", reason: blocked ?? (thumbnailStep >= 3 ? largest : nil)),
            smaller: Item("Smaller Thumbnails", reason: blocked ?? (thumbnailStep <= 0 ? smallest : nil)))
    }
}

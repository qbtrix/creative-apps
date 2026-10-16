// HomeSidebar.swift: the home's sidebar rows (blueprint suite.md 6.1): Home,
// Assets, then one row per app with its symbol (6.4); an app row filters the
// recents. The running dot waits on SidebarRow's trailing accessory (#805).
import SuiteModel
import SuiteUI

enum HomeSidebarRows {
    static let home = "home", assets = "assets"

    /// Computed: SidebarSection isn't Sendable, so it can't be a static let.
    static var sections: [SidebarSection] { [
        SidebarSection(id: "afterglow", title: "AfterGlow", items: [
            SidebarItem(id: home, title: "Home", systemImage: "house"),
            SidebarItem(id: assets, title: "Assets", systemImage: "square.stack"),
        ]),
        SidebarSection(id: "apps", title: "Apps", items: SuiteApp.apps.map {
            SidebarItem(id: $0.rawValue, title: $0.displayName, systemImage: symbol($0))
        }),
    ] }

    /// The selected row: Assets while that page shows, else the filtered app, else Home.
    static func selection(showsAssets: Bool, filter: SuiteApp?) -> String {
        showsAssets ? assets : filter?.rawValue ?? home
    }

    /// Each app's SF Symbol in UI (blueprint 6.4).
    static func symbol(_ app: SuiteApp) -> String {
        let symbols: [SuiteApp: String] = [.flare: "scribble.variable", .design: "square.on.circle",
            .photo: "paintbrush.pointed", .library: "photo.on.rectangle.angled", .halo: "film.stack"]
        return symbols[app] ?? "square.grid.3x3.square"
    }
}

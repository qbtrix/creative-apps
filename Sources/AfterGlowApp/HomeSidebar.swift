// HomeSidebar.swift: the home's sidebar rows (blueprint suite.md 6.1): Home
// with the suite mark, Assets, then one row per app with its mark (6.4,
// AppMark); an app row filters the recents, so its section's title says so
// (#1869; SidebarItem has no help text). The running dot waits on SidebarRow's trailing accessory (#805).
import SuiteModel
import SuiteUI

enum HomeSidebarRows {
    static let home = "home", assets = "assets"
    /// The app rows filter the recents grid; they don't launch the apps (#1869).
    static let appsTitle = "Recents by App"

    /// Computed: SidebarSection isn't Sendable, so it can't be a static let.
    static var sections: [SidebarSection] { [
        SidebarSection(id: "afterglow", title: "AfterGlow", items: [
            SidebarItem(id: home, title: "Home", app: .launcher),
            SidebarItem(id: assets, title: "Assets", systemImage: "square.stack"),
        ]),
        SidebarSection(id: "apps", title: appsTitle, items: SuiteApp.apps.map {
            SidebarItem(id: $0.rawValue, title: $0.displayName, app: $0)
        }),
    ] }

    /// The selected row: Assets while that page shows, else the filtered app, else Home.
    static func selection(showsAssets: Bool, filter: SuiteApp?) -> String {
        showsAssets ? assets : filter?.rawValue ?? home
    }
}

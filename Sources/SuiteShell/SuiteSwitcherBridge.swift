// SuiteSwitcherBridge.swift: the switcher a suite window shows (blueprint 6.2;
// SW-3d). Its rows come from SwitcherEntries, so a row is enabled exactly when
// its Switch To item is, and a click switches through AppLauncher. The rows are
// read when the scene is built and are not refreshed while the window stays
// open: an app launched later shows as enabled, and a click still opens it.
import Foundation
import SuiteModel
import SuiteUI

enum SuiteSwitcherBridge {
    /// The switcher for a window of `app`, with each row's state as it is now.
    static func state(current app: SuiteApp) -> AppSwitcherState {
        let arguments = ProcessInfo.processInfo.arguments
        let bundle = launcherBundlePath()
        let hidden = AppLauncher.hiddenApps(in: arguments)
        let states = Dictionary(uniqueKeysWithValues: SuiteApp.allCases.map {
            ($0, AppLauncher.state(of: $0, bundle: bundle, hidden: hidden))
        })
        let launcher = AppLauncher(bundle: bundle, arguments: arguments)
        let rows = SwitcherEntries.entries(current: app, states: states)
        let items = rows.map { row in
            AppSwitcherItem(id: id(of: row.app), title: row.title, systemImage: row.systemImage,
                            shortcut: row.shortcut, unavailableHelp: row.reason)
        }
        return AppSwitcherState(items: items, current: id(of: app), onSelect: { selected in
            guard let target = appFor(id: selected) else { return }
            Task { _ = try? await launcher.switchTo(target, reason: .menu) }
        })
    }

    /// The switcher's id for an app: "home" for the launcher, the raw value otherwise.
    static func id(of app: SuiteApp) -> String {
        app == .launcher ? "home" : app.rawValue
    }

    static func appFor(id: String) -> SuiteApp? {
        SuiteApp.allCases.first { self.id(of: $0) == id }
    }
}

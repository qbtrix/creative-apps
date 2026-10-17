// SwitcherEntries.swift: the app switcher's rows (blueprint 6.2; SW-3d). Built
// from SwitchMenu's items, so the switcher and Window > Switch To can't
// disagree: a row is enabled exactly when its menu item is, and a disabled row
// carries the menu's reason. Foundation free, Linux-safe, Sendable.

/// One row of the app switcher.
public struct SwitcherEntry: Equatable, Sendable {
    public var app: SuiteApp
    public var title: String
    public var systemImage: String
    /// The Control-Command shortcut shown beside the row, such as "⌃⌘2".
    public var shortcut: String
    /// The sentence a disabled row shows; nil when the row is enabled.
    public var reason: String?

    public init(app: SuiteApp, title: String, systemImage: String, shortcut: String, reason: String?) {
        self.app = app; self.title = title; self.systemImage = systemImage; self.shortcut = shortcut; self.reason = reason
    }
}

/// The switcher's rows, in Switch To order: Home, then the five apps.
public enum SwitcherEntries {
    public static func entries(current: SuiteApp, states: [SuiteApp: AppRunState]) -> [SwitcherEntry] {
        SwitchMenu.items(current: current, states: states).map { item in
            SwitcherEntry(
                app: item.app, title: item.app == .launcher ? "Home" : item.app.displayName,
                systemImage: glyph(for: item.app), shortcut: "⌃⌘\(item.digit)",
                reason: item.enabled ? nil : item.reason)
        }
    }

    /// The SF Symbol a row shows for `app`.
    public static func glyph(for app: SuiteApp) -> String {
        switch app {
        case .launcher: "house"
        case .flare: "flame"
        case .design: "pencil.and.outline"
        case .photo: "camera.aperture"
        case .library: "photo.on.rectangle"
        case .halo: "film"
        }
    }
}

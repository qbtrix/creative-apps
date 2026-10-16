// SuiteApp.swift: the launcher and the five apps inside AfterGlow.app, and
// the Settings pane a hand-off can open. Foundation free, Linux-safe,
// Sendable.

/// The launcher and the five apps, in Window > Switch To order.
public enum SuiteApp: String, CaseIterable, Codable, Hashable, Sendable {
    case launcher, flare, design, photo, library, halo

    /// The five apps, in the home's default order.
    public static let apps: [SuiteApp] = [.flare, .design, .photo, .library, .halo]

    public var displayName: String {
        switch self {
        case .launcher: "AfterGlow"
        case .flare: "Flare"
        case .design: "Design"
        case .photo: "Photo"
        case .library: "Library"
        case .halo: "Halo"
        }
    }

    /// The launcher's id is `SuiteIdentity.launcherBundleID`; each app's is
    /// the prefix and its raw value.
    public var bundleID: String {
        self == .launcher ? SuiteIdentity.launcherBundleID : SuiteIdentity.prefix + "." + rawValue
    }

    /// Path inside AfterGlow.app; the launcher is the bundle itself.
    public var bundlePath: String {
        self == .launcher ? "" : "Contents/Helpers/\(displayName).app"
    }

    /// Window > Switch To shortcut: Control-Command and this digit.
    public var switchDigit: Int {
        switch self {
        case .launcher: 0
        case .flare: 1
        case .design: 2
        case .photo: 3
        case .library: 4
        case .halo: 5
        }
    }
}

/// A Settings pane: the suite-wide one or one app's.
public enum SettingsPane: Codable, Hashable, Sendable { case general, app(SuiteApp) }

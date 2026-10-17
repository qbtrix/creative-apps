// OnboardingStarter.swift: the start page's values (onboarding packet, OB-1):
// a shipped sample, one starter tile, the window's numbers and the control
// ids (blueprint 4.1, `afterglow.onboarding.<name>`). Foundation free,
// Linux-safe, Sendable.

/// One sample document the tour can open, shipped in Contents/Resources/Samples.
public struct SampleFile: Hashable, Sendable {
    public var app: SuiteApp
    public var fileName: String          // "Bounce.flare"
    public var type: SuiteTypeID
    public var title: String             // "Bounce", what the tile says
    public init(app: SuiteApp, fileName: String, type: SuiteTypeID, title: String) {
        self.app = app; self.fileName = fileName; self.type = type; self.title = title
    }
}

/// One tile of the start page: the app's New tile plus its sample.
public struct OnboardingStarter: Equatable, Sendable {
    public var tile: NewTile             // SuiteCreating's title and presets
    public var sample: SampleFile?
    public var sampleReason: String?     // nil when the sample can be opened
    public init(tile: NewTile, sample: SampleFile?, sampleReason: String?) {
        self.tile = tile; self.sample = sample; self.sampleReason = sampleReason
    }
}

/// The window's numbers until SuiteSize.onboardingWindow lands (needs-ui): 720 × 520, 24 pt margins.
public enum OnboardingLayout { public static let width = 720.0, height = 520.0, margin = 24.0 }

/// Identifiers (blueprint 4.1): afterglow.onboarding.<name>.
public enum OnboardingControls {
    static let prefix = "afterglow.onboarding."
    public static let page = prefix + "page"          // value: the page id
    public static let `continue` = prefix + "continue"
    public static let back = prefix + "back"
    public static let skip = prefix + "skip"
    public static let startEmpty = prefix + "start-empty"
    public static let help = prefix + "help"          // the Help menu item
    /// afterglow.onboarding.focus.<raw>
    public static func focus(_ f: OnboardingFocus) -> String { prefix + "focus." + f.rawValue }
    /// afterglow.onboarding.new.<preset id>
    public static func preset(_ p: NewDocumentPreset) -> String { prefix + "new." + p.id }
    /// afterglow.onboarding.sample.<app>
    public static func sample(_ app: SuiteApp) -> String { prefix + "sample." + app.rawValue }
}

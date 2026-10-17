// SuiteIdentity.swift: the suite's one bundle id prefix, the launcher's id
// and the reason text every not-yet-built suite control shows. Foundation
// free, Linux-safe, Sendable. Suite-contracts (SC-1a) fills the rest of
// Values/ (docs/blueprints/suite.md, 5.4).

/// The one id prefix. Placeholder until the captain names the real one (Q1).
public enum SuiteIdentity {
    /// Every bundle id in the suite starts with this.
    public static let prefix = "org.creativesuite"

    /// The launcher's (AfterGlow's) bundle id.
    public static let launcherBundleID = prefix + ".afterglow"

    /// Each feature slug (docs/blueprints/suite.md 8.2) to the plain words a
    /// newcomer reads in a disabled control's help; slugs never reach the UI.
    public static let featurePhrases: [String: String] = [
        "switching": "Switching between apps", "recents-open-in": "Opening recent work",
        "home": "The Home window", "settings": "The Settings window",
        "clipboard-drag": "Copy and paste between apps", "photo-round-trip": "Editing in Photo and back",
        "shared-assets": "The shared asset library", "linked-assets": "Linking assets between apps",
        "onboarding": "The welcome tour", "updater": "Checking for updates",
    ]

    /// The help text of a control whose feature is not built yet, as in
    /// "Switching between apps isn't available yet."
    public static func notConnected(_ feature: String) -> String {
        "\(featurePhrases[feature] ?? "This") isn't available yet."
    }
}

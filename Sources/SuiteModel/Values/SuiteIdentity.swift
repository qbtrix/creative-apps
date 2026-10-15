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

    /// The help text of a control whose feature is not built yet, as in
    /// "Not connected yet (switching)."
    public static func notConnected(_ feature: String) -> String { "Not connected yet (\(feature))." }
}

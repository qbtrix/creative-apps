// SuiteApp.swift: the launcher and the five apps inside AfterGlow.app.
// Foundation free, Linux-safe, Sendable.

/// The launcher and the five apps, in Window > Switch To order.
///
/// Minimal for now: suite-contracts SC-1a (#820) fills in `displayName`,
/// `bundleID`, `bundlePath`, `switchDigit` and `SettingsPane` here, in this
/// file, rather than declaring the type again.
public enum SuiteApp: String, CaseIterable, Codable, Hashable, Sendable {
    case launcher, flare, design, photo, library, halo
}

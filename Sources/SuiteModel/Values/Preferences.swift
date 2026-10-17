// Preferences.swift: the suite-wide preferences every app reads, stored as
// `preferences.json`. Foundation free, Linux-safe, Sendable.

/// The unit rulers, inspectors and new-document sizes show.
public enum LengthUnit: String, Codable, CaseIterable, Sendable { case points, pixels, millimeters, centimeters, inches }

/// The preferences the whole suite shares; each app keeps its own keys in `perApp`.
public struct SuitePreferences: Codable, Equatable, Sendable {
    public var revision: Int
    public var units: LengthUnit
    public var autosaveSeconds: Int          // 10...600
    public var checkForUpdates: Bool
    public var onboardingDoneVersion: Int?   // nil: never finished or skipped
    public var homeOrder: [SuiteApp]
    public var perApp: [String: [String: String]]   // keyed by SuiteApp.rawValue; each app owns its keys
    public init(revision: Int = 0, units: LengthUnit = .points, autosaveSeconds: Int = 30, checkForUpdates: Bool = true,
                onboardingDoneVersion: Int? = nil, homeOrder: [SuiteApp] = SuiteApp.apps, perApp: [String: [String: String]] = [:]) {
        self.revision = revision; self.units = units; self.autosaveSeconds = min(max(autosaveSeconds, 10), 600)
        self.checkForUpdates = checkForUpdates; self.onboardingDoneVersion = onboardingDoneVersion
        self.homeOrder = homeOrder; self.perApp = perApp
    }
}

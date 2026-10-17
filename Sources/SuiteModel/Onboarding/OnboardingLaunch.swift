// OnboardingLaunch.swift: whether the first launch shows the welcome window
// (onboarding packet, OB-1 stub, OB-7 body): never with `-SuiteSkipOnboarding
// YES` (journeys), else the flow's answer on the stored preferences.
// Linux-safe, Sendable.

/// The first-launch rule and the preferences read before the first frame.
public enum OnboardingLaunch {
    public static let skipFlag = "-SuiteSkipOnboarding"
    /// False with "-SuiteSkipOnboarding YES"; else flow.shouldShow(stored ?? defaults, version:).
    public static func presents(arguments: [String], stored: SuitePreferences?, flow: any OnboardingFlowing,
                                version: Int = SuiteOnboarding.version) -> Bool {
        if let flag = arguments.firstIndex(of: skipFlag) {
            let next = arguments.index(after: flag)
            if next < arguments.endIndex, arguments[next] == "YES" { return false }
        }
        return flow.shouldShow(stored ?? SuitePreferences(), version: version)
    }
    /// The stored preferences read synchronously before the first frame; nil when none or unreadable.
    public static func stored(in store: FileStore) -> SuitePreferences? {
        guard let read = try? store.read(StorePreferences.file, as: SuitePreferences.self), var p = read.value else { return nil }
        p.revision = read.revision
        return p
    }
}

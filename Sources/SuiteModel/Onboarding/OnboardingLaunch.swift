// OnboardingLaunch.swift: whether the first launch shows the welcome window
// (onboarding packet OB-7): never with `-SuiteSkipOnboarding YES` (journeys),
// else the flow's answer on the stored preferences. A flag with no value or
// any other value leaves the answer to the flow.
// Linux-safe, Sendable.

/// The first-launch rule and the preferences read before the first frame.
public enum OnboardingLaunch {
    public static let skipFlag = "-SuiteSkipOnboarding"
    /// False with "-SuiteSkipOnboarding YES"; else flow.shouldShow(stored ?? defaults, version:).
    public static func presents(arguments: [String], stored: SuitePreferences?, flow: any OnboardingFlowing,
                                version: Int = SuiteOnboarding.version) -> Bool {
        if zip(arguments, arguments.dropFirst()).contains(where: { $0 == skipFlag && $1 == "YES" }) { return false }
        return flow.shouldShow(stored ?? SuitePreferences(), version: version)
    }
    /// The stored preferences read synchronously before the first frame; nil when none or unreadable.
    public static func stored(in store: FileStore) -> SuitePreferences? {
        guard let read = try? store.read(StorePreferences.file, as: SuitePreferences.self), var p = read.value else { return nil }
        p.revision = read.revision
        return p
    }
}

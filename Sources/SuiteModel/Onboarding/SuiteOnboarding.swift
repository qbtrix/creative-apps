// SuiteOnboarding.swift: the live OnboardingFlowing (UC-13, blueprint 5.2
// row 13). OB-1 stub: the pages and the focus → order rule are the fake's;
// OB-7 writes `shouldShow` as `(done ?? 0) < version`. Foundation free,
// Linux-safe, Sendable.

/// The live OnboardingFlowing (blueprint 5.2 row 13: "same type in Onboarding/").
public struct SuiteOnboarding: OnboardingFlowing {
    public static let version = 1
    /// The one line about rendering on page 1.
    public static let renderingNote = "Rendering is Automatic, which draws on the CPU in this beta. View > Rendering in any app changes it."
    public init() {}
    public var pages: [OnboardingPage] { FakeOnboarding().pages }
    public func shouldShow(_ p: SuitePreferences, version: Int) -> Bool { FakeOnboarding().shouldShow(p, version: version) }
    public func finishing(_ p: SuitePreferences, focus: OnboardingFocus?, version: Int) -> SuitePreferences {
        FakeOnboarding().finishing(p, focus: focus, version: version)
    }
    /// The apps a focus puts first, the order the start page and the home share.
    public static func order(for focus: OnboardingFocus?) -> [SuiteApp] {
        SuiteOnboarding().finishing(SuitePreferences(), focus: focus, version: version).homeOrder
    }
}

// SuiteOnboarding.swift: the live OnboardingFlowing (UC-13, blueprint 5.2
// row 13). The pages and the focus → order rule are the fake's (one rule for
// the window and the home); `shouldShow` is `(done ?? 0) < version`, so a
// bumped version shows the tour again (onboarding OB-7). Foundation free,
// Linux-safe, Sendable.

/// The live OnboardingFlowing (blueprint 5.2 row 13: "same type in Onboarding/").
public struct SuiteOnboarding: OnboardingFlowing {
    public static let version = 1
    /// The one line about rendering on page 1.
    public static let renderingNote = "Rendering is Automatic, which draws on the CPU in this beta. View > Rendering in any app changes it."
    public init() {}
    public var pages: [OnboardingPage] { FakeOnboarding().pages }
    /// True until this version has been finished or skipped; a newer version shows again.
    public func shouldShow(_ p: SuitePreferences, version: Int) -> Bool { (p.onboardingDoneVersion ?? 0) < version }
    /// Records `version` as done and puts the focus's apps first, keeping every other field.
    public func finishing(_ p: SuitePreferences, focus: OnboardingFocus?, version: Int) -> SuitePreferences {
        FakeOnboarding().finishing(p, focus: focus, version: version)
    }
    /// A preset chip's label on the start page. One click creates the document,
    /// so it says "New" (or "Import") and drops the ellipsis: no dialog follows.
    public static func presetTitle(_ preset: NewDocumentPreset) -> String {
        var title = preset.title
        while title.hasSuffix("…") { title.removeLast() }
        return title.hasPrefix("New ") || title.hasPrefix("Import ") ? title : "New " + title
    }
    /// The apps a focus puts first, the order the start page and the home share.
    public static func order(for focus: OnboardingFocus?) -> [SuiteApp] {
        SuiteOnboarding().finishing(SuitePreferences(), focus: focus, version: version).homeOrder
    }
}

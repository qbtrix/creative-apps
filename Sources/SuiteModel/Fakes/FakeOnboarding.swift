// FakeOnboarding.swift: the reference OnboardingFlowing (UC-13), pure. Three
// pages; finishing records the version and puts the chosen focus's apps
// first in `homeOrder` (Photos: Library, then Photo).

public struct FakeOnboarding: OnboardingFlowing {
    public init() {}
    public var pages: [OnboardingPage] {
        [OnboardingPage(id: "apps", title: "Five apps, one AfterGlow",
                        body: "Flare animates, Design draws, Photo retouches, Library sorts your photos, Halo composites. Switch with Control-Command 1 to 5."),
         OnboardingPage(id: "focus", title: "What do you make most?", body: "Each choice puts the apps it names first, here and on the home. Change it any time from Help > Welcome to AfterGlow.",
                        choices: OnboardingFocus.allCases),
         OnboardingPage(id: "start", title: "Start with a sample or a new document",
                        body: "Open a sample to see an app at work, or click a chip to start a new document. A chip ending in … asks for details first.")]
    }
    public func shouldShow(_ p: SuitePreferences, version: Int) -> Bool { p.onboardingDoneVersion == nil }
    public func finishing(_ p: SuitePreferences, focus: OnboardingFocus?, version: Int) -> SuitePreferences {
        var next = p
        next.onboardingDoneVersion = version
        let first = Self.firstApps(for: focus)
        next.homeOrder = first + SuiteApp.apps.filter { !first.contains($0) }
        return next
    }
    /// The apps a focus puts first, in order (its chip names them); empty keeps the usual order.
    public static func firstApps(for focus: OnboardingFocus?) -> [SuiteApp] {
        switch focus {
        case .animation: [.flare, .halo]
        case .design: [.design]
        case .photos: [.library, .photo]
        case .motion: [.halo, .flare]
        case .everything, nil: []
        }
    }
}

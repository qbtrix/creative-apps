// FakeOnboarding.swift: the reference OnboardingFlowing (UC-13), pure. Three
// pages; finishing records the version and puts the chosen focus's apps
// first in `homeOrder` (Photos: Library, then Photo).

public struct FakeOnboarding: OnboardingFlowing {
    public init() {}
    public var pages: [OnboardingPage] {
        [OnboardingPage(id: "apps", title: "Five apps, one AfterGlow",
                        body: "Flare animates, Design draws, Photo retouches, Library sorts your photos, Halo composites. Switch with Control-Command 1 to 5."),
         OnboardingPage(id: "focus", title: "What do you make most?", body: "AfterGlow puts those apps first. You can change this in Settings.",
                        choices: OnboardingFocus.allCases),
         OnboardingPage(id: "start", title: "Start with a sample", body: "Open a sample to see each app at work, or start from an empty home.")]
    }
    public func shouldShow(_ p: SuitePreferences, version: Int) -> Bool { p.onboardingDoneVersion == nil }
    public func finishing(_ p: SuitePreferences, focus: OnboardingFocus?, version: Int) -> SuitePreferences {
        var next = p
        next.onboardingDoneVersion = version
        let first: [SuiteApp]
        switch focus {
        case .animation: first = [.flare, .halo]
        case .design: first = [.design]
        case .photos: first = [.library, .photo]
        case .motion: first = [.halo, .flare]
        case .everything, nil: first = []
        }
        next.homeOrder = first + SuiteApp.apps.filter { !first.contains($0) }
        return next
    }
}

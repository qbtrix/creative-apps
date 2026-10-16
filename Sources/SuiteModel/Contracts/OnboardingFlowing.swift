// OnboardingFlowing.swift: a suite contract from blueprint suite.md 5.2. Every throwing
// requirement throws `SuiteError`, whose `message` is the sentence the UI shows.

/// UC-13 First-launch onboarding (tier 3). Pure.
public protocol OnboardingFlowing: Sendable {
    var pages: [OnboardingPage] { get }
    func shouldShow(_ preferences: SuitePreferences, version: Int) -> Bool
    func finishing(_ preferences: SuitePreferences, focus: OnboardingFocus?, version: Int) -> SuitePreferences
}

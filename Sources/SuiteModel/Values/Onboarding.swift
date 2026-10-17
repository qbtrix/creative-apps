// Onboarding.swift: the pages of the first-run flow and the focus a person
// picks on it. Foundation free, Linux-safe, Sendable.

/// What a person says they mostly do, on the "what you do" page.
public enum OnboardingFocus: String, Codable, CaseIterable, Sendable { case animation, design, photos, motion, everything }

/// One page of the first-run flow.
public struct OnboardingPage: Equatable, Sendable {
    public var id: String
    public var title: String
    public var body: String
    public var choices: [OnboardingFocus]    // empty except on the "what you do" page
    public init(id: String, title: String, body: String, choices: [OnboardingFocus] = []) {
        self.id = id; self.title = title; self.body = body; self.choices = choices
    }
}

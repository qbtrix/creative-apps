// AfterGlowOnboardingSnapshots.swift: the welcome window (onboarding packet)
// as goldens in Golden/afterglow/. OB-3 declares the suite so it compiles
// against OnboardingWindow; OB-4 renders its pages in the four appearances
// and turns the test on. macOS only.
import AppKit
import SuiteModel
import SwiftUI
import Testing

@testable import AfterGlowApp

@MainActor
@Suite struct AfterGlowOnboardingSnapshots {
    @Test(.disabled("waits on OB-4")) func onboardingStates() {
        _ = OnboardingWindow()
    }
}

// RenderBudgetAfterGlowOnboardingTests.swift: the welcome window's render
// budget (Tests/render-budgets.md) on OnboardingWindow.bodyRuns. OB-3
// declares the suite so it compiles against the counter; OB-4 drives Continue
// and Back through the harness and turns both tests on. Nested in
// BodyCountSuites, as every suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import SwiftUI
import Testing

@testable import AfterGlowApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetAfterGlowOnboardingTests {
        @Test(.disabled("waits on OB-4")) func bodies() {
            OnboardingWindow.bodyRuns = 0
            #expect(OnboardingWindow.bodyRuns == 0)
        }

        @Test(.disabled("waits on OB-4")) func timing() {
            #expect(OnboardingWindow.bodyRuns >= 0)
        }
    }
}
#endif

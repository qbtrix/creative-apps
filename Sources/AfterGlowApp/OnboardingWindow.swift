// OnboardingWindow.swift: the "Welcome to AfterGlow" window. Declared in
// AfterGlowApp but never opened yet; the onboarding feature opens it on first
// launch and fills its three pages.
import SuiteUI
import SwiftUI

struct OnboardingWindow: View {
    var body: some View {
        Text("The welcome pages arrive with the onboarding feature.")
            .font(SuiteFont.body)
            .foregroundStyle(SuiteColor.textSecondary)
            .padding(SuiteSpacing.xxl)
    }
}

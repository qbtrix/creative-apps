// LauncherCommands+Onboarding.swift: the onboarding feature's launcher menu
// (blueprint suite.md 6.2, onboarding packet OB-3): Help > Welcome to
// AfterGlow reopens the welcome window at any time. Live from the start, so
// it is not in LauncherMenuStubTests' list of disabled stubs.
import SuiteModel
import SwiftUI

struct LauncherCommandsOnboarding: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .help) {
            Button("Welcome to AfterGlow") { openWindow(id: "onboarding") }
                .accessibilityIdentifier(OnboardingControls.help)
        }
    }
}

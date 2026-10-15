// AfterGlowApp.swift: AfterGlow, the suite's launcher. Three scenes: the
// home window, the Settings scene (AfterGlow > Settings…, Command-comma,
// is its own item and opens it) and the onboarding window, declared here and
// opened only by the onboarding feature. The menus are SuiteCommands'
// Window > Switch To plus one LauncherCommands stub per launcher feature,
// each holding its blueprint 6.2 items disabled with their reason until that
// feature wires them. LauncherDelegate (LauncherRouter.swift) is the app
// delegate. No later feature edits this file: features fill their own
// stubs, views and LauncherRouter+<Area>.swift extensions.
import SuiteModel
import SuiteShell
import SuiteUI
import SwiftUI

@main
struct AfterGlowApp: App {
    @NSApplicationDelegateAdaptor(LauncherDelegate.self) var delegate

    var body: some Scene {
        Window("AfterGlow", id: "home") { HomeWindow() }
            // The launch size SuiteWindow's apps use (#715); HomeWindow sets the minimum.
            .defaultSize(SuiteSize.windowLaunch)
            .commands {
                SuiteCommands(app: .launcher)
                LauncherCommandsHome()
                LauncherCommandsAssets()
                LauncherCommandsUpdate()
            }
        Settings { SettingsView() }
            .commands { LauncherCommandsSettings() }
        Window("Welcome to AfterGlow", id: "onboarding") { OnboardingWindow() }
    }
}

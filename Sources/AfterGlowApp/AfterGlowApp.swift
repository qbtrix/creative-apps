// AfterGlowApp.swift: AfterGlow, the suite's launcher. Three scenes: the
// home window, the Settings scene (AfterGlow > Settings…, Command-comma,
// is its own item and opens it) and the onboarding window, presented over
// the home at first launch and at OnboardingLayout's fixed size. Both the
// home and the welcome window present themselves: a presented scene keeps an
// `.automatic` one closed. The menus are SuiteCommands'
// Window > Switch To plus one LauncherCommands stub per launcher feature,
// each holding its blueprint 6.2 items disabled with their reason until that
// feature wires them, and SuiteHelpCommands' Help menu, whose Welcome to
// AfterGlow opens the onboarding window. LauncherDelegate (LauncherRouter.swift) is the app
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
            // Presents itself: the welcome window presenting would otherwise keep it closed at first launch.
            .defaultLaunchBehavior(.presented)
            .commands {
                SuiteCommands(app: .launcher)
                LauncherCommandsHome()
                LauncherCommandsAssets()
                LauncherCommandsUpdate()
            }
        Settings { SettingsView() }
            .commands { LauncherCommandsSettings() }
        Window("Welcome to AfterGlow", id: "onboarding") { OnboardingWindow() }
            .defaultLaunchBehavior(OnboardingWindow.launchBehavior)
            .restorationBehavior(.disabled)
            .windowResizability(.contentSize)
            .commands { SuiteHelpCommands(app: .launcher) }
    }
}

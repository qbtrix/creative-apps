// AfterGlowApp.swift: AfterGlow, the suite's launcher. For now one window,
// "AfterGlow", holding a placeholder sentence, and Window > Switch To from
// SuiteCommands (disabled until switching). The launcher's scenes and menu
// stubs (BU-1b) replace this body.
import SuiteModel
import SuiteShell
import SuiteUI
import SwiftUI

@main
struct AfterGlowApp: App {
    var body: some Scene {
        Window("AfterGlow", id: "home") {
            Text("The AfterGlow home arrives with the home feature.")
                .font(SuiteFont.body)
                .foregroundStyle(SuiteColor.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // The launch size SuiteWindow's apps use (#715).
        .defaultSize(width: 1000, height: 640)
        .commands { SuiteCommands(app: .launcher) }
    }
}

// HaloApp.swift: Halo, the motion graphics app. The app scene opens
// HaloWindow and registers the Composition menu (HaloCompositionCommands) and
// Layer > New (HaloCommands), which reach the window through focused scene
// values. Views only read HaloProject and call its methods; all state lives in
// HaloModel (scripts/ci checks this).
import HaloModel
import SuiteUI
import SwiftUI

@main
struct HaloApp: App {
    var body: some Scene {
        WindowGroup { HaloWindow() }
            .commands {
                HaloCompositionCommands()
                HaloCommands()
            }
    }
}

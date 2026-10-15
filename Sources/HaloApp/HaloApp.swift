// HaloApp.swift: Halo, the motion graphics app. The app scene opens
// HaloWindow and registers Halo's menus: File (HaloFileMenu), Edit's Undo and
// Redo (HaloEditMenu), Composition (HaloCompositionCommands), Layer
// (HaloCommands) and Animation (HaloAnimationMenu). Every item sends a
// HaloCommand to the focused window's `haloPerform` and reads its project
// (`haloProject`) for its title and availability. A window opens at
// `-HaloWindowSize` when given (HaloLaunch), else at the suite's launch size;
// the flag also sets the frame once the window is up (HaloWindowSizer), since
// a saved frame from an earlier launch outranks the default size.
// Views only read HaloProject and call its methods; all state lives in
// HaloModel (scripts/ci checks this).
import HaloModel
import SuiteUI
import SwiftUI

@main
struct HaloApp: App {
    var body: some Scene {
        WindowGroup {
            HaloWindow()
                .background {
                    if let size = HaloLaunch.current.windowSize { HaloWindowSizer(size: size).accessibilityHidden(true) }
                }
        }
            .defaultSize(HaloLaunch.current.windowSize ?? SuiteSize.windowLaunch)
            .commands {
                HaloFileMenu()
                HaloEditMenu()
                HaloCompositionCommands()
                HaloCommands()
                HaloAnimationMenu()
            }
    }
}

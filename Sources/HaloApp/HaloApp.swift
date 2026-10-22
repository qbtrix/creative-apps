// HaloApp.swift: Halo, the motion graphics app. The app scene opens
// HaloWindow and registers Halo's menus: File (HaloFileMenu), Edit's Undo and
// Redo (HaloEditMenu), Composition (HaloCompositionCommands), Layer
// (HaloCommands) and Animation (HaloAnimationMenu). Every item sends a
// HaloCommand to the focused window's `haloPerform` and reads its project
// (`haloProject`) for its title and availability. A window opens at
// `-HaloWindowSize` when given (HaloLaunch), else at the suite's launch size;
// the flag also sets the frame once the window is up (HaloWindowSizer), since
// a saved frame from an earlier launch outranks the default size.
// Switching (A-HA-1, #865): the scene takes part in the suite
// (`.suiteApp(.halo, host:)` with the suite's app delegate) and Window gets
// Switch To ▸ and AI Access… (SuiteCommands). A hand-off the host accepts
// (`.new`: New Composition; `.open` a .halo: open it) waits in HaloShell's
// inbox until a window takes it (HaloWindow+File.swift). File keeps Halo's
// own Open Recent, so the suite's (SuiteFileCommands) isn't added.
// Views only read HaloProject and call its methods; all state lives in
// HaloModel (scripts/ci checks this).
import HaloModel
import Observation
import SuiteShell
import SuiteUI
import SwiftUI

/// The hand-offs the host accepted that no window has run yet, oldest first.
@MainActor @Observable final class HaloHandOffInbox {
    private(set) var pending: [HaloCommand] = []

    func send(_ command: HaloCommand) { pending.append(command) }

    /// The pending commands, which leave the inbox.
    func take() -> [HaloCommand] {
        let taken = pending
        pending = []
        return taken
    }
}

/// The process's hand-off host and the inbox it delivers to.
@MainActor enum HaloShell {
    static let inbox = HaloHandOffInbox()
    static let host = HaloDocumentHost { command in
        await MainActor.run { HaloShell.inbox.send(command) }
    }
}

@main
struct HaloApp: App {
    @NSApplicationDelegateAdaptor(SuiteAppDelegate.self) private var delegate

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
                SuiteCommands(app: .halo)
            }
            .suiteApp(.halo, host: HaloShell.host)
    }
}

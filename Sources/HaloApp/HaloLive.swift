// HaloLive.swift (editor-menus EM-6): Halo's end of the suite's live command channel. `HaloLive.channel` runs
// an `afterglow` command on the active window's project (as HaloHeadless) and hands it back; the window lands it
// with `HaloProject.landLive`, the command's undo step included. Which window that is lives in `HaloLive.front`,
// the suite's LiveFront: a window joins with `suiteLiveWindow` when it becomes active and lets go when it closes,
// so with none the call answers "no document open". `ask` is AIAccessCenter.ask: a client with no grant sees
// the approval sheet first.
import HaloModel
import SuiteModel
import SuiteShell

/// Which window live commands reach, and the channel that runs them.
@MainActor enum HaloLive {
    static let front = LiveFront<HaloHeadless>()

    static let channel = LiveCommandChannel(
        app: SuiteApp.halo.displayName,
        document: { front.document() },
        apply: { front.apply($0) },
        ask: { await AIAccessCenter.shared.ask($0) })
}

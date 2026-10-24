// FlareLive.swift (editor-menus EM-5): Flare's end of the suite's live command channel. `FlareLive.channel`
// runs an `afterglow` command on the frontmost window's workspace (as FlareHeadless) and hands the result back to
// that window, which takes it through `FlareWorkspace.takeLive`. Which window that is lives in `FlareLive.front`,
// the suite's LiveFront: a window joins with `suiteLiveWindow` when it becomes the active one and lets go when it
// closes. With no window the channel answers "no document open". A client without a grant is asked through
// AIAccessCenter.ask, the approval sheet on the front window.
import FlareModel
import SuiteModel
import SuiteShell

/// The window the live channel reads and writes, and the channel itself.
@MainActor enum FlareLive {
    static let front = LiveFront<FlareHeadless>()

    static let channel = LiveCommandChannel(
        app: SuiteApp.flare.displayName,
        document: { front.document() },
        apply: { front.apply($0) },
        ask: { await AIAccessCenter.shared.ask($0) })
}

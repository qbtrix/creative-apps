// FlareWindow+Stage.swift: the router's stage area (FlareWindow+Router.swift).
// A stub until F3a draws the stage and routes its drags: `performStage` does
// nothing and `stageHelp` says why.
import FlareModel

extension FlareWindow {
    /// Acts on a stage intent; nothing yet.
    func performStage(_ intent: FlareIntent.Stage) {}

    /// Why a stage intent can't act now.
    func stageHelp(_ intent: FlareIntent.Stage) -> String? { "Not built yet (F3a)." }
}

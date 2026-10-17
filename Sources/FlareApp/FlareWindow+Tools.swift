// FlareWindow+Tools.swift: the router's tools area (FlareWindow+Router.swift).
// Choosing a palette tool selects it, with the Model's `toolHelp` as the
// reason one can't act yet; leaving the Pen that way keeps an open path
// (`selectTool` finishes it). Finish Path (the palette's last button and
// Object > Finish Path) commits the open pen path (`model.finishPath`), with
// `finishPathHelp` as its reason. The stage's
// keys (`toolKey`): Return finishes the path, Escape cancels the draft or
// the drag under way; the tool letters are the stage's own (FlareStage).
import FlareModel
import SwiftUI

extension FlareWindow {
    /// Acts on a tools intent through the Model.
    func performTools(_ intent: FlareIntent.Tools) {
        switch intent {
        case .choose(let tool): model.selectTool(tool)
        case .finishPath: model.finishPath()
        }
    }

    /// Why a tools intent can't act now; a tool's own reason, or nil.
    func toolsHelp(_ intent: FlareIntent.Tools) -> String? {
        switch intent {
        case .choose(let tool): model.toolHelp(tool)
        case .finishPath: model.finishPathHelp
        }
    }

    /// A key pressed on the stage: Return finishes an open pen path, Escape cancels; anything else is left alone.
    func toolKey(_ key: KeyPress) -> KeyPress.Result {
        guard key.modifiers.isEmpty else { return .ignored }
        switch key.key {
        case .return: perform(.tools(.finishPath))
        case .escape: perform(.stage(.cancelDrag))
        default: return .ignored
        }
        return .handled
    }
}

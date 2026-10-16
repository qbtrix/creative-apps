// FlareWindow+Tools.swift: the router's tools area (FlareWindow+Router.swift).
// Choosing a palette tool selects it, with the Model's `toolHelp` as the
// reason one can't act yet. Finish Path and the stage keys (`toolKey`,
// Escape and Return) wait for F4a (DK-9).
import FlareModel
import SwiftUI

extension FlareWindow {
    /// Acts on a tools intent: choosing a tool only, for now.
    func performTools(_ intent: FlareIntent.Tools) {
        switch intent {
        case .choose(let tool): model.selectTool(tool)
        case .finishPath: break
        }
    }

    /// Why a tools intent can't act now; a tool's own reason, or nil.
    func toolsHelp(_ intent: FlareIntent.Tools) -> String? {
        switch intent {
        case .choose(let tool): model.toolHelp(tool)
        case .finishPath: "Not built yet (F4a)."
        }
    }

    /// A key pressed on the stage; DK-9 handles Escape and Return.
    func toolKey(_ key: KeyPress) -> KeyPress.Result { .ignored }
}

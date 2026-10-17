// FlareStageContextMenu.swift: the stage's right-click menu, as a modifier on FlareStage. A stub until stage-edit
// SE-3 fills it: it leaves the stage as it is. It reads `model` at `zoom` and will act through `perform`.
import FlareModel
import SwiftUI

struct FlareStageContextMenu: ViewModifier {
    let model: FlareWorkspace
    let zoom: Double
    let perform: @MainActor (FlareIntent) -> Void

    func body(content: Content) -> some View { content }
}

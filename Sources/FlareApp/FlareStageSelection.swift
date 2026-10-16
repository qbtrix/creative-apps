// FlareStageSelection.swift: the selection's handles on the stage (scale and rotate), in the stage's overlay. A stub
// until stage-edit fills it: it draws nothing. It reads `model` at `zoom` and will act through `perform`.
import FlareModel
import SwiftUI

struct FlareStageSelection: View {
    let model: FlareWorkspace
    let zoom: Double
    let perform: @MainActor (FlareIntent) -> Void

    var body: some View { EmptyView() }
}

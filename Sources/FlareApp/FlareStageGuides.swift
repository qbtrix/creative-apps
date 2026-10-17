// FlareStageGuides.swift: the stage's ruler guides and snapping marks, in the stage's overlay. A stub until
// stage-edit fills it: it draws nothing. It reads `model` at `zoom` and will act through `perform`.
import FlareModel
import SwiftUI

struct FlareStageGuides: View {
    let model: FlareWorkspace
    let zoom: Double
    let perform: @MainActor (FlareIntent) -> Void

    var body: some View { EmptyView() }
}

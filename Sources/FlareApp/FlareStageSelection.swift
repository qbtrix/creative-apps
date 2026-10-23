// FlareStageSelection.swift: stage-edit SE-1. SuiteUI's `SelectionHandles` where `selectionReadout` puts them, taking
// no clicks (the stage's drag finds the handle, FlareBoxDrag.swift), and `flare.stage.selection` with the readout's words.
import FlareModel
import SuiteUI
import SwiftUI

struct FlareStageSelection: View {
    let model: FlareWorkspace
    let zoom: Double
    let perform: @MainActor (FlareIntent) -> Void

    var body: some View {
        let readout = model.selectionReadout(stageScale: zoom)
        if let box = readout.box {
            ZStack(alignment: .topLeading) {
                SelectionHandles(box: box, handles: readout.handleRects(stageScale: zoom), zoom: zoom)
                    .allowsHitTesting(false)
                ProbeElement(
                    "flare.stage.selection", label: readout.text, rect: FlareStageOverlay.rect(box), zoom: zoom,
                    traits: .isImage)
            }
        }
    }
}

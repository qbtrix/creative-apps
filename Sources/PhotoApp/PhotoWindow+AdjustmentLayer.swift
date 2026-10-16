// PhotoWindow+AdjustmentLayer.swift: the adjustment layer area of a Photo
// window (photo-adjustment-layers, PV-6): its intents, its route and its hook
// on the window. Layer > New Adjustment Layer sends `add`; the inspector
// sends `adjust` for each change to the selected adjustment layer and
// `endAdjust` when its slider or curve gesture ends, so a gesture is one undo
// step. PhotoAdjustmentLayerArea is the identity until the area needs it.
import PhotoModel
import SwiftUI

/// What the adjustment layer area can be asked to do.
enum AdjustmentLayerIntent {
    /// Adds an adjustment layer of this kind above the selected layer.
    case add(AdjustmentKind)
    /// Changes one value of the adjustment layer with this id.
    case adjust(PhotoLayer.ID, AdjustmentEdit)
    /// A slider's or the curve's gesture on an adjustment layer ended.
    case endAdjust
}

extension PhotoWindow {
    func performAdjustmentLayer(_ intent: AdjustmentLayerIntent) {
        switch intent {
        case .add(let kind): model.addAdjustmentLayer(kind)
        case .adjust(let id, let edit): model.adjustLayer(id, edit)
        case .endAdjust: model.endAdjustLayer()
        }
    }
}

/// The adjustment layer area's state, alerts and dialogs over the window.
struct PhotoAdjustmentLayerArea: ViewModifier {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    func body(content: Content) -> some View { content }
}

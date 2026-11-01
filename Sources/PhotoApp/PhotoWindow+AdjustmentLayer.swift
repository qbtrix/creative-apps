// PhotoWindow+AdjustmentLayer.swift: the adjustment layer area of a Photo
// window (photo-adjustment-layers, PV-6): its intents, its route and its hook
// on the window. Layer > New Adjustment Layer sends `add`; the inspector
// sends `adjust` for each change to the selected adjustment layer and
// `endAdjust` when its slider or curve gesture ends, so a gesture is one undo
// step. Each `adjust`, here and the whole image's in PhotoWindow.perform, runs on the window's live copy
// (LiveTransformCopy+Kernel.swift), as a tone row's drag samples do, so a scrub never re-runs the editor; `endAdjust`, like any other intent, takes the copy back
// first. PhotoAdjustmentLayerArea is the identity until the area needs it.
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
        case .adjust(let id, let edit):
            renderer.show(liveTransform.run(on: model, done: { takeStroke() }) { $0.adjustLayer(id, edit) }, quietly: true)
        case .endAdjust: model.endAdjustLayer()
        }
    }

    /// Whether `intent` is one inspector slider step, on the whole image or an adjustment layer, which runs
    /// on the live copy.
    nonisolated static func isAdjustSample(_ intent: PhotoIntent) -> Bool {
        switch intent {
        case .adjust, .adjustmentLayer(.adjust): true
        default: false
        }
    }
}

/// The adjustment layer area's state, alerts and dialogs over the window.
struct PhotoAdjustmentLayerArea: ViewModifier {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    func body(content: Content) -> some View { content }
}

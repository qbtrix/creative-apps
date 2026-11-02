// PhotoWindow+AdjustmentLayer.swift: the adjustment layer area of a Photo
// window (photo-adjustment-layers, PV-6): its intents, its route and its hook
// on the window. Layer > New Adjustment Layer sends `add`; the inspector
// sends `adjust` for each change to the selected adjustment layer and
// `endAdjust` when its slider or curve gesture ends, so a gesture is one undo
// step. An `adjust` runs on the window's live copy, as a tone row's drag
// sample does (LiveTransformCopy+Kernel.swift), so a scrub never re-runs the
// editor (#2875); `endAdjust`, like any other intent, takes the copy back
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
            let shown = liveTransform.run(on: model, done: { takeStroke() }) { $0.adjustLayer(id, edit) }
            renderer.show(shown, quietly: true)
        case .endAdjust: model.endAdjustLayer()
        }
    }

    /// Whether `intent` is one sample of an adjustment layer's slider or curve, which runs on the live copy.
    nonisolated static func isAdjustmentLayerSample(_ intent: PhotoIntent) -> Bool {
        if case .adjustmentLayer(.adjust) = intent { true } else { false }
    }
}

/// The adjustment layer area's state, alerts and dialogs over the window.
struct PhotoAdjustmentLayerArea: ViewModifier {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    func body(content: Content) -> some View { content }
}

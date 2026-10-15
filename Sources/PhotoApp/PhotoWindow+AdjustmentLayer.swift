// PhotoWindow+AdjustmentLayer.swift: the adjustment layer area of a Photo
// window (photo-adjustment-layers, PV-6): its intents, its route and its hook
// on the window. PV-0 stub: AdjustmentLayerIntent has no case yet, and
// PhotoAdjustmentLayerArea is the identity until PV-6 needs it.
import PhotoModel
import SwiftUI

/// What the adjustment layer area can be asked to do (PV-6 adds the cases).
enum AdjustmentLayerIntent {}

extension PhotoWindow {
    func performAdjustmentLayer(_ intent: AdjustmentLayerIntent) {
        switch intent {}
    }
}

/// The adjustment layer area's state, alerts and dialogs over the window.
struct PhotoAdjustmentLayerArea: ViewModifier {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    func body(content: Content) -> some View { content }
}

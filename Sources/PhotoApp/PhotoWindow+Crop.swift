// PhotoWindow+Crop.swift: the crop area of a Photo window (photo-crop,
// PV-3: crop size fields, aspect lock): its intents, its route and its hook on
// the window. A typed number the model refuses (under 1, or fields disabled)
// keeps the old value and beeps. Apply Crop and Cancel stay flat intents, and
// PhotoCropArea is the identity until PV-3 needs it.
import AppKit
import PhotoModel
import SwiftUI

/// What the crop area can be asked to do.
enum CropIntent {
    /// Sets one of the pending crop's X, Y, W, H, in canvas pixels.
    case field(CropField, Int)
    /// Locks the crop to an aspect (Free unlocks it).
    case aspect(CropAspect)
    /// Swaps the locked ratio's sides (3:2 becomes 2:3).
    case swap
}

extension PhotoWindow {
    func performCrop(_ intent: CropIntent) {
        switch intent {
        case .field(let field, let value): if !model.setCropField(field, to: value) { NSSound.beep() }
        case .aspect(let aspect): model.setCropAspect(aspect)
        case .swap: model.swapCropAspect()
        }
    }
}

/// The crop area's state, alerts and dialogs over the window.
struct PhotoCropArea: ViewModifier {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    func body(content: Content) -> some View { content }
}

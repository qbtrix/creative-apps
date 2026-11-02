// PhotoWindow+Crop.swift: the crop area of a Photo window (photo-crop,
// PV-3: crop size fields, aspect lock): its intents, its route and its hook on
// the window. A typed number the model refuses (under 1, or fields disabled)
// keeps the old value and beeps. The aspect comes from the shared
// CropAspectPicker as a CropPick (orientation-crop OC-13). Apply Crop and Cancel stay flat intents, and
// PhotoCropArea is the identity until PV-3 needs it.
import AppKit
import PhotoModel
import SuiteKernel
import SwiftUI

/// What the crop area can be asked to do.
enum CropIntent {
    /// Sets one of the pending crop's X, Y, W, H, in canvas pixels.
    case field(CropField, Int)
    /// A chip, a custom W:H or the orientation toggle from CropAspectPicker (Free unlocks it).
    case pick(CropPick)
}

extension PhotoWindow {
    func performCrop(_ intent: CropIntent) {
        switch intent {
        case .field(let field, let value): if !model.setCropField(field, to: value) { NSSound.beep() }
        case .pick(let pick): model.pickCropAspect(pick)
        }
    }
}

/// The crop area's state, alerts and dialogs over the window.
struct PhotoCropArea: ViewModifier {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    func body(content: Content) -> some View { content }
}

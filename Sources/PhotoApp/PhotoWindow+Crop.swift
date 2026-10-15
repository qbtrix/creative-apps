// PhotoWindow+Crop.swift: the crop area of a Photo window (photo-crop,
// PV-3: crop size fields, aspect lock): its intents, its route and its hook on
// the window. PV-0 stub: CropIntent has no case yet (Apply Crop and Cancel
// stay flat intents), and PhotoCropArea is the identity until PV-3 needs it.
import PhotoModel
import SwiftUI

/// What the crop area can be asked to do (photo-crop adds the cases).
enum CropIntent {}

extension PhotoWindow {
    func performCrop(_ intent: CropIntent) {
        switch intent {}
    }
}

/// The crop area's state, alerts and dialogs over the window.
struct PhotoCropArea: ViewModifier {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    func body(content: Content) -> some View { content }
}

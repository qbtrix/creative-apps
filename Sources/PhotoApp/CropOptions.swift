// CropOptions.swift: the crop tool's options in the Adjust tab: Apply Crop
// (Return) and Cancel (Escape), both disabled until a crop is dragged out.
// Values in, intents out.
import PhotoModel
import SuiteUI
import SwiftUI

struct CropOptions: View {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    var body: some View {
        HStack(spacing: SuiteSpacing.xs) {
            let why = model.canApplyCrop ? nil : "Drag over the image to choose a crop first."
            toolCommand("Apply Crop", "crop", help: why, .applyCrop, perform: perform).keyboardShortcut(.defaultAction)
            toolCommand("Cancel", "xmark", help: why, .cancelCrop, perform: perform).keyboardShortcut(.cancelAction)
        }
    }
}

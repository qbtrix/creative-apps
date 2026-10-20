// PhotoWindow+Sample.swift: the eyedropper area of a Photo window (eyedropper
// PE-2): its intents and their route. The size chips set the square the tool
// reads; a pick samples the composite through the Model's SampleTarget
// adapter (PhotoSample+Kernel) and makes it the brush colour, with no undo
// step, and a refused pick beeps. PE-3 wires the canvas click and the loupe
// to `.pick(at:)`; PhotoSampleArea is the identity until then.
import AppKit
import PhotoModel
import SuiteKernel
import SwiftUI

/// What the eyedropper area can be asked to do.
enum SampleIntent {
    /// The square the eyedropper reads.
    case size(SampleSize)
    /// Sample the composite at `point` (canvas pixels) into the brush colour.
    case pick(at: Point)
}

extension PhotoWindow {
    func performSample(_ intent: SampleIntent) {
        switch intent {
        case .size(let size): model.setSampleSize(size)
        case .pick(let point):
            do { try model.pickBrushColor(at: point) } catch { NSSound.beep() }
        }
    }
}

/// The eyedropper area's state, alerts and dialogs over the window.
struct PhotoSampleArea: ViewModifier {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    func body(content: Content) -> some View { content }
}

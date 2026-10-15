// PhotoWindow+Sample.swift: the eyedropper area of a Photo window (PV-9:
// sample size, sampling a color): its intents, its route and its hook on the
// window. PV-0 stub: SampleIntent has no case yet (the eyedropper samples
// through its canvas drag), and PhotoSampleArea is the identity until PV-9
// needs it.
import PhotoModel
import SwiftUI

/// What the eyedropper area can be asked to do (PV-9 adds the cases).
enum SampleIntent {}

extension PhotoWindow {
    func performSample(_ intent: SampleIntent) {
        switch intent {}
    }
}

/// The eyedropper area's state, alerts and dialogs over the window.
struct PhotoSampleArea: ViewModifier {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    func body(content: Content) -> some View { content }
}

// PhotoWindow+Select.swift: the selection and mask area of a Photo window
// (PV-5: shapes, feather, invert, layer masks): its intents, its route and
// its hook on the window. PV-0 stub: SelectIntent has no case yet (Select
// All, Deselect, Delete and Fill stay flat intents), and PhotoSelectArea is
// the identity until PV-5 needs it.
import PhotoModel
import SwiftUI

/// What the selection area can be asked to do (PV-5 adds the cases).
enum SelectIntent {}

extension PhotoWindow {
    func performSelect(_ intent: SelectIntent) {
        switch intent {}
    }
}

/// The selection area's state, alerts and dialogs over the window.
struct PhotoSelectArea: ViewModifier {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    func body(content: Content) -> some View { content }
}

// PhotoWindow+History.swift: the history area of a Photo window (PV-4: the
// History tab, stepping to a state): its intents, its route and its hook on
// the window. PV-0 stub: HistoryIntent has no case yet (Undo and Redo stay
// flat intents), and PhotoHistoryArea is the identity until PV-4 needs it.
import PhotoModel
import SwiftUI

/// What the history area can be asked to do (PV-4 adds the cases).
enum HistoryIntent {}

extension PhotoWindow {
    func performHistory(_ intent: HistoryIntent) {
        switch intent {}
    }
}

/// The history area's state, alerts and dialogs over the window.
struct PhotoHistoryArea: ViewModifier {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    func body(content: Content) -> some View { content }
}

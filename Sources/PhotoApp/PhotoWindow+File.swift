// PhotoWindow+File.swift: the file area of a Photo window (photo-documents,
// PV-1): its intents, its route and its hook on the window. PV-0 stub:
// FileIntent has no case yet and New Image, Open, Save and Save As still route
// through PhotoWindow.perform. PhotoFileArea is the identity; photo-documents
// keeps its autosave timer, the recovery offer, Keep layers?, the failed-save
// flag, the close prompt and the edited dot inside it.
import PhotoModel
import SwiftUI

/// What the file area can be asked to do (photo-documents adds the cases).
enum FileIntent {}

extension PhotoWindow {
    func performFile(_ intent: FileIntent) {
        switch intent {}
    }
}

/// The file area's state, alerts, dialogs and timers over the window.
struct PhotoFileArea: ViewModifier {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    func body(content: Content) -> some View { content }
}

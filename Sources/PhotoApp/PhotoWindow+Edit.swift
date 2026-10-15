// PhotoWindow+Edit.swift: the edit area of a Photo window (photo-edit,
// PV-2: cut, copy, paste, duplicate, merge down, flatten): its intents, its
// route and its hook on the window. PV-0 stub: EditIntent has no case yet,
// and PhotoEditArea is the identity until PV-2 keeps the pasteboard and the
// paste refusal alert (`pasteRefusal`) inside it.
import PhotoModel
import SwiftUI

/// What the edit area can be asked to do (photo-edit adds the cases).
enum EditIntent {}

extension PhotoWindow {
    func performEdit(_ intent: EditIntent) {
        switch intent {}
    }
}

/// The edit area's state, alerts and dialogs over the window.
struct PhotoEditArea: ViewModifier {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    func body(content: Content) -> some View { content }
}

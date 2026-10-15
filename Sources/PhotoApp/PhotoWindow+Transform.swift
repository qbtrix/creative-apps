// PhotoWindow+Transform.swift: the transform area of a Photo window (PV-7:
// Free Transform, flips): its intents, its route, Return and Escape while a
// transform is up, and its hook on the window. PV-0 stub: TransformIntent has
// no case yet, `confirmTransform` and `dismissTransform` handle nothing (so
// Return and Escape fall back to the crop and the selection), and
// PhotoTransformArea is the identity until PV-7 keeps its mode
// (`isTransforming`) and its off-main-actor commit inside it.
import PhotoModel
import SwiftUI

/// What the transform area can be asked to do (PV-7 adds the cases).
enum TransformIntent {}

extension PhotoWindow {
    func performTransform(_ intent: TransformIntent) {
        switch intent {}
    }

    /// Return: commits the transform in progress; false when there is none.
    func confirmTransform() -> Bool { false }

    /// Escape: cancels the transform in progress; false when there is none.
    func dismissTransform() -> Bool { false }
}

/// The transform area's state, alerts and dialogs over the window.
struct PhotoTransformArea: ViewModifier {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    func body(content: Content) -> some View { content }
}

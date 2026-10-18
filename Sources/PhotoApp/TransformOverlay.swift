// TransformOverlay.swift: Free Transform's box over the canvas. Empty until
// PV-7 draws the box and its handles: nothing while the workspace has no
// transform draft, and with one only its element `photo.canvas.transform-box`,
// "Transform box", at the box's frame before the transform.
import PhotoModel
import SuiteUI
import SwiftUI

struct TransformOverlay: View {
    let model: PhotoWorkspace
    let zoom: Double

    /// The transform box's element; nil without a transform draft.
    var mark: PhotoCanvasMark? { model.transformDraft.map { PhotoCanvasMark.transformBox($0.box.cgRect) } }

    var body: some View {
        if let mark = mark { mark.probe(zoom: zoom) }
    }
}

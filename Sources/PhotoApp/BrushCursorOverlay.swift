// BrushCursorOverlay.swift: the brush cursor, a ring the brush's size at
// `hover` (the document point under the pointer, nil when outside). Draws
// nothing yet: PV-4 fills it with SuiteUI's BrushCursorMark (#953) and its
// element `photo.canvas.brush-cursor`, "Brush size" (PhotoCanvasMark.brushCursor).
import PhotoModel
import SuiteUI
import SwiftUI

struct BrushCursorOverlay: View {
    let model: PhotoWorkspace
    let zoom: Double
    let hover: CGPoint?

    /// The brush cursor's element; nil until PV-4 draws the ring.
    var mark: PhotoCanvasMark? { nil }

    var body: some View {
        if let mark = mark { mark.probe(zoom: zoom) }
    }
}

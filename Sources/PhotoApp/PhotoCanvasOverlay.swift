// PhotoCanvasOverlay.swift: what PhotoCanvas draws over the picture, inside
// CanvasViewport's overlay at the canvas zoom: the selection
// (SelectionOverlay.swift), a pending crop (CropOverlay.swift), Free
// Transform's box (TransformOverlay.swift) and the brush cursor at `hover`
// (BrushCursorOverlay.swift), in that order. SuiteUI's marks are hidden from
// accessibility, so each visible mark also gets one PhotoCanvasMarkElement: a
// clear rectangle at the mark's frame that the journeys find by identifier,
// an image and never a control, that never takes a click. `marks` lists the
// elements shown, for tests. Values in, nothing out.
import PhotoModel
import SuiteUI
import SwiftUI

struct PhotoCanvasOverlay: View {
    let model: PhotoWorkspace
    let zoom: Double
    /// The document point under the pointer (CanvasViewport's `onPointer`); nil when outside.
    let hover: CGPoint?

    var body: some View {
        ZStack(alignment: .topLeading) {
            SelectionOverlay(model: model, zoom: zoom)
            CropOverlay(model: model, zoom: zoom)
            TransformOverlay(model: model, zoom: zoom)
            BrushCursorOverlay(model: model, zoom: zoom, hover: hover)
        }
    }

    /// The accessibility elements the overlay shows, in drawing order.
    var marks: [PhotoCanvasMark] {
        [
            SelectionOverlay(model: model, zoom: zoom).mark, CropOverlay(model: model, zoom: zoom).mark,
            TransformOverlay(model: model, zoom: zoom).mark,
            BrushCursorOverlay(model: model, zoom: zoom, hover: hover).mark,
        ].compactMap { $0 }
    }
}

/// One canvas mark's accessibility element: its identifier, its label and its
/// frame in document pixels.
struct PhotoCanvasMark: Equatable {
    let identifier: String
    let label: String
    let rect: CGRect

    /// Every mark is an image; none is a button or any other control.
    static let traits: AccessibilityTraits = .isImage

    static func crop(_ rect: CGRect) -> Self { Self(identifier: "photo.canvas.crop", label: "Crop area", rect: rect) }
    static func selection(_ rect: CGRect) -> Self {
        Self(identifier: "photo.canvas.selection", label: "Selection", rect: rect)
    }
    static func transformBox(_ rect: CGRect) -> Self {
        Self(identifier: "photo.canvas.transform-box", label: "Transform box", rect: rect)
    }
    static func brushCursor(_ rect: CGRect) -> Self {
        Self(identifier: "photo.canvas.brush-cursor", label: "Brush size", rect: rect)
    }
}

/// `mark` as a clear rectangle at its frame at `zoom`: one identified,
/// labelled image element that takes no clicks. The SuiteUI mark it covers
/// stays hidden.
struct PhotoCanvasMarkElement: View {
    let mark: PhotoCanvasMark
    let zoom: Double

    var body: some View {
        let box = mark.rect.applying(CGAffineTransform(scaleX: zoom, y: zoom)).standardized
        Color.clear
            .frame(width: box.width, height: box.height)
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: mark.label))
            .accessibilityIdentifier(mark.identifier)
            .accessibilityAddTraits(PhotoCanvasMark.traits)
            .padding(.leading, box.minX)
            .padding(.top, box.minY)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .allowsHitTesting(false)
    }
}

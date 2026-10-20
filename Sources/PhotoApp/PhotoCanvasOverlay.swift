// PhotoCanvasOverlay.swift: what PhotoCanvas draws over the picture, inside
// CanvasViewport's overlay at the canvas zoom: the selection
// (SelectionOverlay.swift), a pending crop (CropOverlay.swift), Free
// Transform's box (TransformOverlay.swift) and the brush cursor at `hover`
// (SuiteUI's BrushCursorMark, the brush's size; `photo.canvas.brush-cursor`)
// and the Eyedropper's loupe (PhotoSampleLoupe, `suite.sample.loupe`), in
// that order. SuiteUI's marks are hidden from
// accessibility, so each visible mark also gets one probe (`probe(zoom:)`): a
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
            if let diameter = model.brushCursorDiameter {
                BrushCursorMark(point: hover, diameter: diameter, zoom: zoom)
                if let mark = brushCursor { mark.probe(zoom: zoom) }
            }
            PhotoSampleLoupe(model: model, zoom: zoom, hover: hover)
        }
    }

    /// The brush cursor's element: a box the brush's size centred on `hover`,
    /// in document pixels; nil off the canvas or with a tool that doesn't paint.
    var brushCursor: PhotoCanvasMark? {
        guard let hover, let diameter = model.brushCursorDiameter else { return nil }
        return .brushCursor(CGRect(x: hover.x - diameter / 2, y: hover.y - diameter / 2, width: diameter, height: diameter))
    }

    /// The accessibility elements the overlay shows, in drawing order.
    var marks: [PhotoCanvasMark] {
        [
            SelectionOverlay(model: model, zoom: zoom).mark, CropOverlay(model: model, zoom: zoom).mark,
            TransformOverlay(model: model, zoom: zoom).mark, brushCursor,
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

extension PhotoCanvasMark {
    /// This mark as a clear rectangle at its frame at `zoom` (SuiteUI's
    /// ProbeElement): one identified, labelled image element that takes no
    /// clicks. The SuiteUI mark it covers stays hidden.
    func probe(zoom: Double) -> ProbeElement {
        ProbeElement(identifier, label: label, rect: rect, zoom: zoom, traits: Self.traits)
    }
}

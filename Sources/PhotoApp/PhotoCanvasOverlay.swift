// PhotoCanvasOverlay.swift: what PhotoCanvas draws over the picture, inside
// CanvasViewport's overlay at the canvas zoom: the selection's ants and an
// area tool's outline in progress (SuiteUI's AreaAnts on the workspace's
// `areaOutline` and `areaDraft`; `photo.canvas.selection`; while an area or
// Crop drag runs on the window's LiveDragLine, its copy's), a pending crop (CropOverlay.swift), Free
// Transform's box (TransformOverlay.swift) and the brush cursor at `hover`
// (SuiteUI's BrushCursorMark, the brush's size; `photo.canvas.brush-cursor`),
// the Gradient tool's line while it drags (SuiteUI's PathMarks from the press
// to the pointer: the window's LiveDragLine while it lasts, else the Model's
// `gradientDrag`; `photo.canvas.gradient-line`), Remove's outline while it
// drags (SuiteUI's MotionPathMarks through its points, from the same live copy
// or `removeStroke`; `photo.canvas.remove-stroke`), the Select tool's box while it drags (SuiteUI's
// SelectBoxMark, from the same live copy or `selectBox`; `photo.canvas.select-box`)
// and the Eyedropper's loupe (PhotoSampleLoupe, `suite.sample.loupe`), in
// that order. SuiteUI's marks are hidden from
// accessibility, so each visible mark also gets one probe (`probe(zoom:)`): a
// clear rectangle at the mark's frame that the journeys find by identifier,
// an image and never a control, that never takes a click. `marks` lists the
// elements shown, for tests. Values in; only Free Transform's handles send
// intents out (`perform`). In a window it reads the PhotoSession's
// `toolOptions` facet itself, so the brush cursor follows a size step that
// re-runs nothing above it; without a session (tests) the workspace it was given.
import CoreRaster
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI

struct PhotoCanvasOverlay: View {
    private let given: PhotoWorkspace
    let zoom: Double
    /// The document point under the pointer (CanvasViewport's `onPointer`); nil when outside.
    let hover: CGPoint?
    /// Where Free Transform's handles send their edits.
    var perform: PhotoPerform = { _ in }
    /// The window's live drag line; read here only, so its samples re-run this body and not the editor's.
    var liveLine: LiveDragLine?
    @Environment(PhotoSession.self) private var session: PhotoSession?

    init(model: PhotoWorkspace, zoom: Double, hover: CGPoint?, perform: @escaping PhotoPerform = { _ in },
         liveLine: LiveDragLine? = nil) {
        (given, self.zoom, self.hover, self.perform, self.liveLine) = (model, zoom, hover, perform, liveLine)
    }

    /// The workspace the marks draw: the live drag line's copy while an area or Crop drag runs on it (its
    /// selection in progress and crop box, #6020), else the window's, read through the `toolOptions` facet; the
    /// given one outside a window.
    private var model: PhotoWorkspace { liveLine?.shown ?? session?.workspace(reading: .toolOptions) ?? given }

    var body: some View {
        ZStack(alignment: .topLeading) {
            AreaAnts(outline: model.areaOutline, draft: model.areaDraft, zoom: zoom)
            if let mark = selection { mark.probe(zoom: zoom) }
            CropOverlay(model: model, zoom: zoom)
            TransformOverlay(model: model, zoom: zoom, perform: perform)
            if let diameter = model.brushCursorDiameter {
                BrushCursorMark(point: hover, diameter: diameter, zoom: zoom)
                if let mark = brushCursor { mark.probe(zoom: zoom) }
            }
            if let line = dragLine, let mark = gradientLine {
                PathMarks(
                    anchors: [
                        PathAnchor(point: CGPoint(x: line.from.x, y: line.from.y), kind: .corner),
                        PathAnchor(point: CGPoint(x: line.to.x, y: line.to.y), kind: .corner),
                    ],
                    segments: [PathSegment(from: 0, to: 1)], zoom: zoom)
                mark.probe(zoom: zoom)
            }
            if let points = removePath, let mark = removeOutline {
                MotionPathMarks(points: points.map { CGPoint(x: $0.x, y: $0.y) }, zoom: zoom)
                mark.probe(zoom: zoom)
            }
            if let box = selectBox {
                SelectBoxMark(rect: box, zoom: zoom)
                PhotoCanvasMark.selectBox(box).probe(zoom: zoom)
            }
            PhotoSampleLoupe(model: model, zoom: zoom, hover: hover)
        }
    }

    /// The selection's element: its bounds, in document pixels; nil without one.
    var selection: PhotoCanvasMark? { model.selection.map { PhotoCanvasMark.selection($0.cgRect) } }

    /// The brush cursor's element: a box the brush's size centred on `hover`,
    /// in document pixels; nil off the canvas or with a tool that doesn't paint.
    var brushCursor: PhotoCanvasMark? {
        guard let hover, let diameter = model.brushCursorDiameter else { return nil }
        return .brushCursor(CGRect(x: hover.x - diameter / 2, y: hover.y - diameter / 2, width: diameter, height: diameter))
    }

    /// The Gradient tool's line's element: the box from the press to the
    /// pointer, in document pixels; nil unless a gradient drag has moved.
    var gradientLine: PhotoCanvasMark? {
        guard let line = dragLine else { return nil }
        let from = CGPoint(x: line.from.x, y: line.from.y), to = CGPoint(x: line.to.x, y: line.to.y)
        return .gradientLine(CGRect(x: from.x, y: from.y, width: to.x - from.x, height: to.y - from.y).standardized)
    }

    /// Remove's outline's element: the box round its points, grown by half the
    /// brush, in document pixels; nil unless a Remove drag has moved.
    var removeOutline: PhotoCanvasMark? {
        guard let points = removePath, let first = points.first else { return nil }
        let half = (model.brushCursorDiameter ?? 0) / 2
        let box = points.reduce(CGRect(x: first.x, y: first.y, width: 0, height: 0)) {
            $0.union(CGRect(x: $1.x, y: $1.y, width: 0, height: 0))
        }
        return .removeStroke(box.insetBy(dx: -half, dy: -half))
    }

    /// The outline a Remove drag shows: the live copy's while one is live, else the workspace's.
    private var removePath: [Mask.Point]? { liveLine?.path ?? model.removeStroke }

    /// The line a drag shows: the live copy's while one is live, else the workspace's.
    private var dragLine: (from: Mask.Point, to: Mask.Point)? { liveLine?.line ?? model.gradientDrag }

    /// The Select tool's box while it drags, in canvas pixels, from `model` (the live copy while one is live).
    private var selectBox: CGRect? {
        model.selectBox.map { CGRect(x: $0.minX, y: $0.minY, width: $0.maxX - $0.minX, height: $0.maxY - $0.minY) }
    }

    /// The accessibility elements the overlay shows, in drawing order.
    var marks: [PhotoCanvasMark] {
        [
            selection, CropOverlay(model: model, zoom: zoom).mark,
            TransformOverlay(model: model, zoom: zoom).mark, brushCursor, gradientLine, removeOutline, selectBox.map(PhotoCanvasMark.selectBox),
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
    static func selectBox(_ rect: CGRect) -> Self { Self(identifier: "photo.canvas.select-box", label: "Selection box", rect: rect) }
    static func gradientLine(_ rect: CGRect) -> Self {
        Self(identifier: "photo.canvas.gradient-line", label: "Gradient line", rect: rect)
    }
    static func removeStroke(_ rect: CGRect) -> Self {
        Self(identifier: "photo.canvas.remove-stroke", label: "Area to remove", rect: rect)
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

// FlareWindow+Stage.swift: the router's stage area (FlareWindow+Router.swift). FlareStage's drags arrive here: a
// pointer move is the Model's `dragChanged` (the live draft, marquee or move preview), mouse-up its `endDrag` (one
// undo step, or a selection change), and Escape mid-drag its `cancelDrag`. FlarePathEditLayer puts SuiteUI's
// PathEditOverlay over the stage (pen-paths FP-2): the picked shape's contours under Direct Select (`pathInEdit`, in
// stage points through its layer's transform) and the open pen draft (`penDraft`). Its intents go to the Model's
// `runPath` through `performPath`; the placeholder overlay draws the outline only until PN-3 adds its gesture.
import FlareCore
import FlareModel
import SuiteKernel
import SuiteUI
import SwiftUI

extension FlareWindow {
    /// Acts on a stage intent through the Model's gesture methods.
    func performStage(_ intent: FlareIntent.Stage) {
        switch intent {
        case .dragChanged(let start, let end, let shift, let option, let stageScale):
            var modifiers: DragModifiers = []
            if shift { modifiers.insert(.shift) }
            if option { modifiers.insert(.option) }
            model.dragChanged(from: start, to: end, modifiers: modifiers, stageScale: stageScale)
        case .endDrag: model.endDrag()
        case .cancelDrag: model.cancelDrag()
        }
    }

    /// Why a stage intent can't act now: the stage needs an open scene.
    func stageHelp(_ intent: FlareIntent.Stage) -> String? {
        model.selectedScene == nil ? "Open an animation to draw on the stage." : nil
    }

    /// Acts on a path overlay intent (a pen click, an anchor pick or drag) through the Model's `runPath`.
    func performPath(_ intent: PathIntent) {
        model.runPath(intent)
    }
}

/// The path overlay over the stage: Direct Select's picked shape and the Pen's open draft, read from `model`.
struct FlarePathEditLayer: View {
    let model: FlareWorkspace
    let zoom: Double

    var body: some View {
        if let tool = Self.tool(model.tool) {
            let edit = model.pathInEdit
            PathEditOverlay(
                draft: model.penDraft.map { Self.standIn($0.contour, through: .identity) },
                path: edit.map { edit in edit.path.contours.map { Self.standIn($0, through: edit.toDocument) } } ?? [],
                tool: tool, zoom: zoom)
        }
    }

    /// The overlay's tool for a Flare tool; nil for a tool that edits no path.
    nonisolated static func tool(_ tool: FlareTool) -> PenTool? {
        switch tool {
        case .pen: .pen
        case .directSelect: .directSelect
        default: nil
        }
    }

    /// `contour` mapped through `matrix` into stage points, as the overlay's stand-in.
    nonisolated static func standIn(_ contour: VectorContour, through matrix: Matrix) -> PathContourStandIn {
        func point(_ p: Point) -> CGPoint {
            let mapped = matrix.apply(p)
            return CGPoint(x: mapped.x, y: mapped.y)
        }
        let anchors = contour.anchors.map { anchor in
            SuiteUI.PathAnchor(point: point(anchor.point), kind: anchor.kind == .corner ? .corner : .smooth,
                               handleIn: anchor.handleIn.map(point), handleOut: anchor.handleOut.map(point))
        }
        return PathContourStandIn(anchors: anchors, closed: contour.closed)
    }
}

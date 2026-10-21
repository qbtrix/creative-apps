// FlareShapeToolDraftTests.swift (shape-tools FS-u): the Shape tool's live draft. A drag with the Shape tool drafts
// the kernel's path for the tool's picked options (`LiveShapes.shape(shapeTool, …)`), so the stage previews a star as
// a star, not a box; Shift and Option follow ShapeRules.dragged. The draw itself still refuses until FS-6: mouse-up
// adds no layer and no undo step.
import FlareCore
import SuiteKernel
import Testing
@testable import FlareModel

@Suite struct FlareShapeToolDraftTests {
    private static func p(_ x: Double, _ y: Double) -> Point { Point(x: x, y: y) }
    private static let a = p(100, 100), b = p(300, 160)

    static func shapeTool() -> FlareWorkspace {
        var ws = FlareWorkspace(services: .fake())
        ws.newDocument()
        ws.selectTool(.shape)
        return ws
    }

    /// The kernel's own drawing of `spec` for a drag from `a` to `b`: the reference the draft must equal.
    static func kernel(_ spec: ShapeSpec, _ a: Point, _ b: Point,
                       _ keys: EditModifiers = []) throws -> FlarePath {
        let (box, dragged) = try #require(ShapeRules.dragged(spec.kind, from: a, to: b, modifiers: keys))
        var drawn = spec
        (drawn.start, drawn.end) = (dragged.start, dragged.end)
        return try ShapeRules.path(drawn, in: box)
    }

    @Test func aStarDragDraftsTheKernelStarNotABox() throws {
        var ws = Self.shapeTool()
        ws.dragChanged(from: Self.a, to: Self.b)
        let draft = try #require(ws.draft, "a Shape drag shows a draft before mouse-up")
        #expect(draft.tool == .shape && draft.shape.closed)
        let star = try Self.kernel(.defaults(.star), Self.a, Self.b)
        #expect(draft.shape.path == star)
        #expect(draft.shape.points.count == 10, "a five-point star has ten corners")
        #expect(draft.shape.path != (try PathBuilders.rectangle(in: Rect(minX: 100, minY: 100, maxX: 300, maxY: 160))))
        #expect(ws.stageMarks.draft == star, "the stage's overlay gets the star's path")
    }

    @Test func shiftAndOptionFollowTheKernelsDragRule() throws {
        var ws = Self.shapeTool()
        ws.dragChanged(from: Self.a, to: Self.b, modifiers: [.shift, .option])
        #expect(ws.draft?.shape.path == (try Self.kernel(.defaults(.star), Self.a, Self.b, [.shift, .option])))
    }

    @Test func theDraftFollowsThePickedOptions() throws {
        var ws = Self.shapeTool()
        let seven = ShapeIntent.points(7).applied(to: ws.shapeTool)
        ws.pickShapeTool(seven)
        ws.dragChanged(from: Self.a, to: Self.b)
        #expect(ws.draft?.shape.path == (try Self.kernel(seven, Self.a, Self.b)))
        #expect(ws.draft?.shape.points.count == 14)
        ws.cancelDrag()
        ws.pickShapeTool(ShapeIntent.kind(.arrow).applied(to: ws.shapeTool))
        ws.dragChanged(from: Self.a, to: Self.b)
        #expect(ws.draft?.shape.path == (try Self.kernel(ws.shapeTool, Self.a, Self.b)))
        #expect(ws.draft?.shape.closed == false, "an arrow draft is open")
    }

    @Test func theLiveDragCopyShowsTheStar() throws {
        var live = FlareLiveDrag(on: Self.shapeTool())
        live.move(StageDragSample(start: Self.a, end: Self.p(200, 130)))
        live.move(StageDragSample(start: Self.a, end: Self.b))
        #expect(live.stageMarks.draft == (try Self.kernel(.defaults(.star), Self.a, Self.b)))
    }

    @Test func aClickDraftsNothingAndMouseUpAddsNothingUntilFS6() {
        var ws = Self.shapeTool()
        let layers = ws.layers.count
        ws.dragChanged(from: Self.a, to: Self.a)
        #expect(ws.draft == nil, "a click is not a drag")
        ws.dragChanged(from: Self.a, to: Self.b)
        ws.endDrag()
        #expect(ws.draft == nil && ws.stageMarks.draft == nil)
        #expect(ws.layers.count == layers && !ws.canUndo, "drawing waits on FS-6")
    }
}

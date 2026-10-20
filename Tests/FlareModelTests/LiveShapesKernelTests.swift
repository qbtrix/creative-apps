// LiveShapesKernelTests.swift: FS-5 of the shape-tools packet (docs/blueprints/flare/features/shape-tools.md). Every
// kind's draft is the kernel's `ShapeRules.path` of `ShapeRules.dragged` (rule 20: the kernel is canonical);
// Rectangle with Shift still squares; Option draws from the centre; a line is open.
import FlareCore
import FlareModel
import SuiteKernel
import Testing

@Suite struct LiveShapesKernelTests {
    private let live = LiveShapes()
    private func p(_ x: Double, _ y: Double) -> Point { Point(x: x, y: y) }

    /// The kernel's own drawing of the drag: the reference every draft must equal.
    private func kernel(_ kind: ShapeKind, _ a: Point, _ b: Point, _ keys: EditModifiers = []) throws -> Path {
        let (box, spec) = try #require(ShapeRules.dragged(kind, from: a, to: b, modifiers: keys))
        return try ShapeRules.path(spec, in: box)
    }

    @Test func everyKindDraftsTheKernelPath() throws {
        for kind in ShapeKind.allCases {
            for (keys, editKeys) in [([], []), (.shift, .shift), (.option, .option),
                                     ([.shift, .option], [.shift, .option])] as [(DragModifiers, EditModifiers)] {
                let shape = try #require(LiveShapes.shape(.defaults(kind), from: p(100, 100), to: p(300, 160),
                                                          modifiers: keys), "\(kind)")
                #expect(shape.path == (try kernel(kind, p(100, 100), p(300, 160), editKeys)), "\(kind) \(keys)")
            }
        }
    }

    @Test func toolDraftsAreTheKernelRectangleAndEllipse() throws {
        for (tool, kind) in [(FlareTool.rectangle, ShapeKind.rectangle), (.ellipse, .ellipse)] {
            let draft = try #require(live.draft(tool, from: p(10, 20), to: p(90, 50), modifiers: [], previous: nil))
            #expect(draft.tool == tool && draft.shape.closed)
            #expect(draft.shape.path == (try kernel(kind, p(10, 20), p(90, 50))))
        }
    }

    @Test func rectangleShiftSquares() throws {
        let draft = try #require(live.draft(.rectangle, from: p(100, 100), to: p(300, 160), modifiers: .shift,
                                            previous: nil))
        #expect(draft.shape.path == (try PathBuilders.rectangle(in: Rect(minX: 100, minY: 100, maxX: 300, maxY: 300))))
    }

    @Test func optionFromCentre() throws {
        let draft = try #require(live.draft(.rectangle, from: p(100, 100), to: p(130, 120), modifiers: .option,
                                            previous: nil))
        #expect(draft.shape.path == (try PathBuilders.rectangle(in: Rect(minX: 70, minY: 80, maxX: 130, maxY: 120))))
        let star = try #require(LiveShapes.shape(.defaults(.star), from: p(0, 0), to: p(50, 50), modifiers: .option))
        #expect(star.path == (try PathBuilders.star(in: Rect(minX: -50, minY: -50, maxX: 50, maxY: 50), points: 5,
                                                    innerRatio: 0.5)))
    }

    @Test func lineIsOpen() throws {
        let line = try #require(LiveShapes.shape(.defaults(.line), from: p(10, 10), to: p(60, 40), modifiers: []))
        #expect(!line.closed && line.points == [p(10, 10), p(60, 40)])
        #expect(line.path?.elements.contains(.close) == false)
        let arrow = try #require(LiveShapes.shape(.defaults(.arrow), from: p(10, 10), to: p(60, 40), modifiers: []))
        #expect(!arrow.closed)
    }

    @Test func anEmptyDragDraftsNothing() {
        #expect(live.draft(.rectangle, from: p(5, 5), to: p(5, 50), modifiers: [], previous: nil) == nil)
        #expect(LiveShapes.shape(.defaults(.star), from: p(5, 5), to: p(5, 5), modifiers: []) == nil)
        #expect(LiveShapes.shape(.defaults(.line), from: p(5, 5), to: p(5, 50), modifiers: []) != nil)
    }
}

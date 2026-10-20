// ShapeCommandsTests.swift: shape.draw and tool.shape (shape-tools SH-1, SH-6) on a small ShapeTarget, and ShapeIntent.
import Testing
import SuiteKernel

struct ShapeBoard: ShapeTarget {
    var shapes: [(id: String, spec: ShapeSpec, box: Rect)] = []
    var history = History<Int>()
    var shapeHelp: String? = nil, shapeTool = ShapeSpec.defaults(.rectangle)
    mutating func pickShapeTool(_ spec: ShapeSpec) { shapeTool = spec }
    mutating func addShape(_ spec: ShapeSpec, in box: Rect, name: String) throws -> String {
        shapes.append(("shape-\(shapes.count + 1)", spec, box))
        history.record(name, shapes.count - 1)
        history.endRun()
        return "shape-\(shapes.count)"
    }
    static let catalog = try? CommandCatalog<ShapeBoard>(app: "shapes", ShapeCommands.specs(ShapeBoard.self), history: { $0.history })
    static func draw(_ kind: String, _ extra: [String: JSONValue] = [:], w: Double = 100) -> JSONValue {
        .object(["kind": .string(kind), "x": .number(0), "y": .number(0), "w": .number(w), "h": .number(w)].merging(extra) { $1 })
    }
}

@Suite struct ShapeCommandsTests {
    @Test func specsDeclareTheTwoCommands() throws {
        let catalog = try #require(ShapeBoard.catalog)
        #expect(catalog.ids == ["shape.draw", "tool.shape"])
        #expect(catalog.describe("shape.draw")?.kind == .edit && catalog.describe("tool.shape")?.kind == .view)
        let closed = ShapeBoard(shapeHelp: "Open a document first.")
        #expect(catalog.availability("shape.draw", on: closed).why == "Open a document first.")
        #expect(catalog.availability("tool.shape", on: closed).why == "Open a document first.")
    }

    @Test func drawIsOneStep() throws {
        let catalog = try #require(ShapeBoard.catalog)
        var board = ShapeBoard()
        let outcome = try catalog.run("shape.draw", params: ShapeBoard.draw("star", ["points": .number(5)]), on: &board)
        #expect(outcome.undoStep == "Draw Star" && board.history.steps == ["Draw Star"])
        #expect(outcome.result == .object(["id": .string("shape-1")]))
        #expect(board.shapes.first?.spec.kind == .star && board.shapes.first?.spec.points == 5)
    }
    @Test func refusesBadSpec() throws {
        let catalog = try #require(ShapeBoard.catalog)
        var board = ShapeBoard()
        let cases = [(ShapeBoard.draw("polygon", ["sides": .number(2)]), "A polygon needs 3 to 64 sides."),
                     (ShapeBoard.draw("star", w: 0), "Draw a shape larger than nothing.")]
        for (params, help) in cases {
            let error = #expect(throws: CatalogError.self) { try catalog.run("shape.draw", params: params, on: &board) }
            #expect(error.map { String(describing: $0).contains(help) } == true)
        }
        #expect(board.shapes.isEmpty && board.history.steps.isEmpty)
    }
    @Test func toolIsViewOnly() throws {
        let catalog = try #require(ShapeBoard.catalog)
        var board = ShapeBoard()
        let outcome = try catalog.run("tool.shape", params: .object(["kind": .string("star"), "points": .number(8)]), on: &board)
        #expect(outcome.undoStep == nil && board.history.steps.isEmpty)
        #expect(board.shapeTool.kind == .star && board.shapeTool.points == 8)
        #expect(ShapeIntent.points(8).applied(to: .defaults(.star)).points == 8 && ShapeIntent.points(8).command.id == "tool.shape")
        _ = try catalog.run("tool.shape", params: .object(["kind": .string("polygon")]), on: &board)
        #expect(board.shapeTool.kind == .polygon && board.shapeTool.points == 8, "a kind change keeps the other options")
        #expect(throws: CatalogError.self) { try catalog.run("tool.shape", params: .object(["kind": .string("star"), "points": .number(2)]), on: &board) }
        #expect(board.shapeTool.points == 8)
    }
    @Test func drawKeepsTheParams() throws {
        let catalog = try #require(ShapeBoard.catalog)
        var board = ShapeBoard()
        let params = ShapeBoard.draw("arrow", ["head": .number(20), "x1": .number(0), "y1": .number(1), "x2": .number(1), "y2": .number(0)])
        #expect(try catalog.run("shape.draw", params: params, on: &board).undoStep == "Draw Arrow")
        let drawn = try #require(board.shapes.first)
        #expect(drawn.box == Rect(minX: 0, minY: 0, maxX: 100, maxY: 100) && drawn.spec.head == 20)
        #expect(drawn.spec.start == Point(x: 0, y: 1) && drawn.spec.end == Point(x: 1, y: 0) && drawn.spec.points == 5)
    }
    @Test func intentsChangeOneOption() {
        let spec = ShapeSpec.defaults(.rectangle)
        #expect(ShapeIntent.kind(.star).applied(to: spec).kind == .star && ShapeIntent.sides(7).applied(to: spec).sides == 7)
        #expect(ShapeIntent.innerRatio(0.3).applied(to: spec).innerRatio == 0.3 && ShapeIntent.cornerRadius(4).applied(to: spec).cornerRadius == 4)
        #expect(ShapeIntent.head(30).applied(to: spec) == ShapeSpec(kind: .rectangle, head: 30))
        #expect(ShapeIntent.kind(.ellipse).command.params == .object(["kind": .string("ellipse")]))
        #expect(ShapeIntent.sides(6).command.params == .object(["kind": .string("polygon"), "sides": .number(6)]))
        #expect(ShapeIntent.innerRatio(0.3).command.params == .object(["kind": .string("star"), "innerRatio": .number(0.3)]))
        #expect(ShapeIntent.cornerRadius(4).command.params == .object(["kind": .string("rectangle"), "cornerRadius": .number(4)]))
        #expect(ShapeIntent.head(9).command.params == .object(["kind": .string("arrow"), "head": .number(9)]))
    }
}

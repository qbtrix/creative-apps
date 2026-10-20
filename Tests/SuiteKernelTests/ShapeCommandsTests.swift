// ShapeCommandsTests.swift: shape.draw and tool.shape (shape-tools SH-1, SH-6).
// The SH-6 acceptance rows run on a small ShapeTarget with a History; they
// wait, disabled by name, until SH-6 fills ShapeCommands.
import Testing
import SuiteKernel

/// A target that keeps its shapes and the tool's options, with one history.
struct ShapeBoard: ShapeTarget {
    var shapes: [(id: String, spec: ShapeSpec, box: Rect)] = []
    var history = History<Int>()
    var shapeHelp: String? = nil
    var shapeTool = ShapeSpec.defaults(.rectangle)
    mutating func pickShapeTool(_ spec: ShapeSpec) { shapeTool = spec }
    mutating func addShape(_ spec: ShapeSpec, in box: Rect, name: String) throws -> String {
        let id = "shape-\(shapes.count + 1)"
        shapes.append((id, spec, box))
        history.record(name, shapes.count - 1)
        history.endRun()
        return id
    }
    static let catalog = try? CommandCatalog<ShapeBoard>(app: "shapes", ShapeCommands.specs(ShapeBoard.self), history: { $0.history })
}

@Suite struct ShapeCommandsTests {
    @Test func specsDeclareTheTwoCommands() throws {
        let catalog = try #require(ShapeBoard.catalog)
        #expect(catalog.ids == ["shape.draw", "tool.shape"])
        #expect(catalog.describe("shape.draw")?.kind == .edit && catalog.describe("tool.shape")?.kind == .view)
        var closed = ShapeBoard(); closed.shapeHelp = "Open a document first."
        #expect(catalog.availability("shape.draw", on: closed).why == "Open a document first.")
        #expect(catalog.availability("tool.shape", on: closed).why == "Open a document first.")
    }

    @Test(.disabled("waits on SH-6")) func drawIsOneStep() throws {
        let catalog = try #require(ShapeBoard.catalog)
        var board = ShapeBoard()
        let params: JSONValue = .object(["kind": .string("star"), "points": .number(5), "innerRatio": .number(0.5),
                                         "x": .number(0), "y": .number(0), "w": .number(100), "h": .number(100)])
        let outcome = try catalog.run("shape.draw", params: params, on: &board)
        #expect(outcome.undoStep == "Draw Star" && board.history.steps == ["Draw Star"])
        #expect(outcome.result == .object(["id": .string("shape-1")]))
        #expect(board.shapes.first?.spec.kind == .star && board.shapes.first?.spec.points == 5)
    }

    @Test(.disabled("waits on SH-6")) func refusesBadSpec() throws {
        let catalog = try #require(ShapeBoard.catalog)
        var board = ShapeBoard()
        let params: JSONValue = .object(["kind": .string("polygon"), "sides": .number(2),
                                         "x": .number(0), "y": .number(0), "w": .number(100), "h": .number(100)])
        #expect(throws: CatalogError.self) { try catalog.run("shape.draw", params: params, on: &board) }
        do { _ = try catalog.run("shape.draw", params: params, on: &board) } catch {
            #expect(error.description.contains("A polygon needs 3 to 64 sides."))
        }
        let empty: JSONValue = .object(["kind": .string("star"), "x": .number(5), "y": .number(5), "w": .number(0), "h": .number(0)])
        do { _ = try catalog.run("shape.draw", params: empty, on: &board) } catch {
            #expect(error.description.contains("Draw a shape larger than nothing."))
        }
        #expect(board.shapes.isEmpty && board.history.steps.isEmpty)
    }

    @Test(.disabled("waits on SH-6")) func toolIsViewOnly() throws {
        let catalog = try #require(ShapeBoard.catalog)
        var board = ShapeBoard()
        let outcome = try catalog.run("tool.shape", params: .object(["kind": .string("star"), "points": .number(8)]), on: &board)
        #expect(outcome.undoStep == nil && board.history.steps.isEmpty)
        #expect(board.shapeTool.kind == .star && board.shapeTool.points == 8)
        let intent = ShapeIntent.points(8)
        #expect(intent.applied(to: .defaults(.star)).points == 8 && intent.command.id == "tool.shape")
    }
}

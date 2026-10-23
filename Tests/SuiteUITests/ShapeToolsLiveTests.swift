// ShapeToolsLiveTests.swift (shape-tools SH-7): the gallery's `shape-tools` page
// on live. Its board is a local ShapeTarget with a History: a drag on the page
// draws through `shape.draw` as one undo step named for the kind, the options
// go through `tool.shape` and record nothing, a zero-length drag draws nothing,
// and each drawn shape paints its `ShapeRules.path`. macOS only (SuiteUI).
import SuiteKernel
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor @Suite struct ShapeToolsLiveTests {
    @Test func aDragDrawsThroughShapeDrawAsOneStep() throws {
        var board = GalleryShapeBoard()
        #expect(board.pick(.kind(.star)).hasPrefix("tool.shape"))
        #expect(board.pick(.points(8)).hasPrefix("tool.shape"))
        #expect(board.history.steps.isEmpty, "tool.shape is view state")
        let line = board.drag(from: Point(x: 20, y: 20), to: Point(x: 120, y: 100), modifiers: [])
        #expect(line.hasPrefix("drag star 100 x 80: shape.draw"), "the page stays on the local log: \(line)")
        #expect(board.history.steps == ["Draw Star"])
        let drawn = try #require(board.shapes.first)
        #expect(board.shapes.count == 1 && drawn.id == "shape-1")
        #expect(drawn.spec.kind == .star && drawn.spec.points == 8 && drawn.spec.innerRatio == 0.5)
        #expect(drawn.box == Rect(minX: 20, minY: 20, maxX: 120, maxY: 100))
    }

    @Test func shiftAndArrowEndsReachTheCommand() throws {
        var board = GalleryShapeBoard()
        _ = board.pick(.kind(.arrow))
        _ = board.drag(from: Point(x: 0, y: 100), to: Point(x: 100, y: 10), modifiers: .shift)
        #expect(board.history.steps == ["Draw Arrow"])
        let arrow = try #require(board.shapes.first)
        #expect(arrow.spec.kind == .arrow && arrow.spec.head == ShapeSpec.defaults(.arrow).head)
        #expect(arrow.spec.start != arrow.spec.end, "the line's ends reach shape.draw")
        _ = board.pick(.kind(.rectangle))
        _ = board.drag(from: Point(x: 0, y: 0), to: Point(x: 40, y: 30), modifiers: .shift)
        #expect(board.shapes.last?.box == Rect(minX: 0, minY: 0, maxX: 40, maxY: 40))
        #expect(board.history.steps == ["Draw Arrow", "Draw Rectangle"])
    }

    @Test func aClickDrawsNothing() {
        var board = GalleryShapeBoard()
        let line = board.drag(from: Point(x: 30, y: 30), to: Point(x: 30, y: 30), modifiers: [])
        #expect(board.shapes.isEmpty && board.history.steps.isEmpty)
        #expect(line.contains("nothing"))
    }

    @Test func eachShapePaintsItsPath() {
        var board = GalleryShapeBoard()
        for kind in ShapeKind.allCases {
            _ = board.pick(.kind(kind))
            _ = board.drag(from: Point(x: 10, y: 10), to: Point(x: 90, y: 70), modifiers: [])
        }
        #expect(board.history.steps.count == ShapeKind.allCases.count)
        for shape in board.shapes {
            let path = GalleryShapeBoard.painted(shape)
            #expect(!path.isEmpty, "\(shape.spec.kind) paints nothing")
            #expect(path.boundingRect.maxX <= 90 + 1e-6, "\(shape.spec.kind) paints past its box")
        }
    }
}

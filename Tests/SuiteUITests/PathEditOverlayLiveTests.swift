// PathEditOverlayLiveTests.swift (pen-paths PN-8): the gallery's `pen-paths` page on live. Its board is a local
// PathEditTarget with a History: each overlay intent runs through `PathCommands` in the board's catalog, so an anchor
// drag of many moves under one token is one `Move Points` step that one undo takes back, and the log line names the
// command and the step. macOS only (SuiteUI).
import SuiteKernel
@testable import SuiteUI
import Testing

@MainActor @Suite struct PathEditOverlayLiveTests {
    static let first = AnchorRef(contour: 0, index: 0)

    /// The sample's first anchor, on the board's path in edit.
    static func firstPoint(_ board: GalleryPenBoard) -> Point? { board.pathInEdit?.path.contours.first?.anchors.first?.point }

    /// Press on an anchor, then 30 moves under one token: one step, the anchor where the drag ended, one undo back.
    @Test func anAnchorDragIsOneUndoStep() {
        var board = GalleryPenBoard()
        #expect(board.pathInEdit == GalleryPenPaths.sample && board.history.steps.isEmpty)
        let picked = board.send(.select(anchors: [Self.first], rect: nil, extend: false))
        #expect(picked.hasPrefix("path.anchor-select ") && board.anchorSelection.ordered == [Self.first], "\(picked)")
        var line = ""
        for _ in 1...30 { line = board.send(.move(dx: 1, dy: 0, drag: "drag-1")) }
        #expect(line.hasPrefix("path.anchor-move ") && line.contains("Move Points, 1 in History"), "the page stays on the local log: \(line)")
        #expect(board.history.steps == ["Move Points"])
        #expect(Self.firstPoint(board) == Point(x: 290, y: 80))
        let undone = board.undo()
        #expect(undone && board.pathInEdit == GalleryPenPaths.sample && !board.history.canUndo)
    }

    /// A handle drag under one token is one `Move Handle` step; a second drag token is a second step.
    @Test func eachDragTokenIsOneStep() {
        var board = GalleryPenBoard()
        let smooth = AnchorRef(contour: 0, index: 1)
        for i in 0..<20 { _ = board.send(.handle(smooth, .handleOut, to: Point(x: 430, y: 180 + Double(i)), breaking: false, drag: "d1")) }
        _ = board.send(.selectAll)
        for _ in 0..<5 { _ = board.send(.move(dx: 0, dy: 2, drag: "d2")) }
        #expect(board.history.steps == ["Move Handle", "Move Points"])
        #expect(Self.firstPoint(board) == Point(x: 260, y: 90))
    }

    /// Three Pen clicks are view commands with no step; closing adds the path as one `Add Path` step beside the sample.
    @Test func thePenClosesIntoOneAddPathStep() {
        var board = GalleryPenBoard()
        for (x, y) in [(40.0, 40.0), (120.0, 40.0), (120.0, 140.0)] {
            let line = board.send(.penAdd(Point(x: x, y: y), handleOut: nil))
            #expect(line.hasPrefix("path.pen-add ") && line.contains("no step"), "\(line)")
        }
        #expect(board.penDraft?.contour.anchors.count == 3 && board.history.steps.isEmpty)
        let closed = board.send(.close)
        #expect(closed.hasPrefix("path.close ") && closed.contains("Add Path, 1 in History"), "\(closed)")
        #expect(board.penDraft == nil && board.shapes.added.first?.contours.first?.closed == true)
        #expect(board.pathInEdit == GalleryPenPaths.sample)
        let undone = board.undo()
        #expect(undone && board.shapes.added.isEmpty)
    }

    /// An intent the commands refuse logs why and records nothing: Delete with no point selected.
    @Test func aRefusedIntentLogsWhy() {
        var board = GalleryPenBoard()
        let line = board.send(.remove)
        #expect(line.hasPrefix("path.anchor-remove ") && line.contains("refused"), "\(line)")
        #expect(board.pathInEdit == GalleryPenPaths.sample && board.history.steps.isEmpty)
    }
}

// StrokeEditorLiveTests.swift (stroke-style SS-9): the gallery's `stroke-editor` page on live. Its board is a local
// StrokeTarget with a History: each StrokeEditor intent runs as its stroke command through the board's catalog, a
// scrub under one drag token is one undo step, dash and trim change the stroke (no local-only logging), and the
// preview paints StrokeRules.paintedPath, trimmed then dashed. macOS only (SuiteUI).
import CoreGraphics
import SuiteKernel
@testable import SuiteUI
import Testing

@MainActor @Suite struct StrokeEditorLiveTests {
    /// A Width scrub of several samples under one token leaves one `Stroke Width` step; one undo puts 2 pt back.
    @Test func aWidthScrubIsOneUndoStep() {
        var board = GalleryStrokeBoard()
        #expect(board.stroke == VectorStroke(width: 2) && board.history.steps.isEmpty)
        for width in [3.0, 4, 5, 6] {
            let line = board.send(.width(width, drag: "scrub"))
            #expect(line.hasPrefix("stroke.width"), "\(line)")
        }
        #expect(board.stroke?.width == 6)
        #expect(board.history.steps == ["Stroke Width"], "the page stays on the local log")
        let undone = board.undo()
        #expect(undone && board.stroke?.width == 2)
        let undoneAgain = board.undo()
        #expect(!undoneAgain)
    }

    /// Dashed scales by the width, Custom keeps its pattern, and a Trim End scrub saves fractions as one step.
    @Test func dashAndTrimRunLive() {
        var board = GalleryStrokeBoard()
        let dashed = board.send(.dash(.dashed, pattern: nil))
        #expect(dashed.hasPrefix("stroke.dash") && !dashed.contains("refused"), "\(dashed)")
        #expect(board.stroke?.dash == [8, 4])
        _ = board.send(.dash(.custom, pattern: [10, 4]))
        #expect(board.stroke?.dash == [10, 4])
        for end in [0.8, 0.6, 0.4] { _ = board.send(.trim(start: 0, end: end, offset: 0, drag: "trim")) }
        #expect(board.stroke?.trim?.end == 0.4 && board.stroke?.trim?.start == 0)
        #expect(board.history.steps == ["Stroke Dash", "Stroke Dash", "Trim Path"])
        let undone = board.undo()
        #expect(undone && board.stroke?.trim == nil && board.stroke?.dash == [10, 4])
    }

    /// Remove clears the stroke and Add brings a 1 pt black one back, each one step.
    @Test func removeThenAdd() {
        var board = GalleryStrokeBoard()
        _ = board.send(.remove)
        #expect(board.stroke == nil)
        let added = board.send(.add)
        #expect(added.hasPrefix("stroke.add"), "\(added)")
        #expect(board.stroke == VectorStroke())
        #expect(board.history.steps == ["Remove Stroke", "Add Stroke"])
    }

    /// A command that can't run is refused in the log and leaves the stroke and the History as they were.
    @Test func aRefusalChangesNothing() {
        var board = GalleryStrokeBoard(stroke: nil)
        let line = board.send(.width(4, drag: nil))
        #expect(line.hasPrefix("stroke.width") && line.contains("refused"), "\(line)")
        #expect(board.stroke == nil && board.history.steps.isEmpty)
    }

    /// The preview paints the painted path: one run when solid, several when dashed, none when trimmed to nothing.
    @Test func thePreviewPaintsTheTrimmedThenDashedPath() {
        let size = CGSize(width: 400, height: 300)
        func runs(_ stroke: VectorStroke) -> Int {
            GalleryStrokeEditor.painted(stroke, in: size).elements.filter { if case .move = $0 { true } else { false } }.count
        }
        var stroke = VectorStroke(width: 2)
        #expect(runs(stroke) == 1)
        stroke.dash = [8, 4]
        #expect(runs(stroke) > 1)
        var board = GalleryStrokeBoard(stroke: stroke)
        _ = board.send(.trim(start: 0.5, end: 0.5, offset: 0, drag: nil))
        #expect(board.stroke.map(runs) == 0)
        #expect(GalleryStrokeEditor.applied(.width(6, drag: nil), to: VectorStroke(width: 2))?.width == 6)
    }
}

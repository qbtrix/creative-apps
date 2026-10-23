// EyedropperLiveTests.swift (eyedropper EY-7): the gallery's `eyedropper` page on live. Its board is a local
// SampleTarget with a History: the page's tool samples the canvas through `color.sample` in the board's
// catalog, and the row takes the sampled colour as one `Sample Colour` step that one undo puts back. A row
// pick (the screen sampler or the hex field) is one `Colour` step however many changes it sends. The canvas
// reads what it draws: the swatches over white paper, the black one at half opacity. macOS only (SuiteUI).
import CoreGraphics
import SuiteKernel
@testable import SuiteUI
import Testing

@MainActor @Suite struct EyedropperLiveTests {
    /// The centre of swatch `id` in canvas points.
    static func centre(_ id: String) -> CGPoint {
        guard let rect = GalleryEyedropperBoard.swatches.first(where: { $0.id == id })?.rect else { return .zero }
        return CGPoint(x: (rect.minX + rect.maxX) / 2, y: (rect.minY + rect.maxY) / 2)
    }

    /// A click on green samples through color.sample and sets the row as one step; one undo puts blue back.
    @Test func theToolSamplesThroughColorSample() {
        var board = GalleryEyedropperBoard()
        #expect(board.color == HexColor(0, 0, 255) && board.history.steps.isEmpty)
        let line = board.sample(at: Self.centre("green"))
        #expect(line.hasPrefix("color.sample {"), "the page stays on the local log: \(line)")
        #expect(line.contains("\"size\":1") && line.contains("#00FF00"), "\(line)")
        #expect(board.color == HexColor(0, 255, 0))
        #expect(board.history.steps == ["Sample Colour"])
        let undone = board.undo()
        #expect(undone && board.color == HexColor(0, 0, 255))
        let undoneAgain = board.undo()
        #expect(!undoneAgain)
    }

    /// The canvas reads what a person sees: red, the paper between swatches, half black over white.
    @Test func theCanvasReadsWhatItDraws() {
        let board = GalleryEyedropperBoard()
        #expect(board.loupeColor(at: Self.centre("red")) == HexColor(255, 0, 0))
        #expect(board.loupeColor(at: CGPoint(x: 1, y: 1)) == HexColor(255, 255, 255))
        #expect(board.loupeColor(at: Self.centre("black")) == HexColor(128, 128, 128))
        #expect(board.loupeColor(at: CGPoint(x: -10, y: 5)) == nil)
        #expect(board.loupeColor(at: CGPoint(x: Double.nan, y: 5)) == nil)
    }

    /// 5 × 5 at green's left edge reads the mean of green and the paper beside it, not green.
    @Test func fiveByFiveAtTheEdgeReadsTheMean() {
        var board = GalleryEyedropperBoard()
        let chosen = board.choose(size: .fiveByFive)
        #expect(chosen == "size 5 × 5")
        guard let green = GalleryEyedropperBoard.swatches.first(where: { $0.id == "green" })?.rect else {
            Issue.record("no green swatch")
            return
        }
        let edge = CGPoint(x: green.minX, y: (green.minY + green.maxY) / 2)
        let line = board.sample(at: edge)
        #expect(line.contains("\"size\":5"), "\(line)")
        #expect(board.color == HexColor(102, 255, 102), "the 5 × 5 mean: 2 columns of paper, 3 of green")
    }

    /// Empty space samples nothing: the row and the History stay as they were.
    @Test func emptySpaceChangesNothing() {
        var board = GalleryEyedropperBoard()
        let line = board.sample(at: CGPoint(x: -20, y: -20))
        #expect(line.hasPrefix("color.sample") && line.contains("no colour"), "\(line)")
        #expect(board.color == HexColor(0, 0, 255) && board.history.steps.isEmpty)
    }

    /// A row pick is one step however many changes it sends; the tool's sample after it is a second.
    @Test func aRowPickIsOneStep() {
        var board = GalleryEyedropperBoard()
        let first = board.pick(HexColor(255, 0, 0))
        #expect(first == "change #FF0000")
        let second = board.pick(HexColor(250, 0, 0))
        #expect(second == "change #FA0000")
        let ended = board.endPick()
        #expect(ended == "end")
        _ = board.sample(at: Self.centre("green"))
        #expect(board.history.steps == ["Colour", "Sample Colour"])
        let firstUndo = board.undo()
        #expect(firstUndo && board.color == HexColor(250, 0, 0))
        let secondUndo = board.undo()
        #expect(secondUndo && board.color == HexColor(0, 0, 255))
    }
}

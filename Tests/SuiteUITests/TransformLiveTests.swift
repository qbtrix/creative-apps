// TransformLiveTests.swift (transform-tools TT-7): the gallery's `transform-handles`
// page on live. Its board is a local TransformTarget with a History, and every
// gesture runs through TransformCommands' catalog: a knob drag is one `Rotate`
// step however many samples it sends, a handle drag one `Transform` step, the
// rows' flip one `Flip Horizontal`, and one undo puts the box back. Each line
// the page logs names the command. macOS only (SuiteUI).
import SuiteKernel
@testable import SuiteUI
import Testing

@MainActor @Suite struct TransformLiveTests {
    /// The page's box: 200 × 120 at (100, 80).
    static let start = TransformBox(box: Rect(minX: 100, minY: 80, maxX: 300, maxY: 200))

    /// A knob drag of 60 samples to a quarter turn is one undo step, and one undo turns it back.
    @Test func aKnobDragLeavesOneUndoStep() {
        var board = GalleryTransformBoard()
        #expect(board.item == Self.start && board.history.steps.isEmpty)
        for n in 1...60 {
            let line = board.knob(turned: Double(n) * 1.5)
            #expect(line.hasPrefix("transform.rotate"), "the page stays on the local log: \(line)")
        }
        let ended = board.end()
        #expect(ended.contains("ends"))
        #expect(board.history.steps == ["Rotate"])
        #expect(abs(board.item.degrees - 90) < 1e-9 && board.item.box == Self.start.box)
        let undone = board.undo()
        #expect(undone && board.item == Self.start)
        let undoneAgain = board.undo()
        #expect(!undoneAgain)
    }

    /// Two knob drags are two steps: the end of a drag closes its run.
    @Test func eachDragIsItsOwnStep() {
        var board = GalleryTransformBoard()
        _ = board.knob(turned: 30)
        _ = board.end()
        _ = board.knob(turned: 15)
        _ = board.knob(turned: 30)
        _ = board.end()
        #expect(board.history.steps == ["Rotate", "Rotate"])
        #expect(abs(board.item.degrees - 60) < 1e-9)
    }

    /// A handle drag runs transform.set, keeps the turn, and is one step.
    @Test func aHandleDragIsOneTransformStep() {
        var board = GalleryTransformBoard()
        _ = board.knob(turned: 90)
        _ = board.end()
        for w in stride(from: 210.0, through: 240, by: 10) {
            let line = board.resize(to: Rect(minX: 100, minY: 80, maxX: 100 + w, maxY: 200))
            #expect(line.hasPrefix("transform.set"), "\(line)")
        }
        _ = board.end()
        #expect(board.history.steps == ["Rotate", "Transform"])
        #expect(board.item.box.width == 240 && abs(board.item.degrees - 90) < 1e-9)
    }

    /// The rows' intents run through the catalog: Flip Horizontal negates the turn, one step named for it.
    @Test func theRowsRunTheirCommands() {
        var board = GalleryTransformBoard()
        _ = board.knob(turned: 90)
        _ = board.end()
        let line = board.send(.flip(.horizontal))
        #expect(line.hasPrefix("transform.flip"), "\(line)")
        #expect(board.item.flipX && abs(board.item.degrees + 90) < 1e-9)
        _ = board.send(.rotate(by: 15, drag: nil))
        #expect(board.history.steps == ["Rotate", "Flip Horizontal", "Rotate"])
        let refused = board.send(.set(TransformBox(box: Rect(minX: 0, minY: 0, maxX: 0, maxY: 10)), drag: nil))
        #expect(refused.contains("refused"))
        #expect(board.history.steps.count == 3)
    }
}

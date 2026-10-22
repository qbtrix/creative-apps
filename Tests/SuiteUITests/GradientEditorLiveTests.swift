// GradientEditorLiveTests.swift (gradient-fill GF-8): the gallery's `gradient-editor` page on live. Its board is a
// local GradientFillTarget with a History: each editor intent runs through `GradientCommands` in the board's catalog,
// so a stop drag of many moves under one token is one `Move Gradient Stop` step that one undo takes back, and the
// log line names the command and the step. macOS only (SuiteUI).
import SuiteKernel
@testable import SuiteUI
import Testing

@MainActor @Suite struct GradientEditorLiveTests {
    /// A stop drag sends 30 moves under one token: one step, the stop where the drag ended, one undo back to the start.
    @Test func aStopDragIsOneUndoStep() {
        var board = GalleryGradientBoard()
        #expect(board.fill == GalleryGradientEditor.start && board.history.steps.isEmpty)
        var line = ""
        for i in 1...30 { line = board.send(.move(index: 0, offset: Double(i) / 100, drag: "drag-1")) }
        #expect(line.hasPrefix("fill.stop-move ") && line.contains("Move Gradient Stop"), "the page stays on the local log: \(line)")
        #expect(board.history.steps == ["Move Gradient Stop"])
        #expect(board.fill.stops.first?.offset == 0.3)
        let undone = board.undo()
        #expect(undone && board.fill == GalleryGradientEditor.start && !board.history.canUndo)
    }

    /// An intent the commands refuse logs why and records nothing: a two-stop gradient keeps both stops.
    @Test func aRefusedIntentLogsWhy() {
        var board = GalleryGradientBoard()
        let line = board.send(.remove(index: 0))
        #expect(line.hasPrefix("fill.stop-remove ") && line.contains("refused"), "\(line)")
        #expect(board.fill == GalleryGradientEditor.start && board.history.steps.isEmpty)
    }

    /// Each intent is its own command: a type switch then an angle are two steps, named for their commands.
    @Test func eachIntentIsOneStep() {
        var board = GalleryGradientBoard()
        _ = board.send(.type(.radial))
        _ = board.send(.type(.linear))
        _ = board.send(.angle(90, drag: nil))
        #expect(board.history.steps == ["Fill Type", "Fill Type", "Gradient Angle"])
        #expect(abs((GradientRules.angle(of: board.fill) ?? 0) - 90) < 1e-9)
    }
}

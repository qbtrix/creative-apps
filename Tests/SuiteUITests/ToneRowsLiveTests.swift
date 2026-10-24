// ToneRowsLiveTests.swift (tone-controls TC-8): the gallery's `tone-rows` page on live. Its board is the CLI's
// fake-tone document with its History: each ToneRows intent runs through `ToneCommands` in that document's catalog,
// so a slider drag of many samples under one token is one undo step that one undo takes back, and the log line names
// the command and the step. macOS only (SuiteUI).
import SuiteImaging
import SuiteKernel
@testable import SuiteUI
import Testing

@MainActor @Suite struct ToneRowsLiveTests {
    /// A slider drag sends 30 samples under one token: one "Temperature" step, the value where the drag ended, one undo
    /// back to neutral.
    @Test func aSliderDragIsOneUndoStep() {
        var board = GalleryToneBoard()
        #expect(board.settings == .neutral && board.document.history.steps.isEmpty)
        var line = ""
        for n in 1...30 { line = board.send(.set(.temperature, Double(n), drag: "drag-1")) }
        #expect(line.hasPrefix("tone.set ") && line.contains("Temperature, 1 in History"), "the page stays on the local log: \(line)")
        #expect(board.document.history.steps == ["Temperature"] && board.settings.value(.temperature) == 30)
        #expect(board.undo() && board.settings == .neutral && !board.document.history.canUndo)
    }

    /// Auto and a section's Reset are one step each, named for their commands.
    @Test func autoAndResetAreOneStepEach() {
        var board = GalleryToneBoard()
        _ = board.send(.set(.shadows, 35, drag: nil))
        let auto = board.send(.auto)
        let reset = board.send(.reset(.tone))
        #expect(auto.hasPrefix("tone.auto ") && reset.hasPrefix("tone.reset "), "\(auto) / \(reset)")
        #expect(board.document.history.steps == ["Shadows", "Auto Tone", "Reset Tone"])
        #expect(board.settings.isNeutral(.tone))
    }

    /// A waiting slider is refused with its reason and records nothing.
    @Test func aRefusedIntentLogsWhy() {
        var board = GalleryToneBoard()
        let line = board.send(.set(.vibrance, 20, drag: nil))
        #expect(line.hasPrefix("tone.set ") && line.contains("refused"), "\(line)")
        #expect(board.settings == .neutral && board.document.history.steps.isEmpty)
    }
}

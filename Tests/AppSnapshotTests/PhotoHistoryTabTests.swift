// PhotoHistoryTabTests.swift (history-panel PH-3): the History tab of a Photo
// window follows the image's history and asks for each jump once. A click on
// a row, or Return on the row the arrows picked, sends exactly one
// `HistoryIntent.jump` with that row's state; a position outside the rows
// sends nothing. After an undo, a redo or a jump the tab's listing moves its
// current row, and the rows past it read "not applied" (the dimmed rows),
// with the step count unchanged. The picture of these states is PH-4's
// (PhotoHistorySnapshots). macOS only.
import CoreRaster
import PhotoModel
import SuiteKernel
import Testing

@testable import PhotoApp
@testable import SuiteUI

@MainActor
@Suite struct PhotoHistoryTabTests {
    /// An 8 x 8 new image turned `count` times, one "Rotate" step each.
    private func rotated(_ count: Int) throws -> PhotoWorkspace {
        var model = PhotoWorkspace()
        try model.newCanvas(width: 8, height: 8)
        for _ in 0..<count { model.rotateImage(.degrees90) }
        return model
    }

    /// The states the window was asked to jump to, in order.
    private func jumps(_ intents: [PhotoIntent]) -> [Int] {
        intents.compactMap { intent in
            if case .history(.jump(let index)) = intent { index } else { nil }
        }
    }

    // MARK: One jump per click

    @Test func aClickSendsOneJump() throws {
        var sent: [PhotoIntent] = []
        let tab = PhotoHistoryTab(model: try rotated(3), perform: { sent.append($0) })
        tab.panel.click(1)
        #expect(sent.count == 1)
        #expect(jumps(sent) == [1])
    }

    @Test func returnOnTheSelectedRowSendsOneJump() throws {
        var sent: [PhotoIntent] = []
        let tab = PhotoHistoryTab(model: try rotated(3), perform: { sent.append($0) })
        var cursor = HistoryPanelCursor(tab.listing)
        tab.panel.press(.up, on: &cursor)
        tab.panel.press(.up, on: &cursor)
        #expect(sent.isEmpty)
        tab.panel.press(.enter, on: &cursor)
        #expect(jumps(sent) == [1] && sent.count == 1)
    }

    @Test func aPositionOutsideTheRowsSendsNothing() throws {
        var sent: [PhotoIntent] = []
        let tab = PhotoHistoryTab(model: try rotated(2), perform: { sent.append($0) })
        tab.panel.click(-1)
        tab.panel.click(3)
        #expect(sent.isEmpty)
    }

    // MARK: The tab follows the listing

    @Test func listsTheBaseAndEveryStepWithTheLastCurrent() throws {
        let tab = PhotoHistoryTab(model: try rotated(3), perform: { _ in })
        #expect(tab.listing == HistoryListing(base: "New Image", steps: ["Rotate", "Rotate", "Rotate"], index: 3, savedIndex: 0))
        #expect(HistoryPanel.label(at: 3, in: tab.listing) == "Step 3 of 3, Rotate, applied")
    }

    @Test func followsAnUndoAndARedo() throws {
        var model = try rotated(3)
        model.undo()
        let undone = PhotoHistoryTab(model: model, perform: { _ in }).listing
        #expect(undone.index == 2 && undone.steps.count == 3)
        #expect(HistoryPanel.label(at: 2, in: undone) == "Step 2 of 3, Rotate, applied")
        #expect(HistoryPanel.label(at: 3, in: undone) == "Step 3 of 3, Rotate, not applied")
        model.redo()
        let redone = PhotoHistoryTab(model: model, perform: { _ in }).listing
        #expect(redone.index == 3 && redone.steps.count == 3)
        #expect(HistoryPanel.label(at: 3, in: redone) == "Step 3 of 3, Rotate, applied")
    }

    @Test func followsAJump() throws {
        var model = try rotated(3)
        model.jumpToHistoryStep(1)
        let jumped = PhotoHistoryTab(model: model, perform: { _ in }).listing
        #expect(jumped.index == 1 && jumped.steps.count == 3)
        #expect(HistoryPanel.label(at: 1, in: jumped) == "Step 1 of 3, Rotate, applied")
        #expect(HistoryPanel.label(at: 2, in: jumped) == "Step 2 of 3, Rotate, not applied")
        #expect(HistoryPanel.label(at: 3, in: jumped) == "Step 3 of 3, Rotate, not applied")
        model.jumpToHistoryStep(0)
        let base = PhotoHistoryTab(model: model, perform: { _ in }).listing
        #expect(base.index == 0 && HistoryPanel.label(at: 0, in: base) == "New Image, saved, applied")
    }
}

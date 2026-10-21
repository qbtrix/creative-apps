// HistoryPanelTests.swift (autosave-history AH-3): HistoryPanel over the gallery's listing, "Open" and eleven steps,
// the eighth current. A click on a row jumps to it once; Down, Down, Return from step 4 jumps to 6, the arrows alone
// jumping nothing; Up on "Open" stays at 0 and Down stops at the last step; rows past the index read "not applied"
// and the saved one reads saved; a pressed row shows its press over the selection and hover. macOS only, like the
// rest of SuiteUI.
@testable import SuiteUI
import SuiteKernel
import SwiftUI
import Testing

@MainActor @Suite struct HistoryPanelTests {
    private static let listing = HistoryListing(
        base: "Open",
        steps: ["Brush", "Brush", "Fill", "Erase", "Brush", "Move", "Transform", "Levels", "Brush", "Crop", "Rename"],
        index: 8, savedIndex: 3)

    private func panel(_ listing: HistoryListing, _ log: JumpLog) -> HistoryPanel {
        HistoryPanel(listing: listing, onJump: { log.jumps.append($0) })
    }

    @Test func clickOnRowFourJumpsOnce() {
        let log = JumpLog()
        panel(Self.listing, log).click(4)
        #expect(log.jumps == [4])
        panel(Self.listing, log).click(12)
        panel(Self.listing, log).click(-1)
        #expect(log.jumps == [4])
    }

    @Test func downDownReturnJumpsToSix() {
        var listing = Self.listing
        listing.index = 4
        let log = JumpLog()
        let view = panel(listing, log)
        var cursor = HistoryPanelCursor(listing)
        #expect(cursor.position == 4)
        view.press(.down, on: &cursor)
        view.press(.down, on: &cursor)
        #expect(log.jumps.isEmpty && cursor.position == 6)
        view.press(.enter, on: &cursor)
        #expect(log.jumps == [6])
    }

    @Test func upOnOpenStaysAtZero() {
        var listing = Self.listing
        listing.index = 0
        let log = JumpLog()
        let view = panel(listing, log)
        var cursor = HistoryPanelCursor(listing)
        view.press(.up, on: &cursor)
        #expect(cursor.position == 0)
        view.press(.enter, on: &cursor)
        #expect(log.jumps == [0])

        var end = HistoryPanelCursor(Self.listing)
        for _ in 0..<20 { _ = end.press(.down) }
        #expect(end.position == 11)
        #expect(HistoryPanelCursor(HistoryListing(base: "Open", steps: [], index: 3)).position == 0)
    }

    @Test func rowsPastTheIndexReadNotApplied() {
        let listing = Self.listing
        #expect(HistoryPanel.label(at: 0, in: listing) == "Open, applied")
        #expect(HistoryPanel.label(at: 6, in: listing) == "Step 6 of 11, Move, applied")
        #expect(HistoryPanel.label(at: 3, in: listing) == "Step 3 of 11, Fill, saved, applied")
        #expect(HistoryPanel.label(at: 8, in: listing).hasSuffix(", applied"))
        for position in 9...11 {
            #expect(HistoryPanel.label(at: position, in: listing).hasSuffix("not applied"))
        }
        for position in 0...8 {
            #expect(!HistoryPanel.label(at: position, in: listing).hasSuffix("not applied"))
        }
        #expect(HistoryPanel.name(at: 11, in: listing) == "Rename")
    }

    @Test func aPressedRowShowsItsPress() {
        #expect(HistoryRowLook.resolve(selected: false, hovering: false, pressed: false) == .rest)
        #expect(HistoryRowLook.resolve(selected: false, hovering: true, pressed: false) == .hover)
        #expect(HistoryRowLook.resolve(selected: true, hovering: true, pressed: false) == .selected)
        #expect(HistoryRowLook.resolve(selected: false, hovering: true, pressed: true) == .pressed)
        #expect(HistoryRowLook.resolve(selected: true, hovering: true, pressed: true) == .pressed)
        #expect(HistoryRowLook.hover.outlined && !HistoryRowLook.selected.outlined && !HistoryRowLook.pressed.outlined)
    }

    @Test func keysMapToTheCursor() {
        #expect(HistoryPanelCursor.key(.upArrow) == .up)
        #expect(HistoryPanelCursor.key(.downArrow) == .down)
        #expect(HistoryPanelCursor.key(.return) == .enter)
        #expect(HistoryPanelCursor.key(.space) == nil)
    }
}

@MainActor private final class JumpLog {
    var jumps: [Int] = []
}

// PhotoHistoryJumpTests.swift: Photo as a HistoryJumping document
// (history-panel PH-1, PH-5). The listing the History tab shows ("Open" or
// "New Image", then every step, the current and the saved one), and the jump
// PH-5 wrote: 12 steps, a jump to 2 lands on step 2's pixels with Undo and
// Redo naming steps 2 and 3, records no step, ends an open slider run, and
// `history.jump` out of range throws.
// Runs on Linux and macOS.
import CoreRaster
@testable import PhotoModel
import SuiteKernel
import Testing

@Suite struct PhotoHistoryJumpTests {
    /// A 16 x 16 image with `count` brush strokes, one per row, each its own step.
    private func painted(_ count: Int = 12) throws -> PhotoWorkspace {
        var workspace = PhotoWorkspace()
        try workspace.open(rgba8: [UInt8](repeating: 255, count: 16 * 16 * 4), width: 16, height: 16, name: "portrait.png")
        for row in 0..<count {
            stroke(&workspace, .brush, from: point(1, Double(row) + 0.5), to: point(14, Double(row) + 0.5))
        }
        return workspace
    }

    // MARK: The listing (PH-1)

    @Test func listingNamesTheBaseAndEveryStep() throws {
        var workspace = try painted(3)
        workspace.undo()
        let listing = workspace.historyListing
        #expect(listing.base == "Open")
        #expect(listing.steps == Array(workspace.historySteps.dropFirst()))
        #expect(listing.steps.count == 3)
        #expect(listing.index == 2)
    }

    @Test func aNewImageListsNewImage() throws {
        let workspace = try whiteImage(4, 4)
        #expect(workspace.historyListing == HistoryListing(base: "New Image", steps: [], index: 0, savedIndex: 0))
    }

    @Test func savedIndexFollowsPhotosSave() throws {
        var workspace = try painted(2)
        #expect(workspace.historyListing.savedIndex == 0)
        workspace.savedStepID = workspace.currentStepID
        #expect(workspace.historyListing.savedIndex == 2)
        workspace.savedStepID = nil
        #expect(workspace.historyListing.savedIndex == nil)
    }

    // MARK: The jump (PH-5)

    @Test func jumpLandsOnStepTwo() throws {
        var expected = try painted(2)
        expected.endAdjust()
        var workspace = try painted()
        let names = workspace.historyListing.steps
        try workspace.jumpHistory(to: 2)
        #expect(workspace.historyListing.index == 2)
        #expect(workspace.undoActionName == "Undo \(names[1])")
        #expect(workspace.redoActionName == "Redo \(names[2])")
        #expect(try workspace.composite() == expected.composite())
    }

    @Test func jumpRecordsNothing() throws {
        var workspace = try painted()
        let steps = workspace.historyListing.steps
        try workspace.jumpHistory(to: 2)
        #expect(workspace.historyListing.steps == steps)
        try workspace.jumpHistory(to: 12)
        #expect(workspace.historyListing.steps == steps)
        #expect(workspace.historyListing.index == 12)
    }

    @Test func jumpEndsRun() throws {
        var workspace = try painted(2)
        let id = try #require(workspace.selectedLayerID)
        workspace.setOpacity(id, percent: 80)
        try workspace.jumpHistory(to: 3)
        workspace.setOpacity(id, percent: 60)
        #expect(workspace.historyListing.steps.count == 4)
        workspace.undo()
        #expect(workspace.layers.first { $0.id == id }?.opacityPercent == 80)
    }

    @Test func jumpOutOfRangeThrows() throws {
        var workspace = try painted(3)
        let before = workspace
        let catalog = try CommandCatalog<PhotoWorkspace>(app: "photo-history", HistoryCommands.specs(PhotoWorkspace.self),
                                                         history: { $0.history.kernel })
        for index in [-1, 4] {
            #expect(throws: CatalogError.failed(id: "history.jump", message: "There is no step \(index).")) {
                _ = try catalog.run("history.jump", params: .object(["index": .number(Double(index))]), on: &workspace)
            }
        }
        #expect(workspace == before)
    }

    @Test func baseIsOpen() throws {
        var workspace = try painted(3)
        try workspace.jumpHistory(to: 0)
        #expect(workspace.historyListing.base == "Open")
        #expect(workspace.historyListing.index == 0)
        #expect(workspace.undoActionName == "Undo")
    }
}

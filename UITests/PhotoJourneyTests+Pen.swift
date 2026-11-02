// PhotoJourneyTests+Pen.swift: PJ-PEN, a path with the shared Pen (#5072). On the
// shared test photo written as beach.png: P picks the Pen, three clicks on the
// canvas and a click on the first point close one path ("Undo Add Path"), drawn
// by SuiteUI's PathEditOverlay (`photo.canvas.pen`); Command-Z takes it back.
// Shots `pen-drawing` and `pen-closed`.
import XCTest

final class PhotoPenJourneyTests: XCTestCase {
    /// The three corners, as offsets in the canvas.
    private static let corners = [CGVector(dx: 0.3, dy: 0.3), CGVector(dx: 0.6, dy: 0.3), CGVector(dx: 0.45, dy: 0.6)]

    /// PJ-PEN:
    /// 1. P picks the Pen; three clicks place a draft's corners.
    /// 2. A click on the first corner closes the path as one Add Path step; Command-Z takes it back.
    @MainActor func testDrawAndClosePath() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "photo-pen-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let beach = folder.appending(path: "beach.png")
        try writeTestPhoto(to: beach)
        let photo = Journey("Photo", self, arguments: photoArguments(open: beach, saveTo: folder))
        XCTAssert(photo.window(named: "beach.png").waitForExistence(timeout: 30), "beach.png didn't open")
        let canvas = photo.element("suite.canvas")
        XCTAssert(canvas.waitForExistence(timeout: 5), "no canvas (suite.canvas)")

        // 1. P, then three corners.
        let pen = photo.element("suite.tools").buttons["Pen"]
        XCTAssert(pen.waitForExistence(timeout: 5), "no Pen on the palette (suite.tools)")
        canvas.click()
        photo.press(character: "p")
        XCTAssert(photo.element("photo.canvas.pen").waitForExistence(timeout: 5), "P didn't show the Pen overlay (photo.canvas.pen)")
        for corner in Self.corners { canvas.coordinate(withNormalizedOffset: corner).click() }
        photo.shot("pen-drawing")

        // 2. The first corner closes it; Undo takes it back.
        canvas.coordinate(withNormalizedOffset: Self.corners[0]).click()
        XCTAssert(photo.app.buttons["Undo Add Path"].waitForExistence(timeout: 5), "closing the path made no Add Path step")
        photo.shot("pen-closed")
        photo.press(character: "z", .command)
        XCTAssertFalse(photo.app.buttons["Undo Add Path"].waitForExistence(timeout: 2), "Command-Z didn't take the path back")
    }
}

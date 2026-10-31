// PhotoJourneyTests+DropFit.swift: dropped photos are fitted and every advertised type places (quality gate #5833).
// Photo opens Sunset.png (800 x 600). Big.png (3200 x 2400) dropped on the canvas lands as a layer "Big" with
// "Placed at 25%." on the status line, fitted inside the image rather than at its own size; one Undo takes it away.
// Sky.heic, written here with Core Image, then places as a layer "Sky" instead of "Can't place Sky.heic.". The
// files are dragged from the runner's small window (Journey+FileDrag.swift).
import CoreImage
import XCTest

final class PhotoDropFitJourneyTests: XCTestCase {
    @MainActor func testDroppedPhotosFitAndHEICPlaces() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "photo-drop-fit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let sunset = folder.appending(path: "Sunset.png")
        try writeTestPhoto(to: sunset)
        let photo = Journey("Photo", self, arguments: photoArguments(open: sunset))
        XCTAssert(photo.window(named: "Sunset.png").waitForExistence(timeout: 30), "Sunset.png didn't open")
        let canvas = photo.element("suite.canvas")
        XCTAssert(canvas.waitForExistence(timeout: 5), "Photo shows no canvas (suite.canvas)")

        let big = folder.appending(path: "Big.png")
        try writeTestPhoto(to: big, width: 3200, height: 2400)
        dragFile(big, onto: canvas)
        XCTAssert(photo.app.staticTexts["Big"].waitForExistence(timeout: 15), "dropping Big.png listed no layer Big")
        let status = photo.app.staticTexts.matching(
            NSPredicate(format: "label == 'Placed at 25%.' OR value == 'Placed at 25%.'")).firstMatch
        XCTAssert(status.waitForExistence(timeout: 5), "the status line doesn't read Placed at 25%.")
        photo.shot("drop-fitted")
        photo.press(character: "z", .command)
        XCTAssert(photo.app.staticTexts["Big"].waitForNonExistence(timeout: 5), "one Undo didn't take Big away")

        let sky = folder.appending(path: "Sky.heic")
        let source = try XCTUnwrap(CIImage(contentsOf: sunset), "Sunset.png doesn't read")
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        try CIContext().writeHEIFRepresentation(of: source, to: sky, format: .RGBA8, colorSpace: space)
        dragFile(sky, onto: canvas)
        XCTAssert(photo.app.staticTexts["Sky"].waitForExistence(timeout: 15), "dropping Sky.heic listed no layer Sky")
        let refused = photo.app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH \"Can't place\"")).firstMatch
        XCTAssertFalse(refused.exists, "the status line says it can't place Sky.heic")
        photo.shot("drop-heic")
    }
}

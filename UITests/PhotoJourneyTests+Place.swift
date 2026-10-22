// PhotoJourneyTests+Place.swift (place-image PP-4 written, PP-7 turned on): PJ-P1, placing a logo in Photo
// as a person does (docs/blueprints/photo/features/place-image.md, Journey steps):
// 1. An 800 x 600 image opens (the kit's test photo, as canvas.png).
// 2. File > Place… (Shift-Command-P), choose `logo.png` (200 x 100) in the panel: a layer `logo` above
//    Background, centred (the canvas's middle shows the logo's red left half, then its blue right half),
//    one "Place Image" step.
// 3. Place `photo-4000x3000.jpg`: a second layer, and the status line reads "Placed at 20%.".
// 4. Undo: the photo layer goes in one step (Redo names Place Image); the logo stays.
// Step 5 (an SVG refused) can't go through the panel, which offers only PNG and JPEG; PhotoPlaceSnapshots'
// `refused` and PhotoPlaceTests prove it. A drop from Finder can't be driven either; PhotoPlaceTests' drop-point
// cases cover it. The panel is the system's open panel: Shift-Command-G types the file's path, Return picks
// it, then its Place button. On live services since PP-7 (PP-5's place bodies, PP-6's catalog). One shot per
// step, "place-".
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest

final class PhotoPlaceJourneyTests: XCTestCase {
    @MainActor func testPlaceLogo() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "photo-place-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let canvas = folder.appending(path: "canvas.png"), logo = folder.appending(path: "logo.png")
        let large = folder.appending(path: "photo-4000x3000.jpg")
        try writeTestPhoto(to: canvas)
        try writeImage(to: logo, width: 200, height: 100, type: .png)
        try writeImage(to: large, width: 4000, height: 3000, type: .jpeg)

        let photo = Journey("Photo", self, arguments: photoArguments(open: canvas)) // 1.
        XCTAssert(photo.window(named: "canvas.png").waitForExistence(timeout: 30), "canvas.png didn't open")
        let background = photo.app.staticTexts["Background"]
        XCTAssert(background.waitForExistence(timeout: 5), "the layer list doesn't list Background")
        XCTAssert(photo.element("suite.canvas").waitForExistence(timeout: 5), "no canvas (suite.canvas)")
        photo.shot("place-opened")

        place(logo, photo) // 2.
        let placed = photo.app.staticTexts["logo"]
        XCTAssert(placed.waitForExistence(timeout: 10), "the layer list lists no logo")
        XCTAssert(placed.frame.minY < background.frame.minY, "logo isn't above Background")
        XCTAssert(photo.app.buttons["Undo Place Image"].waitForExistence(timeout: 5), "the place made no Place Image step")
        XCTAssert(waitFor { self.centred(photo) }, "the logo isn't centred: the canvas's middle isn't red, then blue")
        photo.shot("place-logo")

        place(large, photo) // 3.
        let fitted = photo.app.staticTexts["photo-4000x3000"]
        XCTAssert(fitted.waitForExistence(timeout: 15), "the layer list lists no photo-4000x3000")
        let status = photo.app.staticTexts.matching(
            NSPredicate(format: "label == 'Placed at 20%.' OR value == 'Placed at 20%.'")).firstMatch
        XCTAssert(status.waitForExistence(timeout: 5), "the status line doesn't read Placed at 20%.")
        photo.shot("place-fitted")

        photo.press(character: "z", .command) // 4.
        XCTAssert(waitFor { !fitted.exists }, "Undo left the photo layer")
        XCTAssert(placed.exists, "Undo took the logo too")
        XCTAssert(photo.app.buttons["Redo Place Image"].waitForExistence(timeout: 5), "Undo didn't undo a Place Image step")
        photo.shot("place-undone")
    }

    /// File > Place…, then the file at `url` chosen in the panel by its path.
    @MainActor private func place(_ url: URL, _ photo: Journey) {
        photo.press(character: "p", [.command, .shift])
        let panel = photo.app.sheets.firstMatch.exists ? photo.app.sheets.firstMatch : photo.app.dialogs.firstMatch
        XCTAssert(panel.waitForExistence(timeout: 10), "Place… opened no panel")
        photo.press(character: "g", [.command, .shift])
        let goTo = panel.sheets.firstMatch.exists ? panel.sheets.firstMatch : panel.textFields.firstMatch
        XCTAssert(goTo.waitForExistence(timeout: 5), "Shift-Command-G opened no Go to field in the panel")
        photo.app.typeText(url.path)
        photo.press(.return)
        let button = panel.buttons.matching(NSPredicate(format: "label == 'Place' OR identifier == 'OKButton'")).firstMatch
        XCTAssert(button.waitForExistence(timeout: 5), "the panel has no Place button")
        XCTAssert(waitFor { button.isEnabled }, "the panel didn't pick \(url.lastPathComponent)")
        button.click()
        XCTAssert(waitFor { !panel.exists }, "the panel didn't close on Place")
    }

    /// Whether the canvas's middle row is red just left of centre and blue just right of it: the logo centred.
    /// The image is fitted and centred in the viewport, so its middle is the canvas's.
    @MainActor private func centred(_ photo: Journey) -> Bool {
        guard let left = pixel(photo, at: 0.49), let right = pixel(photo, at: 0.51) else { return false }
        return left[0] > left[2] + 100 && right[2] > right[0] + 100
    }

    /// The RGB of the canvas shot at `x` (a fraction of its width) on its middle row; nil if it doesn't decode.
    @MainActor private func pixel(_ photo: Journey, at x: Double) -> [Int]? {
        let png = photo.element("suite.canvas").screenshot().pngRepresentation
        guard let source = CGImageSourceCreateWithData(png as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
            let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
            let data = context.data
        else { return nil }
        let width = Double(image.width), height = Double(image.height)
        let origin = CGPoint(x: -(width * x).rounded(.down), y: -(height / 2).rounded(.down))
        context.draw(image, in: CGRect(origin: origin, size: CGSize(width: width, height: height)))
        let bytes = data.bindMemory(to: UInt8.self, capacity: 4)
        return (0..<3).map { Int(bytes[$0]) }
    }

    /// Polls `condition` for up to five seconds.
    @MainActor private func waitFor(_ condition: () -> Bool) -> Bool {
        for _ in 0..<25 where !condition() { Thread.sleep(forTimeInterval: 0.2) }
        return condition()
    }

    /// A `width` x `height` image, red on the left half and blue on the right, written as `type`.
    private func writeImage(to url: URL, width: Int, height: Int, type: UTType) throws {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw CocoaError(.fileWriteUnknown) }
        let half = CGFloat(width) / 2
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: half, height: CGFloat(height)))
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: half, y: 0, width: half, height: CGFloat(height)))
        guard let image = context.makeImage(),
            let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }
}

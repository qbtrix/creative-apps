// PhotoJourneyTests+BrushKeys.swift: PJ-BK, the brush keys on a white image (brush-keys BK-8;
// docs/blueprints/suiteui/features/brush-keys.md). B picks the Brush at its 20 px default; `]` twice
// makes it 30 px and 5 sets its opacity to 50%, both shown in the Tool Options; a stroke across the
// middle of the image is then half-opaque black on white, a mid grey on screen.
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest

final class PhotoBrushKeysJourneyTests: XCTestCase {
    /// PJ-BK: B, `]` `]` 5, paint, and the options and the stroke show 30 px at 50%.
    @MainActor func testBracketsAndDigits() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "photo-brush-keys-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: "white.png")
        try Self.writeWhite(to: file)
        let photo = Journey("Photo", self, arguments: photoArguments(open: file))
        XCTAssert(photo.window(named: "white.png").waitForExistence(timeout: 30), "white.png didn't open")
        let canvas = photo.element("suite.canvas")
        XCTAssert(canvas.waitForExistence(timeout: 5), "no canvas (suite.canvas)")
        canvas.click()

        photo.press(character: "b")
        XCTAssert(photo.element("suite.tools").buttons["Brush"].isSelected, "B didn't pick the Brush")
        photo.press(character: "]")
        photo.press(character: "]")
        photo.press(character: "5", step: "brush-keys-30px-50")
        expect(photo.element("photo.tool.size"), contains: "30", "`]` twice didn't make the brush 30 px")
        expect(photo.element("photo.tool.opacity"), contains: "50", "5 didn't set the brush's opacity to 50%")

        photo.drag(on: "suite.canvas.artboard", from: CGVector(dx: 0.2, dy: 0.5), to: CGVector(dx: 0.8, dy: 0.5),
                   step: "brush-keys-stroke")
        let artboard = photo.element("suite.canvas.artboard")
        let gray = try XCTUnwrap(Self.centreGray(artboard.screenshot()), "the artboard's screenshot won't decode")
        XCTAssert((0.3...0.7).contains(gray), "the stroke's centre is \(gray) gray, not half-opaque black on white")
    }

    @MainActor private func expect(_ element: XCUIElement, contains text: String, _ message: String) {
        let match = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", text), object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [match], timeout: 5), .completed, message)
    }

    /// The centre pixel's mean of red, green and blue in sRGB, 0 black to 1 white.
    @MainActor private static func centreGray(_ shot: XCUIScreenshot) -> Double? {
        guard let image = NSBitmapImageRep(data: shot.pngRepresentation)?.cgImage,
            let srgb = CGColorSpace(name: CGColorSpace.sRGB)
        else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        let drawn = pixel.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(
                data: bytes.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: srgb,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            let (w, h) = (CGFloat(image.width), CGFloat(image.height))
            context.draw(image, in: CGRect(x: -w / 2 + 0.5, y: -h / 2 + 0.5, width: w, height: h))
            return true
        }
        guard drawn else { return nil }
        return Double(Int(pixel[0]) + Int(pixel[1]) + Int(pixel[2])) / (3 * 255)
    }

    /// A 400 x 300 opaque white PNG.
    private static func writeWhite(to url: URL) throws {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil, width: 400, height: 300, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw CocoaError(.fileWriteUnknown) }
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
        guard let image = context.makeImage(),
            let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }
}

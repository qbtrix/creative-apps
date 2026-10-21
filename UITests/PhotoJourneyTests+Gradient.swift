// PhotoJourneyTests+Gradient.swift: PJ-G1, a sky gradient in a selection
// (gradient-fill PG-6; docs/blueprints/photo/features/gradient-fill.md,
// Journey steps; RJ-P19). On sky.png (the 800 x 600 test photo) a marquee
// over the top half, then G picks the Gradient tool: Tool Options shows
// SuiteUI's stop bar (`suite.gradient.bar`) and no angle row
// (`suite.gradient.angle`). The first stop goes deep blue and the last pale
// blue through the editor's hex field (`suite.gradient.color`); a drag from
// the selection's top to its bottom fills it, one "Gradient" undo step, and
// leaves the bottom half's pixels as they were; Command-Z puts the layer
// back; Radial (`suite.gradient.type.radial`) and a drag from the centre
// outwards draw a radial fill. Shots `gradient-options`, `gradient-done`,
// `gradient-undone` and `gradient-radial`. Written in PG-6 and turned on in
// PG-7, on the live drawing (PG-3) and options (PG-4). The canvas is the whole
// viewport with the fitted image centred in it, so the image's top half sits
// above the viewport's middle and the marquee from the top corner to the
// middle is clipped to the image.
import CoreGraphics
import ImageIO
import XCTest

final class PhotoGradientJourneyTests: XCTestCase {
    /// The two stops, as the hex field takes them.
    private static let deepBlue = "0B3D91", paleBlue = "CFE8FF"

    /// PJ-G1: marquee the top half, G, blue stops, drag, undo, then Radial.
    @MainActor func testSkyGradient() throws {
        try skyGradient()
    }

    @MainActor private func skyGradient() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "photo-gradient-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: "sky.png")
        try writeTestPhoto(to: file)
        let photo = Journey("Photo", self, arguments: photoArguments(open: file))
        XCTAssert(photo.window(named: "sky.png").waitForExistence(timeout: 30), "sky.png didn't open")
        let canvas = photo.element("suite.canvas")
        XCTAssert(canvas.waitForExistence(timeout: 5), "no canvas (suite.canvas)")

        // 1. Marquee the top half, then G: the stop bar, no angle row.
        photo.element("suite.tools").buttons["Marquee"].click()
        photo.drag(on: "suite.canvas", from: CGVector(dx: 0.01, dy: 0.01), to: CGVector(dx: 0.99, dy: 0.5))
        let selection = photo.app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Selection ' OR value CONTAINS 'Selection '")).firstMatch
        XCTAssert(selection.waitForExistence(timeout: 5), "the marquee left no Selection on the info line")
        photo.press(character: "g")
        let tool = photo.element("suite.tools").buttons["Gradient"]
        XCTAssert(tool.waitForExistence(timeout: 5) && tool.isEnabled, "no enabled Gradient on the palette")
        XCTAssert(tool.isSelected, "G didn't pick the Gradient tool")
        XCTAssert(photo.element("suite.gradient.bar").waitForExistence(timeout: 5), "no stop bar (suite.gradient.bar)")
        XCTAssertFalse(photo.element("suite.gradient.angle").exists, "the Gradient tool shows an angle row")

        // 2. The first stop deep blue, the last pale blue.
        setStop(0, to: Self.deepBlue, photo)
        XCTAssert(photo.element("suite.gradient.stop.0").label.hasSuffix("blue"), "the first stop isn't blue")
        setStop(1, to: Self.paleBlue, photo)
        photo.shot("gradient-options")

        // 3. A drag from the selection's top to its bottom: one Gradient step, the bottom half untouched.
        let before = canvasPixels(photo)
        let bottom = bottomPixels(photo)
        photo.drag(on: "suite.canvas", from: CGVector(dx: 0.5, dy: 0.12), to: CGVector(dx: 0.5, dy: 0.48))
        expect("Undo Gradient", photo, "the drag made no Gradient step")
        XCTAssert(canvasChanged(from: before, photo), "the drag drew no gradient")
        XCTAssertEqual(bottomPixels(photo), bottom, "the gradient spilled into the bottom half")
        photo.shot("gradient-done")

        // 4. Command-Z: the layer is back in one step.
        photo.press(character: "z", .command)
        expect("Redo Gradient", photo, "Command-Z didn't undo the Gradient step")
        XCTAssert(Self.waitUntil { self.canvasPixels(photo) == before }, "one undo didn't put the layer back")
        photo.shot("gradient-undone")

        // 5. Radial, then a drag from the selection's centre outwards: a radial fill.
        photo.element("suite.gradient.type.radial").click()
        XCTAssertFalse(photo.element("suite.gradient.angle").exists, "Radial shows an angle row")
        photo.drag(on: "suite.canvas", from: CGVector(dx: 0.5, dy: 0.3), to: CGVector(dx: 0.75, dy: 0.3))
        expect("Undo Gradient", photo, "the radial drag made no Gradient step")
        XCTAssert(canvasChanged(from: before, photo), "the radial drag drew no gradient")
        XCTAssertEqual(bottomPixels(photo), bottom, "the radial gradient spilled into the bottom half")
        photo.shot("gradient-radial")
    }

    /// Picks stop `index` on the bar and types `hex` into the editor's colour field.
    @MainActor private func setStop(_ index: Int, to hex: String, _ photo: Journey) {
        let stop = photo.element("suite.gradient.stop.\(index)")
        XCTAssert(stop.waitForExistence(timeout: 5), "no stop handle suite.gradient.stop.\(index)")
        stop.click()
        let field = photo.app.textFields.matching(NSPredicate(
            format: "identifier == %@ OR label == %@", "suite.gradient.color", "Color Hex")).firstMatch
        XCTAssert(field.waitForExistence(timeout: 5), "no gradient Color Hex field")
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        photo.press(.rightArrow, .command)
        photo.press(.leftArrow, [.command, .shift])
        photo.app.typeText(hex)
        photo.press(.return)
    }

    /// Waits for the button titled `title`, such as the window toolbar's "Undo Gradient".
    @MainActor private func expect(_ title: String, _ photo: Journey, _ message: String) {
        XCTAssert(photo.app.buttons[title].waitForExistence(timeout: 5), "\(message) (no \(title) button)")
    }

    @MainActor private func canvasPixels(_ photo: Journey) -> Data {
        photo.element("suite.canvas").screenshot().pngRepresentation
    }

    /// The canvas's rows below three fifths of its height, decoded: the image's bottom half, clear of the
    /// selection's bottom edge at the middle.
    @MainActor private func bottomPixels(_ photo: Journey) -> Data? {
        guard let source = CGImageSourceCreateWithData(canvasPixels(photo) as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
            let data = image.dataProvider?.data as Data?
        else { return nil }
        let from = image.bytesPerRow * (image.height * 3 / 5)
        return from < data.count ? data.subdata(in: from..<data.count) : nil
    }

    /// Whether the canvas stops matching `before` within five seconds (it renders off the main actor).
    @MainActor private func canvasChanged(from before: Data, _ photo: Journey) -> Bool {
        Self.waitUntil { self.canvasPixels(photo) != before }
    }

    /// Waits up to 5 seconds for `condition` to hold.
    @MainActor private static func waitUntil(_ condition: () -> Bool) -> Bool {
        for _ in 0..<10 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return false
    }
}

// HaloJourneyTests+Place.swift (placed-images PH-u written; PH-7 turns it on): HJ-P1, placing a logo in Halo
// as a person does (docs/blueprints/halo/features/placed-images.md, Journey steps):
// 1. New Composition…, 1920 × 1080.
// 2. File > Place… (Shift-Command-P), choose `logo.svg` (480 × 160) in the panel: a solid `logo` centred, and
//    IMAGE in the inspector reads "logo.svg · SVG · 480 × 160".
// 3. Key Scale 0 → 100% (frames 0 → 30) and Opacity 0 → 100.
// 4. Render Frame (⌘R) at frame 30.
// 5. Layer > New > Solid (full frame) selected, Fill on, Place… `photo-1200x800.jpg`: the photo fills it;
//    ⌥-drag on the viewer pans its focus, and one Undo puts the focus back in one step.
// Off until PH-7: the place commands run in PH-6 and the window wires `haloPlace` then. The panel is the
// system's open panel, driven as PhotoPlaceJourneyTests drives it. One shot per step, "place-".
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest

final class HaloPlaceJourneyTests: XCTestCase {
    /// PH-7 sets this false once Place runs end to end.
    private static let waitsOnPH7 = true

    @MainActor func testPlaceLogo() throws {
        if Self.waitsOnPH7 { throw XCTSkip("waits on PH-7") }
        let folder = FileManager.default.temporaryDirectory.appending(path: "halo-place-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let logo = folder.appending(path: "logo.svg"), photo = folder.appending(path: "photo-1200x800.jpg")
        try Data(Self.logoSVG.utf8).write(to: logo)
        try writeImage(to: photo, width: 1200, height: 800)

        let halo = Journey("Halo", self, arguments: ["-HaloWindowSize", "1000x640"])
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let steps = ViewerDragSteps(halo: halo)
        halo.reachable("New Composition…").click() // 1.
        halo.reachable("Create", in: halo.app.sheets.firstMatch).click()
        XCTAssert(halo.element("halo.viewer").waitForExistence(timeout: 5), "no viewer after Create")
        halo.shot("place-new")

        place(logo, halo) // 2.
        XCTAssert(halo.trackName("logo").waitForExistence(timeout: 10), "the timeline lists no logo")
        expectText("logo.svg · SVG · 480 × 160", halo)
        halo.shot("place-logo")

        for property in ["scaleX", "scaleY", "opacity"] { // 3.
            set(property, to: "0", halo)
            halo.element("halo.inspector.key.\(property)").click()
        }
        steps.focusLane("logo")
        for _ in 0..<30 { halo.press(.rightArrow) }
        for property in ["scaleX", "scaleY", "opacity"] { set(property, to: "100", halo) }
        steps.expectKeyState("Opacity", "Keyed at this frame")
        halo.shot("place-keyed")

        halo.press(character: "r", .command) // 4.
        let rendered = halo.element("halo.viewer.summary")
        XCTAssert(halo.element("halo.viewer.rendered").waitForExistence(timeout: 10), "Render Frame showed no frame")
        XCTAssert(rendered.label.hasPrefix("Frame 30:"), "the artboard reads \(rendered.label), not frame 30")
        halo.shot("place-rendered")

        halo.choose(menu: ["Layer", "New", "Solid"]) // 5.
        let fill = halo.element("halo.inspector.place.fill")
        XCTAssert(fill.waitForExistence(timeout: 5), "IMAGE has no Fill checkbox")
        if (fill.value as? Int) != 1 { fill.click() }
        place(photo, halo)
        expectText("photo-1200x800.jpg · JPEG · 1200 × 800", halo)
        let canvas = halo.element("halo.viewer.canvas")
        let before = canvas.screenshot().pngRepresentation
        XCUIElement.perform(withKeyModifiers: .option) {
            canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)))
        }
        XCTAssertNotEqual(canvas.screenshot().pngRepresentation, before, "the ⌥-drag didn't pan the photo")
        halo.shot("place-panned")
        halo.press(character: "z", .command)
        XCTAssert(waitFor { canvas.screenshot().pngRepresentation == before }, "one Undo didn't restore the pan")
        halo.shot("place-undone")
    }

    /// A 480 × 160 SVG: a dark rounded bar with a light circle.
    private static let logoSVG = #"<svg xmlns="http://www.w3.org/2000/svg" width="480" height="160"><rect width="480" height="160" rx="24" fill="#202840"/><circle cx="80" cy="80" r="48" fill="#F0C040"/></svg>"#

    /// File > Place…, then the file at `url` chosen in the panel by its path.
    @MainActor private func place(_ url: URL, _ halo: Journey) {
        halo.press(character: "p", [.command, .shift])
        let panel = halo.app.sheets.firstMatch.exists ? halo.app.sheets.firstMatch : halo.app.dialogs.firstMatch
        XCTAssert(panel.waitForExistence(timeout: 10), "Place… opened no panel")
        halo.press(character: "g", [.command, .shift])
        halo.app.typeText(url.path)
        halo.press(.return)
        let button = panel.buttons.matching(NSPredicate(format: "label == 'Place' OR identifier == 'OKButton'")).firstMatch
        XCTAssert(button.waitForExistence(timeout: 5), "the panel has no Place button")
        XCTAssert(waitFor { button.isEnabled }, "the panel didn't pick \(url.lastPathComponent)")
        button.click()
        XCTAssert(waitFor { !panel.exists }, "the panel didn't close on Place")
    }

    /// Types `value` into the inspector's field for `property` and commits it.
    @MainActor private func set(_ property: String, to value: String, _ halo: Journey) {
        let field = halo.element("halo.inspector.row.\(property)").textFields.firstMatch
        XCTAssert(field.waitForExistence(timeout: 5), "no \(property) field in the inspector")
        field.click()
        field.typeKey("a", modifierFlags: .command)
        field.typeText(value + "\r")
    }

    /// Some text in the window reads `text` within five seconds.
    @MainActor private func expectText(_ text: String, _ halo: Journey) {
        let match = halo.app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@ OR value == %@", text, text)).firstMatch
        XCTAssert(match.waitForExistence(timeout: 5), "nothing reads \(text)")
    }

    /// Polls `condition` for up to five seconds.
    @MainActor private func waitFor(_ condition: () -> Bool) -> Bool {
        for _ in 0..<25 where !condition() { Thread.sleep(forTimeInterval: 0.2) }
        return condition()
    }

    /// A `width` × `height` JPEG, red on the left half and blue on the right.
    private func writeImage(to url: URL, width: Int, height: Int) throws {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw CocoaError(.fileWriteUnknown) }
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: width / 2, y: 0, width: width - width / 2, height: height))
        guard let image = context.makeImage(),
            let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }
}

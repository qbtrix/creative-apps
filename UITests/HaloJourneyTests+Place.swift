// HaloJourneyTests+Place.swift (placed-images PH-u written; PH-7 turned it on): HJ-P1, placing a logo in Halo
// as a person does (docs/blueprints/halo/features/placed-images.md, Journey steps):
// 1. New Composition…, 1920 × 1080.
// 2. File > Place…, choose `logo.svg` (480 × 160, red left half, blue right) in the panel: a solid `logo` centred,
//    and IMAGE in the inspector reads "logo.svg · SVG · 480 × 160".
// 3. Key Scale 0 → 100% (frames 0 → 30) and Opacity 0 → 100; frame 15 differs from frames 0 and 30.
// 4. File > Render Frame at frame 30: the rendered frame is red left of centre and blue right of it.
// 5. Layer > New > Solid (full frame) selected, Fill on, Place… `photo-1200x800.jpg`: the photo fills it by cover,
//    which crops its yellow top band; ⌥-drag down on the viewer pans its focus to the top (the band shows), and
//    Edit > Undo puts the focus back in one step. The band is the only part a vertical pan changes (#5003).
// Menus prove each mode change; the playhead still moves by → from the focused lane.
// On live services since PH-7 (no fixture: HaloLaunch picks `.live`): the place commands are PH-6's catalog
// bodies through the window's `haloPlace`. The panel is the system's open panel, driven as
// PhotoPlaceJourneyTests drives it. One shot per step, "place-".
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest

final class HaloPlaceJourneyTests: XCTestCase {
    @MainActor func testPlaceLogo() throws {
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
        expectFile("logo.svg · SVG · 480 × 160", halo)
        halo.shot("place-logo")

        for property in ["scaleX", "scaleY", "opacity"] { // 3.
            set(property, to: "0", halo)
            halo.element("halo.inspector.key.\(property)").click()
        }
        let canvas = halo.element("halo.viewer.canvas")
        let atStart = canvas.screenshot().pngRepresentation
        steps.focusLane("logo")
        for _ in 0..<30 { halo.press(.rightArrow) }
        for property in ["scaleX", "scaleY", "opacity"] { set(property, to: "100", halo) }
        steps.expectKeyState("Opacity", "Keyed at this frame")
        halo.shot("place-keyed")
        let atEnd = canvas.screenshot().pngRepresentation
        steps.focusLane("logo")
        for _ in 0..<15 { halo.press(.leftArrow) }
        let animates = waitFor {
            let middle = canvas.screenshot().pngRepresentation
            return middle != atStart && middle != atEnd
        }
        XCTAssert(animates, "frame 15 looks like frame 0 or 30: the keys don't animate")
        halo.shot("place-scrubbed")
        for _ in 0..<15 { halo.press(.rightArrow) }

        halo.choose(menu: ["File", "Render Frame"]) // 4.
        let summary = halo.element("halo.viewer.summary"), rendered = halo.element("halo.viewer.rendered")
        XCTAssert(rendered.waitForExistence(timeout: 10), "Render Frame showed no frame")
        XCTAssert(summary.label.hasPrefix("Frame 30:"), "the artboard reads \(summary.label), not frame 30")
        let (left, right) = (rgb(rendered, x: 0.44), rgb(rendered, x: 0.56))
        XCTAssert(left.map { $0[0] > $0[2] + 100 } == true, "the render left of centre isn't red: \(left ?? [])")
        XCTAssert(right.map { $0[2] > $0[0] + 100 } == true, "the render right of centre isn't blue: \(right ?? [])")
        halo.shot("place-rendered")

        halo.choose(menu: ["Layer", "New", "Solid"]) // 5.
        let fill = halo.element("halo.inspector.place.fill")
        XCTAssert(fill.waitForExistence(timeout: 5), "IMAGE has no Fill checkbox")
        if (fill.value as? Int) != 1 { fill.click() }
        place(photo, halo)
        expectFile("photo-1200x800.jpg · JPEG · 1200 × 800 px", halo)
        let before = canvas.screenshot().pngRepresentation
        XCUIElement.perform(withKeyModifiers: .option) {
            canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)))
        }
        XCTAssertNotEqual(canvas.screenshot().pngRepresentation, before, "the ⌥-drag didn't pan the photo")
        halo.shot("place-panned")
        let edit = halo.app.menuBars.firstMatch.menuBarItems["Edit"]
        edit.click()
        let undo = edit.menus.firstMatch.children(matching: .menuItem)
            .matching(NSPredicate(format: "title BEGINSWITH 'Undo'")).firstMatch
        XCTAssert(undo.waitForExistence(timeout: 3) && undo.isEnabled, "Edit has no Undo after the pan")
        undo.click()
        XCTAssert(waitFor { canvas.screenshot().pngRepresentation == before }, "one Undo didn't restore the pan")
        halo.shot("place-undone")
    }

    /// A 480 × 160 SVG: red on the left half, blue on the right (the render check in step 4).
    private static let logoSVG = ##"<svg xmlns="http://www.w3.org/2000/svg" width="480" height="160"><rect width="240" height="160" fill="#FF0000"/><rect x="240" width="240" height="160" fill="#0000FF"/></svg>"##

    /// File > Place…, then the file at `url` chosen in the panel by its path.
    @MainActor private func place(_ url: URL, _ halo: Journey) {
        halo.choose(menu: ["File", "Place…"])
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

    /// Types `value` into the inspector's field for `property` and commits it. A TRANSFORM bar holds its typing
    /// field only while it is open, so the bar is clicked first, as a person does.
    @MainActor private func set(_ property: String, to value: String, _ halo: Journey) {
        let bar = halo.element("halo.inspector.row.\(property)")
        XCTAssert(bar.waitForExistence(timeout: 5), "no \(property) row in the inspector")
        halo.reveal(bar)
        bar.click()
        let field = bar.textFields.firstMatch
        XCTAssert(field.waitForExistence(timeout: 5), "clicking \(property) opened no field")
        field.typeKey("a", modifierFlags: .command)
        field.typeText(value + "\r")
    }

    /// IMAGE's File row (`suite.place.file`) names `summary` within five seconds. The row is one element that
    /// combines its label and the summary ("File, logo.svg · …"), so it is read by containment (#4793).
    @MainActor private func expectFile(_ summary: String, _ halo: Journey) {
        let row = halo.element("suite.place.file")
        XCTAssert(row.waitForExistence(timeout: 5), "IMAGE has no File row (suite.place.file)")
        XCTAssert(waitFor { row.label.contains(summary) || "\(row.value ?? "")".contains(summary) },
                  "the File row reads \(row.label), not \(summary)")
    }

    /// The sRGB of `element`'s shot at `x` (a fraction of its width) on its middle row; nil if it doesn't decode.
    @MainActor private func rgb(_ element: XCUIElement, x: Double) -> [Int]? {
        guard let shot = NSBitmapImageRep(data: element.screenshot().pngRepresentation),
            let colour = shot.colorAt(x: Int(Double(shot.pixelsWide) * x), y: shot.pixelsHigh / 2)?
                .usingColorSpace(.sRGB)
        else { return nil }
        return [colour.redComponent, colour.greenComponent, colour.blueComponent].map { Int($0 * 255) }
    }

    /// Polls `condition` for up to five seconds.
    @MainActor private func waitFor(_ condition: () -> Bool) -> Bool {
        for _ in 0..<25 where !condition() { Thread.sleep(forTimeInterval: 0.2) }
        return condition()
    }

    /// A `width` × `height` JPEG, red on the left half and blue on the right, with a yellow band over its top 40 rows.
    /// Cover into 1920 × 1080 crops 62.5 rows off the top, so the band shows only once the focus moves up.
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
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: height - 40, width: width, height: 40))
        guard let image = context.makeImage(),
            let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }
}

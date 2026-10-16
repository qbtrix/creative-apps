// PhotoJourneyTests+Edit.swift: photo-edit's journeys PJ-5 and PJ-6
// (docs/blueprints/photo/features/photo-edit.md, Journey steps 1 and 2).
// PJ-5 copies the sun as a new layer: with no selection Cut and Copy are on
// (the whole layer); with the general pasteboard cleared by the runner Paste
// is off with "Nothing to paste."; a marquee around the sun, Command-C and
// Command-V give "Pasted Layer" above Background, selected, one "Paste" step,
// with the selection on the info line unchanged and, with Background hidden
// for a moment, the pasted pixels filling exactly the marquee's rect with the
// sun in its old place; Command-X on Background
// clears the sun ("Undo Cut", seen once Pasted Layer is hidden); Command-Z
// restores both. Last, a marquee on a new transparent layer and Command-C say
// "Nothing to copy." in the status line. PJ-6 pastes another app's image: the
// runner writes a magenta 200 x 100 PNG to the general pasteboard; Edit >
// Paste on beach.png gives a 200 x 100 layer at (300, 250), centered on the
// 800 x 600 image (one "Paste" step); with no image open it opens a clean
// 200 x 100 "Untitled" image; a 6000 x 4000 PNG opens as 5016 x 3344 with
// "Pasted at 84%.".
// The sun is found by its yellow in the canvas pixels, so the marquee and the
// checks don't depend on where the fitted image sits. `suite.canvas` is the
// whole viewport (682 x 582 pt on the runner), not the artboard: the fitted
// image sits inside it with a margin, so PJ-6 finds the image's rect by its
// colored pixels and measures the pasted layer against that. Layer bounds
// aren't on any label (no accessibility identifier gives them), so the pasted
// layer's size and place are read from the canvas pixels. XCUITest shows a
// disabled menu item's help tag but not its text, so Paste's "Nothing to
// paste." is proven by AppSnapshotTests' PhotoEditMenuTests
// (pasteIsDisabledWithItsReasonWithAnEmptyPasteboard); here Paste is disabled
// with the runner's pasteboard empty and shows a help tag. One shot per step,
// "edit-".
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest

final class PhotoEditJourneyTests: XCTestCase {
    /// PJ-5: copy and paste as a new layer, cut, undo, and "Nothing to copy.".
    @MainActor func testCopyPasteAsNewLayer() throws {
        let photo = try openBeach()
        openLayersTab(photo)
        let sun = try XCTUnwrap(sunCenter(photo), "no yellow sun on the canvas")
        photo.shot("edit-opened")

        // No selection: Cut and Copy act on the whole layer; nothing on the pasteboard: Paste is off.
        _ = NSPasteboard.general.clearContents()
        XCTAssert(
            (NSPasteboard.general.pasteboardItems ?? []).isEmpty,
            "the runner's pasteboard isn't empty, so Paste's reason wouldn't be Nothing to paste.")
        expectEnabled("Cut", photo)
        expectEnabled("Copy", photo)
        expectDisabledWithHelp("Paste", photo)

        // Marquee the sun, Command-C: the image goes on the pasteboard and Paste turns on.
        photo.element("suite.tools").buttons["Marquee"].click()
        let sunBox = try XCTUnwrap(box(of: Self.yellow, photo), "no yellow sun on the canvas")
        let (left, top) = (clamp(sun.dx - 0.16), clamp(sun.dy - 0.21))
        let marquee = CGRect(x: left, y: top, width: clamp(sun.dx + 0.16) - left, height: clamp(sun.dy + 0.21) - top)
        photo.drag(
            on: "suite.canvas", from: CGVector(dx: marquee.minX, dy: marquee.minY),
            to: CGVector(dx: marquee.maxX, dy: marquee.maxY), step: "edit-sun-selected")
        // XCUITest reads a SwiftUI Text's words as its label or its value.
        let selection = photo.app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Selection ' OR value CONTAINS 'Selection '")).firstMatch
        XCTAssert(selection.waitForExistence(timeout: 5), "the marquee left no Selection on the info line")
        let infoLine = { [selection.label, selection.value as? String ?? ""].joined(separator: " ") }
        let selected = infoLine()
        let before = NSPasteboard.general.changeCount
        photo.press(character: "c", .command)
        XCTAssert(
            waitFor { NSPasteboard.general.changeCount != before && NSPasteboard.general.data(forType: .png) != nil },
            "Command-C put no PNG on the pasteboard")
        expectEnabled("Paste", photo)
        photo.shot("edit-copied")

        // Command-V: "Pasted Layer" above Background, selected, one Paste step, the selection kept.
        photo.press(character: "v", .command)
        expect("Undo Paste", photo, "Command-V made no Paste step")
        let pasted = photo.app.staticTexts["Pasted Layer"], background = photo.app.staticTexts["Background"]
        XCTAssert(pasted.waitForExistence(timeout: 5), "the Layers tab lists no Pasted Layer")
        XCTAssert(waitFor { pasted.frame.minY < background.frame.minY }, "Pasted Layer isn't above Background")
        expectHeader("2 layers", photo, "the header doesn't count two layers after the paste")
        expectSelectedRow("Pasted Layer", photo)
        XCTAssertEqual(infoLine(), selected, "the paste changed the selection on the info line")
        photo.shot("edit-pasted")

        // Background hidden: Pasted Layer's pixels fill the marquee's rect, the sun where it was.
        photo.click("Hide Background", in: .window)
        expect("Undo Hide Layer", photo, "Background's eye didn't hide it")
        var layerBox: CGRect?
        XCTAssert(
            waitFor { layerBox = self.box(of: Self.colored, photo); return layerBox != nil },
            "Pasted Layer shows no pixels with Background hidden")
        if let layerBox { expectBox(layerBox, near: marquee, within: 0.012, "Pasted Layer's pixels") }
        let pastedSun = box(of: Self.yellow, photo)
        XCTAssertNotNil(pastedSun, "Pasted Layer holds no sun")
        if let pastedSun { expectBox(pastedSun, near: sunBox, within: 0.01, "Pasted Layer's sun") }
        photo.shot("edit-pasted-alone")
        photo.press(character: "z", .command)
        expect("Undo Paste", photo, "Command-Z didn't undo hiding Background")
        expectSelectedRow("Pasted Layer", photo)

        // Select Background (Select Layer Below), Command-X: one Cut step; with Pasted Layer
        // hidden the sun's place shows no yellow.
        photo.press(character: "[", [.command, .option])
        expectSelectedRow("Background", photo)
        photo.press(character: "x", .command)
        expect("Undo Cut", photo, "Command-X on Background made no Cut step")
        photo.shot("edit-cut")
        photo.click("Hide Pasted Layer", in: .window)
        expect("Undo Hide Layer", photo, "Pasted Layer's eye didn't hide it")
        XCTAssert(waitFor { !self.isYellow(at: sun, photo) }, "the sun is still there after Cut (Pasted Layer hidden)")
        photo.shot("edit-cut-sun-gone")

        // Command-Z undoes the hide, then the Cut and the Paste: one layer, the sun back.
        photo.press(character: "z", .command)
        expect("Undo Cut", photo, "Command-Z didn't undo the hide")
        photo.press(character: "z", .command)
        expect("Undo Paste", photo, "Command-Z didn't undo the Cut")
        photo.press(character: "z", .command)
        expect("Redo Paste", photo, "Command-Z didn't undo the Paste")
        XCTAssert(pasted.waitForNonExistence(timeout: 5), "Pasted Layer is still listed after undoing the paste")
        expectHeader("1 layer", photo, "undoing the paste left two layers")
        XCTAssert(waitFor { self.isYellow(at: sun, photo) }, "undoing the Cut didn't bring the sun back")
        photo.shot("edit-undone")

        // Error: a marquee on a new transparent layer copies nothing, and says so.
        photo.press(character: "n", [.command, .shift])
        expect("Undo New Layer", photo, "Shift-Command-N made no New Layer step")
        photo.drag(on: "suite.canvas", from: CGVector(dx: 0.08, dy: 0.72), to: CGVector(dx: 0.28, dy: 0.9))
        let held = NSPasteboard.general.changeCount
        photo.press(character: "c", .command)
        expectStatus("Nothing to copy.", photo)
        photo.shot("edit-nothing-to-copy")
        XCTAssertEqual(NSPasteboard.general.changeCount, held, "a copy of nothing changed the pasteboard")
    }

    /// PJ-6: another app's image pastes as a layer, opens as a new image, and a
    /// 24 MP one is scaled to fit.
    @MainActor func testPasteFromAnotherApp() throws {
        try putOnPasteboard(Self.magentaPNG(width: 200, height: 100))

        // On beach.png: a 200 x 100 layer, centered on the image at Fit.
        var photo = try openBeach()
        openLayersTab(photo)
        // The fitted image's rect in the viewport: every sky and sun pixel is colored, the margin isn't.
        // `self.`: the local `box` below would shadow the method.
        let image = try XCTUnwrap(self.box(of: Self.colored, photo), "beach.png shows no picture on the canvas")
        choose("Paste", photo)
        expect("Undo Paste", photo, "Edit > Paste made no Paste step")
        XCTAssert(photo.app.staticTexts["Pasted Layer"].waitForExistence(timeout: 5), "the Layers tab lists no Pasted Layer")
        expectHeader("2 layers", photo, "the header doesn't count two layers after the paste")
        var box: CGRect?
        XCTAssert(waitFor { box = self.magentaBox(photo); return box != nil }, "the pasted image isn't on the canvas")
        // 200 x 100 at (300, 250) on the 800 x 600 image, within 4 image pixels, mapped into the
        // image's rect in the viewport.
        let placed = CGRect(
            x: image.minX + image.width * 300 / 800, y: image.minY + image.height * 250 / 600,
            width: image.width * 200 / 800, height: image.height * 100 / 600)
        if let box { expectBox(box, near: placed, within: image.width * 4 / 800, "the pasted 200 x 100 layer") }
        photo.shot("edit-pasted-from-app")
        photo.app.terminate()

        // No image open: Paste opens a clean 200 x 100 "Untitled" image.
        photo = Journey("Photo", self, arguments: photoArguments())
        XCTAssert(photo.app.windows["Photo"].waitForExistence(timeout: 30), "the empty Photo window didn't open")
        choose("Paste", photo)
        XCTAssert(photo.app.windows["Untitled"].waitForExistence(timeout: 15), "Paste with no image opened no Untitled image")
        expectHeader("200 × 100 px", photo, "the pasted image isn't 200 × 100 px")
        expectHeader("1 layer", photo, "the pasted image has more than one layer")
        expect("photo.bar.undo", photo, "the window has no Undo button")
        XCTAssertFalse(photo.app.buttons["photo.bar.undo"].isEnabled, "the pasted new image came with undo history")
        photo.shot("edit-pasted-new-image")
        photo.app.terminate()

        // Error: a 6000 x 4000 image (24 MP) is over the open limit, so it opens
        // scaled to 5016 x 3344. Decoding and a lanczos3 resize take a while: a long wait.
        try putOnPasteboard(Self.magentaPNG(width: 6000, height: 4000))
        photo = Journey("Photo", self, arguments: photoArguments())
        XCTAssert(photo.app.windows["Photo"].waitForExistence(timeout: 30), "the empty Photo window didn't open")
        choose("Paste", photo)
        expectStatus("Pasted at 84%.", photo, timeout: 180)
        photo.shot("edit-pasted-scaled")
        XCTAssert(photo.app.windows["Untitled"].waitForExistence(timeout: 5), "the 24 MP paste opened no Untitled image")
        expectHeader("5016 × 3344 px", photo, "the 24 MP paste isn't 5016 × 3344 px")
        _ = NSPasteboard.general.clearContents()
    }

    // MARK: - Steps

    /// Launches Photo on a fresh beach.png (the kit's test photo) and waits for it.
    @MainActor private func openBeach() throws -> Journey {
        let folder = FileManager.default.temporaryDirectory.appending(path: "photo-edit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: "beach.png")
        try writeTestPhoto(to: file)
        let photo = Journey("Photo", self, arguments: photoArguments(open: file))
        XCTAssert(photo.app.windows["beach.png"].waitForExistence(timeout: 30), "beach.png didn't open")
        XCTAssert(photo.element("suite.canvas").waitForExistence(timeout: 5), "no canvas (suite.canvas)")
        return photo
    }

    @MainActor private func openLayersTab(_ photo: Journey) {
        let tab = photo.app.radioButtons["Layers"]
        XCTAssert(tab.waitForExistence(timeout: 5), "no Layers tab")
        tab.click()
        XCTAssert(photo.app.staticTexts["Background"].waitForExistence(timeout: 5), "the Layers tab doesn't list Background")
    }

    /// Clears the general pasteboard and puts `png` on it, as another app would.
    @MainActor private func putOnPasteboard(_ png: Data) throws {
        let pasteboard = NSPasteboard.general
        _ = pasteboard.clearContents()
        XCTAssert(pasteboard.setData(png, forType: .png), "the runner couldn't write the PNG to the pasteboard")
    }

    /// The Edit menu's `item`, with the menu open.
    @MainActor private func editItem(_ item: String, _ photo: Journey) -> XCUIElement {
        let menu = photo.app.menuBars.firstMatch.menuBarItems["Edit"]
        XCTAssert(menu.waitForExistence(timeout: 5), "no Edit menu")
        menu.click()
        let entry = menu.menuItems[item]
        XCTAssert(entry.waitForExistence(timeout: 3), "the Edit menu has no \(item)")
        return entry
    }

    /// Picks Edit > `item`, which must be enabled.
    @MainActor private func choose(_ item: String, _ photo: Journey) {
        expectEnabled(item, photo, close: false)
        photo.app.menuBars.firstMatch.menuBarItems["Edit"].menuItems[item].click()
    }

    /// Edit > `item` is enabled. The window reads the pasteboard four times a
    /// second, so the menu is reopened for up to 3 s. Closes it unless `close` is false.
    @MainActor private func expectEnabled(_ item: String, _ photo: Journey, close: Bool = true) {
        var enabled = false
        for attempt in 0..<6 {
            enabled = editItem(item, photo).isEnabled
            if enabled { break }
            photo.press(.escape)
            if attempt < 5 { Thread.sleep(forTimeInterval: 0.5) }
        }
        XCTAssert(enabled, "Edit > \(item) is disabled")
        if close { closeMenu(photo) }
    }

    /// Edit > `item` is disabled and hovering it shows a help tag. The tag's
    /// text isn't read: XCUITest exposes the help tag of a SwiftUI menu item
    /// with no label, title or value (dev run 38835566584 found the tag, 138 x
    /// 18 pt beside Paste, but no text), so the text is proven by
    /// PhotoEditMenuTests and the screen shot shows it to the reviewer.
    @MainActor private func expectDisabledWithHelp(_ item: String, _ photo: Journey) {
        var entry = editItem(item, photo)
        for _ in 0..<5 where entry.isEnabled {
            photo.press(.escape)
            Thread.sleep(forTimeInterval: 0.5)
            entry = editItem(item, photo)
        }
        XCTAssertFalse(entry.isEnabled, "Edit > \(item) is enabled")
        entry.hover()
        XCTAssert(photo.app.helpTags.firstMatch.waitForExistence(timeout: 5), "Edit > \(item) shows no help tag")
        photo.shot("edit-\(photo.slug(item))-disabled", screen: true)
        closeMenu(photo)
    }

    @MainActor private func closeMenu(_ photo: Journey) {
        photo.press(.escape)
        // Best effort: app.menus still matches the menu bar's menus after one closes (HaloJourneyTests+Layers).
        _ = photo.app.menus.firstMatch.waitForNonExistence(timeout: 2)
    }

    /// Waits for the button titled `title`, such as the top bar's "Undo Paste".
    @MainActor private func expect(_ title: String, _ photo: Journey, _ message: String) {
        XCTAssert(photo.app.buttons[title].waitForExistence(timeout: 5), "\(message) (no \(title) button)")
    }

    /// Waits for a label holding `text`, as the header's "beach.png, 800 × 600 px, sRGB · 1 layer".
    @MainActor private func expectHeader(_ text: String, _ photo: Journey, _ message: String) {
        if labelled(text, photo).waitForExistence(timeout: 5) { return }
        let header = labelled(" px, sRGB", photo)
        XCTFail("\(message) (no label holds \(text); the header reads \(header.exists ? header.label : "nothing"))")
    }

    @MainActor private func labelled(_ text: String, _ photo: Journey) -> XCUIElement {
        photo.app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// The status line (`photo.status.message`) says `text`; the window clears it after 4 s.
    @MainActor private func expectStatus(_ text: String, _ photo: Journey, timeout: TimeInterval = 5) {
        let message = photo.app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier == %@ AND (label CONTAINS %@ OR value CONTAINS %@)", "photo.status.message", text, text))
            .firstMatch
        XCTAssert(message.waitForExistence(timeout: timeout), "the status line doesn't say \(text)")
    }

    /// The Layers list's row holding `name` is the selected one.
    @MainActor private func expectSelectedRow(_ name: String, _ photo: Journey) {
        let rowTypes = [XCUIElement.ElementType.tableRow, .outlineRow].map { NSNumber(value: $0.rawValue) }
        let row = photo.element("photo.layers").descendants(matching: .any)
            .matching(NSPredicate(format: "elementType == %@ OR elementType == %@", rowTypes[0], rowTypes[1]))
            .containing(NSPredicate(format: "label == %@ OR value == %@", name, name)).firstMatch
        XCTAssert(row.waitForExistence(timeout: 5), "the Layers list has no row for \(name)")
        XCTAssert(waitFor { row.isSelected }, "\(name) isn't the selected layer")
    }

    // MARK: - Canvas pixels

    /// The canvas as 8-bit RGBA, top row first.
    private struct Bitmap {
        let width: Int, height: Int, bytes: [UInt8]

        func rgb(_ x: Int, _ y: Int) -> (Int, Int, Int) {
            let at = (min(max(y, 0), height - 1) * width + min(max(x, 0), width - 1)) * 4
            guard at + 2 < bytes.count else { return (0, 0, 0) }
            return (Int(bytes[at]), Int(bytes[at + 1]), Int(bytes[at + 2]))
        }
    }

    @MainActor private func canvasBitmap(_ photo: Journey) -> Bitmap? {
        let image = photo.element("suite.canvas").screenshot().image
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
            let space = CGColorSpace(name: CGColorSpace.sRGB)
        else { return nil }
        let (width, height) = (cgImage.width, cgImage.height)
        guard width > 0, height > 0 else { return nil }
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? Bitmap(width: width, height: height, bytes: bytes) : nil
    }

    /// The sun's yellow (255, 219, 77); the sky's orange end has far less green.
    private static func yellow(_ pixel: (Int, Int, Int)) -> Bool {
        pixel.0 > 210 && pixel.1 > 185 && pixel.2 < 150
    }

    /// The pasted image's magenta (255, 0, 255).
    private static func magenta(_ pixel: (Int, Int, Int)) -> Bool {
        pixel.0 > 180 && pixel.1 < 90 && pixel.2 > 180
    }

    /// Any picture pixel: the checkerboard and the marching ants are gray, the sky and sun
    /// aren't (the sky's grayest row still spreads its channels by about 22).
    private static func colored(_ pixel: (Int, Int, Int)) -> Bool {
        max(pixel.0, pixel.1, pixel.2) - min(pixel.0, pixel.1, pixel.2) > 12
    }

    /// `box` matches `expected` (both fractions of the canvas) edge by edge within `tolerance`.
    private func expectBox(_ box: CGRect, near expected: CGRect, within tolerance: CGFloat, _ what: String) {
        let edges = [
            (box.minX, expected.minX), (box.minY, expected.minY), (box.maxX, expected.maxX), (box.maxY, expected.maxY),
        ]
        XCTAssert(
            edges.allSatisfy { abs($0.0 - $0.1) <= tolerance },
            "\(what) cover \(box) of the canvas, not \(expected) (within \(tolerance))")
    }

    /// Where the yellow sun's middle is, as a fraction of the canvas.
    @MainActor private func sunCenter(_ photo: Journey) -> CGVector? {
        box(of: Self.yellow, photo).map { CGVector(dx: $0.midX, dy: $0.midY) }
    }

    /// The pasted magenta's bounds, as fractions of the canvas.
    @MainActor private func magentaBox(_ photo: Journey) -> CGRect? {
        box(of: Self.magenta, photo)
    }

    /// The bounds of the canvas pixels that match, as fractions of the canvas; nil when none do.
    @MainActor private func box(of matches: ((Int, Int, Int)) -> Bool, _ photo: Journey) -> CGRect? {
        guard let bitmap = canvasBitmap(photo) else { return nil }
        var (minX, minY, maxX, maxY) = (Int.max, Int.max, -1, -1)
        for y in 0..<bitmap.height {
            for x in 0..<bitmap.width where matches(bitmap.rgb(x, y)) {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= 0 else { return nil }
        let (w, h) = (CGFloat(bitmap.width), CGFloat(bitmap.height))
        return CGRect(
            x: CGFloat(minX) / w, y: CGFloat(minY) / h,
            width: CGFloat(maxX - minX + 1) / w, height: CGFloat(maxY - minY + 1) / h)
    }

    @MainActor private func isYellow(at point: CGVector, _ photo: Journey) -> Bool {
        guard let bitmap = canvasBitmap(photo) else { return false }
        let x = Int(point.dx * CGFloat(bitmap.width)), y = Int(point.dy * CGFloat(bitmap.height))
        return Self.yellow(bitmap.rgb(x, y))
    }

    private func clamp(_ fraction: CGFloat) -> CGFloat { min(max(fraction, 0.02), 0.98) }

    // MARK: - Files

    /// A solid magenta PNG, `width` x `height`, as another app would put on the pasteboard.
    private static func magentaPNG(width: Int, height: Int) throws -> Data {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw CocoaError(.fileWriteUnknown) }
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let data = NSMutableData()
        guard let image = context.makeImage(),
            let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        return data as Data
    }

    /// Whether `condition` holds within `seconds`.
    @MainActor private func waitFor(seconds: Int = 5, _ condition: () -> Bool) -> Bool {
        for _ in 0..<(seconds * 5) {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }
}

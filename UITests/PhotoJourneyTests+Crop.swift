// PhotoJourneyTests+Crop.swift: PJ-8, a typed crop size and an aspect lock
// (photo-crop CP-5, #544; docs/blueprints/photo/features/photo-crop.md,
// Journey steps; blueprint 4.2). On beach.png (800 x 600), C picks Crop: the
// inspector shows X, Y, W, H (`photo.crop.x`, `.y`, `.width`, `.height`, each
// one combined element whose label and value hold its letter, name and
// "<n> pixels"), the caption (`photo.crop.caption`) and the six aspect chips,
// found by title until they carry identifiers (#1148). 1:1 gives a centred
// 600 x 600 crop at X 100; W 400 and Return give H 400 with X and Y kept and
// the crop still pending (the image still 800 x 600); the overlay's pill
// (`photo.canvas.crop.aspect`) reads 1:1. 3:2 then Swap reads 2:3 with H > W;
// Free drops the pill. A drag from image pixel (10, 10) to (210, 110) gives
// W 200, H 100 within a pixel at Fit (a point's worth when a point is more).
// It is aimed from the pending crop's mark (`photo.canvas.crop`), whose frame
// over the crop the fields show gives the image's place and zoom on screen:
// `suite.canvas` is the scroll area around the image, not the image (#566).
// X 700 and Return reads X 800 - W (600) clamped. Return on the canvas then
// applies it: the image becomes W x H and Edit shows Undo Crop. A click on
// the canvas would start a new crop (a click is a drag that doesn't move), so
// keys go back to the canvas the way a person's drag gives them: a drag over
// the crop the fields show, from its top left to past the image's right edge,
// which redraws the same crop. Every step checks `photo.canvas.crop` while a
// crop is pending and shoots `photo-crop-*`. Values are waited for with query
// predicates, never a sleep.
import CoreGraphics
import XCTest

final class PhotoCropJourneyTests: XCTestCase {
    /// The six chips, in the order the panel shows them.
    private static let chips = ["Free", "Original", "1:1", "3:2", "4:3", "16:9"]

    /// PJ-8: typed crop fields, an aspect lock and its pill, then Return applies.
    @MainActor func testTypedCropSizeAndAspect() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "photo-crop-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: "beach.png")
        try writeTestPhoto(to: file)
        let photo = Journey("Photo", self, arguments: photoArguments(open: file))
        XCTAssert(photo.window(named: "beach.png").waitForExistence(timeout: 30), "beach.png didn't open")
        expectText("800 × 600 px", photo, "the status bar shows no 800 × 600 px image size")

        // 1. C picks Crop: the four fields, the caption and the six chips.
        let canvas = photo.element("suite.canvas")
        XCTAssert(canvas.waitForExistence(timeout: 5), "no canvas (suite.canvas)")
        canvas.click()
        photo.press(character: "c")
        XCTAssert(photo.app.buttons["photo.crop.apply"].waitForExistence(timeout: 5), "C didn't pick the crop tool (no Apply Crop)")
        for id in ["photo.crop.x", "photo.crop.y", "photo.crop.width", "photo.crop.height"] {
            XCTAssert(photo.element(id).waitForExistence(timeout: 5), "no crop field \(id)")
        }
        let caption = photo.element("photo.crop.caption")
        XCTAssert(caption.waitForExistence(timeout: 5), "no crop caption (photo.crop.caption)")
        let start = "Drag on the image, or pick a ratio below, to start a crop."
        let said = [caption.label, caption.value as? String ?? ""].joined(separator: " ")
        XCTAssert(said.contains(start), "the caption doesn't read \(start) (it reads \(said))")
        for chip in Self.chips {
            XCTAssert(panel(photo).buttons[chip].waitForExistence(timeout: 5), "no \(chip) aspect chip in the panel")
        }
        photo.shot("crop-typed-options")

        // 2. 1:1 gives the largest centred square: 600 x 600 at X 100, Y 0.
        chip("1:1", photo)
        expectCropPending(photo, "1:1")
        expectField("photo.crop.width", 600, photo)
        expectField("photo.crop.height", 600, photo)
        expectField("photo.crop.x", 100, photo)
        expectField("photo.crop.y", 0, photo)
        expectPill("1:1", photo)
        photo.shot("crop-typed-1to1")

        // 3. W 400 and Return: H follows the lock, X and Y stay, nothing is applied.
        typeNumber(400, into: "photo.crop.width", photo)
        expectField("photo.crop.height", 400, photo)
        expectField("photo.crop.width", 400, photo)
        expectField("photo.crop.x", 100, photo)
        expectField("photo.crop.y", 0, photo)
        expectCropPending(photo, "Return in W")
        expectText("800 × 600 px", photo, "Return in the W field applied the crop (the image isn't 800 × 600 px)")
        XCTAssertFalse(photo.app.buttons["Undo Crop"].exists, "Return in the W field made a Crop step")
        expectPill("1:1", photo)
        photo.shot("crop-typed-width")

        // 4. 3:2, then Swap: the lock reads 2:3 and the crop stands up.
        chip("3:2", photo)
        expectPill("3:2", photo)
        let swap = photo.app.buttons["photo.crop.swap"]
        XCTAssert(swap.waitForExistence(timeout: 5) && swap.isEnabled, "Swap isn't enabled under 3:2")
        swap.click()
        expectPill("2:3", photo)
        expectCropPending(photo, "Swap")
        let width = number(in: "photo.crop.width", photo), height = number(in: "photo.crop.height", photo)
        XCTAssertGreaterThan(height, width, "after Swap the crop isn't taller than wide (W \(width), H \(height))")
        photo.shot("crop-typed-swapped")

        // 5. Free: the crop stays, the pill goes.
        chip("Free", photo)
        expectCropPending(photo, "Free")
        let pill = photo.element("photo.canvas.crop.aspect")
        XCTAssert(pill.waitForNonExistence(timeout: 5), "the aspect pill still shows under Free")
        photo.shot("crop-typed-free")

        // 6. A drag from image pixel (10, 10) to (210, 110) gives W 200, H 100.
        let image = imageOnScreen(photo)
        let slack = max(1, Int((1 / max(image.scale, 0.01)).rounded(.up)))
        drag(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 210, y: 110), on: image, photo)
        expectCropPending(photo, "the drag")
        expectField("photo.crop.width", around: 200, within: slack, photo)
        expectField("photo.crop.height", around: 100, within: slack, photo)
        XCTAssertFalse(pill.exists, "a Free drag shows an aspect pill")
        let dragged = number(in: "photo.crop.width", photo)
        photo.shot("crop-typed-dragged")

        // 7. X 700 and Return clamps X so the crop stays on the image: 800 - W (600).
        typeNumber(700, into: "photo.crop.x", photo)
        expectField("photo.crop.x", 800 - dragged, photo)
        expectCropPending(photo, "X 700")
        photo.shot("crop-typed-clamped")

        // 8. Keys back to the canvas by a drag over the same crop, then Return applies it.
        let x = number(in: "photo.crop.x", photo), y = number(in: "photo.crop.y", photo)
        let h = number(in: "photo.crop.height", photo)
        drag(from: CGPoint(x: x, y: y), to: CGPoint(x: 805, y: y + h), on: image, photo)
        expectCropPending(photo, "the drag back to the canvas")
        expectField("photo.crop.x", around: x, within: slack, photo)
        let finalW = number(in: "photo.crop.width", photo), finalH = number(in: "photo.crop.height", photo)
        XCTAssertEqual(Double(finalW), 200, accuracy: Double(slack), "the crop to apply isn't 200 wide")
        XCTAssertEqual(Double(finalH), 100, accuracy: Double(slack), "the crop to apply isn't 100 tall")
        photo.press(.return)
        XCTAssert(photo.app.buttons["Undo Crop"].waitForExistence(timeout: 5), "Return on the canvas didn't apply the crop")
        expectText("\(finalW) × \(finalH) px", photo, "the cropped image isn't \(finalW) × \(finalH) px")
        XCTAssert(photo.element("photo.canvas.crop").waitForNonExistence(timeout: 5), "the crop is still pending after Return")
        photo.shot("crop-typed-applied")
        photo.app.menuBars.menuBarItems["Edit"].click()
        XCTAssert(photo.app.menuBars.menuItems["Undo Crop"].waitForExistence(timeout: 5), "Edit doesn't show Undo Crop")
        photo.shot("crop-typed-undo-menu", screen: true)
        photo.press(.escape)
    }

    // MARK: Steps

    /// The right-hand panel, where the crop options sit.
    @MainActor private func panel(_ photo: Journey) -> XCUIElement { photo.element("suite.inspector") }

    /// Clicks the aspect chip titled `title`.
    @MainActor private func chip(_ title: String, _ photo: Journey) {
        let button = panel(photo).buttons[title].firstMatch
        XCTAssert(button.waitForExistence(timeout: 5), "no \(title) aspect chip in the panel")
        button.click()
    }

    /// The crop's element is there after `step`.
    @MainActor private func expectCropPending(_ photo: Journey, _ step: String) {
        XCTAssert(photo.element("photo.canvas.crop").waitForExistence(timeout: 5), "no pending crop (photo.canvas.crop) after \(step)")
    }

    /// The aspect pill reads `text`.
    @MainActor private func expectPill(_ text: String, _ photo: Journey) {
        let pill = photo.app.descendants(matching: .any).matching(identifier: "photo.canvas.crop.aspect")
            .matching(NSPredicate(format: "label == %@", text)).firstMatch
        let shown = photo.element("photo.canvas.crop.aspect")
        XCTAssert(pill.waitForExistence(timeout: 5), "the aspect pill doesn't read \(text) (it reads \(shown.exists ? shown.label : "nothing"))")
    }

    /// A label or value holding `text`, as the status bar's "800 × 600 px".
    @MainActor private func expectText(_ text: String, _ photo: Journey, _ message: String) {
        let match = photo.app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text)).firstMatch
        XCTAssert(match.waitForExistence(timeout: 5), message)
    }

    /// Waits for the crop field `id` to read `value` pixels.
    @MainActor private func expectField(_ id: String, _ value: Int, _ photo: Journey) {
        expectField(id, around: value, within: 0, photo)
    }

    /// Waits for the crop field `id` to read a whole number of pixels within `slack` of `value`.
    @MainActor private func expectField(_ id: String, around value: Int, within slack: Int, _ photo: Journey) {
        let numbers = (max(0, value - slack)...(value + slack)).map(String.init).joined(separator: "|")
        // The whole number before " px" or " pixel(s)", not the tail of a longer one.
        let pattern = "(?s)(.*[^0-9])?(\(numbers)) (px|pixel).*"
        let field = photo.app.descendants(matching: .any).matching(identifier: id)
            .matching(NSPredicate(format: "label MATCHES %@ OR value MATCHES %@", pattern, pattern)).firstMatch
        let shown = slack == 0 ? "\(value)" : "\(value) ± \(slack)"
        XCTAssert(field.waitForExistence(timeout: 5), "\(id) doesn't read \(shown) px (it reads \(text(of: id, photo)))")
    }

    /// The whole pixels the crop field `id` shows; -1 when it shows none.
    @MainActor private func number(in id: String, _ photo: Journey) -> Int {
        let words = text(of: id, photo).split { $0 == " " || $0 == "," }
        for (word, next) in zip(words, words.dropFirst()) where next.hasPrefix("px") || next.hasPrefix("pixel") {
            if let value = Int(word) { return value }
        }
        XCTFail("\(id) shows no number of pixels (it reads \(text(of: id, photo)))")
        return -1
    }

    /// The label and value of the element `id`, as one string.
    @MainActor private func text(of id: String, _ photo: Journey) -> String {
        let element = photo.element(id)
        guard element.exists else { return "nothing" }
        return [element.label, element.value as? String ?? ""].joined(separator: " ")
    }

    /// Clicks the crop field `id`'s number to type, replaces it with `value` and presses Return.
    @MainActor private func typeNumber(_ value: Int, into id: String, _ photo: Journey) {
        let field = photo.element(id)
        XCTAssert(field.waitForExistence(timeout: 5) && field.isEnabled, "the crop field \(id) isn't there to type in")
        // The number sits at the row's right, inside its 12 pt inset and 56 pt wide.
        field.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5)).withOffset(CGVector(dx: -40, dy: 0)).click()
        let typing = panel(photo).textFields.firstMatch
        // The typing field takes the keys as it opens (ScrubField asks for focus), as typeValue in PhotoJourneyTests.
        _ = typing.waitForExistence(timeout: 3)
        photo.app.typeKey(.rightArrow, modifierFlags: .command)
        for _ in 0..<8 { photo.app.typeKey(.delete, modifierFlags: []) }
        photo.app.typeText("\(value)")
        photo.app.typeKey(.return, modifierFlags: [])
        XCTAssert(typing.waitForNonExistence(timeout: 5), "Return didn't close \(id)'s typing field")
    }

    /// Drags on the canvas between two image pixels, the image placed as `image` says.
    @MainActor private func drag(
        from start: CGPoint, to end: CGPoint, on image: (origin: CGPoint, scale: CGFloat), _ photo: Journey
    ) {
        let canvas = photo.element("suite.canvas")
        let corner = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0)), frame = canvas.frame
        let at = { (pixel: CGPoint) in
            corner.withOffset(CGVector(
                dx: image.origin.x - frame.minX + pixel.x * image.scale,
                dy: image.origin.y - frame.minY + pixel.y * image.scale))
        }
        at(start).press(forDuration: 0.1, thenDragTo: at(end))
    }

    /// Where image pixel (0, 0) sits on screen and the points per pixel, read
    /// from the pending crop's mark, whose frame covers the crop the fields show.
    @MainActor private func imageOnScreen(_ photo: Journey) -> (origin: CGPoint, scale: CGFloat) {
        let mark = photo.element("photo.canvas.crop").frame
        let (x, y) = (number(in: "photo.crop.x", photo), number(in: "photo.crop.y", photo))
        let (w, h) = (number(in: "photo.crop.width", photo), number(in: "photo.crop.height", photo))
        let scale = mark.width / CGFloat(max(w, 1))
        XCTAssertEqual(
            mark.height / CGFloat(max(h, 1)), scale, accuracy: 0.01, "the crop mark \(mark) isn't \(w) × \(h) at one zoom")
        return (CGPoint(x: mark.minX - CGFloat(x) * scale, y: mark.minY - CGFloat(y) * scale), scale)
    }
}

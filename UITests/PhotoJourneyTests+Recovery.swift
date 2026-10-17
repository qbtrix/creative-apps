// PhotoJourneyTests+Recovery.swift: photo-documents' journey PJ-3
// (docs/blueprints/photo/features/photo-documents.md, Journey steps 4;
// blueprint photo 4.2). beach.png opens with `-PhotoRecoveryDir <tmp>`;
// Layer > New Layer and a brush stroke make it "Edited", and 5 s after the
// last edit `photo.bar.saved` reads "Edited, autosaved" with a `.ora` in the
// folder. `app.terminate()` stands in for a crash; a relaunch on the same
// folder with no file offers "Restore beach.png from <time>?" with
// `photo.recovery.restore` and `photo.recovery.discard`. Restore gives 2
// layers, still edited. Command-Q asks (D-10's alert), Don't Save quits and
// takes the recovery file with it, so the next launch offers nothing. Packet
// note 3: a recovery file that isn't a zip (`not a zip`) is removed at launch
// and offers nothing. One shot per step, "recovery-".
import XCTest

final class PhotoRecoveryJourneyTests: XCTestCase {
    /// PJ-3: autosave, a crash, Restore, a clean quit, and a damaged file dropped.
    @MainActor func testRestoreAfterCrash() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "photo-recovery-\(UUID().uuidString)")
        let recovery = folder.appending(path: "recovery")
        try FileManager.default.createDirectory(at: recovery, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: "beach.png")
        try writeTestPhoto(to: file)

        // 1. beach.png, New Layer, a stroke: "Edited", then "Edited, autosaved" 5 s on, a .ora in the folder.
        var photo = Journey("Photo", self, arguments: photoArguments(open: file, recoveryDir: recovery))
        XCTAssert(photo.window(named: "beach.png").waitForExistence(timeout: 30), "beach.png didn't open")
        XCTAssert(photo.element("suite.canvas").waitForExistence(timeout: 5), "no canvas (suite.canvas)")
        photo.shot("recovery-opened")
        choose("New Layer", from: "Layer", photo)
        expect("Undo New Layer", photo, "Layer > New Layer made no New Layer step")
        photo.element("suite.tools").buttons["Brush"].click()
        photo.drag(on: "suite.canvas", from: CGVector(dx: 0.2, dy: 0.3), to: CGVector(dx: 0.8, dy: 0.7))
        expect("Undo Paint", photo, "the brush stroke on Layer 1 didn't paint")
        let painted = Date()
        expectStatus("Edited", photo, timeout: 3)
        photo.shot("recovery-edited")
        expectStatus("Edited, autosaved", photo, timeout: 20)
        let waited = Date().timeIntervalSince(painted)
        XCTAssertGreaterThanOrEqual(waited, 4, "it autosaved \(waited) s after the stroke; the delay is 5 s")
        XCTAssert(waitFor { !self.recoveryFiles(recovery).isEmpty }, "the autosave left no .ora in the recovery folder")
        photo.shot("recovery-autosaved")

        // 2–3. A crash, then a launch with no file: the offer names beach.png and a time.
        photo.app.terminate()
        photo = Journey("Photo", self, arguments: photoArguments(recoveryDir: recovery))
        let offer = offerTitle(photo)
        XCTAssert(offer.waitForExistence(timeout: 30), "the relaunch offered no restore of beach.png")
        let message = [offer.label, offer.value as? String ?? ""].first { $0.hasPrefix("Restore ") } ?? offer.label
        let time = message.dropFirst("Restore beach.png from ".count).dropLast()
        XCTAssert(message.hasSuffix("?") && time.contains { $0.isNumber }, "the offer reads \(message), not Restore beach.png from <time>?")
        let restore = photo.app.buttons["photo.recovery.restore"], discard = photo.app.buttons["photo.recovery.discard"]
        XCTAssert(restore.waitForExistence(timeout: 5), "the offer has no Restore (photo.recovery.restore)")
        XCTAssert(discard.exists, "the offer has no Discard (photo.recovery.discard)")
        photo.shot("recovery-offer")

        // 4. Restore: 2 layers, and the image is edited (nothing of it is saved).
        restore.click()
        XCTAssert(offer.waitForNonExistence(timeout: 10), "the offer stayed up after Restore")
        XCTAssert(photo.element("suite.canvas").waitForExistence(timeout: 15), "Restore opened no canvas")
        expectHeader("2 layers", photo, "the restored image doesn't have 2 layers")
        expectStatus("Edited", photo, timeout: 3, prefix: true)
        photo.shot("recovery-restored")

        // 5. Command-Q asks; Don't Save quits and discards; the next launch offers nothing.
        photo.press(character: "q", .command)
        let dontSave = photo.app.buttons["photo.unsaved.dontSave"]
        XCTAssert(dontSave.waitForExistence(timeout: 15), "Command-Q on the restored image didn't ask (photo.unsaved.dontSave)")
        XCTAssert(photo.app.buttons["photo.unsaved.save"].exists, "the unsaved alert has no Save (photo.unsaved.save)")
        XCTAssert(photo.app.buttons["photo.unsaved.cancel"].exists, "the unsaved alert has no Cancel (photo.unsaved.cancel)")
        photo.shot("recovery-quit-prompt")
        dontSave.click()
        XCTAssert(photo.app.wait(for: .notRunning, timeout: 15), "Don't Save didn't quit Photo")
        XCTAssert(waitFor { self.recoveryFiles(recovery).isEmpty }, "Don't Save left \(recoveryFiles(recovery)) behind")
        photo = relaunchExpectingNoOffer(recovery, step: "recovery-no-offer")
        photo.app.terminate()

        // Packet note 3: a damaged recovery file is removed at launch, and nothing is offered.
        let damaged = recovery.appending(path: "x.ora")
        try Data("not a zip".utf8).write(to: damaged)
        photo = relaunchExpectingNoOffer(recovery, step: "recovery-damaged-dropped")
        XCTAssert(
            waitFor { !FileManager.default.fileExists(atPath: damaged.path) },
            "the launch left the damaged x.ora in the recovery folder")
    }

    // MARK: - Steps

    /// Launches Photo on `recovery` with no file: the empty window, and no offer within 5 s.
    @MainActor private func relaunchExpectingNoOffer(_ recovery: URL, step: String) -> Journey {
        let photo = Journey("Photo", self, arguments: photoArguments(recoveryDir: recovery))
        XCTAssert(photo.app.windows["Photo"].waitForExistence(timeout: 30), "the empty Photo window didn't open")
        XCTAssertFalse(offerTitle(photo).waitForExistence(timeout: 5), "the launch offered a restore: \(offerTitle(photo).label)")
        XCTAssertFalse(photo.app.buttons["photo.recovery.restore"].exists, "the launch shows Restore (photo.recovery.restore)")
        photo.shot(step)
        return photo
    }

    /// The offer's title: a static text whose label or value starts "Restore beach.png from ".
    @MainActor private func offerTitle(_ photo: Journey) -> XCUIElement {
        let prefix = "Restore beach.png from "
        return photo.app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@ OR value BEGINSWITH %@", prefix, prefix)).firstMatch
    }

    /// `photo.bar.saved` reads `title` (or starts with it, when `prefix`).
    @MainActor private func expectStatus(_ title: String, _ photo: Journey, timeout: TimeInterval, prefix: Bool = false) {
        let match = prefix ? "label BEGINSWITH %@" : "label == %@"
        let status = photo.app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == 'photo.bar.saved' AND \(match)", title)).firstMatch
        if status.waitForExistence(timeout: timeout) { return }
        let saved = photo.element("photo.bar.saved")
        XCTFail("photo.bar.saved doesn't read \(title) (it reads \(saved.exists ? saved.label : "nothing"))")
    }

    /// Picks the enabled `item` from the menu bar's `menu`, then waits for the menu to close.
    @MainActor private func choose(_ item: String, from menu: String, _ photo: Journey) {
        photo.app.menuBars.menuBarItems[menu].click()
        let entry = photo.app.menuBars.menuItems[item]
        XCTAssert(entry.waitForExistence(timeout: 5), "the \(menu) menu has no \(item)")
        XCTAssert(entry.isEnabled, "\(menu) > \(item) is disabled")
        entry.click()
        // Closed menus stay in the tree with empty frames (#1222, HaloJourneyTests+Menus.swift).
        XCTAssert(waitFor { !photo.app.menus.allElementsBoundByIndex.contains { !$0.frame.isEmpty } }, "the \(menu) menu stayed open")
    }

    /// Waits for the button titled `title`, such as the window toolbar's "Undo Paint".
    @MainActor private func expect(_ title: String, _ photo: Journey, _ message: String) {
        XCTAssert(photo.app.buttons[title].waitForExistence(timeout: 5), "\(message) (no \(title) button)")
    }

    /// Waits for a label holding `text`, as the header's "beach.png, 800 × 600 px, sRGB · 2 layers".
    @MainActor private func expectHeader(_ text: String, _ photo: Journey, _ message: String) {
        let matching = photo.app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text))
        if matching.firstMatch.waitForExistence(timeout: 5) { return }
        let header = photo.app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", " px, sRGB"))
            .firstMatch
        XCTFail("\(message) (no label holds \(text); the header reads \(header.exists ? header.label : "nothing"))")
    }

    /// The `.ora` files in `folder`.
    private func recoveryFiles(_ folder: URL) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).filter { $0.hasSuffix(".ora") }
    }

    /// Whether `condition` holds within `seconds`.
    @MainActor private func waitFor(seconds: Int = 10, _ condition: () -> Bool) -> Bool {
        for _ in 0..<(seconds * 5) {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }
}

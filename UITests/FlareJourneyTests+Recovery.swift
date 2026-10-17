// FlareJourneyTests+Recovery.swift: J28 of layers-files (LF-5;
// docs/blueprints/flare/features/layers-files.md, Journey step 5). On
// `-FlareSample bounce` with `-FlareSaveTo` a folder the test made read-only
// and `-FlareRecoveryFile` in this test's temp folder: New Layer, then the
// toolbar's Save shows the save alert, and after OK `flare.saveStatus` still
// reads "Not saved" (in the error color; the shot shows it). Then Select
// drags Ball (at (80, 100) on frame 0) 100 scene points right; the autosave
// writes the recovery file 30 s after that last edit. `app.terminate()`
// stands in for a crash; a relaunch on the same recovery file with no
// document offers "Restore the unsaved animation from <time>?" with
// `flare.recovery.restore` and `flare.recovery.discard`. Restore brings back
// the document, edited and untitled, with Ball at the moved spot: a click
// there selects Ball's track, a click where Ball was doesn't. One shot per
// step, `flare-recovery-<step>`.
import XCTest

final class FlareRecoveryJourneys: XCTestCase {
    private static let sceneWidth = 550.0

    @MainActor func testSaveFailureAndRecovery() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "flare-recovery-\(UUID().uuidString)")
        let locked = folder.appending(path: "Locked")
        try FileManager.default.createDirectory(at: locked, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: locked.path)
        addTeardownBlock {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path)
            try? FileManager.default.removeItem(at: folder)
        }
        let recovery = folder.appending(path: "Recovery.flare")
        let recoveryFlag = ["-FlareRecoveryFile", recovery.path]

        // 1. An edit, then Save into a read-only folder: the alert, then "Not saved" in the window.
        var flare = launch(["-FlareSample", "bounce", "-FlareSaveTo", locked.path] + recoveryFlag)
        let newLayer = flare.element("suite.sidebar").buttons["New Layer"]
        XCTAssert(newLayer.waitForExistence(timeout: 10), "the sidebar has no New Layer")
        newLayer.click()
        expectFile("Edited", flare)
        let save = flare.app.toolbars.firstMatch.buttons["flare.file.save"]
        XCTAssert(save.waitForExistence(timeout: 10) && waitFor { save.isEnabled }, "Save is missing or disabled")
        save.click()
        let failed = alert(flare)
        let message = failed.staticTexts.matching(NSPredicate(
            format: "label BEGINSWITH %@ OR value BEGINSWITH %@",
            "Flare couldn't save this animation", "Flare couldn't save this animation")).firstMatch
        XCTAssert(message.waitForExistence(timeout: 10), "a read-only save showed no save alert")
        let status = flare.element("flare.saveStatus")
        XCTAssert(status.waitForExistence(timeout: 5) && status.label == "Not saved",
                  "the window doesn't say Not saved (flare.saveStatus) after the failed save")
        flare.shot("recovery-1-save-alert")
        failed.buttons["OK"].click()
        XCTAssert(waitFor { status.exists && status.label == "Not saved" }, "Not saved went with the alert")
        expectFile("Edited", flare)
        flare.shot("recovery-1-not-saved")

        // 2. Select, drag Ball 100 points right; the recovery file lands about 30 s after the drag.
        let canvas = flare.element("suite.canvas")
        XCTAssert(canvas.waitForExistence(timeout: 10), "no stage (suite.canvas)")
        let select = flare.element("suite.tools").buttons["Select"]
        XCTAssert(select.waitForExistence(timeout: 5), "no Select in the palette")
        select.click()
        point(80, 100, on: canvas).press(forDuration: 0.1, thenDragTo: point(180, 100, on: canvas))
        let moved = Date()
        XCTAssert(waitFor(seconds: 60) { FileManager.default.fileExists(atPath: recovery.path) },
                  "no autosave wrote \(recovery.path) within 60 s of the drag")
        let waited = Date().timeIntervalSince(moved)
        XCTAssertGreaterThanOrEqual(waited, 25, "it autosaved \(waited) s after the drag; the delay is 30 s")
        flare.shot("recovery-2-autosaved")

        // 3. A crash, then a launch with no document: the offer with its time, Restore and Discard.
        flare.app.terminate()
        flare = launch(recoveryFlag)
        let offer = flare.app.staticTexts.matching(NSPredicate(
            format: "label BEGINSWITH %@ OR value BEGINSWITH %@",
            "Restore the unsaved animation from ", "Restore the unsaved animation from ")).firstMatch
        XCTAssert(offer.waitForExistence(timeout: 30), "the relaunch offered no restore")
        let text = [offer.label, offer.value as? String ?? ""].first { $0.hasPrefix("Restore ") } ?? offer.label
        XCTAssert(text.hasSuffix("?") && text.contains { $0.isNumber }, "the offer reads \(text), not one with a time")
        let restore = flare.app.buttons["flare.recovery.restore"]
        XCTAssert(restore.waitForExistence(timeout: 5), "the offer has no Restore (flare.recovery.restore)")
        XCTAssert(flare.app.buttons["flare.recovery.discard"].exists, "the offer has no Discard (flare.recovery.discard)")
        flare.shot("recovery-3-offer")

        // 4. Restore: edited and untitled, Ball where the drag left it.
        restore.click()
        XCTAssert(offer.waitForNonExistence(timeout: 10), "the offer stayed up after Restore")
        let stage = flare.element("suite.canvas")
        XCTAssert(stage.waitForExistence(timeout: 15), "Restore opened no stage")
        expectFile("Edited", flare)
        let window = flare.app.windows.firstMatch
        XCTAssert(waitFor { window.title == "Untitled" }, "the restored window is titled \(window.title)")
        let pick = flare.element("suite.tools").buttons["Select"]
        XCTAssert(pick.waitForExistence(timeout: 5), "no Select in the palette")
        pick.click()
        let ball = flare.element("flare.timeline").buttons.matching(
            NSPredicate(format: "label == 'Ball'")).firstMatch
        XCTAssert(ball.waitForExistence(timeout: 5), "no Ball track in the timeline")
        point(80, 100, on: stage).click()
        XCTAssert(waitFor { !ball.isSelected }, "a click where Ball was still hits Ball after Restore")
        point(180, 100, on: stage).click()
        XCTAssert(waitFor { ball.isSelected }, "Restore lost the move: Ball isn't at the moved spot")
        flare.shot("recovery-4-restored")
    }

    // MARK: - Helpers

    @MainActor private func launch(_ arguments: [String]) -> Journey {
        let flare = Journey("Flare", self, arguments: arguments)
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        return flare
    }

    /// `flare.file`'s label: "Edited" while the dot shows, else "Saved".
    @MainActor private func expectFile(_ status: String, _ flare: Journey) {
        let element = flare.element("flare.file")
        XCTAssert(waitFor { element.label == status }, "flare.file reads \(element.label), not \(status)")
    }

    @MainActor private func alert(_ flare: Journey) -> XCUIElement {
        let sheet = flare.app.sheets.firstMatch
        return sheet.waitForExistence(timeout: 10) ? sheet : flare.app.dialogs.firstMatch
    }

    /// The screen point of the scene point (`x`, `y`): the artboard's corner plus the point at its fit scale.
    @MainActor private func point(_ x: Double, _ y: Double, on canvas: XCUIElement) -> XCUICoordinate {
        let scale = canvas.frame.width / Self.sceneWidth
        return canvas.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x * scale, dy: y * scale))
    }

    private func waitFor(seconds: Int = 10, _ condition: () -> Bool) -> Bool {
        for _ in 0..<(seconds * 10) {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return condition()
    }
}

// PhotoJourneyTests+Tone.swift: PJ-T1 testWarmShadowsAndSharpen (tone-controls
// PT-6; docs/blueprints/photo/features/tone-controls.md, Journey steps). On
// tools.png the Adjust panel shows SuiteUI's tone rows (WHITE BALANCE, TONE,
// PRESENCE, SHARPEN) under Photo's own Exposure, with one Exposure row.
// Temperature −25 changes the canvas and one Undo gives it back; Shadows +40,
// Highlights −30 and Auto make one "Auto Tone" step; on a Levels adjustment
// layer Contrast +20 changes the canvas and Sharpen is off with its help;
// back on the image, Sharpen Amount 80 changes the canvas and Export writes a
// PNG. Written skipped in PT-6; PT-7 turned it on, with the rows' controls
// (TC-3) and the tone.* commands (PT-4) live. Rows are found by their
// `suite.tone.<slider>` ids, Auto by `suite.tone.auto`. Shots: `photo-tone-*`.
import XCTest

final class PhotoToneJourneyTests: XCTestCase {
    /// PJ-T1: white balance, tone and Auto, an adjustment layer's tone, then Sharpen and Export.
    @MainActor func testWarmShadowsAndSharpen() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "photo-tone-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: "tools.png"), exports = folder.appending(path: "exports")
        try FileManager.default.createDirectory(at: exports, withIntermediateDirectories: true)
        try writeTestPhoto(to: file)
        let photo = Journey("Photo", self, arguments: photoArguments(open: file, exportTo: exports))
        XCTAssert(photo.window(named: "tools.png").waitForExistence(timeout: 30), "tools.png didn't open")
        let opened = canvas(photo)

        // 1. The tone rows under Exposure; Exposure shows once.
        let panel = photo.element("suite.tone")
        XCTAssert(panel.waitForExistence(timeout: 5), "the Adjust panel shows no tone rows (suite.tone)")
        for group in ["WHITE BALANCE", "TONE", "PRESENCE", "SHARPEN"] {
            XCTAssert(panel.staticTexts[group].exists, "the tone rows have no \(group) section")
        }
        let exposure = photo.app.sliders.matching(NSPredicate(format: "label == 'Exposure'"))
        XCTAssertEqual(exposure.count, 1, "the Adjust panel shows Exposure \(exposure.count) times")
        photo.shot("tone-panel")

        // 2. Temperature −25 changes the canvas; one Undo gives it back.
        type("-25", into: "temperature", photo)
        XCTAssert(waitUntil { self.canvas(photo) != opened }, "Temperature −25 didn't change the canvas")
        photo.press(character: "z", .command)
        XCTAssert(waitUntil { self.canvas(photo) == opened }, "one Undo didn't give back the opened canvas")

        // 3. Shadows +40, Highlights −30, then Auto: one "Auto Tone" step.
        type("40", into: "shadows", photo)
        type("-30", into: "highlights", photo)
        photo.app.buttons["suite.tone.auto"].click()
        XCTAssert(photo.app.buttons["Undo Auto Tone"].waitForExistence(timeout: 5), "Auto made no Auto Tone step")
        photo.shot("tone-auto")

        // 4. A Levels adjustment layer: Contrast +20 changes the canvas; Sharpen is off with its help.
        photo.choose(menu: ["Layer", "New Adjustment Layer", "Levels"])
        let before = canvas(photo)
        type("20", into: "contrast", photo)
        XCTAssert(waitUntil { self.canvas(photo) != before }, "the layer's Contrast +20 didn't change the canvas")
        let amount = photo.element("suite.tone.sharpenAmount")
        XCTAssert(amount.waitForExistence(timeout: 5) && !amount.isEnabled, "Sharpen is on for an adjustment layer")
        XCTAssertFalse(amount.label.isEmpty && (amount.value as? String ?? "").isEmpty, "the off Sharpen row has no help")
        photo.shot("tone-layer")

        // 5. The image again: Sharpen Amount 80 changes the canvas, and Export writes a PNG.
        photo.app.staticTexts["Background"].click()
        let soft = canvas(photo)
        type("80", into: "sharpenAmount", photo)
        XCTAssert(waitUntil { self.canvas(photo) != soft }, "Sharpen Amount 80 didn't change the canvas")
        photo.choose(menu: ["File", "Export…"])
        photo.reachable("Export", in: photo.app.sheets.firstMatch).click()
        XCTAssert(waitUntil {
            let names = (try? FileManager.default.contentsOfDirectory(atPath: exports.path)) ?? []
            return names.contains { $0.lowercased().hasSuffix(".png") }
        }, "Export wrote no PNG")
        photo.shot("tone-sharpened")
    }

    /// The canvas as the screen shows it.
    @MainActor private func canvas(_ photo: Journey) -> Data {
        photo.element("suite.canvas").screenshot().pngRepresentation
    }

    /// Types `value` into the tone row `suite.tone.<slider>`'s number, then Return.
    @MainActor private func type(_ value: String, into slider: String, _ photo: Journey) {
        let row = photo.element("suite.tone.\(slider)")
        XCTAssert(row.waitForExistence(timeout: 5), "no tone row suite.tone.\(slider)")
        row.doubleClick()
        let field = row.textFields.firstMatch.exists ? row.textFields.firstMatch : photo.app.textFields.firstMatch
        XCTAssert(field.waitForExistence(timeout: 5), "suite.tone.\(slider) opened no field to type in")
        field.typeKey("a", modifierFlags: .command)
        field.typeText(value + "\r")
    }

    /// True once `condition` holds, polled for five seconds.
    @MainActor private func waitUntil(_ condition: () -> Bool) -> Bool {
        for _ in 0..<20 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return condition()
    }
}

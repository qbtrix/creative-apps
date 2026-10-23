// HaloJourneyTests+Settings.swift: HJ-DS (document-setup DS-11, slice DS-halo), Composition Settings… later.
// A 10 s composition; Composition > Composition Settings… opens the shared Document Settings sheet: Duration
// 15, Background Color #1B2A4A, Apply. The inspector header reads "· 15 s" and the viewer's centre is navy;
// one Undo puts back 10 s and the white canvas. The Model half is HaloCompositionSettingsTests. One shot per
// step, `halo-settings-<n>-<step>`.
import AppKit
import XCTest

final class HaloSettingsJourneyTests: XCTestCase {
    /// HJ-DS: 10 s to 15 s on navy through Composition Settings…, then one Undo restores both.
    @MainActor func testCompositionSettingsLater() throws {
        try XCTSkipIf(true, "waits on DS-12")
        let halo = Journey("Halo", self, arguments: ["-HaloWindowSize", "1000x640"])
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")

        // 1. A 10 s composition from New Composition…'s defaults.
        halo.reachable("New Composition…").click()
        let newSheet = halo.app.sheets.firstMatch
        XCTAssert(newSheet.waitForExistence(timeout: 5), "New Composition… opened no sheet")
        halo.reachable("Create", in: newSheet).click()
        XCTAssert(header("· 10 s", halo).waitForExistence(timeout: 5), "the new composition isn't 10 s")
        halo.shot("settings-1-new")

        // 2. Composition Settings…: Duration 15, Background Color #1B2A4A, Apply.
        halo.choose(menu: ["Composition", "Composition Settings…"])
        let sheet = halo.app.sheets.firstMatch
        XCTAssert(sheet.waitForExistence(timeout: 5), "Composition Settings… opened no sheet")
        type("15", into: sheet.textFields["Duration"])
        let kinds = sheet.segmentedControls["suite.newdoc.background"]
        XCTAssert(kinds.waitForExistence(timeout: 5), "the sheet has no background picker")
        kinds.buttons["Color"].click()
        type("#1B2A4A", into: sheet.textFields["#RRGGBB"])
        halo.shot("composition-settings")
        halo.element("suite.newdoc.create").click()

        // 3. The timeline is 15 s and the viewer navy.
        XCTAssert(header("· 15 s", halo).waitForExistence(timeout: 5), "the header doesn't read 15 s")
        XCTAssert(isNavy(centreOf: halo.element("halo.viewer.canvas")), "the viewer isn't navy")
        halo.shot("settings-2-navy")

        // 4. One Undo restores both.
        halo.app.typeKey("z", modifierFlags: .command)
        XCTAssert(header("· 10 s", halo).waitForExistence(timeout: 5), "Undo didn't restore 10 s")
        XCTAssert(!isNavy(centreOf: halo.element("halo.viewer.canvas")), "Undo didn't restore the white canvas")
        halo.shot("settings-3-undone")
    }

    /// The inspector header once its label contains `text`.
    @MainActor private func header(_ text: String, _ halo: Journey) -> XCUIElement {
        halo.app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == 'halo.inspector.header' AND label CONTAINS %@", text)).firstMatch
    }

    /// Replaces `field`'s text with `text`.
    @MainActor private func type(_ text: String, into field: XCUIElement) {
        XCTAssert(field.waitForExistence(timeout: 5), "no \(field) field")
        field.click()
        field.typeKey("a", modifierFlags: .command)
        field.typeText(text)
    }

    /// Whether the centre pixel of `element`'s screenshot is the navy #1B2A4A, give or take display colour.
    @MainActor private func isNavy(centreOf element: XCUIElement) -> Bool {
        guard element.waitForExistence(timeout: 5),
              let bitmap = NSBitmapImageRep(data: element.screenshot().pngRepresentation),
              let color = bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2)?.usingColorSpace(.sRGB)
        else { return false }
        return color.redComponent < 0.25 && color.blueComponent > 0.2 && color.blueComponent > color.redComponent + 0.1
    }
}

// SuiteJourneyTests+LayerStyle.swift: the gallery's `layer-style` page (Sources/SuiteUI/Gallery/GalleryLayerStyle.swift),
// Journey steps 1 to 7 of docs/blueprints/suiteui/features/layer-styles.md (numbered below), in Library, shot under
// `suiteui`. The panel's controls are LS-3's `suite.style.*`: `kind.<kind>` (a kind's row), `toggle.<kind>` (its
// switch), the selected kind's rows by field (`distance`, `angle`, `altitude`, `opacity`, `blend`,
// `position.<inside|outside|center>`, `fill.gradient`), `presets`, `done` and `help`; the shared editor is
// `suite.gradient.bar`. The preview is `suite.gallery.layer-style.preview`, its value the enabled kinds ("no style",
// "dropShadow, outerGlow"); the page logs `<command id> <intent>` to `suite.gallery.log`. Written in LS-2, skipped
// until LS-4 turns it on. SJ0 (testGalleryOpensEveryPage) opens the page meanwhile.
import XCTest

final class SuiteLayerStyleJourneyTests: XCTestCase {
    @MainActor func testLayerStylePanelEditsAStyle() throws {
        throw XCTSkip("waits on LS-4") // LS-4 turns it on: `walkTheLayerStylePanel()` in place of this line.
    }

    /// Steps 1 to 7 on the page.
    @MainActor private func walkTheLayerStylePanel() {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "index"])
        XCTAssert(gallery.element("suite.gallery.index").waitForExistence(timeout: 30), "no gallery index")
        gallery.element("suite.gallery.index.layer-style").click() // 1. A rounded square, no style, eight rows off.
        XCTAssert(gallery.element("suite.gallery.layer-style").waitForExistence(timeout: 10), "no suite.gallery.layer-style")
        let preview = gallery.element("suite.gallery.layer-style.preview")
        XCTAssert(preview.waitForExistence(timeout: 5), "no layer style preview")
        XCTAssertEqual(preview.value as? String, "no style", "the page doesn't start on no style")
        for kind in Self.kinds {
            XCTAssertEqual(gallery.element("suite.style.toggle.\(kind)").value as? Int, 0, "\(kind) starts on")
        }
        gallery.shot("layer-style-open")

        gallery.element("suite.style.toggle.dropShadow").click() // 2. Drop Shadow on: one style.enable or style.add.
        expectStyleLog(gallery, "style.", "turning on Drop Shadow logged nothing")
        XCTAssertEqual(preview.value as? String, "dropShadow", "Drop Shadow didn't turn on")
        gallery.shot("layer-style-drop-shadow")

        let distance = gallery.element("suite.style.distance") // 3. Distance 8 to 24: one drag token.
        let grip = distance.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
        grip.press(forDuration: 0.1, thenDragTo: grip.withOffset(CGVector(dx: 80, dy: 0)))
        expectStyleLog(gallery, "style.set", "the Distance scrub logged no style.set")
        let tokens = Set(logLines(gallery).filter { $0.hasPrefix("style.set") }.compactMap { line in
            line.range(of: "drag: ").map { String(line[$0.upperBound...]) }
        })
        XCTAssertEqual(tokens.count, 1, "one Distance scrub logged more than one drag token")

        gallery.element("suite.style.blend").click() // 4. Multiply, 50% opacity, then the Lifted preset.
        gallery.app.menuItems["Multiply"].click()
        let opacity = gallery.element("suite.style.opacity")
        opacity.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).doubleClick()
        gallery.app.typeText("50")
        gallery.press(.return)
        gallery.element("suite.style.presets").click()
        gallery.app.menuItems["Lifted"].click()
        expectStyleLog(gallery, "style.preset", "Lifted logged no style.preset")
        XCTAssertEqual(logLines(gallery).filter { $0.hasPrefix("style.preset") }.count, 1, "Lifted logged more than one step")
        XCTAssertEqual(preview.value as? String, "dropShadow, outerGlow", "Lifted didn't set a shadow and a glow")
        gallery.shot("layer-style-preset")

        gallery.element("suite.style.kind.stroke").click() // 5. Stroke outside, then a gradient fill shows the editor.
        gallery.element("suite.style.toggle.stroke").click()
        gallery.element("suite.style.position.outside").click()
        gallery.element("suite.style.fill.gradient").click()
        XCTAssert(gallery.element("suite.gradient.bar").waitForExistence(timeout: 5), "no gradient editor under Stroke")
        gallery.shot("layer-style-stroke-gradient")

        gallery.element("suite.style.kind.bevel").click() // 6. Bevel & Emboss; keyboard and VoiceOver.
        gallery.element("suite.style.toggle.bevel").click()
        for field in ["angle", "altitude"] {
            let row = gallery.element("suite.style.\(field)")
            let start = row.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 40, dy: 0)))
        }
        expectStyleLog(gallery, "style.set", "the bevel scrubs logged no style.set")
        XCTAssertEqual(gallery.element("suite.style.toggle.dropShadow").label, "Drop Shadow")
        gallery.element("suite.style.toggle.innerShadow").click()
        gallery.press(.space)
        XCTAssertEqual(gallery.element("suite.style.toggle.innerShadow").value as? Int, 0, "Space didn't toggle Inner Shadow back")
        gallery.shot("layer-style-bevel")

        gallery.element("suite.style.done").click() // 7. Done closes the panel; the fx button opens it (where landed).
        expectStyleLog(gallery, "style.panel", "Done logged no style.panel")
    }

    /// The panel's eight kinds, in order.
    private static let kinds = ["dropShadow", "innerShadow", "outerGlow", "innerGlow", "stroke", "colorOverlay",
                                "gradientOverlay", "bevel"]

    /// The page's log, one line per intent.
    @MainActor private func logLines(_ gallery: Journey) -> [Substring] {
        (gallery.element("suite.gallery.log").value as? String ?? "").split(separator: "\n")
    }

    /// Waits up to five seconds for a line of the page's log to start with `id`.
    @MainActor private func expectStyleLog(_ gallery: Journey, _ id: String, _ message: String) {
        let log = gallery.element("suite.gallery.log")
        let wait = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label BEGINSWITH %@ OR label CONTAINS %@", id, "\n\(id)"), object: log)
        XCTAssertEqual(XCTWaiter().wait(for: [wait], timeout: 5), .completed, "\(message); the log reads \(log.value ?? "nothing")")
    }
}

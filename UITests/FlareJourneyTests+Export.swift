// FlareJourneyTests+Export.swift: J22 of flare-export (FX-3;
// docs/blueprints/flare/features/flare-export.md, section 4), on
// `-FlareFixture showcase` (550 × 400, 24 fps, 48 frames, scene `scene-1`)
// with `-FlareExportTo` on this test's own temp folder, so Export writes with
// no panel. The toolbar's Export… opens SuiteUI's export sheet, Export writes
// scene-1.svg (an `<svg>` root 550 by 400), Done closes it; File > Export…
// opens it again, the Format menu picks Lottie and Export writes scene-1.json
// (`fr` 24, `w` 550, `h` 400, `op` 48). The sheet's suite.export.* ids carry
// these steps. The warnings, the flare.export.* ids, the From, To and Step
// rows and the 7-file PNG run wait on the sheet's options slot (#1989), so the
// test ends in a skip naming them. One shot per step, `flare-export-<step>`.
import XCTest

final class FlareExportJourneys: XCTestCase {
    @MainActor func testExportSVGLottieAndPNGSequence() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "flare-export-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let flare = Journey("Flare", self, arguments: ["-FlareFixture", "showcase", "-FlareExportTo", folder.path])
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")

        // 1. The toolbar's Export…: the sheet, Export enabled.
        let open = flare.app.toolbars.firstMatch.buttons["flare.export.showSheet"]
        XCTAssert(open.waitForExistence(timeout: 10) && Self.waitFor { open.isEnabled }, "Export… is missing or disabled")
        open.click()
        let start = expectSheet(flare)
        XCTAssert(start.isEnabled, "Export (suite.export.start) is disabled on showcase")
        flare.shot("export-1-sheet")

        // 2. Export: scene-1.svg, an <svg> root 550 by 400.
        start.click()
        let svg = folder.appending(path: "scene-1.svg")
        XCTAssert(Self.waitFor { FileManager.default.fileExists(atPath: svg.path) }, "Export wrote no scene-1.svg")
        let svgData = try Data(contentsOf: svg)
        XCTAssert(String(decoding: svgData.prefix(64), as: UTF8.self).hasPrefix("<svg"), "scene-1.svg doesn't start <svg")
        let root = SVGRoot()
        let parser = XMLParser(data: svgData)
        parser.delegate = root
        XCTAssert(parser.parse(), "XMLParser can't read scene-1.svg")
        XCTAssertEqual(root.attributes["width"], "550")
        XCTAssertEqual(root.attributes["height"], "400")
        flare.shot("export-2-svg")

        // 3. Done; File > Export…; the Format menu's Lottie.
        close(flare)
        flare.app.menuBars.firstMatch.menuBarItems["File"].click()
        let item = flare.app.menuBars.firstMatch.menuItems["Export…"]
        XCTAssert(item.waitForExistence(timeout: 5) && item.isEnabled, "File > Export… is missing or disabled")
        item.click()
        let again = expectSheet(flare)
        let format = flare.app.sheets.firstMatch.menuButtons.firstMatch
        XCTAssert(format.waitForExistence(timeout: 5), "the sheet has no Format menu")
        format.click()
        let lottie = flare.app.menuItems["Lottie"].firstMatch
        XCTAssert(lottie.waitForExistence(timeout: 5), "the Format menu offers no Lottie")
        lottie.click()
        flare.shot("export-3-lottie")

        // 4. Export: scene-1.json with fr 24, w 550, h 400, op 48.
        again.click()
        let json = folder.appending(path: "scene-1.json")
        XCTAssert(Self.waitFor { FileManager.default.fileExists(atPath: json.path) }, "Export wrote no scene-1.json")
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: json)) as? [String: Any]
        XCTAssertEqual((object?["fr"] as? NSNumber)?.doubleValue, 24)
        XCTAssertEqual((object?["w"] as? NSNumber)?.doubleValue, 550)
        XCTAssertEqual((object?["h"] as? NSNumber)?.doubleValue, 400)
        XCTAssertEqual((object?["op"] as? NSNumber)?.doubleValue, 48)
        flare.shot("export-4-lottie-written")
        close(flare)

        // Steps 1 and 3's warnings, the flare.export.* ids and Reveal, and steps 5 and 6 (the From, To and Step
        // rows, the 7-file PNG run) need Flare's rows in the sheet.
        throw XCTSkip("waits on #1989")
    }

    // MARK: - Helpers

    /// The sheet is up; returns its Export button.
    @MainActor private func expectSheet(_ flare: Journey) -> XCUIElement {
        XCTAssert(flare.app.sheets.firstMatch.waitForExistence(timeout: 10), "Export… showed no sheet")
        let start = flare.element("suite.export.start")
        XCTAssert(start.waitForExistence(timeout: 5), "the sheet has no Export (suite.export.start)")
        return start
    }

    /// Done once the run finished; the sheet goes.
    @MainActor private func close(_ flare: Journey) {
        let done = flare.element("suite.export.close")
        XCTAssert(Self.waitFor { done.exists && done.label == "Done" }, "the run never finished (no Done)")
        done.click()
        XCTAssert(flare.app.sheets.firstMatch.waitForNonExistence(timeout: 5), "Done left the sheet open")
    }

    private static func waitFor(_ condition: () -> Bool) -> Bool {
        for _ in 0..<100 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return condition()
    }
}

/// Keeps the first element's attributes: the SVG root's.
private final class SVGRoot: NSObject, XMLParserDelegate {
    var attributes: [String: String] = [:]
    private var seen = false

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String]) {
        guard !seen else { return }
        seen = true
        attributes = attributeDict
    }
}

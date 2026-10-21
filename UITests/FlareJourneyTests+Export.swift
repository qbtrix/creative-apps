// FlareJourneyTests+Export.swift: J22 of flare-export (FX-3, live in FX-9;
// docs/blueprints/flare/features/flare-export.md, section 4), on
// `-FlareSample showcase` (550 × 400, 24 fps, 48 frames, scene `scene-1`)
// with `-FlareExportTo` on this test's own temp folder, so Export writes with
// no panel. The toolbar's Export… opens SuiteUI's export sheet under Flare's
// flare.export.* ids with the scan's three warnings; Export writes scene-1.svg
// (an `<svg>` root 550 by 400) and offers Reveal in Finder; File > Export…
// and the Lottie chip add the background warning and write scene-1.json
// (`fr` 24, `w` 550, `h` 400, `op` 48); the PNG sequence with To 12 and Step 2
// reads "7 files" and writes frame_0000.png … frame_0012.png, each 550 wide
// in its IHDR (StageRasterizer's pixels, not the fakes' 1 × 1). One shot per
// step, `flare-export-<step>`.
import XCTest

final class FlareExportJourneys: XCTestCase {
    @MainActor func testExportSVGLottieAndPNGSequence() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "flare-export-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let flare = Journey("Flare", self, arguments: ["-FlareSample", "showcase", "-FlareExportTo", folder.path])
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")

        // 1. The toolbar's Export…: the sheet, Export enabled.
        let open = flare.app.toolbars.firstMatch.buttons["flare.export.showSheet"]
        XCTAssert(open.waitForExistence(timeout: 10) && Self.waitFor { open.isEnabled }, "Export… is missing or disabled")
        open.click()
        let start = expectSheet(flare)
        XCTAssert(start.isEnabled, "Export (flare.export.start) is disabled on showcase")
        let svgChip = flare.element("flare.export.format.svgFrame")
        XCTAssert(svgChip.waitForExistence(timeout: 5) && svgChip.isSelected, "SVG frame (flare.export.format.svgFrame) isn't chosen")
        for warning in Self.warnings { expectLine(warning, flare) }
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
        expectLine("Exported scene-1.svg.", flare)
        let reveal = flare.element("flare.export.reveal")
        XCTAssert(reveal.waitForExistence(timeout: 5) && reveal.isEnabled, "no enabled Reveal in Finder (flare.export.reveal)")
        flare.shot("export-2-svg")

        // 3. Done; File > Export…; the Lottie chip.
        close(flare)
        flare.app.menuBars.firstMatch.menuBarItems["File"].click()
        let item = flare.app.menuBars.firstMatch.menuItems["Export…"]
        XCTAssert(item.waitForExistence(timeout: 5) && item.isEnabled, "File > Export… is missing or disabled")
        item.click()
        let again = expectSheet(flare)
        let lottie = flare.element("flare.export.format.lottie")
        XCTAssert(lottie.waitForExistence(timeout: 5), "the sheet has no Lottie chip (flare.export.format.lottie)")
        lottie.click()
        for warning in Self.warnings + ["Background color isn't part of Lottie."] { expectLine(warning, flare) }
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
        expectLine("Exported scene-1.json.", flare)
        flare.shot("export-4-lottie-written")

        // 5. Done; Export…; PNG sequence; To 12; Step 2: From, To, Step and Transparent shown, "7 files".
        close(flare)
        open.click()
        let png = expectSheet(flare)
        let chip = flare.element("flare.export.format.pngSequence")
        XCTAssert(chip.waitForExistence(timeout: 5), "the sheet has no PNG sequence chip (flare.export.format.pngSequence)")
        chip.click()
        for id in ["flare.export.from", "flare.export.to", "flare.export.step", "flare.export.transparent"] {
            XCTAssert(flare.element(id).waitForExistence(timeout: 5), "the PNG sequence sheet has no \(id)")
        }
        type("12", into: "flare.export.to", flare)
        type("2", into: "flare.export.step", flare)
        let count = flare.element("flare.export.count")
        XCTAssert(
            Self.waitFor { count.exists && [count.label, count.value as? String].contains("7 files") },
            "the file count reads \(count.value ?? count.label), not 7 files"
        )
        flare.shot("export-5-png-rows")

        // 6. Export: "Exported 7 files."; frame_0000.png … frame_0012.png, each a PNG 550 wide.
        png.click()
        expectLine("Exported 7 files.", flare)
        let header: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
        for frame in stride(from: 0, through: 12, by: 2) {
            let file = folder.appending(path: String(format: "frame_%04d.png", frame))
            let bytes = (try? Data(contentsOf: file)).map { [UInt8]($0) } ?? []
            XCTAssertEqual(Array(bytes.prefix(4)), header, "\(file.lastPathComponent) is missing or not a PNG")
            XCTAssertEqual(Self.ihdrWidth(bytes), 550, "\(file.lastPathComponent)'s IHDR width isn't 550")
        }
        let written = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasSuffix(".png") }
        XCTAssertEqual(written.count, 7, "the run wrote \(written.sorted()), not 7 PNGs")
        flare.shot("export-6-png-written")
        close(flare)
    }

    /// The scan's warnings on showcase in every format.
    private static let warnings = [
        "Text isn't exported yet (1 layer).", "Symbol animation exports as its first frame (1 instance).",
        "Interactions aren't exported (1 machine).",
    ]

    // MARK: - Helpers

    /// The sheet is up; returns its Export button.
    @MainActor private func expectSheet(_ flare: Journey) -> XCUIElement {
        XCTAssert(flare.app.sheets.firstMatch.waitForExistence(timeout: 10), "Export… showed no sheet")
        let start = flare.element("flare.export.start")
        XCTAssert(start.waitForExistence(timeout: 5), "the sheet has no Export (flare.export.start)")
        return start
    }

    /// The sheet reads `text` (a warning or the run's line) within ten seconds.
    @MainActor private func expectLine(_ text: String, _ flare: Journey) {
        // A SwiftUI Text reaches XCUITest as its value, not its label (as the other journeys match).
        let reads = NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text)
        let line = flare.app.sheets.firstMatch.staticTexts.matching(reads).firstMatch
        XCTAssert(line.waitForExistence(timeout: 10), "the sheet never read \"\(text)\"")
    }

    /// Clicks the bar `id` to type, selects its text and enters `text`.
    @MainActor private func type(_ text: String, into id: String, _ flare: Journey) {
        let bar = flare.element(id)
        XCTAssert(bar.waitForExistence(timeout: 5), "no \(id)")
        bar.click()
        flare.press(character: "a", .command)
        flare.app.typeText(text)
        flare.press(.return)
    }

    /// Done once the run finished; the sheet goes.
    @MainActor private func close(_ flare: Journey) {
        let done = flare.element("flare.export.dismiss")
        XCTAssert(Self.waitFor { done.exists }, "the run never finished (no Done)")
        done.click()
        XCTAssert(flare.app.sheets.firstMatch.waitForNonExistence(timeout: 5), "Done left the sheet open")
    }

    /// The width in a PNG's IHDR: bytes 16 to 19, big-endian, after the signature, the chunk length and "IHDR".
    private static func ihdrWidth(_ bytes: [UInt8]) -> Int? {
        guard bytes.count >= 24, bytes[12..<16].elementsEqual(Array("IHDR".utf8)) else { return nil }
        return bytes[16..<20].reduce(0) { $0 << 8 | Int($1) }
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

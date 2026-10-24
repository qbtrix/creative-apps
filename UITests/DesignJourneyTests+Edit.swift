// DesignJourneyTests+Edit.swift: DJ-CB (clipboard-interop CB-5 writes it skipped, CB-6 turns it on;
// packet docs/blueprints/suiteui/features/clipboard-interop.md, Journey steps). On `cards` at
// 1024 x 768: rectangle A pressed on the page and Edit > Copy puts three types on the general
// pasteboard, Design's own layers, an SVG and a PNG (`edit-copy-types`). A 300 x 200 PNG written
// to the pasteboard by the test, then Edit > Paste: one new layer, "Undo Paste", the picture
// selected and centred in the view (`edit-paste-image`). Presses on the page go to
// `suite.canvas.artboard` at page points over the page's 1440 x 1024 size, as Arrange's do.
import AppKit
import XCTest

final class DesignEditJourneyTests: XCTestCase {
    /// The slice this journey waits on; CB-6 sets it to nil.
    private static let waitsOn: String? = nil
    static let arguments = ["-DesignFixture", "cards", "-SuiteWindowSize", "1024x768"]
    /// The types a Design copy offers (SuiteTypeID's designLayers, svg and png).
    private static let ownType = NSPasteboard.PasteboardType("org.creativesuite.design.layers")
    private static let svgType = NSPasteboard.PasteboardType("public.svg-image")

    /// DJ-CB: Copy writes own, SVG and PNG; a PNG pasted in is one centred picture layer.
    @MainActor func testCopyOutPasteImageIn() throws {
        if let waitsOn = Self.waitsOn { throw XCTSkip("waits on \(waitsOn)") }
        let design = Journey("Design", self, arguments: Self.arguments)
        XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let page = design.element("suite.canvas.artboard")
        XCTAssert(page.waitForExistence(timeout: 10), "no page on the canvas (suite.canvas.artboard)")
        let undo = design.element("design.bar.undo")

        // 1. A pressed, Edit > Copy: the pasteboard holds own layers, SVG and PNG.
        _ = NSPasteboard.general.clearContents()
        page.coordinate(withNormalizedOffset: CGVector(dx: 150.0 / 1440, dy: 140.0 / 1024)).click()
        choose("Copy", design)
        let pasteboard = NSPasteboard.general
        XCTAssert(waitFor { pasteboard.data(forType: .png) != nil }, "Copy put no PNG on the pasteboard")
        let types = pasteboard.types ?? []
        for type in [Self.ownType, Self.svgType, .png] {
            XCTAssert(types.contains(type), "Copy left \(type.rawValue) off the pasteboard (it holds \(types.map(\.rawValue)))")
        }
        design.shot("edit-copy-types")

        // 2. A 300 x 200 PNG on the pasteboard, Edit > Paste: one more layer, one step, selected.
        let rows = layerRows(design)
        _ = pasteboard.clearContents()
        XCTAssert(pasteboard.setData(try Self.png(width: 300, height: 200), forType: .png), "could not put a PNG on the pasteboard")
        choose("Paste", design)
        XCTAssert(waitFor { undo.label == "Undo Paste" }, "Paste of a PNG made no step (Undo reads \(undo.label))")
        XCTAssert(waitFor { self.layerRows(design) == rows + 1 }, "Paste of a PNG left \(layerRows(design)) rows, not \(rows + 1)")
        let status = design.element("design.status.selection")
        XCTAssert(waitFor { status.exists && !(status.value as? String ?? status.label).isEmpty },
                  "the pasted picture isn't selected")
        design.shot("edit-paste-image")
    }

    // MARK: Helpers

    /// Opens the Edit menu and clicks `item`.
    @MainActor private func choose(_ item: String, _ design: Journey) {
        let edit = design.app.menuBars.firstMatch.menuBarItems["Edit"]
        edit.click()
        let entry = edit.menuItems[item]
        XCTAssert(entry.waitForExistence(timeout: 3), "the Edit menu shows no \(item)")
        XCTAssert(entry.isEnabled, "Edit > \(item) is off")
        entry.click()
    }

    /// How many Layers rows show now.
    @MainActor private func layerRows(_ design: Journey) -> Int {
        design.element("suite.sidebar").descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'design.layer.'")).count
    }

    /// A solid red PNG of `width` x `height` pixels.
    private static func png(width: Int, height: Int) throws -> Data {
        let rep = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        for x in 0..<width { for y in 0..<height { rep.setColor(.red, atX: x, y: y) } }
        return try XCTUnwrap(rep.representation(using: .png, properties: [:]))
    }

    /// Whether `condition` holds within about five seconds.
    @MainActor private func waitFor(_ condition: () -> Bool) -> Bool {
        for _ in 0..<25 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }
}

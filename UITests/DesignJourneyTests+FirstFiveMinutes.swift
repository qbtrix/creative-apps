// DesignJourneyTests+FirstFiveMinutes.swift: Design's "first five minutes"
// beta gate (Journey+FirstFive.swift has the rules). Three first-week tasks,
// one test each, as a new user does them with no help: start a new design
// with a frame, add a shape and a line of text, export it as a PNG. Each
// starts from the top bar's New File on a fresh profile. Export passes
// `-DesignExportTo <folder>` as Photo's and Flare's journeys do, so a built
// export writes there with no panel. A test that fails on a missing or
// hidden entry point names its `finding` issue. Shots are
// `design-first5-<step>`.
import XCTest

final class DesignFirstFiveJourneys: XCTestCase {
    /// New File in the top bar, then the Frame tool: a frame on the canvas.
    @MainActor func testFirst5NewDesignWithFrame() {
        let design = newDesign([])
        draw("Frame", from: CGVector(dx: 0.1, dy: 0.1), to: CGVector(dx: 0.6, dy: 0.7), design)
        design.snap("first5-frame")
    }

    /// The Rectangle tool and the Text tool: a shape and a typed title.
    @MainActor func testFirst5AddShapeAndText() {
        let design = newDesign([])
        draw("Rectangle", from: CGVector(dx: 0.2, dy: 0.2), to: CGVector(dx: 0.5, dy: 0.5), design)
        design.reachable("Text", in: design.element("suite.tools")).click()
        design.drag(on: "suite.canvas", from: CGVector(dx: 0.3, dy: 0.75), to: CGVector(dx: 0.3, dy: 0.75))
        design.app.typeText("Summer sale\r")
        XCTAssert(design.app.buttons["Undo Add Text"].waitForExistence(timeout: 5), "typing a title made no text")
        design.snap("first5-shape-and-text")
    }

    /// File > Export…, PNG, Export: a PNG of the frame in the export folder.
    @MainActor func testFirst5ExportPNG() throws {
        let exports = FirstFive.folder("design-first5-exports")
        let design = newDesign(["-DesignExportTo", exports.path])
        draw("Frame", from: CGVector(dx: 0.1, dy: 0.1), to: CGVector(dx: 0.6, dy: 0.7), design)
        design.choose(menu: ["File", "Export…"], stuck: Self.stuckExport)
        let png = design.element("design.export.format.png")
        XCTAssert(png.waitForExistence(timeout: 5), "the Export sheet offers no PNG \(Self.stuckExport)")
        png.click()
        design.snap("first5-export-sheet")
        design.reachable("Export", in: design.app.sheets.firstMatch, stuck: Self.stuckExport).click()
        let file = FirstFive.file(in: exports, ext: "png", timeout: 30)
        let written = try XCTUnwrap(file, "Export wrote no PNG \(Self.stuckExport)")
        XCTAssertEqual(Array(try Data(contentsOf: written).prefix(4)), [0x89, 0x50, 0x4E, 0x47], "the export isn't a PNG")
        let size = FirstFive.pixelSize(of: written)
        XCTAssert((size?.width ?? 0) > 0 && (size?.height ?? 0) > 0, "the PNG reads \(String(describing: size))")
    }

    /// Where a new user gets stuck, by finding issue.
    private static let stuckExport = "(first five minutes: finding #3528)"

    /// Design on a fresh profile, after the top bar's New File.
    @MainActor private func newDesign(_ arguments: [String]) -> Journey {
        let design = Journey("Design", self, arguments: arguments + FirstFive.freshProfile())
        design.timeBox()
        XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        design.reachable("New File").click()
        XCTAssert(design.element("suite.canvas").waitForExistence(timeout: 10), "New File showed no canvas")
        return design
    }

    /// Picks `tool` from the palette and drags it across the canvas: one Add step.
    @MainActor private func draw(_ tool: String, from start: CGVector, to end: CGVector, _ design: Journey) {
        design.reachable(tool, in: design.element("suite.tools")).click()
        design.drag(on: "suite.canvas", from: start, to: end)
        XCTAssert(design.app.buttons["Undo Add \(tool)"].waitForExistence(timeout: 5), "drawing with \(tool) added nothing")
    }
}

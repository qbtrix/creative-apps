// DesignJourneyTests+Stroke.swift: the Journey steps of docs/blueprints/design/features/stroke-style.md (numbered
// below) on `cards` at 1024 × 768. Click A's row in Layers, then Add Stroke: a 1 pt black stroke, and SuiteUI's
// stroke editor (DK-2, no trim rows in Design) shows Width, Join, Cap and Dash; scrub Width to 2, pick the Round cap
// and Dashed, one step per gesture; Undo three times back to a plain 1 pt stroke; and an `old-strokes.design` saved
// before the feature keeps its colours and widths. The editor's rows are SS-3's `suite.stroke.*` ids. DK-2 wrote it;
// DK-8 turns it on, on live services: step 4 writes the old file (a stroke of only colour and width, the shape files
// had before DK-5) into its own temp folder and relaunches with `-DesignOpenFile <path>`.
import XCTest

final class DesignStrokeJourneyTests: XCTestCase {
    static let arguments = ["-DesignServices", "live", "-DesignFixture", "cards", "-SuiteWindowSize", "1024x768"]
    /// Desktop's row (collapsed when the file opens) and A's inside it (DesignFixtures.cards).
    static let desktopRow = "design.layer.node-1", rowA = "design.layer.node-2"
    /// The editor's own Add Stroke, the section's only one (#3864).
    static let addStroke = "suite.stroke.add"

    /// The packet's dashed border: add, width, cap, dash, three undos, then an old file's strokes.
    @MainActor func testDashedBorder() throws {
        let design = Journey("Design", self, arguments: Self.arguments)
        XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(design.element("suite.canvas").waitForExistence(timeout: 10), "the cards fixture showed no page")

        design.expandDesignLayer(Self.desktopRow) // 1. A, then Add Stroke: Width, Join, Cap and Dash, no trim.
        design.clickDesignLayer(Self.rowA)
        let add = design.element(Self.addStroke)
        XCTAssert(add.waitForExistence(timeout: 5), "no Add Stroke (\(Self.addStroke))")
        add.click()
        for row in ["width", "join.round", "cap.round", "dash.dashed"] where !design.element("suite.stroke.\(row)").exists {
            XCTFail("the stroke editor shows no suite.stroke.\(row)")
        }
        XCTAssertFalse(design.element("suite.stroke.trim-start").exists, "Design's stroke editor shows trim rows")
        for twin in ["design.inspector.stroke-width", "design.inspector.stroke-remove"] {
            XCTAssertFalse(design.element(twin).exists, "\(twin) beside the editor's own row (#3864)")
        }
        design.shot("stroke-added")

        let width = design.element("suite.stroke.width") // 2. Width 2, Round cap, Dashed: one step each.
        let start = width.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 10, dy: 0)))
        design.element("suite.stroke.cap.round").click()
        design.element("suite.stroke.dash.dashed").click()
        design.shot("stroke-dashed")

        let undo = design.element("design.bar.undo") // 3. Three undos: a plain 1 pt stroke again.
        for _ in 0..<3 { undo.click() }
        XCTAssert(design.element("suite.stroke.dash.solid").exists, "three undos left a dash")
        design.shot("stroke-undone")

        try openOldStrokes() // 4. An old file's 3 pt red stroke opens as a stroke, still 3 pt.
    }

    /// `old-strokes.design`: one rectangle whose stroke is the old shape, colour and width only (DesignStrokeMigrationTests).
    private static let oldStrokes = #"{"pages":[{"frameHeight":400,"frameWidth":400,"id":"page-1","name":"Page 1","nodes":["#
        + #"{"children":[],"cornerRadius":0,"fill":{"blue":217,"green":217,"red":217},"frame":{"height":80,"width":100,"x":100,"y":100},"#
        + #""id":"node-2","isHidden":false,"isLocked":false,"kind":"rectangle","name":"A","opacity":1,"#
        + #""stroke":{"color":{"blue":0,"green":0,"red":255},"width":3},"text":"","#
        + #""textStyle":{"alignment":"leading","family":"System","size":16,"weight":400}}]}],"version":1}"#

    @MainActor private func openOldStrokes() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "design-old-strokes-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: "old-strokes.design")
        try Data(Self.oldStrokes.utf8).write(to: file)
        let old = Journey("Design", self, arguments: ["-DesignServices", "live", "-DesignOpenFile", file.path,
                                                      "-SuiteWindowSize", "1024x768"])
        XCTAssert(old.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened for old-strokes.design")
        XCTAssert(old.element("suite.canvas").waitForExistence(timeout: 10), "old-strokes.design showed no page")
        old.clickDesignLayer(Self.rowA)
        let width = old.element("suite.stroke.width")
        XCTAssert(width.waitForExistence(timeout: 5), "the old file's stroke opened as no stroke (no suite.stroke.width)")
        XCTAssertFalse(old.element(Self.addStroke).exists, "the old file's layer offers Add Stroke: its stroke was lost")
        let three = width.descendants(matching: .any).matching(NSPredicate(format: "value BEGINSWITH '3'")).firstMatch
        XCTAssert((width.value as? String ?? "").hasPrefix("3") || three.exists, "the old 3 pt stroke lost its width")
        old.shot("stroke-old-file")
    }
}

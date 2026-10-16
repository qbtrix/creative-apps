// DesignJourneyTests+Shell.swift: Design in the suite window at 1024 × 768
// (packet docs/blueprints/design/features/shell-parity.md, Journey steps
// DS-J1..DS-J5). The light journey checks the empty window (title, sidebar,
// toolbar, empty canvas, "No Selection"), opens a file and finds the floating
// palette, draws a rectangle on the page's left edge, fits the page and checks
// the shell geometry with the palette clear of the rulers and of the page grown
// by half a handle's hit, then selects the rectangle from Layers and undoes it.
// The dark journey shoots the open and selected states and checks the geometry
// again. Written before its code (lead.md, contract rule 13); DS-3 put Design on
// SuiteWindow and turned it on. The palette shows only while a file is open, so
// the empty window is checked region by region rather than by expectEditorWindow().
import XCTest

final class DesignShellJourneyTests: XCTestCase {
    static let size = ["-SuiteWindowSize", "1024x768"]
    static let bar = ["design.bar.new", "design.bar.open", "design.bar.save", "design.bar.undo",
                      "design.bar.redo", "design.bar.zoom-out", "design.bar.fit", "design.bar.zoom-in"]

    /// DS-J1..DS-J4 in light.
    @MainActor func testShellLight() throws {
        let design = Journey("Design", self, arguments: Self.size)
        // DS-J1: the empty window, every editor region up but the palette, which waits for a file.
        let window = design.app.windows.firstMatch
        XCTAssert(window.waitForExistence(timeout: 30), "no window opened")
        for identifier in Journey.editorRegions where identifier != "suite.tools" {
            let region = design.element(identifier)
            XCTAssert(region.waitForExistence(timeout: 5), "no \(identifier)")
            XCTAssert(region.isHittable, "\(identifier) isn't hittable")
        }
        XCTAssert(design.app.toolbars.firstMatch.exists, "no window toolbar")
        XCTAssertEqual(window.title, "Design", "the empty window's title")
        let sidebar = design.element("suite.sidebar")
        for header in ["Pages", "Layers"] {
            XCTAssert(sidebar.staticTexts[header].waitForExistence(timeout: 5), "the sidebar shows no \(header)")
        }
        XCTAssert(design.element("suite.switcher").exists, "no app switcher (suite.switcher)")
        for identifier in Self.bar {
            let item = design.element(identifier)
            XCTAssert(item.waitForExistence(timeout: 5), "no toolbar item \(identifier)")
            let open = identifier == "design.bar.new" || identifier == "design.bar.open"
            // The reasons are DesignToolbarItemsTests' (DS-1); the runner shows no help tag.
            XCTAssertEqual(item.isEnabled, open, "\(identifier) is \(item.isEnabled ? "enabled" : "disabled") with no file")
        }
        XCTAssert(design.element("design.new-file").exists, "no empty state with New File (design.new-file)")
        XCTAssertFalse(design.element("suite.tools").buttons["Rectangle"].exists, "the palette shows with no file")
        XCTAssert(design.element("suite.inspector").staticTexts["No Selection"].exists, "the inspector doesn't read No Selection")
        design.shot("shell-empty")

        // DS-J2: New File.
        openFile(design, shot: "shell-open")
        XCTAssertEqual(window.title, "Untitled", "the open file's title")
        let status = design.element("suite.status")
        let zoom = status.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Zoom '")).firstMatch
        XCTAssert(zoom.exists, "the status line shows no zoom")
        let size = status.staticTexts.matching(NSPredicate(format: "label CONTAINS ' × '")).firstMatch
        XCTAssert(size.exists, "the status line shows no page size")
        XCTAssertEqual(design.element("design.status.tool").label, "Move", "the status line's tool")

        // DS-J3: a selected rectangle on the page's left edge, at Fit Page.
        drawOnEdge(design, shot: "shell-handles")
        expectGeometry(design)

        // DS-J4: pick it in Layers, then undo it from the toolbar.
        let rows = sidebar.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'design.layer.'"))
        XCTAssert(rows.firstMatch.waitForExistence(timeout: 5), "no Layers row for the rectangle")
        rows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).click()
        let inspector = design.element("suite.inspector")
        XCTAssert(inspector.descendants(matching: .any)["design.properties"].waitForExistence(timeout: 5), "no Properties in the inspector")
        XCTAssert(inspector.descendants(matching: .any)["design.fill"].exists, "the inspector shows no rectangle's Fill")
        let undo = design.element("design.bar.undo")
        XCTAssertEqual(undo.label, "Undo Add Rectangle", "the toolbar's Undo")
        undo.click()
        XCTAssertFalse(rows.firstMatch.waitForExistence(timeout: 2), "Undo left the rectangle in Layers")
        design.shot("shell-undone")
    }

    /// DS-J5: the same window in dark.
    @MainActor func testShellDark() throws {
        let design = Journey("Design", self, arguments: Self.size + ["-AppleInterfaceStyle", "Dark"])
        XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        openFile(design, shot: "shell-open-dark")
        drawOnEdge(design, shot: "shell-handles-dark")
        expectGeometry(design)
    }

    /// ⌘N: the page, and the palette's six tools in order at the canvas's leading edge.
    @MainActor private func openFile(_ design: Journey, shot: String) {
        design.app.typeKey("n", modifierFlags: .command)
        XCTAssert(design.element("suite.canvas").waitForExistence(timeout: 10), "New File showed no page")
        let tools = design.element("suite.tools").buttons
        XCTAssert(tools.firstMatch.waitForExistence(timeout: 5), "no floating palette (suite.tools)")
        let titles = (0..<tools.count).map { tools.element(boundBy: $0).label }
        XCTAssertEqual(titles, ["Move", "Frame", "Rectangle", "Ellipse", "Text", "Pen"], "the palette's tools")
        let palette = design.element("suite.tools").frame, viewport = design.element("suite.viewport").frame
        XCTAssertLessThan(palette.minX - viewport.minX, viewport.width / 4, "the palette isn't at the canvas's leading edge")
        design.shot(shot)
    }

    /// Rectangle, dragged from the page's left edge, 2% to 25% down and 25% across, then View > Fit Page.
    @MainActor private func drawOnEdge(_ design: Journey, shot: String) {
        design.element("suite.tools").buttons["Rectangle"].click()
        design.drag(on: "suite.canvas", from: CGVector(dx: 0, dy: 0.02), to: CGVector(dx: 0.25, dy: 0.25))
        XCTAssert(design.app.buttons["Undo Add Rectangle"].waitForExistence(timeout: 5), "drawing made no undo step")
        design.app.menuBars.firstMatch.menuBarItems["View"].click()
        design.app.menuItems["Fit Page"].click()
        design.shot(shot)
    }

    /// The shell's rules, the eight toolbar items in the window beside a centred
    /// switcher, and the palette clear of both rulers and the page grown by its handles.
    @MainActor private func expectGeometry(_ design: Journey) {
        var items: [String: XCUIElement] = ["suite.switcher": design.element("suite.switcher")]
        for identifier in Self.bar {
            items[identifier] = design.element(identifier)
            XCTAssert(design.element(identifier).isHittable, "\(identifier) isn't hittable (in the overflow?)")
        }
        let window = design.app.windows.firstMatch.frame, switcher = design.element("suite.switcher").frame
        XCTAssertEqual(switcher.midX, window.midX, accuracy: 2, "the switcher isn't centred in the toolbar")
        design.expectShellGeometry(
            minimums: [
                "suite.viewport": (width: 440, height: 360), "suite.inspector": (width: 304, height: 1),
                "suite.tools": (width: 32, height: 32),
            ],
            regions: items)

        let ruler = 20.0, hit = 12.0
        let viewport = rect(design.element("suite.viewport").frame), page = rect(design.element("suite.canvas").frame)
        let regions = [
            "palette": rect(design.element("suite.tools").frame),
            "top ruler": AppAudit.Rect(x: viewport.x, y: viewport.y, width: viewport.width, height: ruler),
            "leading ruler": AppAudit.Rect(x: viewport.x, y: viewport.y, width: ruler, height: viewport.height),
            "page grown by its handles": AppAudit.Rect(
                x: page.x - hit / 2, y: page.y - hit / 2, width: page.width + hit, height: page.height + hit),
        ]
        let found = ShellGeometry.violations(
            window: rect(window), regions: regions, minimums: [:], apart: [],
            clear: [("palette", "top ruler"), ("palette", "leading ruler"), ("palette", "page grown by its handles")])
        XCTAssert(found.isEmpty, "the palette covers a ruler or a handle:\n" + found.joined(separator: "\n"))
    }

    private func rect(_ frame: CGRect) -> AppAudit.Rect {
        AppAudit.Rect(x: Double(frame.minX), y: Double(frame.minY), width: Double(frame.width), height: Double(frame.height))
    }
}

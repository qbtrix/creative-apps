// SuiteJourneyTests+EditorWindow.swift: steps 1 to 6 of docs/blueprints/suiteui/features/editor-in-window.md
// (EW-5) on the gallery's `editor-window` page in Library. Shots under `suiteui`: Light "launch", the tools, the
// geometry, "inspector-hidden", "switcher"; Dark "launch-dark", the geometry, "switcher-dark". Numbers are SuiteUI tokens
// (this bundle doesn't link SuiteUI). `.principal` sits after the title, not centred: step 6 bounds the switcher by Open
// and the trailing actions (#1561: Design too).
import XCTest

final class SuiteEditorWindowJourneys: XCTestCase {
    static let launch = ["-SuiteGallery", "editor-window", "-SuiteWindowSize", "1024x768", "-SuitePerfProbe"]
    static let inspectorWidth = 304.0  // SuiteSize.editorPanelWidth (280) + 2 × SuiteSpacing.m (12)
    static let contentMinimum = (width: 440.0, height: 360.0)  // SuiteSize.contentMinimum
    static let toolButton = 32.0  // SuiteSize.toolButton
    static let ruler = 20.0  // SuiteSize.ruler
    static let anchorHit = 12.0  // SuiteSize.anchorHit
    static let documentActions = ["new", "open"]
    static let actions = ["save", "undo", "redo", "zoom-out", "fit", "zoom-in"]
    static let tools = ["select", "rectangle", "ellipse", "pen", "text"]
    /// The switcher's items in order; each one's title is its id capitalized.
    static let switcher = ["home", "flare", "design", "photo", "library", "halo"]
    /// How the system joins a window's title and subtitle in the title it reports.
    static let subtitleSeparator = " \u{2013} "
    static let notConnected = "Not connected yet (switching)."  // AppSwitcherState.notConnected

    /// Steps 1 to 4 and 6, in Light.
    @MainActor func testEditorWindow() {
        let gallery = Journey("Library", self, name: "suiteui", arguments: Self.launch)
        XCTAssert(gallery.element("suite.gallery.editor-window").waitForExistence(timeout: 30), "no editor-window page")

        // Step 1: every slot of the editor window, then the "launch" shot.
        expectSlots(gallery)
        gallery.expectEditorWindow()

        // Step 2: every enabled tool, clicked and shot.
        gallery.clickEachTool()

        // Step 3: the geometry at the display size.
        expectGeometry(gallery)

        // Step 4: Option-Command-I hides the inspector; the detail grows and the palette stays put.
        let viewport = gallery.element("suite.viewport")
        let palette = gallery.element("suite.tools")
        let before = (viewport: viewport.frame, palette: palette.frame)
        gallery.app.typeKey("i", modifierFlags: [.command, .option])
        let inspector = gallery.element("suite.inspector")
        XCTAssert(inspector.waitForNonExistence(timeout: 5), "Option-Command-I left the inspector up")
        let grown = waitFor { viewport.frame.width > before.viewport.width + Self.inspectorWidth / 2 }
        XCTAssert(grown, "the detail didn't grow")
        XCTAssertEqual(palette.frame.minX, before.palette.minX, accuracy: 1, "the palette moved when the inspector hid")
        gallery.shot("inspector-hidden")
        gallery.app.typeKey("i", modifierFlags: [.command, .option])
        XCTAssert(inspector.waitForExistence(timeout: 5), "Option-Command-I didn't bring the inspector back")

        // Step 6: the app switcher between the actions, Library current, every item disabled with its reason.
        expectSwitcher(gallery)
        gallery.shot("switcher", element: gallery.element("suite.switcher"))
    }

    /// Step 5 and the dark switcher crop.
    @MainActor func testEditorWindowDark() {
        // The appearance pair goes first. After the value-less -SuitePerfProbe, "-AppleInterfaceStyle" was
        // read as the probe's value and the stray "Dark" opened as a file, so Library started with no
        // window at all (run 38981651490).
        let dark = ["-AppleInterfaceStyle", "Dark"] + Self.launch
        let gallery = Journey("Library", self, name: "suiteui", arguments: dark)
        XCTAssert(gallery.element("suite.viewport").waitForExistence(timeout: 30), "no viewport (suite.viewport)")
        XCTAssert(gallery.element("suite.tools").waitForExistence(timeout: 10), "no tool palette (suite.tools)")
        gallery.shot("launch-dark")
        expectGeometry(gallery)
        gallery.shot("switcher-dark", element: gallery.element("suite.switcher"))
    }

    /// Step 1: title, subtitle, the sidebar's own list, the toolbar, artboard, palette, 304 pt inspector.
    @MainActor private func expectSlots(_ gallery: Journey) {
        // macOS reports the title with the subtitle joined on ("Poster – Edited"), so read both parts.
        let window = gallery.app.windows.firstMatch
        let parts = { window.title.components(separatedBy: Self.subtitleSeparator) }
        XCTAssert(waitFor { parts() == ["Poster", "Edited"] }, "the window title is \(window.title), not Poster – Edited")
        XCTAssert(reads("Edited", in: window), "no subtitle Edited")

        let sidebar = gallery.element("suite.sidebar")
        XCTAssert(sidebar.waitForExistence(timeout: 5), "no sidebar (suite.sidebar)")
        let list = sidebar.descendants(matching: .any)["suite.gallery.editor-window.list"].firstMatch
        XCTAssert(list.exists, "the page's own list isn't inside suite.sidebar")
        for section in ["Pages", "Layers"] { XCTAssert(reads(section, in: sidebar), "no \(section) section") }
        let add = sidebar.descendants(matching: .any)["suite.gallery.page.add"].firstMatch
        let delete = sidebar.descendants(matching: .any)["suite.gallery.page.delete"].firstMatch
        XCTAssert(add.exists && add.isEnabled, "no enabled Add Page in the sidebar")
        XCTAssert(delete.exists && !delete.isEnabled, "Delete Page isn't there disabled with one page")

        let toolbar = gallery.app.toolbars.firstMatch
        for id in Self.documentActions + Self.actions {
            let button = gallery.element("suite.gallery.bar.\(id)")
            XCTAssert(button.waitForExistence(timeout: 5), "no toolbar action suite.gallery.bar.\(id)")
        }
        let toggle = toolbar.descendants(matching: .any)["suite.inspectorToggle"].firstMatch
        XCTAssert(toggle.isHittable, "no hittable inspector toggle")
        XCTAssertFalse(gallery.element("suite.gallery.bar.undo").isEnabled, "Undo is enabled with nothing to undo")
        let controls = gallery.controls()?.controls ?? []
        let undo = controls.first { $0.id == "suite.gallery.bar.undo" }
        XCTAssertEqual(undo?.reason, "Nothing to undo.", "Undo's tooltip")
        XCTAssertEqual(
            controls.first { $0.id == "suite.gallery.page.delete" }?.reason, "A document keeps at least one page.",
            "Delete Page's tooltip")

        let artboard = gallery.element("suite.canvas")
        XCTAssert(artboard.waitForExistence(timeout: 5), "no artboard (suite.canvas)")
        let ratio = Double(artboard.frame.width / max(artboard.frame.height, 1))
        XCTAssertEqual(ratio, 1.6, accuracy: 0.02, "not a 1600 × 1000 artboard")
        let viewport = gallery.element("suite.viewport").frame, palette = gallery.element("suite.tools").frame
        XCTAssert(palette.maxX < viewport.midX, "the palette isn't at the leading edge")
        let inspector = Double(gallery.element("suite.inspector").frame.width)
        XCTAssertEqual(inspector, Self.inspectorWidth, accuracy: 1, "the inspector isn't 304 pt")
    }

    /// Steps 3 and 5: every region, toolbar action (none in the overflow) and the switcher
    /// inside the window at its minimum; the palette clear of both rulers and the artboard's handles.
    @MainActor private func expectGeometry(_ gallery: Journey) {
        var minimums: [String: (width: Double, height: Double)] = [
            "suite.viewport": Self.contentMinimum, "suite.inspector": (Self.inspectorWidth - 1, 1),
            "suite.switcher": (1, 1),
        ]
        var regions: [String: XCUIElement] = ["suite.switcher": gallery.element("suite.switcher")]
        for tool in Self.tools {
            regions["tool.\(tool)"] = gallery.element("suite.gallery.tool.\(tool)")
            minimums["tool.\(tool)"] = (Self.toolButton, Self.toolButton)
        }
        for id in Self.documentActions + Self.actions {
            let button = gallery.element("suite.gallery.bar.\(id)")
            regions["bar.\(id)"] = button
            minimums["bar.\(id)"] = (1, 1)
            XCTAssert(button.isHittable, "suite.gallery.bar.\(id) isn't hittable (in the overflow?)")
        }
        gallery.expectShellGeometry(minimums: minimums, regions: regions)

        let window = rect(gallery.app.windows.firstMatch.frame)
        let viewport = rect(gallery.element("suite.viewport").frame)
        let artboard = rect(gallery.element("suite.canvas").frame)
        let grow = Self.anchorHit / 2
        let bands = [
            "palette": rect(gallery.element("suite.tools").frame),
            "top ruler": AppAudit.Rect(x: viewport.x, y: viewport.y, width: viewport.width, height: Self.ruler),
            "leading ruler": AppAudit.Rect(x: viewport.x, y: viewport.y, width: Self.ruler, height: viewport.height),
            "artboard grown by its handles": AppAudit.Rect(
                x: artboard.x - grow, y: artboard.y - grow, width: artboard.width + 2 * grow, height: artboard.height + 2 * grow),
        ]
        let found = ShellGeometry.violations(
            window: window, regions: bands, minimums: [:], apart: [],
            clear: [("palette", "top ruler"), ("palette", "leading ruler"), ("palette", "artboard grown by its handles")])
        XCTAssert(found.isEmpty, "the palette covers a ruler or a handle:\n" + found.joined(separator: "\n"))
    }

    private func rect(_ frame: CGRect) -> AppAudit.Rect {
        AppAudit.Rect(x: Double(frame.minX), y: Double(frame.minY), width: Double(frame.width), height: Double(frame.height))
    }

    /// Step 6: six items in order between Open and the trailing actions, Library selected, each disabled saying why.
    @MainActor private func expectSwitcher(_ gallery: Journey) {
        let row = gallery.element("suite.switcher")
        XCTAssert(row.waitForExistence(timeout: 10), "no app switcher (suite.switcher)")
        let window = gallery.app.windows.firstMatch.frame, frame = row.frame
        let open = gallery.element("suite.gallery.bar.open").frame.maxX
        let trailing = (Self.actions.map { "suite.gallery.bar.\($0)" } + ["suite.inspectorToggle"]).map { gallery.element($0).frame.minX }.min() ?? window.maxX
        XCTAssert(frame.minX >= open, "the switcher starts at \(frame.minX), before Open ends (\(open))")
        XCTAssert(frame.maxX <= trailing, "the switcher ends at \(frame.maxX), past the first trailing action (\(trailing))")
        XCTAssert(window.contains(frame), "the switcher \(frame) isn't inside the window \(window)")
        let controls = gallery.controls()?.controls ?? []
        var lastX = -Double.infinity
        for id in Self.switcher {
            let item = gallery.element("suite.switcher.\(id)")
            XCTAssert(item.exists, "no switcher item suite.switcher.\(id)")
            XCTAssert(item.isHittable, "suite.switcher.\(id) isn't hittable")
            XCTAssertEqual(item.label, id.capitalized, "suite.switcher.\(id)'s label")
            XCTAssertFalse(item.isEnabled, "suite.switcher.\(id) is enabled with nothing to switch to")
            XCTAssertEqual(item.isSelected, id == "library", "suite.switcher.\(id)'s selected trait")
            XCTAssertEqual(
                controls.first { $0.id == "suite.switcher.\(id)" }?.reason, Self.notConnected,
                "suite.switcher.\(id)'s reason")
            XCTAssert(Double(item.frame.midX) > lastX, "suite.switcher.\(id) is out of order")
            lastX = Double(item.frame.midX)
        }
    }

    /// Whether some text in `element` reads `text`, within three seconds.
    @MainActor private func reads(_ text: String, in element: XCUIElement) -> Bool {
        let match = element.descendants(matching: .any)
            .matching(NSPredicate(format: "label ==[c] %@ OR value ==[c] %@", text, text)).firstMatch
        return waitFor { match.exists }
    }

    /// Whether `condition` holds within three seconds.
    @MainActor private func waitFor(_ condition: () -> Bool) -> Bool {
        for _ in 0..<15 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }
}

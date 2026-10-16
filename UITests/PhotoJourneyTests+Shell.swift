// PhotoJourneyTests+Shell.swift: Photo in the suite window at 1024 × 768
// (packet docs/blueprints/photo/features/shell-parity.md, Journey steps
// PS-J1..PS-J6), one test per step, each launched with -SuiteWindowSize. J1
// checks the empty window (title, layer list, toolbar items enabled or not,
// the canvas's Open… empty state, the inspector's no-image state, the app
// switcher centred with Photo current). J2 opens the 800 × 600 test photo with
// -PhotoOpenFile and checks the title, subtitle, one layer row, the palette at
// the canvas's leading edge and the inspector's header and sections. J3 drags
// a marquee from the image's left edge, fits it and checks the shell geometry
// with the palette clear of the rulers and of the image grown by anchorHit / 2.
// J4 brushes and undoes from the toolbar, reading the save state in the title
// bar; J5 adds, hides and inspects a layer; J6 is J2 and J3 in dark.
// The geometry steps (J3, J6) wait on SuiteUI #1456: the viewport and status
// line span under the floating sidebar and inspector, and the inspector
// measures 280, not 304, so they fail until it merges, as Design's do.
// The rulers carry no identifier: their bands are computed from suite.viewport
// and SuiteSize.ruler (20), as DesignJourneyTests+Shell does.
// A plain Text reads its words as its value on macOS, so texts are read by label or value.
import XCTest

final class PhotoShellJourneyTests: XCTestCase {
    static let size = ["-SuiteWindowSize", "1024x768"]
    static let bar = ["photo.bar.open", "photo.bar.save", "photo.bar.export", "photo.bar.undo",
                      "photo.bar.redo", "photo.bar.zoom-out", "photo.bar.fit", "photo.bar.zoom-in"]
    static let file = "shell.png"

    /// PS-J1: the empty window, every region up but the palette, which waits for an image.
    @MainActor func testShell1Empty() {
        let photo = Journey("Photo", self, arguments: Self.size + photoArguments())
        let window = photo.app.windows.firstMatch
        XCTAssert(window.waitForExistence(timeout: 30), "no window opened")
        for identifier in Journey.editorRegions where identifier != "suite.tools" {
            let region = photo.element(identifier)
            XCTAssert(region.waitForExistence(timeout: 5), "no \(identifier)")
            XCTAssert(region.isHittable, "\(identifier) isn't hittable")
        }
        XCTAssertEqual(window.title, "Photo", "the empty window's title")
        let sidebar = photo.element("suite.sidebar")
        XCTAssert(sidebar.descendants(matching: .any)["photo.layers"].exists, "the sidebar has no layer list (photo.layers)")
        XCTAssertEqual(eyes(photo).count, 0, "the layer list isn't empty with no image")
        for identifier in Self.bar {
            let item = photo.element(identifier)
            XCTAssert(item.waitForExistence(timeout: 5), "no toolbar item \(identifier)")
            // The reasons are PhotoToolbarItemsTests' (PS-1); the runner shows no help tag.
            let open = identifier == "photo.bar.open"
            XCTAssertEqual(item.isEnabled, open, "\(identifier) is \(item.isEnabled ? "enabled" : "disabled") with no image")
        }
        let viewport = photo.element("suite.viewport")
        XCTAssert(viewport.buttons["Open…"].exists, "the canvas's empty state has no Open…")
        XCTAssertFalse(photo.element("suite.tools").buttons.firstMatch.exists, "the palette shows with no image")
        XCTAssert(text("No Image Open", in: photo.element("suite.inspector")).exists, "the inspector doesn't read No Image Open")
        photo.shot("shell-empty")
        expectSwitcher(photo)
    }

    /// PS-J2: the test photo open.
    @MainActor func testShell2Open() throws {
        let photo = try launch()
        expectOpen(photo, shot: "shell-open")
    }

    /// PS-J3: a marquee from the image's left edge, at Fit on Screen, and the geometry.
    @MainActor func testShell3Selection() throws {
        let photo = try launch()
        select(photo, shot: "shell-selection")
        expectGeometry(photo)
    }

    /// PS-J4: a brush stroke makes the window Edited; Undo Paint in the toolbar takes it back.
    @MainActor func testShell4UndoPaint() throws {
        let photo = try launch()
        photo.element("suite.tools").buttons["Brush"].click()
        photo.drag(on: "suite.canvas", from: CGVector(dx: 0.2, dy: 0.3), to: CGVector(dx: 0.8, dy: 0.7))
        XCTAssert(waitFor { self.showsSubtitle("Edited", photo) }, "the title bar doesn't read Edited after a stroke")
        let undo = photo.element("photo.bar.undo")
        XCTAssert(waitFor { undo.label == "Undo Paint" }, "the toolbar's Undo reads \(undo.label), not Undo Paint")
        undo.click()
        XCTAssert(waitFor { !self.showsSubtitle("Edited", photo) }, "the title bar still reads Edited after Undo Paint")
    }

    /// PS-J5: New Layer in the sidebar, its eye, and the inspector's Layer section.
    @MainActor func testShell5Layers() throws {
        let photo = try launch()
        let sidebar = photo.element("suite.sidebar")
        photo.click("New Layer", in: .window)
        XCTAssert(text("Layer 1", in: sidebar).waitForExistence(timeout: 5), "New Layer listed no Layer 1")
        XCTAssertEqual(eyes(photo).count, 2, "the sidebar doesn't list two layers")
        photo.click("Hide Layer 1", in: .window)
        XCTAssert(photo.app.buttons["Show Layer 1"].waitForExistence(timeout: 5), "Layer 1's eye didn't hide it")
        let inspector = photo.element("suite.inspector").descendants(matching: .any)
        for identifier in ["photo.layer.blend", "photo.layer.opacity"] {
            XCTAssert(inspector[identifier].waitForExistence(timeout: 5), "the inspector's Layer section has no \(identifier)")
        }
    }

    /// PS-J6: J2 and J3 in dark.
    @MainActor func testShell6Dark() throws {
        let photo = try launch(["-AppleInterfaceStyle", "Dark"])
        expectOpen(photo, shot: "shell-open-dark")
        select(photo, shot: "shell-selection-dark")
        expectGeometry(photo)
        expectSwitcher(photo)
    }

    // MARK: Steps

    /// Writes the 800 × 600 test photo and opens it with -PhotoOpenFile at the runner's size.
    @MainActor private func launch(_ extra: [String] = []) throws -> Journey {
        let folder = FileManager.default.temporaryDirectory.appending(path: "photo-shell-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: Self.file)
        try writeTestPhoto(to: url)
        let photo = Journey("Photo", self, arguments: Self.size + extra + photoArguments(open: url))
        XCTAssert(photo.app.windows[Self.file].waitForExistence(timeout: 30), "\(Self.file) didn't open")
        return photo
    }

    /// The title, an empty or Saved subtitle, one layer, the palette at the
    /// canvas's leading edge and the inspector's header, Tool Options, Layer and adjustments.
    @MainActor private func expectOpen(_ photo: Journey, shot: String) {
        XCTAssertEqual(photo.app.windows.firstMatch.title, Self.file, "the open image's title")
        for status in ["Edited", "Not saved"] {
            XCTAssertFalse(showsSubtitle(status, photo), "the freshly opened image's subtitle reads \(status)")
        }
        XCTAssertEqual(eyes(photo).count, 1, "the sidebar doesn't list the one layer")
        let palette = photo.element("suite.tools")
        XCTAssert(palette.buttons.firstMatch.waitForExistence(timeout: 5), "no floating palette (suite.tools)")
        let viewport = photo.element("suite.viewport").frame
        XCTAssertLessThan(palette.frame.minX - viewport.minX, viewport.width / 4, "the palette isn't at the canvas's leading edge")
        let inspector = photo.element("suite.inspector").descendants(matching: .any)
        let header = "\(Self.file), 800 × 600 px, sRGB · 1 layer"
        let labelled = inspector.matching(NSPredicate(format: "label CONTAINS %@", header)).firstMatch
        XCTAssert(labelled.waitForExistence(timeout: 5), "the inspector's header doesn't read \(header)")
        for section in ["tool-options", "layer"] {
            XCTAssert(inspector["suite.inspector.section." + section].exists, "the inspector has no \(section) section")
        }
        XCTAssert(photo.element("suite.inspector").sliders["Exposure"].exists, "the inspector shows no adjustments (Exposure)")
        photo.shot(shot)
    }

    /// Marquee from the image's left edge to 30% across, then View > Fit on Screen.
    @MainActor private func select(_ photo: Journey, shot: String) {
        photo.element("suite.tools").buttons["Marquee"].click()
        photo.drag(on: "suite.canvas", from: CGVector(dx: 0, dy: 0.2), to: CGVector(dx: 0.3, dy: 0.6))
        let selection = photo.app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Selection ' OR value CONTAINS 'Selection '"))
        XCTAssert(selection.firstMatch.waitForExistence(timeout: 5), "the marquee drag made no selection")
        photo.app.menuBars.firstMatch.menuBarItems["View"].click()
        photo.app.menuItems["Fit on Screen"].click()
        photo.shot(shot)
    }

    /// The shell's rules with the toolbar items, the switcher and each tool in
    /// the window, then the palette clear of both rulers and of the image
    /// grown by half an anchor's hit (SuiteSize.ruler 20, anchorHit 12).
    @MainActor private func expectGeometry(_ photo: Journey) {
        var regions: [String: XCUIElement] = ["suite.switcher": photo.element("suite.switcher")]
        for identifier in Self.bar {
            regions[identifier] = photo.element(identifier)
            XCTAssert(photo.element(identifier).isHittable, "\(identifier) isn't hittable (in the overflow?)")
        }
        var minimums: [String: (width: Double, height: Double)] = [
            "suite.viewport": (width: 440, height: 360), "suite.inspector": (width: 304, height: 1),
        ]
        for tool in photo.element("suite.tools").buttons.allElementsBoundByIndex {
            regions["tool " + tool.label] = tool
            minimums["tool " + tool.label] = (width: 32, height: 32)
        }
        photo.expectShellGeometry(minimums: minimums, regions: regions)

        let ruler = 20.0, hit = 12.0
        let viewport = rect(photo.element("suite.viewport").frame), image = rect(photo.element("suite.canvas").frame)
        let bands = [
            "palette": rect(photo.element("suite.tools").frame),
            "top ruler": AppAudit.Rect(x: viewport.x, y: viewport.y, width: viewport.width, height: ruler),
            "leading ruler": AppAudit.Rect(x: viewport.x, y: viewport.y, width: ruler, height: viewport.height),
            "image grown by its anchors": AppAudit.Rect(
                x: image.x - hit / 2, y: image.y - hit / 2, width: image.width + hit, height: image.height + hit),
        ]
        let found = ShellGeometry.violations(
            window: rect(photo.app.windows.firstMatch.frame), regions: bands, minimums: [:], apart: [],
            clear: [("palette", "top ruler"), ("palette", "leading ruler"), ("palette", "image grown by its anchors")])
        XCTAssert(found.isEmpty, "the palette covers a ruler or the selection's edge:\n" + found.joined(separator: "\n"))
    }

    /// The app switcher, centred in the toolbar with Photo current, inside the window.
    @MainActor private func expectSwitcher(_ photo: Journey) {
        let switcher = photo.element("suite.switcher")
        XCTAssert(switcher.waitForExistence(timeout: 5), "no app switcher (suite.switcher)")
        XCTAssertEqual(switcher.frame.midX, photo.app.windows.firstMatch.frame.midX, accuracy: 2, "the switcher isn't centred in the toolbar")
        XCTAssert(switcher.buttons["Photo"].isSelected, "Photo isn't the switcher's current item")
        photo.expectShellGeometry(minimums: ["suite.switcher": (width: 1, height: 1)], regions: ["suite.switcher": switcher])
    }

    // MARK: Reading

    /// The layer rows' eyes (`photo.layer.<id>.eye`) in the sidebar.
    @MainActor private func eyes(_ photo: Journey) -> [XCUIElement] {
        photo.element("suite.sidebar").descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH 'photo.layer.' AND identifier ENDSWITH '.eye'")).allElementsBoundByIndex
    }

    /// A text under `root` reading `string` as its label or value.
    @MainActor private func text(_ string: String, in root: XCUIElement) -> XCUIElement {
        root.staticTexts.matching(NSPredicate(format: "label == %@ OR value == %@", string, string)).firstMatch
    }

    /// Whether the title bar's subtitle starts with `status` ("Edited" also
    /// covers "Edited, autosaved"): a text in the window outside the status
    /// line, whose `photo.bar.saved` says the same.
    @MainActor private func showsSubtitle(_ status: String, _ photo: Journey) -> Bool {
        let line = photo.element("suite.status").frame
        let texts = photo.app.windows.firstMatch.staticTexts.matching(NSPredicate(
            format: "(label BEGINSWITH %@ OR value BEGINSWITH %@) AND identifier != %@", status, status, "photo.bar.saved"))
        return texts.allElementsBoundByIndex.contains { !line.intersects($0.frame) }
    }

    /// Whether `condition` holds within five seconds.
    @MainActor private func waitFor(_ condition: () -> Bool) -> Bool {
        for _ in 0..<25 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }

    private func rect(_ frame: CGRect) -> AppAudit.Rect {
        AppAudit.Rect(x: Double(frame.minX), y: Double(frame.minY), width: Double(frame.width), height: Double(frame.height))
    }
}

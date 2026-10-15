// HaloJourneyTests.swift: Halo driven like a person would, with a
// whole-window screenshot after every step (see Journey.swift). Each test is
// one journey; grow them as Halo's features land, and replace the skipped
// test with the real journey when its issue is built.
//
// Foundation (#777): H-J0 checks the empty viewer and inspector; H-J1 fills
// the New Composition sheet by its field labels (#286); H-J13 reads the
// `halo.controls` JSON on the `keyed` fixture, clicks every enabled control
// (then Escape and Command-Z) and checks it changed the window, and that every
// disabled one says why (QB-F1). `halo.controls` travels by preference, which
// may not leave the inspector or toolbar, so H-J13 also launches with
// `-SuitePerfProbe` and adds the `halo.*` entries of `suite.controls`, which
// `.haloControl` registers too. testEveryMenuOpens checks the Composition,
// Layer and Animation menus hold exactly their items and File and Edit hold
// Halo's. testLayoutAtWidths relaunches at five window sizes with a layer
// selected (blueprint 7.3): L1 is the audit on each `halo-layout-<w>` shot, L2
// finds the artboard in the viewer's pixels (white on the surround) and checks
// it is centered within 1 pt with its 16:9 aspect within 0.5%, L6 that it is
// at least 160 pt wide at the minimum size; it also checks every halo.*
// control lies inside the window and the viewer is narrower at 880 than at
// 1024 (the content column follows the window). Every other journey launches
// pinned at the runner's launch size (`launch`), so a sized launch never
// carries over. Run order is by name, so
// testScrubTheTimeline runs last and attaches the audit counts.
import AppKit
import XCTest

final class HaloJourneyTests: XCTestCase {
    @MainActor func testLaunchShowsWindowShell() {
        let halo = launch()
        halo.expectWindowShell()
        XCTAssert(Self.contains("No Composition", in: halo.app.splitGroups.firstMatch).exists, "the viewer doesn't say No Composition")
        XCTAssert(halo.element("halo.viewer.newComposition").exists, "the empty viewer offers no New Composition…")
        XCTAssert(Self.contains("No Selection", in: halo.element("suite.inspector")).exists, "the inspector doesn't read No Selection")
    }

    @MainActor func testNewComposition() {
        let halo = launch()
        halo.click("New Composition…", step: "new-composition-sheet")
        let sheet = halo.app.sheets.firstMatch
        enter("abc", into: "Width", in: sheet)
        XCTAssert(
            Self.contains("Width must be a whole number of pixels.", in: sheet).waitForExistence(timeout: 5),
            "no problem line for a width of abc")
        XCTAssertFalse(sheet.buttons["Create"].isEnabled, "Create is enabled with a width of abc")
        halo.shot("new-composition-invalid")
        enter("1080", into: "Width", in: sheet)
        enter("1920", into: "Height", in: sheet)
        let rate = sheet.popUpButtons["Frame Rate"]
        XCTAssert(rate.exists, "no Frame Rate pop-up by its label")
        rate.click()
        halo.app.menuItems["24 fps"].click()
        halo.shot("new-composition-filled")
        halo.click("Create", in: .sheet, step: "new-composition")
        // The header is one element reading "Comp 1, 1080 × 1920, 24 fps · 10 s".
        let header = halo.element("halo.inspector.header")
        XCTAssert(header.waitForExistence(timeout: 5), "no composition inspector header after Create")
        XCTAssert(header.label.contains("1080 × 1920"), "the inspector header doesn't read 1080 × 1920: \(header.label)")
        XCTAssert(header.label.contains("24 fps · 10 s"), "the inspector header doesn't read 24 fps · 10 s: \(header.label)")
        let inspector = halo.element("suite.inspector")
        XCTAssert(Self.contains("Frame Rate", in: inspector).exists, "the inspector has no Frame Rate row")
        XCTAssert(halo.element("halo.inspector.composition.size").exists, "the inspector has no Size value")
        XCTAssert(Self.contains("Comp 1", in: halo.element("suite.sidebar")).exists, "the sidebar has no Comp 1 row")
    }

    @MainActor func testScrubTheTimeline() {
        let halo = launch()
        halo.click("New Composition…")
        halo.click("Create", in: .sheet, step: "timeline")
        // The ruler is the timeline's top 24 pt, so the drag stays near its top.
        halo.drag(on: "halo.timeline", from: CGVector(dx: 0.3, dy: 0.05), to: CGVector(dx: 0.6, dy: 0.05), step: "timeline-scrub")
        let window = halo.app.windows.firstMatch.frame
        let ruler = halo.app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Frame Ruler'")).firstMatch
        XCTAssert(ruler.waitForExistence(timeout: 5), "no Frame Ruler in the timeline")
        XCTAssert(window.contains(ruler.frame), "the ruler \(ruler.frame) runs outside the window \(window)")
        for bar in halo.app.windows.firstMatch.scrollBars.allElementsBoundByIndex where bar.isHittable {
            XCTAssertFalse(bar.frame.intersects(ruler.frame), "a scroll bar \(bar.frame) covers the ruler \(ruler.frame)")
        }
        let timeline = halo.element("halo.timeline").frame
        XCTAssertLessThanOrEqual(timeline.height, window.height * 0.4 + 1, "the timeline takes over 40% of the window")
    }

    @MainActor func testEveryMenuOpens() {
        let halo = launch()
        halo.click("New Composition…")
        halo.click("Create", in: .sheet)
        halo.openEachMenu()
        for (menu, items) in Self.menus {
            let titles = itemTitles(of: menu, in: halo)
            XCTAssertEqual(titles, items, "the \(menu) menu doesn't hold exactly its items")
        }
        for (menu, items) in Self.menusHolding {
            let titles = itemTitles(of: menu, in: halo)
            for item in items {
                XCTAssert(titles.contains { $0.hasPrefix(item) }, "the \(menu) menu has no \(item): \(titles)")
            }
        }
        XCTAssertEqual(submenuTitles("New", of: "Layer", in: halo), ["Solid", "Shape", "Text", "Null"])
        XCTAssertEqual(
            submenuTitles("Keyframe Easing", of: "Animation", in: halo),
            ["Linear", "Ease In", "Ease Out", "Ease In and Out", "Hold"])
    }

    /// H-J13 (QB-F1): every enabled control acts, every disabled one says why.
    @MainActor func testEveryControlActsOrSaysWhy() {
        let halo = launch(["-HaloFixture", "keyed", "-HaloControlsProbe", "-SuitePerfProbe"])
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        halo.shot("controls")
        let listed = Self.decode(halo.element("halo.controls"))
        XCTAssertNotNil(listed, "no halo.controls JSON under -HaloControlsProbe")
        let suite = Self.decode(halo.element("suite.controls"))?.controls.filter { $0.id.hasPrefix("halo.") } ?? []
        var entries: [String: ControlEntry] = [:]
        for entry in suite + (listed?.controls ?? []) { entries[entry.id] = entry }
        XCTAssertFalse(entries.isEmpty, "neither halo.controls nor suite.controls lists a halo control")
        attach(entries.values.sorted { $0.id < $1.id }, as: "halo-controls")
        for id in onScreenControlIDs(halo) {
            XCTAssertNotNil(entries[id], "\(id) is on screen but in neither halo.controls nor suite.controls")
        }
        for entry in entries.values.sorted(by: { $0.id < $1.id }) {
            guard entry.enabled else {
                XCTAssertFalse((entry.reason ?? "").isEmpty, "\(entry.id) is disabled and doesn't say why")
                continue
            }
            let control = halo.element(entry.id)
            XCTAssert(control.waitForExistence(timeout: 5), "\(entry.id) is listed but not on screen")
            let before = halo.app.windows.firstMatch.screenshot().pngRepresentation
            let labels = (halo.element("halo.controls").label, halo.element("halo.viewer").label)
            control.click()
            Thread.sleep(forTimeInterval: 0.5)
            let after = halo.app.windows.firstMatch.screenshot().pngRepresentation
            let changed = before != after
                || labels != (halo.element("halo.controls").label, halo.element("halo.viewer").label)
            halo.shot("control-\(halo.slug(entry.id))")
            XCTAssert(changed, "\(entry.id) is enabled but clicking it changed nothing")
            halo.press(.escape)
            halo.press(character: "z", .command)
        }
    }

    /// Layout L1, L2 and L6 (blueprint 7.3) at five window sizes.
    @MainActor func testLayoutAtWidths() {
        // SuiteSize.windowMinimum: sidebar ideal 200 + content minimum 440 + inspector ideal 240, by 560.
        let sizes = [CGSize(width: 880, height: 560), CGSize(width: 1024, height: 768), CGSize(width: 1280, height: 800),
                     CGSize(width: 1440, height: 900), CGSize(width: 1920, height: 1080)]
        let screen = NSScreen.screens.first?.frame.size ?? .zero
        var viewerWidths: [Int: CGFloat] = [:]
        for size in sizes {
            let width = Int(size.width)
            let halo = Journey("Halo", self, arguments: ["-HaloFixture", "keyed", "-HaloWindowSize", "\(width)x\(Int(size.height))"])
            let window = halo.app.windows.firstMatch
            XCTAssert(window.waitForExistence(timeout: 30), "no window opened at \(width)")
            if size.width <= screen.width {
                XCTAssertEqual(window.frame.width, size.width, accuracy: 2, "-HaloWindowSize \(width) wasn't the window's width")
            }
            let row = halo.element("halo.layer.row.comp-1-layer-2")
            XCTAssert(row.waitForExistence(timeout: 5), "no Ball row in the inspector's layers at \(width)")
            row.click()
            let ball = halo.app.descendants(matching: .any).matching(
                NSPredicate(format: "identifier == 'halo.inspector.header' AND label CONTAINS %@", "Frames 0–47")).firstMatch
            XCTAssert(ball.waitForExistence(timeout: 5), "clicking the Ball row selected no layer at \(width)")
            halo.shot("layout-\(width)")
            let outside = haloControls(in: halo).filter { !window.frame.contains($0.frame) }
            XCTAssert(outside.isEmpty, "halo controls outside the \(width) window \(window.frame): "
                + outside.map { "\($0.identifier) \($0.frame)" }.joined(separator: ", "))
            viewerWidths[width] = halo.element("halo.viewer").frame.width
            let timeline = halo.element("halo.timeline").frame
            XCTAssertLessThanOrEqual(timeline.maxY, window.frame.maxY, "the timeline runs off the window at \(width)")
            let tracks = halo.app.windows.firstMatch.buttons.matching(identifier: "halo.timeline.track").allElementsBoundByIndex
            for track in tracks {
                XCTAssertGreaterThanOrEqual(track.frame.minX, timeline.minX - 1,
                    "a timeline track \(track.frame) starts left of the timeline \(timeline) at \(width): it runs under the sidebar")
            }
            guard let artboard = artboardFrame(in: halo.element("halo.viewer")) else {
                XCTFail("no artboard found in the viewer at \(width)")
                continue
            }
            let viewer = halo.element("halo.viewer").frame
            XCTAssertEqual(artboard.midX, viewer.width / 2, accuracy: 1, "L2: the artboard isn't centered across at \(width)")
            XCTAssertEqual(artboard.midY, viewer.height / 2, accuracy: 1, "L2: the artboard isn't centered down at \(width)")
            let aspect = artboard.height > 0 ? artboard.width / artboard.height : 0
            XCTAssertEqual(aspect / (1920.0 / 1080.0), 1, accuracy: 0.005, "L2: the artboard's aspect is \(aspect) at \(width)")
            if size == sizes.first {
                XCTAssertGreaterThanOrEqual(artboard.width, 160, "L6: the artboard is under 160 pt wide at the minimum")
            }
        }
        // The content follows the window: nothing in it holds the column at a fixed width.
        let (narrow, wide) = (viewerWidths[880] ?? 0, viewerWidths[1024] ?? 0)
        XCTAssertLessThan(narrow, wide, "the viewer is \(narrow) pt at 880 and \(wide) pt at 1024: the content column is rigid")
    }

    @MainActor func testKeyLayerAndSave() throws {
        throw XCTSkip("journey arrives with #207 (key), #208 (undo) and #209 (save)")
    }

    // MARK: - Menus

    /// The Halo menus that hold only Halo's items, top level, in order (separators left out).
    private static let menus: [(String, [String])] = [
        ("Composition", ["New", "Duplicate", "Delete"]),
        ("Layer", ["New", "Duplicate", "Rename…", "Delete", "Bring Forward", "Send Backward"]),
        ("Animation", [
            "Play/Pause", "Loop", "Next Frame", "Previous Frame", "Go to Start", "Go to End", "Set In Point",
            "Set Out Point", "Keyframe Easing",
        ]),
    ]

    /// The system menus Halo adds to: each holds these items (Undo and Redo by prefix, titled by their step).
    private static let menusHolding: [(String, [String])] = [
        ("File", ["New Composition…", "Open…", "Open Recent", "Save", "Save As…", "Render…", "Render Frame"]),
        ("Edit", ["Undo", "Redo"]),
    ]

    /// The titles of `menu`'s top-level items, read with the menu open.
    @MainActor private func itemTitles(of menu: String, in halo: Journey) -> [String] {
        let bar = halo.app.menuBars.firstMatch.menuBarItems[menu]
        XCTAssert(bar.waitForExistence(timeout: 5), "no \(menu) menu")
        bar.click()
        let items = bar.menus.firstMatch.children(matching: .menuItem)
        _ = items.firstMatch.waitForExistence(timeout: 3)
        let titles = items.allElementsBoundByIndex.map(\.title).filter { !$0.isEmpty }
        halo.press(.escape)
        return titles
    }

    /// The titles of the submenu `item` of `menu`, opened by hovering it.
    @MainActor private func submenuTitles(_ item: String, of menu: String, in halo: Journey) -> [String] {
        let bar = halo.app.menuBars.firstMatch.menuBarItems[menu]
        bar.click()
        let parent = bar.menus.firstMatch.children(matching: .menuItem)[item]
        XCTAssert(parent.waitForExistence(timeout: 3), "the \(menu) menu has no \(item)")
        parent.hover()
        let items = parent.menus.firstMatch.children(matching: .menuItem)
        _ = items.firstMatch.waitForExistence(timeout: 3)
        let titles = items.allElementsBoundByIndex.map(\.title).filter { !$0.isEmpty }
        halo.press(.escape)
        halo.press(.escape)
        return titles
    }

    // MARK: - Helpers

    /// SuiteSize.windowLaunch, the size a plain launch opens at on the runner.
    private static let runnerSize = "1000x640"

    /// Launches Halo with `arguments` at the runner's launch size, pinned with
    /// `-HaloWindowSize`, so no earlier sized launch can change this one's window.
    @MainActor private func launch(_ arguments: [String] = []) -> Journey {
        Journey("Halo", self, arguments: arguments + ["-HaloWindowSize", Self.runnerSize])
    }

    /// The window's `halo.*` controls (onScreenControlIDs' types), timeline tracks included.
    @MainActor private func haloControls(in halo: Journey) -> [XCUIElement] {
        let types: [XCUIElement.ElementType] = [.button, .popUpButton, .textField, .checkBox, .slider, .cell]
        return types.flatMap { type in
            halo.app.windows.firstMatch.descendants(matching: type)
                .matching(NSPredicate(format: "identifier BEGINSWITH 'halo.'")).allElementsBoundByIndex
        }
    }

    /// Clicks the sheet's field labelled `label`, selects its text and types `text`.
    @MainActor private func enter(_ text: String, into label: String, in sheet: XCUIElement) {
        let field = sheet.textFields[label]
        XCTAssert(field.waitForExistence(timeout: 5), "no \(label) field by its label (#286)")
        field.click()
        field.typeKey("a", modifierFlags: .command)
        field.typeText(text)
    }

    /// The first element under `root` whose label contains `text`, or static
    /// text whose value does: a plain SwiftUI Text (an empty state's title, a
    /// problem line) reads as a static text with an empty label and its string
    /// as its value. Only static texts are searched by value, whose value is
    /// always a string, so CONTAINS never meets a checkbox's number.
    @MainActor private static func contains(_ text: String, in root: XCUIElement) -> XCUIElement {
        let staticText = NSNumber(value: XCUIElement.ElementType.staticText.rawValue)
        let predicate = NSPredicate(
            format: "label CONTAINS %@ OR (elementType == %@ AND value CONTAINS %@)", text, staticText, text)
        return root.descendants(matching: .any).matching(predicate).firstMatch
    }

    /// The ControlDocument in `probe`'s label; nil when it's missing or isn't one.
    @MainActor private static func decode(_ probe: XCUIElement) -> ControlDocument? {
        guard probe.waitForExistence(timeout: 5) else { return nil }
        return try? JSONDecoder().decode(ControlDocument.self, from: Data(probe.label.utf8))
    }

    /// The `halo.*` identifiers of the window's buttons, pop-ups, fields and
    /// rows, but the timeline's track names (SuiteUI's buttons, which take
    /// `halo.timeline.track` from their strip and act through the timeline).
    @MainActor private func onScreenControlIDs(_ halo: Journey) -> Set<String> {
        let window = halo.app.windows.firstMatch
        let types: [XCUIElement.ElementType] = [.button, .popUpButton, .textField, .checkBox, .slider, .cell]
        var ids = Set<String>()
        for type in types {
            let query = window.descendants(matching: type).matching(NSPredicate(format: "identifier BEGINSWITH 'halo.'"))
            for element in query.allElementsBoundByIndex where element.identifier != "halo.timeline.track" {
                ids.insert(element.identifier)
            }
        }
        return ids
    }

    /// The artboard's frame in `viewer`, in points from its top left, found in
    /// its pixels: each pixel's share of the way from the surround's gray (a
    /// corner) to the artboard's white (the center), summed along the center
    /// row and column, so an antialiased edge counts in part. Nil when the
    /// center doesn't stand out from the corner.
    @MainActor private func artboardFrame(in viewer: XCUIElement) -> CGRect? {
        guard viewer.waitForExistence(timeout: 5), viewer.frame.width > 0,
            let image = NSBitmapImageRep(data: viewer.screenshot().pngRepresentation)?.cgImage,
            let srgb = CGColorSpace(name: CGColorSpace.sRGB)
        else { return nil }
        let (width, height) = (image.width, image.height)
        guard width > 2, height > 2 else { return nil }
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = rgba.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(
                data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: srgb, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        func gray(_ x: Int, _ y: Int) -> Double {
            let i = (y * width + x) * 4
            return (Double(rgba[i]) + Double(rgba[i + 1]) + Double(rgba[i + 2])) / 3
        }
        let surround = gray(1, 1), board = gray(width / 2, height / 2)
        guard abs(board - surround) > 8 else { return nil }
        func share(_ x: Int, _ y: Int) -> Double { min(max((gray(x, y) - surround) / (board - surround), 0), 1) }
        let across = (0..<width).map { share($0, height / 2) }
        let down = (0..<height).map { share(width / 2, $0) }
        let (sumX, sumY) = (across.reduce(0, +), down.reduce(0, +))
        guard sumX > 0, sumY > 0 else { return nil }
        let midX = zip(across.indices, across).reduce(0) { $0 + (Double($1.0) + 0.5) * $1.1 } / sumX
        let midY = zip(down.indices, down).reduce(0) { $0 + (Double($1.0) + 0.5) * $1.1 } / sumY
        let scale = Double(width) / Double(viewer.frame.width)
        return CGRect(
            x: (midX - sumX / 2) / scale, y: (midY - sumY / 2) / scale, width: sumX / scale, height: sumY / scale)
    }

    private func attach(_ value: some Encodable, as name: String) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let json = try? encoder.encode(value) else { return }
        let attachment = XCTAttachment(data: json, uniformTypeIdentifier: "public.json")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

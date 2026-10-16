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
// selected from its timeline lane (blueprint 7.3): L1 is the audit on each
// `halo-layout-<w>` shot, L2
// takes the artboard as the drawn layers' frame (`halo.viewer.canvas`) and
// checks it is centered within 1 pt (across: the surround on its two sides,
// measured in the screen's pixels to where each panel starts, as a person
// sees it, or the viewer's frame when a panel is off the screen) with its
// 16:9 aspect within 0.5%, L6 that it is
// at least 160 pt wide at the minimum size; it also checks every halo.*
// control lies inside the window and the viewer is narrower at 880 than at
// 1024 (the content column follows the window). Every other journey launches
// pinned at the runner's launch size (`launch`), so a sized launch never
// carries over. H-J3 (testScrubTheTimeline, viewer-playback VP-11) drags the
// ruler on `-HaloSample three-layers`, then sets Badge's span to 20–50 from
// the keys and reads the timecode, header and artboard. Run order is by name, so
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

    /// H-J3 (viewer-playback VP-11): the shipped ruler drag, then Badge's
    /// span set from the keys: Home, → 20, I, → 30, O, → 10.
    @MainActor func testScrubTheTimeline() {
        let halo = launch(["-HaloSample", "three-layers"])
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(halo.element("halo.timeline").waitForExistence(timeout: 10), "no timeline (halo.timeline)")
        halo.shot("timeline")
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
        setBadgeSpanFromTheKeys(halo)
    }

    /// H-J3's keys: clicking Badge's lane selects it and focuses the
    /// timeline, so HaloViewer routes Home and → (VP-10), I and O. Badge's
    /// header reads in…out−1: O at 50 stores outFrame 51 (W0's
    /// selectedLayerHeader), so it reads "Frames 20–50", and at 60 the
    /// artboard (W0's viewerSummary) no longer names Badge.
    @MainActor private func setBadgeSpanFromTheKeys(_ halo: Journey) {
        let lane = halo.app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == 'halo.timeline.track' AND label == 'Badge'")).firstMatch
        XCTAssert(lane.waitForExistence(timeout: 5), "no Badge lane in the timeline")
        lane.click()
        XCTAssert(header("Badge", halo).waitForExistence(timeout: 5), "clicking Badge's lane didn't select Badge")
        halo.press(.home)
        step(20, halo)
        expectTimecode("00:00:00:20 · frame 20", halo)
        halo.shot("scrub-frame-20")
        halo.press(character: "i", step: "scrub-in-20")
        step(30, halo)
        expectTimecode("00:00:02:02 · frame 50", halo)
        halo.press(character: "o")
        XCTAssert(
            header("Frames 20–50", halo).waitForExistence(timeout: 5),
            "Badge's header doesn't read Frames 20–50: \(halo.element("halo.inspector.header").label)")
        halo.shot("scrub-out-50")
        step(10, halo)
        let summary = "Frame 60: Background, Title: Hello Halo"
        // The summary is read by label from `halo.viewer.summary`: values read empty (#262).
        let artboard = halo.app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == 'halo.viewer.summary' AND label == %@", summary)).firstMatch
        XCTAssert(
            artboard.waitForExistence(timeout: 5),
            "the artboard reads \(halo.element("halo.viewer.summary").label), not \(summary)")
        halo.shot("scrub-frame-60")
    }

    /// Presses → `count` times.
    @MainActor private func step(_ count: Int, _ halo: Journey) {
        for _ in 0..<count { halo.press(.rightArrow) }
    }

    /// The inspector header whose label contains `text`.
    @MainActor private func header(_ text: String, _ halo: Journey) -> XCUIElement {
        halo.app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == 'halo.inspector.header' AND label CONTAINS %@", text)).firstMatch
    }

    /// The status row's timecode pill (statusTimecode: the playhead's
    /// timecode, then the length and rate) starts with `timecode`, within
    /// five seconds. A plain Text may read as a static text whose value holds
    /// the string, so only static texts are matched by value (see `contains`).
    @MainActor private func expectTimecode(_ timecode: String, _ halo: Journey) {
        let staticText = NSNumber(value: XCUIElement.ElementType.staticText.rawValue)
        let predicate = NSPredicate(
            format: "label BEGINSWITH %@ OR (elementType == %@ AND value BEGINSWITH %@)", timecode, staticText, timecode)
        let pill = halo.app.windows.firstMatch.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssert(pill.waitForExistence(timeout: 5), "the status timecode doesn't read \(timecode)")
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
        for listed in entries.values.sorted(by: { $0.id < $1.id }) {
            // Earlier clicks move state Undo doesn't restore (End leaves the
            // playhead on the last frame, so Next turns off and says why), so
            // judge each control as the probe lists it now, not at launch.
            let entry = Self.decode(halo.element("halo.controls"))?.controls.first { $0.id == listed.id } ?? listed
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
            // Ball's timeline lane, not its inspector row: from 1280 up the
            // window is wider than the runner's 1024 pt display and the
            // inspector is off it, where nothing can be clicked (run
            // 38848092018: no hit point for suite.inspector at x 1064).
            let lane = halo.app.descendants(matching: .any).matching(
                NSPredicate(format: "identifier == 'halo.timeline.track' AND label == 'Ball'")).firstMatch
            XCTAssert(lane.waitForExistence(timeout: 5), "no Ball lane in the timeline at \(width)")
            lane.click()
            let ball = halo.app.descendants(matching: .any).matching(
                NSPredicate(format: "identifier == 'halo.inspector.header' AND label CONTAINS %@", "Frames 0–47")).firstMatch
            XCTAssert(ball.waitForExistence(timeout: 5), "clicking Ball's lane selected no layer at \(width)")
            halo.shot("layout-\(width)")
            let outside = haloControls(in: halo).compactMap { control -> String? in
                guard let shown = visibleFrame(of: control, in: window) else { return nil }
                return window.frame.insetBy(dx: -1, dy: -1).contains(shown) ? nil : "\(control.identifier) \(shown)"
            }
            XCTAssert(outside.isEmpty, "halo controls outside the \(width) window \(window.frame): "
                + outside.joined(separator: ", "))
            viewerWidths[width] = halo.element("halo.viewer").frame.width
            let timeline = halo.element("halo.timeline").frame
            XCTAssertLessThanOrEqual(timeline.maxY, window.frame.maxY, "the timeline runs off the window at \(width)")
            let tracks = halo.app.windows.firstMatch.buttons.matching(identifier: "halo.timeline.track").allElementsBoundByIndex
            for track in tracks {
                XCTAssertGreaterThanOrEqual(track.frame.minX, timeline.minX - 1,
                    "a timeline track \(track.frame) starts left of the timeline \(timeline) at \(width): it runs under the sidebar")
            }
            assertLanesFit(halo, timeline: timeline, width: width)
            // The artboard is the drawn layers' frame (`halo.viewer.canvas`,
            // laid out on it exactly as CanvasSurface lays out the artboard).
            // Its pixels can't stand in: the surround's own shading, the
            // keyed fixture's red Floor and its antialiased edges each threw
            // a pixel measure off by 2 to 17 pt in runs 38823293728 to
            // 38838721076, and at 880 it is 175.5 pt tall, too fine for whole
            // pixels at 0.5%.
            let viewer = halo.element("halo.viewer").frame
            let board = halo.element("halo.viewer.canvas").frame
            guard board.width > 0, board.height > 0 else {
                XCTFail("no drawn artboard (halo.viewer.canvas) in the viewer at \(width)")
                continue
            }
            if let side = sideMargins(of: board, viewer: viewer) {
                XCTAssertEqual(side.left, side.right, accuracy: 2,
                    "L2: the artboard isn't centered across at \(width): \(side.left) pt of surround left, \(side.right) pt right")
            } else {
                // A panel's edge is off the screen (the window is wider than
                // the runner's display): judge against the viewer's frame.
                XCTAssertEqual(board.midX, viewer.midX, accuracy: 1, "L2: the artboard isn't centered across at \(width)")
            }
            XCTAssertEqual(board.midY, viewer.midY, accuracy: 1, "L2: the artboard isn't centered down at \(width)")
            let aspect = board.width / board.height
            XCTAssertEqual(aspect / (1920.0 / 1080.0), 1, accuracy: 0.005, "L2: the artboard's aspect is \(aspect) at \(width)")
            if size == sizes.first {
                XCTAssertGreaterThanOrEqual(board.width, 160, "L6: the artboard is under 160 pt wide at the minimum")
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

    /// #1019: the lanes fit the width that shows. The ruler spans every frame
    /// plus the trailing room, so it ends at the timeline's visible trailing
    /// edge (no frame clipped past it, none short of it). That edge is the
    /// timeline's own frame, which XCUITest reads clipped to the column the
    /// inspector leaves. The lanes' horizontal scroll view can't stand in:
    /// SwiftUI runs a scroll view into the safe area along its axis, so it
    /// reaches under the inspector with its content inset by the inspector's
    /// width, and its accessibility frame takes that inset off the part
    /// already clipped at the inspector, reading 240 pt narrower than the
    /// lanes that show (run 38799320916: 151 pt for 391 pt of lanes).
    @MainActor private func assertLanesFit(_ halo: Journey, timeline: CGRect, width: Int) {
        let container = halo.element("halo.timeline")
        let ruler = container.descendants(matching: .any).matching(NSPredicate(format: "label == 'Frame Ruler'")).firstMatch
        XCTAssert(ruler.waitForExistence(timeout: 5), "no Frame Ruler in the timeline at \(width)")
        let end = ruler.frame.maxX
        XCTAssertLessThanOrEqual(
            end, timeline.maxX + 1, "the lanes run \(end - timeline.maxX) pt past the timeline \(timeline) at \(width): the last frames are cut off")
        XCTAssertGreaterThanOrEqual(end, timeline.maxX - 2, "the lanes stop \(timeline.maxX - end) pt short of the timeline \(timeline) at \(width)")
    }

    /// The part of `control` that shows: its frame cut by every scroll view
    /// around it, nil when it is scrolled out of view. The packet's L1
    /// (docs/blueprints/halo/features/foundation.md, Layout step) defines
    /// "nothing off the window" as the app audit on each halo-layout-<w>
    /// shot, and the audit's offscreen check
    /// (Tests/AppAuditTests/Checks/Offscreen.swift, with AuditCore's
    /// flatten) judges this visible frame against the window with 1 pt of
    /// slack. So a timeline track whose raw frame starts under the sidebar,
    /// in a scroll view that clips it to the window, passes, and a control
    /// pushed off the window still fails.
    @MainActor private func visibleFrame(of control: XCUIElement, in window: XCUIElement) -> CGRect? {
        let frame = control.frame
        guard !window.frame.insetBy(dx: -1, dy: -1).contains(frame) else { return frame }
        let scrolls = window.descendants(matching: .scrollView)
            .containing(control.elementType, identifier: control.identifier).allElementsBoundByIndex
        let shown = scrolls.reduce(frame) { $0.intersection($1.frame) }
        return shown.isNull || shown.isEmpty ? nil : shown
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

    /// The surround's width left and right of `artboard` (screen points),
    /// along the screen's row through its middle: from the artboard to the
    /// sharpest step in the screen's pixels between it and `viewer`'s edge
    /// (within 8 pt), where a panel starts; 12 pt nearest the artboard are
    /// its shadow and left out. This is the centering a person sees, between
    /// the panels, rather than against XCUITest's frame for the viewer, which
    /// is its split view column clipped to the window. Nil when either range
    /// runs off the screen. The screen, not the window: a window wider than
    /// the display shoots only its visible part (1012 of 1024 pt in run
    /// 38843147593), which no scale from its frame maps back.
    @MainActor private func sideMargins(of artboard: CGRect, viewer: CGRect) -> (left: Double, right: Double)? {
        let display = NSScreen.screens.first?.frame.size ?? .zero
        guard display.width > 0, let shot = ShotPixels(XCUIScreen.main.screenshot()) else { return nil }
        let scale = Double(shot.width) / Double(display.width)
        let y = Int((Double(artboard.midY) * scale).rounded())
        guard (0..<shot.height).contains(y) else { return nil }
        func px(_ x: CGFloat) -> Int { Int((Double(x) * scale).rounded()) }
        /// The point just past the sharpest step between `from` and `to`.
        func step(_ from: CGFloat, _ to: CGFloat) -> Double? {
            let (a, b) = (px(from), px(to))
            guard a >= 0, b < shot.width - 1, a < b else { return nil }
            let jump = { (x: Int) in abs(shot.gray(x + 1, y) - shot.gray(x, y)) }
            guard let i = (a..<b).max(by: { jump($0) < jump($1) }) else { return nil }
            return Double(i + 1) / scale
        }
        guard let left = step(viewer.minX - 8, artboard.minX - 12), let right = step(artboard.maxX + 12, viewer.maxX + 8)
        else { return nil }
        return (Double(artboard.minX) - left, right - Double(artboard.maxX))
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

/// A screenshot as sRGB, read as gray levels, top row first.
private struct ShotPixels {
    let width: Int
    let height: Int
    private let rgba: [UInt8]

    @MainActor init?(_ screenshot: XCUIScreenshot) {
        guard let image = NSBitmapImageRep(data: screenshot.pngRepresentation)?.cgImage,
            let srgb = CGColorSpace(name: CGColorSpace.sRGB)
        else { return nil }
        (width, height) = (image.width, image.height)
        var rgba = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let drawn = rgba.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(
                data: bytes.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: srgb, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        guard drawn else { return nil }
        self.rgba = rgba
    }

    /// The mean of a pixel's red, green and blue.
    func gray(_ x: Int, _ y: Int) -> Double {
        let i = (y * width + x) * 4
        return (Double(rgba[i]) + Double(rgba[i + 1]) + Double(rgba[i + 2])) / 3
    }
}

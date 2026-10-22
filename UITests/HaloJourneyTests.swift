// HaloJourneyTests.swift: Halo driven like a person would, with a
// whole-window screenshot after every step (see Journey.swift). Each test is
// one journey; grow them as Halo's features land, and replace the skipped
// test with the real journey when its issue is built.
//
// Foundation (#777): H-J0 checks the empty viewer and inspector; H-J1 fills
// the New Composition sheet by its field labels (#286); H-J13 reads the
// `halo.controls` JSON on `-HaloSample keyed` (live services, CL-12), clicks
// every enabled control (then Escape and Command-Z) and checks it changed the
// window, and that every disabled one says why (QB-F1). `halo.controls` travels by preference, which
// may not leave the inspector or toolbar, so H-J13 also launches with
// `-SuitePerfProbe` and adds the `halo.*` entries of `suite.controls`, which
// `.haloControl` registers too. testEveryMenuOpens checks the Composition,
// Layer and Animation menus hold exactly their items and File, Edit and
// Window hold Halo's; testSwitchToMenu (A-HA-1, #865) reads Window > Switch
// To. testLayoutAtWidths relaunches at five window sizes with a layer
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
// testScrubTheTimeline runs last and attaches the audit counts. H-J12
// (testKeyLayerAndSave, core-loop CL-13) makes a 2 s, 24 fps Loop on a plain
// launch, keys a solid's Position X at 0 and 24 (stopwatch, then a viewer
// drag through H-J5's ViewerDragSteps), eases 0–24 Out, plays and pauses,
// adds a Hello text layer, undoes and redoes it by menu, renders 48 PNGs at
// Half, saves through -HaloSaveTo and reopens Loop.halo with -HaloOpenFile.
import AppKit
import ImageIO
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
        let lane = halo.trackName("Badge")
        XCTAssert(lane.waitForExistence(timeout: 5), "no Badge track (halo.timeline.name.*) in the timeline")
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

    /// A-HA-1 (#865): Window > Switch To lists the suite's other apps, then Halo's own window.
    @MainActor func testSwitchToMenu() {
        let halo = launch()
        XCTAssertEqual(
            submenuTitles("Switch To", of: "Window", in: halo),
            ["Home", "Flare", "Design", "Photo", "Library", "Show Halo Window"])
    }

    /// H-J13 (QB-F1): every enabled control acts, every disabled one says why.
    @MainActor func testEveryControlActsOrSaysWhy() {
        let halo = launch(["-HaloSample", "keyed", "-HaloControlsProbe", "-SuitePerfProbe"])
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
            // End and Loop aren't undo steps, so earlier clicks leave state ⌘Z
            // doesn't restore. The Start reset after each click puts the
            // playhead back on frame 0: a play-once pass started on the last
            // frame ends there again before XCUITest's idle wait returns. Still
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
            let start = halo.element("halo.transport.start")
            if start.exists, start.isEnabled { start.click() }
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
            let halo = Journey("Halo", self, arguments: ["-HaloSample", "keyed", "-HaloWindowSize", "\(width)x\(Int(size.height))"])
            let window = halo.app.windows.firstMatch
            XCTAssert(window.waitForExistence(timeout: 30), "no window opened at \(width)")
            if size.width <= screen.width {
                XCTAssertEqual(window.frame.width, size.width, accuracy: 2, "-HaloWindowSize \(width) wasn't the window's width")
            }
            // Ball's timeline lane, not its inspector row: from 1280 up the
            // window is wider than the runner's 1024 pt display and the
            // inspector is off it, where nothing can be clicked (run
            // 38848092018: no hit point for suite.inspector at x 1064).
            let lane = halo.trackName("Ball")
            XCTAssert(lane.waitForExistence(timeout: 5), "no Ball track (halo.timeline.name.*) in the timeline at \(width)")
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
            let tracks = halo.app.windows.firstMatch.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH 'halo.timeline.name.'")).allElementsBoundByIndex
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

    /// H-J12 (core-loop CL-13): make, key, ease, play, title, undo, render,
    /// save and reopen a 2 s loop on live services, one shot per step.
    @MainActor func testKeyLayerAndSave() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "halo-loop-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: "Loop.halo").path
        var halo = launch(["-HaloSaveTo", file, "-HaloRenderTo", folder.path])
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        var steps = ViewerDragSteps(halo: halo)

        // 1. New Composition… Loop, 24 fps, 2 s: the header and the sidebar read it.
        halo.click("New Composition…")
        let sheet = halo.app.sheets.firstMatch
        enter("Loop", into: "Name", in: sheet)
        enter("2", into: "Duration (seconds)", in: sheet)
        sheet.popUpButtons["Frame Rate"].click()
        halo.app.menuItems["24 fps"].click()
        halo.click("Create", in: .sheet)
        XCTAssert(header("1920 × 1080", halo).waitForExistence(timeout: 5), "the header doesn't read 1920 × 1080")
        XCTAssert(header("24 fps · 2 s", halo).exists, "the header doesn't read 24 fps · 2 s")
        XCTAssert(Self.contains("Loop", in: halo.element("suite.sidebar")).exists, "the sidebar has no Loop row")
        halo.shot("loop-new")

        // 2. Layer > New > Solid: the first row is Solid 1, drawn on the canvas.
        choose(["Layer", "New", "Solid"], halo)
        XCTAssert(layerRow("Solid 1", halo).waitForExistence(timeout: 5), "no Solid 1 row in the layer list")
        expectLabel("halo.viewer.drawn", "1 layer drawn", halo)
        halo.shot("loop-solid")

        // 3. The Position X stopwatch keys frame 0.
        let stopwatch = halo.element("halo.inspector.key.x")
        scrollInspector(toShow: stopwatch, halo)
        stopwatch.click()
        steps.expectKeyState("Position X", "Keyed at this frame")
        steps.expectEditItem("Undo Animate Position X")
        halo.shot("loop-stopwatch")

        // 4. Scrub the ruler, then → or ← from the timeline to frame 24 (00:00:01:00).
        halo.drag(on: "halo.timeline", from: CGVector(dx: 0.02, dy: 0.05), to: CGVector(dx: 0.5, dy: 0.05))
        steps.focusLane("Solid 1")
        let frame = viewerFrame(halo) ?? 0
        for _ in 0..<abs(24 - frame) { halo.press(frame < 24 ? .rightArrow : .leftArrow) }
        steps.expectPlayhead("00:00:01:00")
        halo.shot("loop-frame-24")

        // 5. Drag the solid 300 px right from its centre: a key at 24.
        let (x, y) = (steps.pixels("x"), steps.pixels("y"))
        steps.drag(from: (x, y), by: (300, 0))
        let tolerance = steps.tolerance()
        XCTAssertEqual(steps.pixels("x"), x + 300, accuracy: tolerance, "Position X after a 300 px drag (±\(tolerance) px)")
        steps.expectKeyState("Position X", "Keyed at this frame")
        steps.expectEditItem("Undo Move")
        halo.shot("loop-dragged")

        // 6. Pick the 0–24 span in EASING and give it Ease Out.
        let span = halo.element("halo.easing.key.x.0")
        scrollInspector(toShow: span, halo)
        span.click()
        chip("Ease Out", halo).click()
        expectRow("halo.easing.key.x.0", reads: "Ease Out", halo)
        expectUndo("Undo Keyframe Easing", halo)
        halo.shot("loop-ease-out")

        // 7. From the start, Play for a second and pause: the playhead stops inside the loop; Space twice too.
        choose(["Animation", "Go to Start"], halo)
        let play = halo.element("halo.transport.play")
        XCTAssert(play.waitForExistence(timeout: 5), "no Play button (halo.transport.play)")
        play.click()
        expectPlay("Playing", halo)
        Thread.sleep(forTimeInterval: 1)
        play.click()
        expectPlay("Paused", halo)
        let paused = viewerFrame(halo) ?? 0
        XCTAssert((1...47).contains(paused), "Play then pause stopped at frame \(paused), not 1…47")
        steps.focusLane("Solid 1")
        halo.press(.space)
        Thread.sleep(forTimeInterval: 0.5)
        halo.press(.space)
        expectPlay("Paused", halo)
        halo.shot("loop-paused")

        // 8. Layer > New > Text, Hello and Return: the artboard draws it on top.
        choose(["Layer", "New", "Text"], halo)
        let words = halo.element("halo.inspector.text.string")
        scrollInspector(toShow: words, halo)
        words.click()
        halo.press(character: "a", .command)
        words.typeText("Hello")
        halo.press(.return)
        expectSummary(endingWith: "Solid 1, Text 1: Hello", halo)
        expectUndo("Undo Edit Text", halo)
        halo.shot("loop-text")

        // 9. Edit > Undo, then Edit > Redo, by menu: the titles flip and Hello is back.
        choose(["Edit", "Undo Edit Text"], halo)
        expectUndo("Undo New Layer", halo)
        choose(["Edit", "Redo Edit Text"], halo)
        expectUndo("Undo Edit Text", halo)
        expectSummary(endingWith: "Text 1: Hello", halo)
        halo.shot("loop-undo-redo")

        // 10. Render… PNG Sequence at Half: 48 files, Loop_0001.png … Loop_0048.png, each 960 × 540.
        choose(["File", "Render…"], halo)
        tap("halo.render.format.pngSequence", halo)
        tap("halo.render.size.half", halo)
        expectLabel("halo.render.summary", "48 PNG files, 960 × 540, into a new folder \"Loop\"", halo)
        let start = halo.element("halo.render.start")
        XCTAssert(waitFor(seconds: 5) { start.isEnabled }, "the start button is disabled with -HaloRenderTo set")
        start.click()
        // "Exported Loop" until #3402 retitles the finished line "Rendered 48 frames.".
        XCTAssert(Self.contains("Exported Loop", in: halo.app).waitForExistence(timeout: 60), "the render never finished")
        let pngs = folder.appending(path: "Loop", directoryHint: .isDirectory)
        let names = try FileManager.default.contentsOfDirectory(atPath: pngs.path).sorted()
        XCTAssertEqual(names, (1...48).map { String(format: "Loop_%04d.png", $0) }, "the files in \(pngs.path)")
        for name in names {
            let size = pixelSize(of: pngs.appending(path: name))
            XCTAssert(size?.width == 960 && size?.height == 540, "\(name) is \(String(describing: size)), not 960 × 540")
        }
        tap("halo.render.dismiss", halo)
        XCTAssert(waitFor(seconds: 5) { !start.exists }, "the Render sheet stayed open after Done")
        halo.shot("loop-rendered")

        // 11. File > Save by menu, ⌘S as parity: titled Loop, Saved, on disk.
        choose(["File", "Save"], halo)
        XCTAssert(waitFor(seconds: 5) { halo.app.windows.firstMatch.title == "Loop" }, "the window isn't titled Loop")
        expectLabel("halo.file", "Saved", halo)
        halo.press(character: "s", .command)
        expectLabel("halo.file", "Saved", halo)
        XCTAssert(FileManager.default.fileExists(atPath: file), "Save wrote no \(file)")
        halo.shot("loop-saved")

        // 12. Quit and reopen Loop.halo: two layers, Ease Out then Linear, Hello at 0, nothing to undo.
        halo.press(character: "q", .command)
        if !halo.app.wait(for: .notRunning, timeout: 15) { halo.app.terminate() }
        halo = launch(["-HaloOpenFile", file])
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened on Loop.halo")
        steps = ViewerDragSteps(halo: halo)
        let rows = halo.element("halo.layer.list").descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "halo.layer.row."))
        XCTAssert(waitFor(seconds: 10) { Set(rows.allElementsBoundByIndex.map(\.identifier)).count == 2 }, "Loop reopened without two layers")
        let solid = layerRow("Solid 1", halo)
        scrollInspector(toShow: solid, halo)
        solid.click()
        let first = halo.element("halo.easing.key.x.0")
        scrollInspector(toShow: first, halo)
        XCTAssertEqual(first.label, "Position X, frames 0–24", "the first EASING row's title")
        expectRow("halo.easing.key.x.0", reads: "Ease Out", halo)
        // The stopwatch also keyed the last frame, so the second span is 24–47.
        XCTAssertEqual(halo.element("halo.easing.key.x.24").label, "Position X, frames 24–47", "the second EASING row's title")
        expectRow("halo.easing.key.x.24", reads: "Linear", halo)
        choose(["Animation", "Go to Start"], halo)
        expectLabel("halo.viewer.summary", "Frame 0: Solid 1, Text 1: Hello", halo)
        let undo = menuItem(["Edit", "Undo"], halo)
        XCTAssertFalse(undo.isEnabled, "Edit > Undo is enabled after an open")
        halo.press(.escape)
        XCTAssert(halo.menusClosed(), "the Edit menu stayed open")
        halo.shot("loop-reopened")
    }

    // MARK: - H-J12 helpers (copied from H-J7, H-J10, H-J11 and H-J21)

    /// Opens the menu bar item `path[0]`, hovers each submenu on the way and
    /// returns the last item (the menu stays open).
    @MainActor private func menuItem(_ path: [String], _ halo: Journey) -> XCUIElement {
        var item = halo.app.menuBars.firstMatch.menuBarItems[path.first ?? ""]
        XCTAssert(item.waitForExistence(timeout: 5), "no \(path.first ?? "") menu")
        item.click()
        for (depth, title) in path.dropFirst().enumerated() {
            if depth > 0 { item.hover() }
            item = item.menus.firstMatch.children(matching: .menuItem)[title]
            XCTAssert(item.waitForExistence(timeout: 3), "no \(path.joined(separator: " > "))")
        }
        return item
    }

    /// Clicks the enabled menu item at `path`.
    @MainActor private func choose(_ path: [String], _ halo: Journey) {
        let item = menuItem(path, halo)
        XCTAssert(item.isEnabled, "\(path.joined(separator: " > ")) is disabled")
        item.click()
    }

    /// The Edit menu's first item reads `title`; the menu is closed again.
    @MainActor private func expectUndo(_ title: String, _ halo: Journey) {
        let first = menuItem(["Edit"], halo).menus.firstMatch.children(matching: .menuItem).firstMatch
        XCTAssert(first.waitForExistence(timeout: 3), "the Edit menu shows no items")
        XCTAssertEqual(first.title, title, "the Edit menu's first item")
        halo.press(.escape)
        XCTAssert(halo.menusClosed(), "a menu stayed open after Escape")
    }

    /// Clicks the element `id` once it shows.
    @MainActor private func tap(_ id: String, _ halo: Journey) {
        let element = halo.element(id)
        XCTAssert(element.waitForExistence(timeout: 5), "no \(id)")
        element.click()
    }

    /// The layer list's row labelled `name` (`halo.layer.row.<id>`).
    @MainActor private func layerRow(_ name: String, _ halo: Journey) -> XCUIElement {
        halo.element("halo.layer.list").descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'halo.layer.row.' AND label == %@", name)).firstMatch
    }

    /// The element `id`'s label reads `label` within five seconds (values read empty, #262).
    @MainActor private func expectLabel(_ id: String, _ label: String, _ halo: Journey) {
        let element = halo.element(id)
        XCTAssert(waitFor(seconds: 5) { element.label == label }, "\(id) reads \(element.label), not \(label)")
    }

    /// The artboard summary ("Frame f: Solid 1, Text 1: Hello") ends with `tail`.
    @MainActor private func expectSummary(endingWith tail: String, _ halo: Journey) {
        let summary = halo.element("halo.viewer.summary")
        XCTAssert(waitFor(seconds: 5) { summary.label.hasSuffix(tail) }, "the artboard reads \(summary.label), not …\(tail)")
    }

    /// The frame the artboard summary names ("Frame 12: …" gives 12).
    @MainActor private func viewerFrame(_ halo: Journey) -> Int? {
        let label = halo.element("halo.viewer.summary").label
        guard label.hasPrefix("Frame ") else { return nil }
        return Int(label.dropFirst("Frame ".count).prefix { $0.isNumber })
    }

    /// `halo.transport.play` reads `state`; a value read empty (#262) passes
    /// when the playhead moves (Playing) or holds (Paused) over 0.3 s.
    @MainActor private func expectPlay(_ state: String, _ halo: Journey) {
        let play = halo.element("halo.transport.play")
        if waitFor(seconds: 3, { (play.value as? String) == state }) { return }
        let value = play.value as? String ?? ""
        XCTAssert(value.isEmpty, "halo.transport.play reads \(value), not \(state)")
        let before = viewerFrame(halo)
        Thread.sleep(forTimeInterval: 0.3)
        XCTAssertEqual(before != viewerFrame(halo), state == "Playing", "the playhead doesn't look \(state)")
    }

    /// The EASING chip titled `title`, scrolled whole into the inspector (the chips are lazy grids, #1411).
    @MainActor private func chip(_ title: String, _ halo: Journey) -> XCUIElement {
        let inspector = halo.element("suite.inspector"), curve = halo.element("halo.easing")
        XCTAssert(curve.waitForExistence(timeout: 5), "no easing curve (halo.easing) with a span picked")
        let chip = inspector.buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
        for _ in 0..<20 where !(chip.exists && inspector.frame.contains(chip.frame)) {
            inspector.scroll(byDeltaX: 0, deltaY: curve.frame.minY > inspector.frame.midY ? -40 : 40)
        }
        XCTAssert(chip.exists, "no \(title) chip in EASING")
        return chip
    }

    /// The EASING row `id` reads `easing` as its value, or holds a text reading it (#262).
    @MainActor private func expectRow(_ id: String, reads easing: String, _ halo: Journey) {
        let row = halo.element(id)
        XCTAssert(
            waitFor(seconds: 5) { (row.value as? String) == easing || Self.contains(easing, in: row).exists },
            "\(id) reads \(String(describing: row.value)), not \(easing)")
    }

    /// Scrolls the inspector (`suite.inspector`) until `element` lies whole inside it.
    @MainActor private func scrollInspector(toShow element: XCUIElement, _ halo: Journey) {
        let inspector = halo.element("suite.inspector")
        XCTAssert(element.waitForExistence(timeout: 5), "nothing to scroll to in the inspector")
        for _ in 0..<20 where !inspector.frame.contains(element.frame) {
            inspector.scroll(byDeltaX: 0, deltaY: element.frame.minY < inspector.frame.minY ? 40 : -40)
        }
        XCTAssert(inspector.frame.contains(element.frame), "\(element.frame) didn't scroll into \(inspector.frame)")
    }

    /// The pixel size of the PNG at `url`, decoded with ImageIO; nil when it doesn't decode.
    private func pixelSize(of url: URL) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        return (image.width, image.height)
    }

    /// Whether `condition` holds within `seconds`.
    @MainActor private func waitFor(seconds: Int = 3, _ condition: () -> Bool) -> Bool {
        for _ in 0..<(seconds * 5) {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
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
        ("Window", ["Switch To", "AI Access…"]),
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
    /// rows, but the timeline strip's own parts (SuiteUI's, which act through
    /// the timeline): what takes `halo.timeline.track` from the strip, and
    /// its track names, lanes and keys.
    @MainActor private func onScreenControlIDs(_ halo: Journey) -> Set<String> {
        let window = halo.app.windows.firstMatch
        let types: [XCUIElement.ElementType] = [.button, .popUpButton, .textField, .checkBox, .slider, .cell]
        // Generated per track and key from the strip's `halo.timeline` prefix, not controls.
        let generated = ["halo.timeline.name.", "halo.timeline.lane.", "halo.timeline.key."]
        var ids = Set<String>()
        for type in types {
            let query = window.descendants(matching: type).matching(NSPredicate(format: "identifier BEGINSWITH 'halo.'"))
            for element in query.allElementsBoundByIndex where element.identifier != "halo.timeline.track" {
                let id = element.identifier
                if !generated.contains(where: { id.hasPrefix($0) }) { ids.insert(id) }
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

/// A timeline track's parts by their SuiteUI identifiers under Halo's
/// `halo.timeline` prefix (TimelineStrip, TimelineLaneAccess): the name
/// button `halo.timeline.name.<id>` and the lane `halo.timeline.lane.<id>`,
/// each labelled with the track's name.
extension Journey {
    /// The name button of the track `name`; a click selects its layer and focuses the timeline.
    func trackName(_ name: String) -> XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'halo.timeline.name.' AND label == %@", name)).firstMatch
    }

    /// The lane of the track `name`.
    func trackLane(_ name: String) -> XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'halo.timeline.lane.' AND label == %@", name)).firstMatch
    }
}

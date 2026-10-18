// SuiteJourneyTests+ChromePanels.swift: SJ5 to SJ8 and SP9, EC-b (editor-chrome
// packet, Journey steps 2 to 6), on the gallery's `editor` and `empty` pages.
// SJ5 plays, steps and loops the TransportCapsule (`suite.transport.<id>`),
// reads its timecode (`suite.transport.timecode`) and, since XCUITest reads no
// tooltip, the timecode's tooltip from the page's hidden
// `suite.gallery.editor.timecode-help` readout; the `frameCount` 0 switch
// disables every button with "Nothing to play." (`suite.controls` reasons).
// SJ6 reads the status bar's zoom and size pills, presses the Onion toggle pill
// on and off and finds the warning pill's triangle. SJ7 presses the empty
// state's one primary button and finds no button in the variant without an
// action. SJ8 clicks Layers, then ← back to Adjust. SP9 makes 60 presses over
// the tools, tabs and transport and reports series `press`, report-only. Each
// change is read from the `suite.gallery.log` element, one line per change.
import XCTest

extension SuiteJourneyTests {
    /// The transport buttons, in the capsule's order.
    private static let panelTransportIDs = ["start", "back", "play", "forward", "end", "loop"].map { "suite.transport.\($0)" }

    /// SJ5: Play ↔ Pause, two steps, the end clamps with loop off and wraps with loop on, seconds:frames, nothing to play.
    @MainActor func testTransportPlaysStepsAndLoops() throws {
        let gallery = openPanelPage("editor")
        let log = gallery.element("suite.gallery.log")
        let play = panelElement("suite.transport.play", gallery)
        let timecode = panelElement("suite.transport.timecode", gallery)
        XCTAssertEqual(play.label, "Play", "the play button doesn't read Play before playing")
        XCTAssertEqual(timecode.label, "00:12 / 02:00", "frame 12 of 48 at 24 fps isn't seconds:frames")
        let help = panelElement("suite.gallery.editor.timecode-help", gallery)
        XCTAssert(help.label.contains("Seconds:frames"), "the timecode's tooltip doesn't say seconds:frames: \(help.label)")
        // 1. Play, then Pause: the label swaps and the log says so.
        play.click()
        expectPanelLog("play on", log)
        XCTAssert(panelWait { play.label == "Pause" }, "the play button reads \(play.label), not Pause, while playing")
        play.click()
        expectPanelLog("play off", log)
        XCTAssert(panelWait { play.label == "Play" }, "the play button reads \(play.label), not Play, after Pause")
        // 2. Two steps from frame 12.
        let forward = panelElement("suite.transport.forward", gallery)
        forward.click()
        forward.click()
        expectPanelLog("frame 14", log)
        gallery.shot("editor-transport-stepped")
        // 3. At the end with loop off a step stays on the last frame.
        panelElement("suite.transport.end", gallery).click()
        expectPanelLog("frame 47", log)
        forward.click()
        XCTAssert(panelWait { self.panelLines(log).suffix(2) == ["frame 47", "frame 47"] },
                  "a step past the end with loop off didn't stay on 47: \(panelLines(log).suffix(3))")
        XCTAssertEqual(timecode.label, "01:23 / 02:00", "the last frame's timecode")
        // 4. Loop on: the same step wraps to frame 0.
        panelElement("suite.transport.loop", gallery).click()
        expectPanelLog("loop on", log)
        forward.click()
        expectPanelLog("frame 0", log)
        XCTAssert(panelWait { timecode.label == "00:00 / 02:00" }, "the wrapped timecode reads \(timecode.label)")
        gallery.shot("editor-transport-wrapped")
        // 5. The frameCount 0 switch: every button disabled, each saying why.
        panelElement("suite.gallery.editor.no-frames", gallery).click()
        expectPanelLog("frames 0", log)
        for id in Self.panelTransportIDs {
            XCTAssert(panelWait { !self.panelElement(id, gallery).isEnabled }, "\(id) stays enabled with nothing to play")
        }
        var reasons: [String: String] = [:]
        _ = panelWait {
            let entries = gallery.controls()?.controls ?? []
            reasons = Dictionary(entries.map { ($0.id, $0.reason ?? "") }, uniquingKeysWith: { first, _ in first })
            return Self.panelTransportIDs.allSatisfy { reasons[$0] == "Nothing to play." }
        }
        for id in Self.panelTransportIDs {
            XCTAssertEqual(reasons[id], "Nothing to play.", "\(id)'s reason with frameCount 0")
        }
        gallery.shot("editor-transport-nothing")
    }

    /// SJ6: the zoom and size pills, the Onion toggle pill on and off, the warning pill's triangle and label.
    @MainActor func testStatusPills() throws {
        let gallery = openPanelPage("editor")
        let log = gallery.element("suite.gallery.log")
        // ViewerZoom.percentText(2) is "200%"; the pill's label is "Zoom 200%".
        XCTAssert(gallery.app.staticTexts["Zoom 200%"].firstMatch.waitForExistence(timeout: 5), "no zoom pill reading 200%")
        XCTAssert(gallery.app.staticTexts["1920 × 1080"].firstMatch.exists, "no size pill reading 1920 × 1080")
        let onion = panelElement("suite.gallery.editor.onion", gallery)
        XCTAssertFalse(panelSelected(onion), "the Onion pill starts selected")
        onion.click()
        expectPanelLog("toggle onion", log)
        XCTAssert(panelWait { self.panelSelected(onion) }, "the Onion pill isn't selected after a press")
        gallery.shot("editor-pills-onion")
        onion.click()
        XCTAssert(panelWait { self.panelLines(log).suffix(2) == ["toggle onion", "toggle onion"] }, "the second press logged nothing")
        XCTAssert(panelWait { !self.panelSelected(onion) }, "the Onion pill stays selected after a second press")
        let warning = panelElement("suite.gallery.editor.warning-pill", gallery)
        XCTAssertEqual(warning.label.isEmpty ? warning.value as? String : warning.label, "Dropping frames", "the warning pill's label")
        // The triangle is the image just left of the label, on its line.
        let triangle = gallery.app.windows.firstMatch.images.allElementsBoundByIndex.first {
            abs($0.frame.midY - warning.frame.midY) < 8 && $0.frame.maxX <= warning.frame.minX + 1
                && warning.frame.minX - $0.frame.maxX < 16
        }
        XCTAssertNotNil(triangle, "the warning pill shows no triangle before its label")
        gallery.shot("editor-pills-warning")
        panelElement("suite.gallery.editor.warning", gallery).click()
        expectPanelLog("warning off", log)
        XCTAssert(panelWait { !warning.exists }, "the warning pill stays with its switch off")
    }

    /// SJ7: the empty state's title, message and one primary button, which acts; the variant without an action has none.
    @MainActor func testEmptyStateOffersAction() throws {
        let gallery = openPanelPage("empty")
        let offered = panelElement("suite.gallery.empty.action", gallery)
        XCTAssert(offered.staticTexts["No Document"].firstMatch.exists, "the empty state has no title")
        XCTAssert(offered.staticTexts["Create a document to start drawing."].firstMatch.exists, "the empty state has no message")
        XCTAssertEqual(offered.buttons.count, 1, "the empty state offers \(offered.buttons.count) buttons, not one")
        var primaries: [ControlEntry] = []
        _ = panelWait {
            primaries = (gallery.controls()?.controls ?? []).filter { $0.role == "primary" }
            return primaries.count == 1
        }
        XCTAssertEqual(primaries.map(\.id), ["suite.gallery.empty.new"], "suite.controls lists these primary actions")
        panelElement("suite.gallery.empty.new", gallery).click()
        expectPanelLog("action new", gallery.element("suite.gallery.log"))
        let plain = panelElement("suite.gallery.empty.plain", gallery)
        XCTAssert(plain.staticTexts["Nothing Selected"].firstMatch.exists, "the variant without an action has no title")
        XCTAssertEqual(plain.buttons.count, 0, "the variant without an action draws a button")
        gallery.shot("empty-acted")
    }

    /// SJ8: Layers is picked by a click, then ← picks Adjust; the selected tab reads selected.
    @MainActor func testSegmentedTabsSwitch() throws {
        let gallery = openPanelPage("editor")
        let log = gallery.element("suite.gallery.log")
        let layers = panelTab("Layers", gallery)
        layers.click()
        expectPanelLog("tab layers", log)
        XCTAssert(panelWait { self.panelSelected(layers) }, "Layers isn't selected after a click")
        gallery.shot("editor-tabs-layers")
        gallery.press(.leftArrow)
        expectPanelLog("tab adjust", log)
        let adjust = panelTab("Adjust", gallery)
        XCTAssert(panelWait { self.panelSelected(adjust) && !self.panelSelected(layers) }, "← didn't move the selection to Adjust")
        gallery.shot("editor-tabs-adjust")
    }

    /// SP9: 60 presses over the tools, the tabs and the transport, series `press`; report-only (QB-S8).
    @MainActor func testPressLatency() throws {
        let gallery = openPanelPage("editor")
        let log = gallery.element("suite.gallery.log")
        let targets: [XCUIElement] = [
            panelElement("suite.gallery.editor.tool.b", gallery), panelElement("suite.gallery.editor.tool.a", gallery),
            panelTab("Layers", gallery), panelTab("Adjust", gallery),
            panelElement("suite.transport.forward", gallery), panelElement("suite.transport.back", gallery),
        ]
        for press in 0..<60 {
            targets[press % targets.count].click()
        }
        XCTAssert(panelWait { self.panelLines(log).last == "frame 12" }, "the last press, Previous Frame, logged \(panelLines(log).last ?? "nothing")")
        gallery.shot("editor-press-perf")
        if let document = gallery.perf() { gallery.expectValid(document, series: "press") }
    }

    /// Launches the gallery on `page` with the probes on, and waits for its root.
    @MainActor private func openPanelPage(_ page: String) -> Journey {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", page, "-SuitePerfProbe"])
        XCTAssert(gallery.element("suite.gallery.\(page)").waitForExistence(timeout: 30), "no gallery page \(page)")
        return gallery
    }

    /// The element `id`, failing when it doesn't come within five seconds.
    @MainActor private func panelElement(_ id: String, _ gallery: Journey) -> XCUIElement {
        let element = gallery.element(id)
        XCTAssert(element.waitForExistence(timeout: 5), "no \(id) on the page")
        return element
    }

    /// The segment titled `title` of the editor page's tabs (`suite.gallery.editor.tabs`).
    @MainActor private func panelTab(_ title: String, _ gallery: Journey) -> XCUIElement {
        let tabs = panelElement("suite.gallery.editor.tabs", gallery)
        let segment = tabs.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@ OR title == %@", title, title)).firstMatch
        XCTAssert(segment.waitForExistence(timeout: 5), "the tabs have no \(title) segment")
        return segment
    }

    /// Whether `element` reads selected: its own trait, a radio segment's value of 1, or a selected child.
    @MainActor private func panelSelected(_ element: XCUIElement) -> Bool {
        if element.isSelected || (element.value as? NSNumber)?.intValue == 1 { return true }
        return element.descendants(matching: .any).matching(NSPredicate(format: "selected == true")).count > 0
    }

    @MainActor private func expectPanelLog(_ line: String, _ log: XCUIElement) {
        XCTAssert(panelWait { self.panelLines(log).last == line }, "the log's last line reads \(panelLines(log).last ?? "nothing"), not \(line)")
    }

    /// The log's lines: its value when it has one, else its label.
    @MainActor private func panelLines(_ log: XCUIElement) -> [String] {
        let value = log.value as? String ?? ""
        return (value.isEmpty ? log.label : value).split(separator: "\n").map(String.init)
    }

    /// Whether `condition` holds within about three seconds.
    @MainActor private func panelWait(_ condition: () -> Bool) -> Bool {
        (0..<15).contains { _ in condition() || { Thread.sleep(forTimeInterval: 0.2); return false }() } || condition()
    }
}

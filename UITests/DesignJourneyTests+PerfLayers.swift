// DesignJourneyTests+PerfLayers.swift: layers-panel's perf journey P3
// (docs/blueprints/design/features/layers-panel.md, Journey steps item 2;
// blueprint design section 4, P3, and 7.1, QD-S10). On `crowd` (40 frames of
// 49 layers each, 2,000 layers) at 1024 × 768 it expands every frame's row in
// Layers, then scrolls the list end to end: down until Frame 1's last row
// (Rectangle 1, `design.layer.node-2`) shows, and back up until Frame 40's row
// (`design.layer.node-1951`) does. Frames are expanded bottom up from the
// keyboard: select Frame 1's row, Right Arrow opens it, Up Arrow moves to the
// frame above, which opening a lower row never shifts.
// Report-only (QB-L10; docs/review-rubric.md, How gates are set): the scroll
// times each scroll call's round trip, which needs the app's main thread to
// answer, as a coarse sign of a stall, and adds `suite.perf`'s frame intervals
// when Design's window publishes them (SuiteUI's FrameProbe, #330 and #333).
// The numbers go to .build/ui-screens/perf-design-layers.json and attach as
// "perf-design-layers"; the test asserts only that every row was reached.
// Written before its fixture (lead.md, contract rule 13): `-DesignFixture
// crowd` arrives with design-window (D0-5a), so it is skipped by name until then.
// Frame N's id is node-(50N - 49) and its Text is node-(50N) (DesignFixtures.crowd).
import XCTest

final class DesignPerfLayersJourneyTests: XCTestCase {
    static let arguments = ["-DesignFixture", "crowd", "-SuiteWindowSize", "1024x768", "-SuitePerfProbe"]
    /// `crowd`'s frames, Frame 1 (painted first, so listed last) to Frame 40.
    static let frames = (1...40).map { "design.layer.node-\(50 * $0 - 49)" }
    /// The list's first and last rows with every frame expanded.
    static let topRow = "design.layer.node-1951"
    static let bottomRow = "design.layer.node-2"
    /// A scroll round trip over this many milliseconds counts as a stall (about six 60 Hz refreshes).
    static let stallMilliseconds = 100.0

    /// P3: every frame expanded, scroll Layers to the end and back; report the scroll's timing.
    @MainActor func testLayerListScroll() throws {
        throw XCTSkip("waits on design-window D0-5a")
        let design = Journey("Design", self, arguments: Self.arguments)
        XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(design.element("suite.canvas").waitForExistence(timeout: 10), "crowd showed no page (suite.canvas)")
        let layers = design.element("design.layers")
        XCTAssert(layers.waitForExistence(timeout: 10), "no Layers list (design.layers)")
        expandEveryFrame(design, layers)
        design.shot("perf-layers-expanded")

        let down = scroll(layers, until: row(design, Self.bottomRow), by: -120)
        design.shot("perf-layers-bottom")
        let up = scroll(layers, until: row(design, Self.topRow), by: 120)
        design.shot("perf-layers-top")
        report(down: down, up: up, perf: design.element("suite.perf"))
    }

    // MARK: - Steps

    /// Opens all 40 frames' rows, Frame 1 first, from the keyboard.
    @MainActor private func expandEveryFrame(_ design: Journey, _ layers: XCUIElement) {
        let first = row(design, Self.frames[0])
        _ = scroll(layers, until: first, by: -120)
        first.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        for (index, frame) in Self.frames.enumerated() {
            if index > 0 { design.press(.upArrow) }
            design.press(.rightArrow)
            let text = row(design, "design.layer.node-\(50 * (index + 1))")
            XCTAssert(text.waitForExistence(timeout: 5), "Right Arrow didn't open \(frame): its Text row never showed")
        }
    }

    /// Scrolls `list` by `delta` until `target` is hittable, at most 200 times; the round trip of each call.
    @MainActor private func scroll(_ list: XCUIElement, until target: XCUIElement, by delta: CGFloat) -> [Double] {
        var trips: [Double] = []
        while !(target.exists && target.isHittable), trips.count < 200 {
            let started = Date()
            list.scroll(byDeltaX: 0, deltaY: delta)
            trips.append(Date().timeIntervalSince(started) * 1000)
        }
        XCTAssert(target.exists && target.isHittable, "\(trips.count) scrolls didn't reach \(target.identifier)")
        return trips
    }

    @MainActor private func row(_ design: Journey, _ identifier: String) -> XCUIElement {
        design.element("design.layers").descendants(matching: .any)[identifier].firstMatch
    }

    /// Writes the report-only numbers to .build/ui-screens/perf-design-layers.json and attaches them.
    @MainActor private func report(down: [Double], up: [Double], perf: XCUIElement) {
        var numbers: [String: String] = [
            "QD-S10 P3 scroll-down": summary(down),
            "QD-S10 P3 scroll-up": summary(up),
        ]
        if perf.exists, let document = try? JSONDecoder().decode(ProbeDocument.self, from: Data(perf.label.utf8)) {
            for (series, intervals) in document.intervals {
                numbers["QB-L10 \(series)"] = "p95 \(intervals.p95Refreshes) refreshes (gate 1.5, report-only)"
            }
        } else {
            numbers["QB-L10"] = "no suite.perf frame intervals: Design's window doesn't publish FrameProbe yet (#330, #333)"
        }
        for (key, value) in numbers.sorted(by: { $0.key < $1.key }) { print("\(key): \(value)") }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let json = try? encoder.encode(numbers) else { return }
        // This file is UITests/DesignJourneyTests+PerfLayers.swift, so its grandparent is the repo root.
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let folder = root.appending(path: ".build/ui-screens")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? json.write(to: folder.appending(path: "perf-design-layers.json"))
        let attachment = XCTAttachment(data: json, uniformTypeIdentifier: "public.json")
        attachment.name = "perf-design-layers"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// "scrolls=n median-ms=m longest-ms=l over-100ms=s report-only".
    private func summary(_ trips: [Double]) -> String {
        let sorted = trips.sorted()
        let median = sorted.isEmpty ? 0 : sorted[sorted.count / 2]
        let stalls = trips.filter { $0 > Self.stallMilliseconds }.count
        return "scrolls=\(trips.count) median-ms=\(String(format: "%.0f", median)) "
            + "longest-ms=\(String(format: "%.0f", sorted.last ?? 0)) over-\(Int(Self.stallMilliseconds))ms=\(stalls) report-only"
    }
}

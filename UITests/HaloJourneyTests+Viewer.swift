// HaloJourneyTests+Viewer.swift: H-J2, layers draw at the playhead
// (viewer-playback VP-12, #37; docs/blueprints/halo/features/viewer-playback.md,
// Journey steps). On `-HaloSample three-layers` (Title 24–71, Badge,
// Background and the Rig null, top first, 24 fps, 72 frames, live services)
// it clicks Badge's lane, which selects Badge and focuses the timeline so
// HaloViewer takes Home and → (as H-J3 does), scrubs to 12 and to 30, then
// adds Layer > New > Solid. The artboard (`halo.viewer`) reads the Model's
// viewerSummary, bottom layer first, and the canvas inside it
// (`halo.viewer.canvas`) its draw list's drawnSummary, which proves the
// live drawing rather than the layer list: 2, 3, then 4 layers drawn (the
// null draws nothing). A new layer goes on top, so the list's first row is
// Solid 1. One shot per step, `halo-viewer-<step>`.
import XCTest

final class HaloViewerJourneyTests: XCTestCase {
    /// H-J2: the artboard and its canvas follow the playhead and a new layer.
    @MainActor func testLayersDrawAtThePlayhead() {
        let halo = Journey("Halo", self, arguments: ["-HaloSample", "three-layers", "-HaloWindowSize", "1000x640"])
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(halo.element("halo.viewer").waitForExistence(timeout: 10), "no artboard (halo.viewer)")
        focusTimeline(halo)

        // 1. Scrub to 12: Title starts at 24, so only Background and Badge draw.
        halo.press(.home)
        step(12, halo)
        expectArtboard("Frame 12: Background, Badge", halo)
        expectCanvas("2 layers drawn", halo)
        halo.shot("viewer-frame-12")

        // 2. Scrub to 30: Title is in.
        step(18, halo)
        expectArtboard("Frame 30: Background, Badge, Title: Hello Halo", halo)
        expectCanvas("3 layers drawn", halo)
        halo.shot("viewer-frame-30")

        // 3. Layer > New > Solid: Solid 1 on top, drawn last.
        choose(["Layer", "New", "Solid"], halo)
        expectArtboard("Frame 30: Background, Badge, Title: Hello Halo, Solid 1", halo)
        expectCanvas("4 layers drawn", halo)
        XCTAssert(
            waitFor { self.firstRowLabel(halo).contains("Solid 1") },
            "the layer list's first row reads \(firstRowLabel(halo)), not Solid 1")
        halo.shot("viewer-solid-on-top")
    }

    // MARK: - Helpers

    /// Clicks Badge's lane: it selects Badge and focuses the timeline, so
    /// HaloViewer's keys (Home, →) reach the Model.
    @MainActor private func focusTimeline(_ halo: Journey) {
        let lane = halo.app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == 'halo.timeline.track' AND label == 'Badge'")).firstMatch
        XCTAssert(lane.waitForExistence(timeout: 10), "no Badge lane in the timeline")
        lane.click()
    }

    /// Presses → `count` times.
    @MainActor private func step(_ count: Int, _ halo: Journey) {
        for _ in 0..<count { halo.press(.rightArrow) }
    }

    /// The artboard (`halo.viewer`) reads `summary` within five seconds.
    @MainActor private func expectArtboard(_ summary: String, _ halo: Journey) {
        expectValue(summary, of: "halo.viewer", what: "the artboard", halo)
    }

    /// The canvas (`halo.viewer.canvas`) reads `summary` within five seconds.
    @MainActor private func expectCanvas(_ summary: String, _ halo: Journey) {
        expectValue(summary, of: "halo.viewer.canvas", what: "the canvas", halo)
    }

    /// The element `identifier`'s accessibility value is `value`, within five seconds.
    @MainActor private func expectValue(_ value: String, of identifier: String, what: String, _ halo: Journey) {
        let match = halo.app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == %@ AND value == %@", identifier, value)).firstMatch
        XCTAssert(
            match.waitForExistence(timeout: 5),
            "\(what) reads \(String(describing: halo.element(identifier).value)), not \(value)")
    }

    /// The label (or value) of the layer list's top row; empty with no rows.
    @MainActor private func firstRowLabel(_ halo: Journey) -> String {
        let rows = halo.element("halo.layer.list").descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "halo.layer.row.")).allElementsBoundByIndex
        guard let top = rows.min(by: { $0.frame.minY < $1.frame.minY }) else { return "" }
        return top.label.isEmpty ? (top.value as? String ?? "") : top.label
    }

    /// Opens the menu bar item `path[0]`, hovers each submenu on the way and
    /// clicks the last item, which must be enabled.
    @MainActor private func choose(_ path: [String], _ halo: Journey) {
        var item = halo.app.menuBars.firstMatch.menuBarItems[path.first ?? ""]
        XCTAssert(item.waitForExistence(timeout: 5), "no \(path.first ?? "") menu")
        item.click()
        for (depth, title) in path.dropFirst().enumerated() {
            if depth > 0 { item.hover() }
            item = item.menus.firstMatch.children(matching: .menuItem)[title]
            XCTAssert(item.waitForExistence(timeout: 3), "no \(path.joined(separator: " > "))")
        }
        XCTAssert(item.isEnabled, "\(path.joined(separator: " > ")) is disabled")
        item.click()
        _ = halo.app.menus.firstMatch.waitForNonExistence(timeout: 2)
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

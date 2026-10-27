// HaloJourneyTests+LayerStyle.swift: HJ-Y1, a keyed outer glow (layer-styles HY-4 written, HY-7 turns it on;
// docs/blueprints/halo/features/layer-styles.md, Journey steps). The packet's `shapes` fixture doesn't exist, so it
// runs on `-HaloSample three-layers` with Badge (a shape, frames 0 to 71; Title starts at 24): Layer > Layer Style…,
// Outer Glow on (`suite.style.toggle.outerGlow`), Done (`halo.style.done`); LAYER STYLE shows Glow Size
// (`halo.inspector.row.glowSize`) with its stopwatch, "Animate Glow Size"; at frame 0 it types 0 and turns the
// stopwatch on, at frame 30 types 20: Badge's lane reads 3 keyframes (0, 30 and the stopwatch's last-frame key
// holding 0, Packet-Review 1 amendment 2). A click on the bar opens its field, as on
// TRANSFORM's rows (HaloJourneyTests+Inspector.swift). Steps 3 and 4 shoot the viewer at frames 15 and 30, and at 0
// (`halo.viewer.canvas`); the PNG render of frames 0 and 30 is RJ-H43's (HY-6). One shot per step,
// `layer-style-<step>`. Skipped until LS-9: HY-7 routes styles to the GPU view, whose draw throws until then.
import XCTest

final class HaloLayerStyleJourneyTests: XCTestCase {
    private static let badge = "comp-1-layer-3"

    @MainActor func testKeyedGlow() throws {
        throw XCTSkip("waits on LS-9") // LS-9 builds StyleRoute.draw: `walkTheKeyedGlow()` in place of this line.
    }

    /// Steps 1 to 4.
    @MainActor private func walkTheKeyedGlow() {
        let halo = Journey("Halo", self, arguments: ["-HaloSample", "three-layers", "-HaloWindowSize", "1280x820"])
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")

        // 1. Select Badge, Layer > Layer Style…, Outer Glow on, Done.
        let row = halo.element("halo.layer.row.\(Self.badge)")
        XCTAssert(row.waitForExistence(timeout: 10), "no Badge row (halo.layer.row.\(Self.badge))")
        row.click()
        let layer = halo.app.menuBars.firstMatch.menuBarItems["Layer"]
        layer.click()
        let item = layer.menus.firstMatch.children(matching: .menuItem)["Layer Style…"]
        XCTAssert(item.waitForExistence(timeout: 3) && item.isEnabled, "Layer > Layer Style… is off")
        item.click()
        let toggle = halo.element("suite.style.toggle.outerGlow")
        XCTAssert(toggle.waitForExistence(timeout: 5), "the style panel shows no Outer Glow switch")
        toggle.click()
        halo.shot("layer-style-1-glow-on")
        halo.element("halo.style.done").click()

        // 2. Glow Size has a stopwatch; 0 at frame 0, stopwatch on; 20 at frame 30: three keys (the stopwatch also keys
        // the last frame, holding 0).
        let size = halo.element("halo.inspector.row.glowSize")
        XCTAssert(size.waitForExistence(timeout: 5), "LAYER STYLE shows no Glow Size row")
        let stopwatch = halo.element("suite.inspector").buttons.matching(NSPredicate(format: "label == %@", "Animate Glow Size")).firstMatch
        XCTAssert(stopwatch.exists, "Glow Size has no stopwatch")
        goTo(frame: 0, halo)
        type("0", into: size, halo)
        stopwatch.click()
        XCTAssert(waitUntil { (stopwatch.value as? String) == "Keyed at this frame" }, "the stopwatch didn't key Glow Size at 0")
        goTo(frame: 30, halo)
        type("20", into: size, halo)
        XCTAssert(waitUntil { halo.laneKeys("Badge").contains("3 keyframes") }, "Badge's lane reads \(halo.laneKeys("Badge")), not 3 keyframes")
        halo.shot("layer-style-2-keys")

        // 3. Scrub back: the glow grows from nothing at 0 to 20 px at 30.
        let canvas = halo.element("halo.viewer.canvas")
        goTo(frame: 15, halo)
        halo.shot("layer-style-3-frame-15", element: canvas)
        goTo(frame: 30, halo)
        halo.shot("layer-style-3-frame-30", element: canvas)

        // 4. Frame 0 draws no glow.
        goTo(frame: 0, halo)
        halo.shot("layer-style-4-frame-0", element: canvas)
    }

    /// Focuses the timeline on Badge's title, then Home and → `frame` times.
    @MainActor private func goTo(frame: Int, _ halo: Journey) {
        let title = halo.trackName("Badge")
        XCTAssert(title.waitForExistence(timeout: 5), "no Badge track title in the timeline")
        title.click()
        halo.press(.home)
        for _ in 0..<frame { halo.press(.rightArrow) }
    }

    /// Clicks `bar` (opening its field), types `text` over it and presses Return.
    @MainActor private func type(_ text: String, into bar: XCUIElement, _ halo: Journey) {
        bar.click()
        let field = halo.element("suite.inspector").textFields.firstMatch
        XCTAssert(field.waitForExistence(timeout: 5), "clicking \(bar.identifier) opened no field")
        halo.press(character: "a", .command)
        field.typeText(text)
        halo.press(.return)
    }

    /// `condition` holds within three seconds.
    @MainActor private func waitUntil(_ condition: () -> Bool) -> Bool {
        for _ in 0..<15 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }
}

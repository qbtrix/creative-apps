// FlareJourneyTests+Select.swift: J5 (stage-edit SE-1) on `-FlareSample bounce`. The readout is the label of
// `flare.stage.selection` ("2 selected, scale 1.50 × 1.50, rotation 90°"); handles are SuiteUI's `suite.handles.*`.
import XCTest

final class FlareSelectJourneys: XCTestCase {
    private static let sceneWidth = 550.0

    @MainActor func testSelectMarqueeScaleRotate() {
        let flare = Journey("Flare", self, arguments: ["-FlareSample", "bounce"])
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let canvas = flare.element("suite.canvas")
        XCTAssert(canvas.waitForExistence(timeout: 10), "no stage (suite.canvas)")
        let readout = flare.element("flare.stage.selection")

        // 1. V, then click Ball at (80, 100): 1 selected. The first click on the empty stage gives it the keyboard.
        point(450, 60, on: canvas).click()
        flare.press(character: "v")
        point(80, 100, on: canvas).click()
        XCTAssertEqual(reading(readout).count, 1, "clicking Ball: \(readout.label)")
        flare.shot("select-1-ball")

        // 2. Shift-click Shadow at (275, 352): 2 selected.
        XCUIElement.perform(withKeyModifiers: .shift) { point(275, 352, on: canvas).click() }
        XCTAssertEqual(reading(readout, until: 2).count, 2, "Shift-clicking Shadow: \(readout.label)")
        flare.shot("select-2-shadow")

        // 3. Click the empty stage (only the locked Background there): nothing selected, no box.
        point(450, 60, on: canvas).click()
        XCTAssert(readout.waitForNonExistence(timeout: 5), "the empty click kept a selection: \(readout.label)")
        flare.shot("select-3-none")

        // 4. A marquee from (40, 60) to (330, 370) round Ball and Shadow: 2 selected.
        point(40, 60, on: canvas).press(forDuration: 0.1, thenDragTo: point(330, 370, on: canvas))
        XCTAssertEqual(reading(readout, until: 2).count, 2, "the marquee: \(readout.label)")
        flare.shot("select-4-marquee")

        // 5. Click Ball: 1 selected; drag the bottom-right handle out by half the box: scale 1.50.
        point(80, 100, on: canvas).click()
        XCTAssertEqual(reading(readout, until: 1).count, 1, "clicking Ball again: \(readout.label)")
        let box = readout.frame
        drag(handle("bottomRight", flare), by: CGVector(dx: box.width / 2, dy: box.height / 2), on: canvas)
        XCTAssert(waitFor { abs((reading(readout).scaleX ?? 0) - 1.5) <= 0.02 }, "the handle drag: \(readout.label)")
        XCTAssertEqual(reading(readout).scaleY ?? 0, 1.5, accuracy: 0.02, "scale y: \(readout.label)")
        flare.shot("select-5-scaled")

        // 6. Drag the rotate zone a quarter turn clockwise about the box centre: rotation 90°, one Undo Rotate.
        let turned = readout.frame, zone = handle("rotate", flare)
        let arm = turned.midY - zone.y
        drag(zone, by: CGVector(dx: turned.midX + arm - zone.x, dy: turned.midY - zone.y), on: canvas)
        XCTAssert(waitFor { abs((reading(readout).rotation ?? 0) - 90) <= 1 }, "the quarter turn: \(readout.label)")
        flare.shot("select-6-rotated")
        let menu = flare.app.menuBars.firstMatch.menuBarItems["Edit"]
        menu.click()
        XCTAssert(menu.menuItems["Undo Rotate"].waitForExistence(timeout: 3), "the Edit menu has no Undo Rotate")
        flare.shot("select-7-undo-rotate", screen: true)
        flare.press(.escape)
    }

    /// The readout's count, scale and rotation, parsed from its label; nil for one it doesn't show or reads "mixed".
    @MainActor private func reading(_ readout: XCUIElement, until count: Int? = nil)
        -> (count: Int?, scaleX: Double?, scaleY: Double?, rotation: Double?)
    {
        if let count { _ = waitFor { readout.exists && readout.label.hasPrefix("\(count) selected") } }
        guard readout.waitForExistence(timeout: 5) else { return (nil, nil, nil, nil) }
        let parts = readout.label.components(separatedBy: ", ")
        func part(_ prefix: String) -> String? {
            parts.first { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
        }
        let scale = part("scale ")?.components(separatedBy: " × ") ?? []
        return (Int(parts.first?.components(separatedBy: " ").first ?? ""), scale.first.flatMap { Double($0) },
                scale.dropFirst().first.flatMap { Double($0) },
                part("rotation ").flatMap { Double($0.replacingOccurrences(of: "°", with: "")) })
    }

    @MainActor private func handle(_ name: String, _ flare: Journey) -> CGPoint {
        let mark = flare.element("suite.handles.\(name)")
        XCTAssert(mark.waitForExistence(timeout: 5), "the box has no \(name) handle")
        return CGPoint(x: mark.frame.midX, y: mark.frame.midY)
    }

    @MainActor private func drag(_ start: CGPoint, by offset: CGVector, on canvas: XCUIElement) {
        let origin = canvas.coordinate(withNormalizedOffset: .zero)
        let from = origin.withOffset(CGVector(dx: start.x - canvas.frame.minX, dy: start.y - canvas.frame.minY))
        from.press(forDuration: 0.1, thenDragTo: from.withOffset(offset))
    }

    @MainActor private func point(_ x: Double, _ y: Double, on canvas: XCUIElement) -> XCUICoordinate {
        let scale = canvas.frame.width / Self.sceneWidth
        return canvas.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x * scale, dy: y * scale))
    }

    @MainActor private func waitFor(_ condition: () -> Bool) -> Bool {
        for _ in 0..<25 where !condition() { Thread.sleep(forTimeInterval: 0.2) }
        return condition()
    }
}

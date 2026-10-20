// FlareJourneyTests+FirstFiveMinutes.swift: Flare's "first five minutes"
// beta gate (Journey+FirstFive.swift has the rules). Three first-week tasks,
// one test each, as a new user does them with no help: make a new animation
// and draw a shape, animate it (Auto-key, Go to End, drag the shape, play),
// export it as Lottie. Each starts from the empty window's New Animation on a
// fresh profile; -FlareExportTo stands in for the export folder panel. A test
// that fails on a missing or hidden entry point names its `finding` issue.
// Shots are `flare-first5-<step>`.
import XCTest

final class FlareFirstFiveJourneys: XCTestCase {
    /// New Animation, Create, then the Ellipse tool: a shape on the stage.
    @MainActor func testFirst5NewAnimationAndShape() {
        let flare = newAnimationWithShape([])
        flare.snap("first5-shape")
    }

    /// Auto-key, Go to End, drag the shape: its lane holds a key; Play plays.
    @MainActor func testFirst5AnimateShape() {
        let flare = newAnimationWithShape([])
        flare.reachable("Auto-key", stuck: Self.stuckAnimate).click()
        flare.reachable("Go to End", stuck: Self.stuckAnimate).click()
        flare.reachable("Select", in: flare.element("suite.tools")).click()
        flare.drag(on: "suite.canvas", from: CGVector(dx: 0.4, dy: 0.4), to: CGVector(dx: 0.7, dy: 0.4))
        // Keyed: the lane shows a key, or the inspector's X row its key diamond.
        let key = flare.element("flare.timeline").descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Key at frame'")).firstMatch
        let diamond = flare.element("flare.inspector.x.key.diamond")
        XCTAssert(FirstFive.wait(5) { key.exists || diamond.exists }, "moving the shape at the end keyed nothing \(Self.stuckAnimate)")
        flare.snap("first5-keyed")
        let play = flare.reachable("Play/Pause")
        play.click()
        XCTAssert(FirstFive.wait(3) { (play.value as? String) == "Playing" || play.isSelected }, "Play didn't play")
        play.click()
    }

    /// Export… in the toolbar, Lottie, Export: a Lottie JSON with the stage's size and a layer.
    @MainActor func testFirst5ExportLottie() throws {
        let exports = FirstFive.folder("flare-first5-exports")
        let flare = newAnimationWithShape(["-FlareExportTo", exports.path])
        flare.reachable("Export…").click()
        let lottie = flare.element("flare.export.format.lottie")
        XCTAssert(lottie.waitForExistence(timeout: 5), "the Export sheet offers no Lottie")
        lottie.click()
        flare.snap("first5-export-sheet")
        flare.reachable("Export", in: flare.app.sheets.firstMatch).click()
        let written = try XCTUnwrap(FirstFive.file(in: exports, ext: "json", timeout: 30), "Export wrote no Lottie file")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: written)) as? [String: Any]
        XCTAssert((json?["w"] as? Int ?? 0) > 0 && (json?["h"] as? Int ?? 0) > 0, "the Lottie has no size")
        XCTAssertFalse((json?["layers"] as? [Any] ?? []).isEmpty, "the Lottie has no layers")
    }

    /// Where a new user gets stuck, by finding issue.
    private static let stuckAnimate = "(first five minutes: finding #TBD)"

    /// Flare on a fresh profile: New Animation, Create, Ellipse drawn across the stage.
    @MainActor private func newAnimationWithShape(_ arguments: [String]) -> Journey {
        let flare = Journey("Flare", self, arguments: arguments + FirstFive.freshProfile())
        flare.timeBox()
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        flare.reachable("New Animation").click()
        flare.reachable("Create", in: flare.app.sheets.firstMatch).click()
        XCTAssert(flare.element("suite.canvas").waitForExistence(timeout: 10), "Create showed no stage")
        flare.reachable("Ellipse", in: flare.element("suite.tools")).click()
        flare.drag(on: "suite.canvas", from: CGVector(dx: 0.3, dy: 0.3), to: CGVector(dx: 0.5, dy: 0.5))
        let undo = flare.app.toolbars.firstMatch.buttons["flare.edit.undo"]
        XCTAssert(FirstFive.wait(5) { undo.isEnabled }, "drawing an ellipse added nothing to undo")
        return flare
    }
}

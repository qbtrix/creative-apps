// HaloJourneyTests+FirstFiveMinutes.swift: Halo's "first five minutes" beta
// gate (Journey+FirstFive.swift has the rules). Three first-week tasks, one
// test each, as a new user does them with no help: make a composition, add a
// title and fade it in (Animate Opacity, Go to End, drag Opacity), render a
// movie. Each starts from the empty viewer's New Composition… on a fresh
// profile; -HaloRenderTo stands in for the render folder panel. A test that
// fails on a missing or hidden entry point names its `finding` issue. Shots
// are `halo-first5-<step>`.
import XCTest

final class HaloFirstFiveJourneys: XCTestCase {
    /// New Composition…, Create: the inspector names the new composition.
    @MainActor func testFirst5NewComposition() {
        let halo = newComposition([])
        halo.snap("first5-composition")
    }

    /// Layer > New > Text, type a title, Animate Opacity, Go to End, drag Opacity: keyed twice.
    @MainActor func testFirst5TitleFadesIn() {
        let halo = newComposition([])
        addTitle(halo)
        let animate = halo.element("suite.inspector").buttons.matching(NSPredicate(format: "label == 'Animate Opacity'")).firstMatch
        scrollInspector(toShow: animate, halo)
        XCTAssert(animate.isHittable, "a new user can't find Animate Opacity \(Self.stuckAnimate)")
        animate.click()
        XCTAssert(FirstFive.wait(3) { (animate.value as? String) == "Keyed at this frame" }, "Animate Opacity keyed nothing")
        halo.choose(menu: ["Animation", "Go to End"])
        halo.drag(on: "halo.inspector.row.opacity", from: CGVector(dx: 0.8, dy: 0.5), to: CGVector(dx: 0.2, dy: 0.5))
        XCTAssert(FirstFive.wait(3) { (animate.value as? String) == "Keyed at this frame" },
                  "dragging Opacity at the end keyed nothing \(Self.stuckAnimate)")
        halo.snap("first5-faded")
    }

    /// File > Render…, Movie, Render: an MPEG-4 movie in the render folder.
    @MainActor func testFirst5RenderMovie() throws {
        let renders = FirstFive.folder("halo-first5-renders")
        let halo = newComposition(["-HaloRenderTo", renders.path])
        addTitle(halo)
        halo.choose(menu: ["File", "Render…"])
        segment("Movie", in: "halo.render.format", halo)
        segment("Half", in: "halo.render.size", halo)
        halo.snap("first5-render-sheet")
        halo.reachable("Render", in: halo.app.sheets.firstMatch).click()
        let written = try XCTUnwrap(FirstFive.file(in: renders, ext: "mp4", timeout: 240), "Render wrote no .mp4")
        let head = try Data(contentsOf: written).prefix(12)
        XCTAssertEqual(String(decoding: head.dropFirst(4).prefix(4), as: UTF8.self), "ftyp", "the movie isn't MPEG-4")
    }

    /// Where a new user gets stuck, by finding issue.
    private static let stuckAnimate = "(first five minutes: finding #TBD)"

    /// Halo on a fresh profile: New Composition… and Create with its defaults.
    @MainActor private func newComposition(_ arguments: [String]) -> Journey {
        let halo = Journey("Halo", self, arguments: arguments + FirstFive.freshProfile() + ["-HaloWindowSize", "1000x640"])
        halo.timeBox()
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        halo.reachable("New Composition…").click()
        halo.reachable("Create", in: halo.app.sheets.firstMatch).click()
        XCTAssert(halo.element("halo.inspector.header").waitForExistence(timeout: 5), "Create made no composition")
        return halo
    }

    /// Layer > New > Text, then the TEXT field reads a typed title.
    @MainActor private func addTitle(_ halo: Journey) {
        halo.choose(menu: ["Layer", "New", "Text"])
        let field = halo.element("halo.inspector.text.string")
        XCTAssert(field.waitForExistence(timeout: 10), "a new text layer shows no text field")
        scrollInspector(toShow: field, halo)
        field.doubleClick()
        field.typeText("Hello\r")
        XCTAssert(FirstFive.wait(5) { (field.value as? String) == "Hello" }, "the title reads \(String(describing: field.value))")
    }

    /// Clicks the segment titled `title` of the Render sheet's picker `id`.
    @MainActor private func segment(_ title: String, in id: String, _ halo: Journey) {
        let named = NSPredicate(format: "label == %@ OR title == %@", title, title)
        var choice = halo.element(id).descendants(matching: .any).matching(named).firstMatch
        if !choice.waitForExistence(timeout: 10) { choice = halo.app.sheets.firstMatch.radioButtons.matching(named).firstMatch }
        XCTAssert(choice.waitForExistence(timeout: 5), "the Render sheet offers no \(title)")
        choice.click()
    }

    /// Scrolls the inspector until `element` is inside it.
    @MainActor private func scrollInspector(toShow element: XCUIElement, _ halo: Journey) {
        let inspector = halo.element("suite.inspector")
        XCTAssert(element.waitForExistence(timeout: 5), "nothing to scroll to in the inspector")
        for _ in 0..<20 where !inspector.frame.contains(element.frame) {
            inspector.scroll(byDeltaX: 0, deltaY: element.frame.minY < inspector.frame.minY ? 40 : -40)
        }
    }
}

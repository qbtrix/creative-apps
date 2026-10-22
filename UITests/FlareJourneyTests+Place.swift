// FlareJourneyTests+Place.swift (svg-place PF-4 written, PF-7 turns it on; docs/blueprints/flare/features/svg-place.md,
// Journey steps): New; File > Place… (Shift-Command-P) picks two-groups.svg in the open panel by its path (Shift-
// Command-G): layers `red` and `blue` and "Placed two-groups.svg: 2 layers."; key blue's x; undo the keys, then both
// layers in one step. Step 5's PNG is covered by FlarePlaceMenuTests (the panel offers SVG only). Shots "place-".
import XCTest

final class FlarePlaceJourneyTests: XCTestCase {
    /// True until PF-7 turns the journey on.
    static let waitsOnPF7 = true

    @MainActor func testPlaceSVGArt() throws {
        if Self.waitsOnPF7 { throw XCTSkip("waits on PF-7") }
        let folder = FileManager.default.temporaryDirectory.appending(path: "flare-place-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let svg = folder.appending(path: "two-groups.svg")
        try Data(("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"240\" height=\"80\">"
            + "<g id=\"red\"><rect width=\"100\" height=\"80\" fill=\"#E53935\"/></g>"
            + "<g id=\"blue\"><rect x=\"140\" width=\"100\" height=\"80\" fill=\"#1E88E5\"/></g></svg>").utf8).write(to: svg)

        let flare = Journey("Flare", self) // 1.
        flare.press(character: "n", .command)
        XCTAssert(flare.element("suite.canvas").waitForExistence(timeout: 10), "New made no stage (suite.canvas)")
        flare.shot("place-new")

        place(svg, flare) // 2.
        let red = flare.app.staticTexts["red"], blue = flare.app.staticTexts["blue"]
        XCTAssert(red.waitForExistence(timeout: 10), "the layer list lists no red")
        XCTAssert(blue.waitForExistence(timeout: 5), "the layer list lists no blue")
        let report = "Placed two-groups.svg: 2 layers."
        XCTAssert(flare.app.staticTexts.matching(NSPredicate(format: "label == %@ OR value == %@", report, report))
            .firstMatch.waitForExistence(timeout: 5), "the status line doesn't report the place")
        flare.shot("place-placed")

        blue.click() // 3.
        flare.press(.home)
        flare.press(character: "k")
        for _ in 0..<24 { flare.press(.rightArrow) }
        flare.press(character: "k")
        flare.shot("place-keyed")

        for _ in 0..<3 { flare.press(character: "z", .command) } // 4.
        XCTAssert(waitFor { !red.exists && !blue.exists }, "Undo didn't take both placed layers in one step")
        XCTAssert(flare.app.buttons["Redo Place Image"].waitForExistence(timeout: 5), "Undo didn't undo a Place Image step")
        flare.shot("place-undone")
    }

    /// File > Place…, then the file at `url` chosen in the panel by its path.
    @MainActor private func place(_ url: URL, _ flare: Journey) {
        flare.press(character: "p", [.command, .shift])
        let panel = flare.app.sheets.firstMatch.exists ? flare.app.sheets.firstMatch : flare.app.dialogs.firstMatch
        XCTAssert(panel.waitForExistence(timeout: 10), "Place… opened no panel")
        flare.press(character: "g", [.command, .shift])
        flare.app.typeText(url.path)
        flare.press(.return)
        let button = panel.buttons.matching(NSPredicate(format: "label == 'Place' OR identifier == 'OKButton'")).firstMatch
        XCTAssert(waitFor { button.exists && button.isEnabled }, "the panel didn't pick \(url.lastPathComponent)")
        button.click()
        XCTAssert(waitFor { !panel.exists }, "the panel didn't close on Place")
    }

    /// Polls `condition` for up to five seconds.
    @MainActor private func waitFor(_ condition: () -> Bool) -> Bool {
        for _ in 0..<25 where !condition() { Thread.sleep(forTimeInterval: 0.2) }
        return condition()
    }
}

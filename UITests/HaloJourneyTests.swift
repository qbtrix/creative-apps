// HaloJourneyTests.swift: Halo driven like a person would, with a
// whole-window screenshot after every step (see Journey.swift). Each test is
// one journey; grow them as Halo's features land, and replace the skipped
// test with the real journey when its issue is built.
import XCTest

final class HaloJourneyTests: XCTestCase {
    @MainActor func testLaunchShowsWindowShell() {
        Journey("Halo", self).expectWindowShell()
    }

    @MainActor func testNewComposition() {
        let halo = Journey("Halo", self)
        halo.click("New Composition…", step: "new-composition-sheet")
        halo.click("Create", in: .sheet, step: "new-composition")
    }

    @MainActor func testEveryMenuOpens() {
        let halo = Journey("Halo", self)
        halo.click("New Composition…")
        halo.click("Create", in: .sheet)
        halo.openEachMenu()
    }

    @MainActor func testBuildCompositionAndRender() throws {
        throw XCTSkip("journey arrives with its line:halo issue")
    }
}

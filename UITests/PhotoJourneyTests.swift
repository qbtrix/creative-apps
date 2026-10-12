// PhotoJourneyTests.swift: Photo driven like a person would, with a
// whole-window screenshot after every step (see Journey.swift). Each test is
// one journey; grow them as Photo's features land, and replace the skipped
// test with the real journey when its issue is built.
import XCTest

final class PhotoJourneyTests: XCTestCase {
    @MainActor func testLaunchShowsWindowShell() {
        Journey("Photo", self).expectWindowShell()
    }

    @MainActor func testNewImageAndEveryTool() {
        let photo = Journey("Photo", self)
        photo.click("New Image", step: "new-image")
        photo.clickEachTool()
    }

    @MainActor func testEveryMenuOpens() {
        let photo = Journey("Photo", self)
        photo.click("New Image")
        photo.openEachMenu()
    }

    @MainActor func testOpenImagePaintAndSave() throws {
        throw XCTSkip("journey arrives with its line:photo issue")
    }
}

// LibraryJourneyTests+Keywords.swift: MD-J2 (metadata-more), keywords, title and caption on a selection.
// Steps 1-6 on the `cameras` fixture, 7 imports and relaunches. Written first (MD-9): skips until MD-13.
import Foundation
import XCTest

final class LibraryKeywordsJourneyTests: XCTestCase {
    private var library: Journey!  // set by step 1 or 7; a later step skips before it reads it
    private var skipped: [String] = []

    @MainActor func testKeywordsOnASelection() throws {
        try step("1") { try self.addTyped() }
        try step("2") { try self.undoRedo() }
        try step("3") { try self.partial() }
        try step("4") { try self.suggest() }
        try step("5") { try self.remove() }
        try step("6") { try self.titleAndCaption() }
        library?.app.terminate()
        try step("7") { try self.relaunch() }
        if !skipped.isEmpty { throw XCTSkip(skipped.joined(separator: "; ")) }
    }
    @MainActor private func step(_ name: String, _ body: () throws -> Void) throws {
        do { try body() } catch let skip as XCTSkip { skipped.append("step \(name): \(skip.message ?? "skipped")") }
    }
    @MainActor private func addTyped() throws {
        throw XCTSkip("waits on MD-13")
        library = Journey("Library", self, arguments: ["-LibraryFixture", "cameras"])
        XCTAssert(cell("IMG_0024").waitForExistence(timeout: 60), "no grid cell for IMG_0024")
        select("IMG_0010", plus: ["IMG_0011", "IMG_0012"])
        type("beach,  Sunset ,beach", into: "library.metadata.keywords")
        XCTAssert(token("Beach").waitForExistence(timeout: 5), "no Beach token")
        library.shot("keywords-added")
        XCTAssertEqual([text(token("Beach")), text(token("Sunset"))], ["Beach", "Sunset"])
    }
    @MainActor private func undoRedo() throws {
        throw XCTSkip("waits on MD-13")
        cell("IMG_0011").click()
        library.shot("keywords-undo-name")
        edit("Undo", reads: "Undo Add Keywords")
        XCTAssertFalse(token("Beach").exists, "Beach is still there after Undo")
        edit("Redo", reads: "Redo Add Keywords")
        XCTAssert(token("Sunset").waitForExistence(timeout: 5), "Redo didn't bring Sunset back")
    }
    @MainActor private func partial() throws {
        throw XCTSkip("waits on MD-13")
        select("IMG_0012", plus: ["IMG_0001"])
        XCTAssert(token("Sunset").waitForExistence(timeout: 5), "no Sunset token")
        library.shot("keywords-partial")
        XCTAssertEqual([text(token("Beach")), text(token("Sunset"))], ["Beach", "Sunset, 1 of 2"])
        token("Sunset").click()
        XCTAssertEqual(text(token("Sunset")), "Sunset")
        edit("Undo", reads: "Undo Add Keyword", choose: false)
    }
    @MainActor private func suggest() throws {
        throw XCTSkip("waits on MD-13")
        cell("IMG_0007").click()
        type("su", into: "library.metadata.keywords", submit: false)
        let sunset = library.app.menuItems["Sunset"]
        XCTAssert(sunset.waitForExistence(timeout: 5), "no Sunset suggestion")
        library.shot("keywords-suggest")
        XCTAssertLessThan(sunset.frame.minY, library.app.menuItems["Summer"].frame.minY, "Summer before Sunset")
        library.press(.escape)
    }
    @MainActor private func remove() throws {
        throw XCTSkip("waits on MD-13")
        cell("IMG_0001").click()
        library.element("library.metadata.removeKeyword.beach").click()
        XCTAssertFalse(token("Beach").exists, "Beach wasn't removed")
        edit("Undo", reads: "Undo Remove Keyword", choose: false)
    }
    @MainActor private func titleAndCaption() throws {
        throw XCTSkip("waits on MD-13")
        type("Harbour at dawn", into: "library.metadata.title")
        type("Low tide", into: "library.metadata.caption")
        edit("Undo", reads: "Undo Set Caption")
        edit("Undo", reads: "Undo Set Title", choose: false)
    }
    @MainActor private func relaunch() throws {
        throw XCTSkip("waits on MD-13")
        let (folder, catalog) = (try LibraryFiles.freshPhotoFolder(), try LibraryFiles.freshCatalogDir())
        addTeardownBlock { [folder, catalog].forEach { try? FileManager.default.removeItem(at: $0) } }
        let names = try LibraryFiles.write(3, in: folder).map { "/" + $0.lastPathComponent }
        library = Journey("Library", self, arguments: [
            "-LibraryImportFolder", folder.path, "-LibraryCatalogDir", catalog.path, "-LibraryImportOnLaunch",
        ])
        XCTAssert(cell(names[2]).waitForExistence(timeout: 30), "the JPEGs weren't imported")
        select(names[0], plus: [names[1], names[2]])
        type("Pier", into: "library.metadata.keywords")
        let saved = (0..<50).contains { _ in  // the `library.catalog` saved stand-in: catalog.json on disk
            let data = try? Data(contentsOf: catalog.appending(path: "catalog.json"))
            let photos = (data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any])?["photos"]
            defer { Thread.sleep(forTimeInterval: 0.2) }
            return (photos as? [[String: Any]])?.filter { $0["keywords"] as? [String] == ["Pier"] }.count == 3
        }
        XCTAssert(saved, "catalog.json never held Pier on all three")
        library.app.terminate()
        library = Journey("Library", self, arguments: ["-LibraryCatalogDir", catalog.path])
        XCTAssert(cell(names[2]).waitForExistence(timeout: 30), "the relaunch shows no photos")
        select(names[0], plus: [names[1], names[2]])
        XCTAssert(token("Pier").waitForExistence(timeout: 5), "the relaunched catalog lost Pier")
        library.shot("keywords-relaunch")
        XCTAssertEqual(text(token("Pier")), "Pier", "Pier isn't on all three")
    }
    @MainActor private func select(_ first: String, plus others: [String]) {
        cell(first).click()
        let more = others.map { cell($0) }
        XCUIElement.perform(withKeyModifiers: .command) { more.forEach { $0.click() } }
    }
    @MainActor private func type(_ text: String, into id: String, submit: Bool = true) {
        library.element(id).click()
        library.app.typeText(text + (submit ? "\n" : ""))
    }
    @MainActor private func edit(_ item: String, reads title: String, choose: Bool = true) {
        let menu = library.app.menuBars.firstMatch.menuBarItems["Edit"]
        menu.click()
        let entry = menu.menuItems.matching(NSPredicate(format: "title BEGINSWITH %@", item)).firstMatch
        XCTAssertEqual(entry.waitForExistence(timeout: 3) ? entry.title : "no \(item)", title)
        if choose { entry.click() } else { library.press(.escape) }
    }
    @MainActor private func token(_ name: String) -> XCUIElement {
        library.element("library.metadata.keyword.\(name.lowercased())")
    }
    @MainActor private func cell(_ name: String) -> XCUIElement {
        library.app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND identifier CONTAINS %@", "library.grid.cell.", name)).firstMatch
    }
    @MainActor private func text(_ item: XCUIElement) -> String {
        (item.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? item.label
    }
}

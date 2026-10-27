// LibraryJourneyTests+Sidecars.swift: MD-J3 (metadata-more), keywords and stars write an XMP sidecar
// beside the photo, never into it, and leave another app's sidecar alone. Steps 1-4 on imported
// JPEGs, 5 on the `cameras` fixture with failing fakes. Written first (MD-14): skips until MD-18.
import CryptoKit
import Foundation
import XCTest

final class LibrarySidecarJourneyTests: XCTestCase {
    private var library: Journey!  // set by step 1 or 5; a later step skips before it reads it
    private var skipped: [String] = []
    private var folder: URL!
    private var photos: [(url: URL, hash: Data, modified: Date?)] = []
    private let foreignPacket = Data("<x:xmpmeta xmlns:x=\"adobe:ns:meta/\"><rdf:RDF/></x:xmpmeta>".utf8)

    @MainActor func testKeywordsWriteASidecar() throws {
        try step("1") { try self.importTwo() }
        try step("2") { try self.saved() }
        try step("3-4") { try self.foreignAndUntouched() }
        library?.app.terminate()
        try step("5") { try self.failed() }
        if !skipped.isEmpty { throw XCTSkip(skipped.joined(separator: "; ")) }
    }
    @MainActor private func step(_ name: String, _ body: () throws -> Void) throws {
        do { try body() } catch let skip as XCTSkip { skipped.append("step \(name): \(skip.message ?? "skipped")") }
    }
    @MainActor private func importTwo() throws {
        throw XCTSkip("waits on MD-18")
        let (photoFolder, catalog) = (try LibraryFiles.freshPhotoFolder(), try LibraryFiles.freshCatalogDir())
        addTeardownBlock { [photoFolder, catalog].forEach { try? FileManager.default.removeItem(at: $0) } }
        folder = photoFolder
        for (index, written) in try LibraryFiles.write(2, in: photoFolder).enumerated() {
            let url = photoFolder.appending(path: "IMG_\(index + 1).jpg")
            try FileManager.default.moveItem(at: written, to: url)
            photos.append(try fingerprint(url))
        }
        try foreignPacket.write(to: photoFolder.appending(path: "IMG_2.xmp"))
        library = Journey("Library", self, arguments: [
            "-LibraryImportFolder", photoFolder.path, "-LibraryCatalogDir", catalog.path, "-LibraryImportOnLaunch",
        ])
        XCTAssert(cell("IMG_2").waitForExistence(timeout: 30), "the JPEGs weren't imported")
    }
    @MainActor private func saved() throws {
        throw XCTSkip("waits on MD-18")
        cell("IMG_1").click()
        type("Pier", into: "library.metadata.keywords")
        library.press(character: "3")
        XCTAssert(sidecar(reads: "Saved to IMG_1.xmp"), "the Sidecar row never read Saved to IMG_1.xmp")
        library.shot("sidecar-saved")
        let packet = String(decoding: try Data(contentsOf: folder.appending(path: "IMG_1.xmp")), as: UTF8.self)
        XCTAssert(packet.contains("<rdf:li>Pier</rdf:li>"), "IMG_1.xmp has no Pier in dc:subject")
        XCTAssert(packet.contains("<xmp:Rating>3</xmp:Rating>"), "IMG_1.xmp isn't rated 3")
    }
    @MainActor private func foreignAndUntouched() throws {
        throw XCTSkip("waits on MD-18")
        cell("IMG_2").click()
        type("Pier", into: "library.metadata.keywords")
        let sentence = "IMG_2.xmp was written by another app; Library left it unchanged."
        XCTAssert(sidecar(reads: sentence), "the Sidecar row never read the foreign sentence")
        library.shot("sidecar-foreign")
        XCTAssertEqual(try Data(contentsOf: folder.appending(path: "IMG_2.xmp")), foreignPacket, "IMG_2.xmp changed")
        let now = try photos.map { try fingerprint($0.url) }
        XCTAssert(zip(photos, now).allSatisfy { $0.hash == $1.hash && $0.modified == $1.modified }, "a JPEG changed")
    }
    @MainActor private func failed() throws {
        throw XCTSkip("waits on MD-18")
        library = Journey("Library", self, arguments: ["-LibraryFixture", "cameras", "-LibraryFakeMode", "fail"])
        XCTAssert(cell("IMG_0001").waitForExistence(timeout: 60), "no grid cell for IMG_0001")
        cell("IMG_0001").click()
        type("Pier", into: "library.metadata.keywords")
        XCTAssert(sidecar(reads: "Not saved: The folder is read-only."), "the Sidecar row never read the failure")
        library.shot("sidecar-failed")
        XCTAssert(library.element("library.metadata.keyword.pier").exists, "the failed write dropped Pier")
    }
    @MainActor private func sidecar(reads expected: String) -> Bool {
        let row = library.element("library.metadata.sidecar")
        return (0..<50).contains { _ in
            defer { Thread.sleep(forTimeInterval: 0.2) }
            return row.exists && ((row.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? row.label) == expected
        }
    }
    private func fingerprint(_ url: URL) throws -> (url: URL, hash: Data, modified: Date?) {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (url, Data(SHA256.hash(data: try Data(contentsOf: url))), attributes[.modificationDate] as? Date)
    }
    @MainActor private func type(_ text: String, into id: String) {
        library.element(id).click()
        library.app.typeText(text + "\n")
    }
    @MainActor private func cell(_ name: String) -> XCUIElement {
        library.app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND identifier CONTAINS %@", "library.grid.cell.", name)).firstMatch
    }
}

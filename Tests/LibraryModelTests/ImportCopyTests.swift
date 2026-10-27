// ImportCopyTests.swift (catalog-files LC-1 written, LC-5 on): Copy on import's plan: unique names, no overwrite,
// dated folders by capture date else file date (noon UTC dates), no copyTo plans nothing; the live copy refuses a
// short copy and a copying import adds the copies. Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import LibraryModel
import CoreColor
import Testing

@Suite struct ImportCopyTests {
    static let oct21 = Date(timeIntervalSince1970: 1_792_584_000), oct22 = oct21.addingTimeInterval(86_400)
    static let card = [(path: "/card/DCIM/100/IMG_0001.jpg", captured: Optional(oct21), modified: oct22),
                       (path: "/card/DCIM/101/IMG_0001.jpg", captured: Optional(oct21), modified: oct22)]

    @Test func duplicateNamesNeverCollide() {
        let steps = ImportCopyPlan.plan(Self.card, options: ImportCopyOptions(copyTo: "/Pictures"), exists: { _ in false })
        #expect(steps == [ImportCopyStep(source: "/card/DCIM/100/IMG_0001.jpg", destination: "/Pictures/IMG_0001.jpg"),
                          ImportCopyStep(source: "/card/DCIM/101/IMG_0001.jpg", destination: "/Pictures/IMG_0001 2.jpg")])
    }

    @Test func anExistingFileIsNeverOverwritten() {
        let taken: Set = ["/Pictures/IMG_0001.jpg", "/Pictures/IMG_0001 2.jpg"]
        let steps = ImportCopyPlan.plan(Self.card, options: ImportCopyOptions(copyTo: "/Pictures"), exists: taken.contains)
        #expect(steps.map(\.destination) == ["/Pictures/IMG_0001 3.jpg", "/Pictures/IMG_0001 4.jpg"])
    }

    @Test func datedFoldersFollowTheCaptureDateElseTheFileDate() {
        let sources = [(path: "/card/IMG_0001.jpg", captured: Optional(Self.oct21), modified: Self.oct22),
                       (path: "/card/IMG_0002.jpg", captured: Date?.none, modified: Self.oct22)]
        let steps = ImportCopyPlan.plan(sources, options: ImportCopyOptions(copyTo: "/Pictures", byDate: true), exists: { _ in false })
        #expect(steps.map(\.destination) == ["/Pictures/2026/2026-10-21/IMG_0001.jpg", "/Pictures/2026/2026-10-22/IMG_0002.jpg"])
    }

    /// On now: no copyTo adds in place, and `file.import`'s options leave copying off unless asked.
    @Test func noCopyToPlansNothingAndOptionsDefaultOff() throws {
        #expect(ImportCopyPlan.plan(Self.card, options: ImportCopyOptions(), exists: { _ in false }).isEmpty)
        let decoded = try JSONDecoder().decode(ImportOptions.self, from: Data(#"{"folder": "/card"}"#.utf8))
        #expect(decoded == ImportOptions(folder: "/card"))
        #expect(decoded.copy == ImportCopyOptions(copyTo: nil, byDate: false))
        let copying = try JSONDecoder().decode(ImportOptions.self, from: Data(#"{"folder": "/card", "copyTo": "/P", "byDate": true}"#.utf8))
        #expect(copying.copy == ImportCopyOptions(copyTo: "/P", byDate: true))
    }

    /// A fresh temp folder holding `card/IMG_0001.jpg` ("photo bytes").
    static func cardFolder() throws -> (root: String, source: String) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ImportCopyTests-\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: root + "/card", withIntermediateDirectories: true)
        try Data("photo bytes".utf8).write(to: URL(fileURLWithPath: root + "/card/IMG_0001.jpg"))
        return (root, root + "/card/IMG_0001.jpg")
    }

    @Test func aShortCopyIsRefused() throws {
        let (root, source) = try Self.cardFolder()
        let step = ImportCopyStep(source: source, destination: root + "/out/IMG_0001.jpg")
        #expect(throws: LibraryError.self) {
            try LiveImporter.copy(step) { _, to in try Data("pho".utf8).write(to: URL(fileURLWithPath: to)) }
        }
        #expect(!FileManager.default.fileExists(atPath: step.destination))
        #expect(try FileManager.default.contentsOfDirectory(atPath: root + "/out").isEmpty)
        try LiveImporter.copy(step)
        #expect(FileManager.default.contents(atPath: step.destination) == Data("photo bytes".utf8))
    }

    @Test func aCopyingImportAddsTheCopiesAndKeepsWhatWasThere() async throws {
        let (root, source) = try Self.cardFolder()
        try FileManager.default.createDirectory(atPath: root + "/Pictures", withIntermediateDirectories: true)
        try Data("older".utf8).write(to: URL(fileURLWithPath: root + "/Pictures/IMG_0001.jpg"))
        let photo = PhotoItem(id: "IMG_0001", name: "IMG_0001", captureDate: Self.oct21, color: Color3(0.5, 0.5, 0.5))
        let importer = LiveImporter(decoder: FakeDecoder(photos: [photo])).copying(ImportCopyOptions(copyTo: root + "/Pictures"))
        let result = try await importer.importFolder(root + "/card", known: [], progress: { _ in }, added: { _ in })
        let copy = root + "/Pictures/IMG_0001 2.jpg"
        #expect(result.added.map(\.path) == [copy])
        #expect(result.added.map(\.id) == [copy])
        #expect(FileManager.default.contents(atPath: copy) == Data("photo bytes".utf8))
        #expect(FileManager.default.contents(atPath: root + "/Pictures/IMG_0001.jpg") == Data("older".utf8))
        #expect(FileManager.default.fileExists(atPath: source))
    }
}

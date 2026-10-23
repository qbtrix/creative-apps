// ImportCopyTests.swift (catalog-files LC-1 written, LC-5 on): Copy on import's plan. Two IMG_0001.jpg from two
// folders land as "IMG_0001.jpg" and "IMG_0001 2.jpg" (SuiteModel's UniqueFileNames); a file already in the
// destination is never a destination; dated folders are yyyy/yyyy-MM-dd by the capture date, else the file date;
// no copyTo plans nothing. The dates are noon UTC, so the day holds in any zone within 11 hours. Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import LibraryModel
import Testing

@Suite struct ImportCopyTests {
    /// 2026-10-21 and 2026-10-22 at noon UTC.
    static let oct21 = Date(timeIntervalSince1970: 1_792_584_000), oct22 = oct21.addingTimeInterval(86_400)
    static let card = [(path: "/card/DCIM/100/IMG_0001.jpg", captured: Optional(oct21), modified: oct22),
                       (path: "/card/DCIM/101/IMG_0001.jpg", captured: Optional(oct21), modified: oct22)]

    @Test(.disabled("waits on LC-5")) func duplicateNamesNeverCollide() {
        let steps = ImportCopyPlan.plan(Self.card, options: ImportCopyOptions(copyTo: "/Pictures"), exists: { _ in false })
        #expect(steps == [ImportCopyStep(source: "/card/DCIM/100/IMG_0001.jpg", destination: "/Pictures/IMG_0001.jpg"),
                          ImportCopyStep(source: "/card/DCIM/101/IMG_0001.jpg", destination: "/Pictures/IMG_0001 2.jpg")])
    }

    @Test(.disabled("waits on LC-5")) func anExistingFileIsNeverOverwritten() {
        let taken: Set = ["/Pictures/IMG_0001.jpg", "/Pictures/IMG_0001 2.jpg"]
        let steps = ImportCopyPlan.plan(Self.card, options: ImportCopyOptions(copyTo: "/Pictures"), exists: taken.contains)
        #expect(steps.map(\.destination) == ["/Pictures/IMG_0001 3.jpg", "/Pictures/IMG_0001 4.jpg"])
        #expect(steps.allSatisfy { !taken.contains($0.destination) })
    }

    @Test(.disabled("waits on LC-5")) func datedFoldersFollowTheCaptureDateElseTheFileDate() {
        let sources = [(path: "/card/IMG_0001.jpg", captured: Optional(Self.oct21), modified: Self.oct22),
                       (path: "/card/IMG_0002.jpg", captured: Date?.none, modified: Self.oct22)]
        let steps = ImportCopyPlan.plan(sources, options: ImportCopyOptions(copyTo: "/Pictures", byDate: true), exists: { _ in false })
        #expect(steps.map(\.destination) == ["/Pictures/2026/2026-10-21/IMG_0001.jpg", "/Pictures/2026/2026-10-22/IMG_0002.jpg"])
    }

    @Test(.disabled("waits on LC-5")) func sameNameOnDifferentDaysNeedsNoSuffix() {
        let sources = [(path: "/card/a/IMG_0001.jpg", captured: Optional(Self.oct21), modified: Self.oct21),
                       (path: "/card/b/IMG_0001.jpg", captured: Optional(Self.oct22), modified: Self.oct22)]
        let steps = ImportCopyPlan.plan(sources, options: ImportCopyOptions(copyTo: "/P", byDate: true), exists: { _ in false })
        #expect(steps.map(\.destination) == ["/P/2026/2026-10-21/IMG_0001.jpg", "/P/2026/2026-10-22/IMG_0001.jpg"])
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
}

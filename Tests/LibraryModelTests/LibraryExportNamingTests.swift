// LibraryExportNamingTests.swift: EX-9, export name templates ({name}, {date},
// {seq}, {rating}): padding, illegal characters, unknown-token help.
import CoreColor
import Foundation
import Testing

@testable import LibraryModel

@Suite struct LibraryExportNamingTests {
    /// 2026-06-01T10:07:00Z.
    static let june1 = Date(timeIntervalSince1970: 1_780_308_420)

    func photo(_ name: String = "IMG_0003", rating: Int = 0) -> PhotoItem {
        PhotoItem(name: name, captureDate: Self.june1, color: Color3(0.5, 0.5, 0.5), rating: rating)
    }

    func stem(_ template: String, index: Int = 0, count: Int = 1, rating: Int = 0) -> String {
        ExportNaming(template: template).stem(for: photo(rating: rating), index: index, count: count)
    }

    @Test func dateAndSeqPadToTheCount() {
        #expect(stem("{date}-{seq}", index: 2, count: 12) == "2026-06-01-03")
        #expect(stem("{date}-{seq}", index: 2, count: 9) == "2026-06-01-3")
        #expect(stem("{seq}", index: 0, count: 100) == "001")
        #expect(stem("{name} {seq}", index: 9, count: 10) == "IMG_0003 10")
    }

    @Test func ratingAndNameFill() {
        #expect(stem("{rating}", rating: 4) == "4")
        #expect(stem("{name}") == "IMG_0003" && ExportNaming.original.help == nil)
        #expect(stem("Trip {name}") == "Trip IMG_0003")
    }

    @Test func namesNeverEscapeTheFolder() {
        #expect(stem("a/b:c") == "a-b-c")
        #expect(stem(".hidden") == "hidden")
        #expect(stem("../{name}") == "-IMG_0003")
        #expect(stem("...") == "IMG_0003")
    }

    @Test func emptyTemplateFallsBackToTheName() {
        #expect(stem("") == "IMG_0003")
        #expect(stem("   ") == "IMG_0003")
        #expect(ExportNaming(template: "").help == nil)
    }

    @Test func unknownTokenSaysWhyAndPlansNothing() {
        #expect(ExportNaming(template: "{date}-{nope}").help == "Unknown token {nope}.")
        #expect(ExportNaming(template: "{date}-{seq}-{rating}").help == nil)
        #expect(ExportNaming(template: "a{b").help == nil && stem("a{b") == "a{b")
        let photos = LibraryFixtures.photos(named: "shoot")
        var catalog = LibraryCatalog(services: .fake(photos))
        catalog.load(photos)
        catalog.select(["/fixture/shoot/IMG_0001.jpg"])
        _ = catalog.beginExport(folder: "/out")
        catalog.setExportOptions(ExportOptions(folder: "/out", naming: ExportNaming(template: "{nope}")))
        #expect(catalog.exportPlan(existingNames: []) == nil)
    }
}

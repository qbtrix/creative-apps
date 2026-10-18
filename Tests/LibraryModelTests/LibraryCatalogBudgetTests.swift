// LibraryCatalogBudgetTests.swift: the catalog file's budgets (persist PE-3,
// packet Quality tests QB-LIB-2, model half) on the `large` fixture (10,000
// photos), each with a path, every third one rated and labelled, and every
// tenth one developed with a crop, so the file carries every field v1 writes.
// `LiveCatalogCoding.decode` of that file within 1 s and `encode` within
// 500 ms, debug; a tenth of each (100 ms, 50 ms) in a release build. The
// medians gate. Each prints a `LIBRARY-BUDGET catalog …` line. Runs on Linux
// and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import LibraryModel
import Testing

#if DEBUG
/// Release limits are a tenth of the debug ones (packet Quality tests).
private let scale = 1.0
#else
private let scale = 0.1
#endif

@Suite struct LibraryCatalogBudgetTests {
    private let coding = LiveCatalogCoding()

    /// The 10,000-photo catalog with every field the file stores in use.
    private static func largeCatalog() -> [PhotoItem] {
        let crop = CropSettings(angle: 2, rect: UnitRect(x: 0.1, y: 0.05, width: 0.8, height: 0.9), aspect: .free)
        let developed = DevelopSettings.neutral.setting(.temperature, to: 8).setting(.shadows, to: 25).setting(crop: crop)
        return LibraryFixtures.photos(named: "large").enumerated().map { index, sample in
            let rated = index % 3 == 0
            return PhotoItem(
                id: sample.id, name: sample.name, captureDate: sample.captureDate, color: sample.color,
                rating: rated ? index % 5 + 1 : 0, label: rated ? .red : nil, path: "/Shots/\(sample.name).jpg",
                develop: index % 10 == 0 ? developed : .neutral)
        }
    }

    @Test func decodeLargeWithinBudget() throws {
        let photos = Self.largeCatalog()
        let data = try coding.encode(photos)
        var decoded: [[PhotoItem]] = []
        var failed = false
        let cost = Budget.measure("catalog decode-10000", runs: 5) {
            do { decoded.append(try coding.decode(data)) } catch { failed = true }
        }
        #expect(!failed)
        #expect(decoded.count == 5)
        let last = try #require(decoded.last)
        // Plain Bools, so a miss doesn't print 10,000 photos.
        let sameIDs = last.map(\.id) == photos.map(\.id)
        let sameFile = try coding.encode(last) == data
        #expect(sameIDs)
        #expect(sameFile)
        #expect(last.filter { $0.develop != .neutral }.count == 1_000)
        #expect(cost.median <= 1_000 * scale)
    }

    @Test func encodeLargeWithinBudget() throws {
        let photos = Self.largeCatalog()
        let expected = try coding.encode(photos)
        var encoded: [Data] = []
        var failed = false
        let cost = Budget.measure("catalog encode-10000", runs: 5) {
            do { encoded.append(try coding.encode(photos)) } catch { failed = true }
        }
        #expect(!failed)
        #expect(encoded.count == 5)
        let allEqual = encoded.allSatisfy { $0 == expected }
        #expect(allEqual)
        #expect(try coding.decode(expected).count == 10_000)
        #expect(cost.median <= 500 * scale)
    }
}

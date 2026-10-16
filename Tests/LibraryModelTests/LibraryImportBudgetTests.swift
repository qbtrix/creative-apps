// LibraryImportBudgetTests.swift: the import model's budgets (import IM-3,
// packet Quality tests QB-L9 and QB-LIB-1, model half) on the `large`
// fixture (10,000 photos): beginImport within 10 ms, finishImport of 200
// within 50 ms, and LiveImporter planning 10,000 candidates (half of them
// known) against 10,000 known within 200 ms. The medians gate at those debug
// limits, and at a tenth of them in a release build. Each prints a
// `LIBRARY-BUDGET import …` line. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
import CoreRaster
@testable import LibraryModel
import Testing

#if DEBUG
/// Release limits are a tenth of the debug ones (packet Quality tests).
private let scale = 1.0
#else
private let scale = 0.1
#endif

/// A scan that hands back a fixed list; decoding is never asked for.
private struct PlannedDecoder: PhotoDecoding {
    var scan: FolderScan
    func scan(folder: String) async throws -> FolderScan { scan }
    func decode(path: String, maxLongSide: Int?) async throws -> DisplayImage { throw LibraryError.missingFile(path) }
}

/// The 10,000-photo catalog, built fresh so each copy owns its storage.
private func largeCatalog() -> LibraryCatalog {
    var catalog = LibraryCatalog()
    catalog.load(LibraryFixtures.photos(named: "large"))
    return catalog
}

/// `count` new photos at `/Import/IMG_<n>.jpg`, a day apart from 2027.
private func newPhotos(_ count: Int) -> [PhotoItem] {
    let start = Date(timeIntervalSince1970: 1_798_761_600)
    return (0..<count).map { index in
        let path = "/Import/IMG_\(index).jpg"
        return PhotoItem(id: path, name: "IMG_\(index)", captureDate: start.addingTimeInterval(Double(index) * 86_400),
                         color: Color3(0.5, 0.5, 0.5), path: path)
    }
}

@Test func beginImportWithinBudget() {
    var catalog = largeCatalog()
    #expect(catalog.items.count == 10_000)
    // Kept, so freeing each set isn't timed with the next run.
    var handed: [Set<String>] = []
    let cost = Budget.measure("import begin-10000") {
        handed.append(catalog.beginImport() ?? [])
        catalog.failImport(.noPhotos("Shots"), folder: "Shots")
    }
    #expect(handed.allSatisfy { $0.count == 10_000 })
    #expect(cost.median <= 10 * scale)
}

@Test func finishImportWithinBudget() {
    let runs = 10
    var catalogs = (0..<runs).map { _ in largeCatalog() }
    for index in catalogs.indices { _ = catalogs[index].beginImport() }
    let result = ImportResult(added: newPhotos(200), alreadyKnown: 0, failures: [])
    var next = 0
    let cost = Budget.measure("import finish-200-into-10000", runs: runs) {
        catalogs[next].finishImport(result, folder: "Import")
        next += 1
    }
    #expect(catalogs.allSatisfy { $0.items.count == 10_200 && $0.order.count == 10_200 && $0.importState == .idle })
    #expect(cost.median <= 50 * scale)
}

@Test func planAgainstKnownWithinBudget() async throws {
    let start = Date(timeIntervalSince1970: 1_767_225_600)
    // 10,000 candidates in reverse capture order; the even ones are known,
    // and the other 5,000 known paths match no candidate.
    let candidates = (0..<10_000).reversed().map { index in
        ImportCandidate(path: "/Shots/IMG_\(index).jpg", captureDate: start.addingTimeInterval(Double(index) * 60),
                        pixelSize: PixelSize(width: 4000, height: 3000), kind: .jpeg)
    }
    let known = Set((0..<10_000).map { $0 % 2 == 0 ? "/Shots/IMG_\($0).jpg" : "/Elsewhere/IMG_\($0).jpg" })
    let importer = LiveImporter(decoder: PlannedDecoder(scan: FolderScan(candidates: candidates, failures: [])),
                                now: { .zero })
    let clock = ContinuousClock()
    var costs: [Double] = []
    var result: ImportResult?
    for _ in 0..<5 {
        let elapsed = try await clock.measure {
            result = try await importer.importFolder("/Shots", known: known, progress: { _ in }, added: { _ in })
        }
        costs.append(Double(elapsed.components.seconds) * 1_000 + Double(elapsed.components.attoseconds) / 1e15)
    }
    let median = costs.sorted()[costs.count / 2]
    print("LIBRARY-BUDGET import plan-10000-against-10000 median=\(median)")
    #expect(result?.added.count == 5_000)
    #expect(result?.alreadyKnown == 5_000)
    #expect(result?.added.first?.id == "/Shots/IMG_1.jpg")
    #expect(median <= 200 * scale)
}

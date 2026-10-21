// LibrarySidecarPlanTests.swift: which sidecars the catalog writes after a change, the Info tab's
// Sidecar row (metadata-more MD-16), and QB-LIB-M4's plan budget. Written before its code (contract
// rule 13, MD-14); MD-16 turned them on. `shoot` stands in for `cameras` (not on this base):
// its photos have files, and each test sets what they say. Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import LibraryModel
import Testing

#if DEBUG
private let scale = 1.0
#else
private let scale = 0.1
#endif

private func shot(_ n: Int) -> String { "/fixture/shoot/IMG_000\(n).jpg" }

/// `shoot` with Beach on IMG_0001 and IMG_0003 and 2 stars on IMG_0002.
private func shoot() -> LibraryCatalog {
    var photos = LibraryFixtures.photos(named: "shoot")
    photos[0].keywords = ["Beach"]
    photos[2].keywords = ["Beach"]
    photos[1].rating = 2
    var catalog = LibraryCatalog()
    catalog.load(photos)
    return catalog
}

/// Every photo's fields, as if each sidecar had been written.
private func allWritten(_ catalog: LibraryCatalog) -> [String: SidecarFields] {
    Dictionary(uniqueKeysWithValues: catalog.items.map { ($0.id, SidecarFields(photo: $0)) })
}

@Test func onlyPhotosWithSomethingToSayArePlanned() throws {
    let catalog = shoot()
    let plan = catalog.sidecarWrites(after: [:])
    #expect(plan.map(\.photoID).sorted() == [shot(1), shot(2), shot(3)])
    let one = try #require(plan.first { $0.photoID == shot(1) })
    #expect(one.path == "/fixture/shoot/IMG_0001.xmp" && one.data == XMPSidecar.encode(one.fields))
    #expect(catalog.sidecarWrites(after: allWritten(catalog)).isEmpty)
}

@Test func oneChangeIsOneWriteAndClearingWritesEmptyFields() throws {
    var catalog = shoot()
    let written = allWritten(catalog)
    catalog.select([shot(4)])
    catalog.setLabel(.green)
    let plan = catalog.sidecarWrites(after: written)
    let write = try #require(plan.first)
    #expect(plan.count == 1 && write.photoID == shot(4))
    #expect(write.path == "/fixture/shoot/IMG_0004.xmp" && write.fields.label == .green)
    catalog.select([shot(2)])
    catalog.setRating(0)
    #expect(catalog.sidecarWrites(after: written).first { $0.photoID == shot(2) }?.fields.isEmpty == true)
    #expect(catalog.sidecarStatus(for: shot(2), written: written, failures: [:], writing: []) == "No sidecar yet")
}

@Test func aWrittenRejectIsNotRewritten() throws {
    var catalog = shoot()
    catalog.select([shot(2)])
    catalog.setFlag(.reject)
    let write = try #require(catalog.sidecarWrites(after: allWritten(shoot())).first)
    #expect(write.photoID == shot(2) && write.fields.rating == -1)
    let written = allWritten(catalog)
    #expect(catalog.sidecarWrites(after: written).isEmpty)
    #expect(catalog.sidecarStatus(for: shot(2), written: written, failures: [:], writing: []) == "Saved to IMG_0002.xmp")
}

@Test func theSidecarRowSaysWhereTheSidecarIs() throws {
    let catalog = shoot()
    let written = allWritten(catalog)
    func status(_ written: [String: SidecarFields], _ failure: String? = nil, writing: Bool = false) -> String? {
        catalog.sidecarStatus(for: shot(1), written: written, failures: failure.map { [shot(1): $0] } ?? [:],
                              writing: writing ? [shot(1)] : [])
    }
    #expect(status([:]) == "No sidecar yet")
    #expect(status(written) == "Saved to IMG_0001.xmp")
    #expect(status(written, writing: true) == "Saving…")
    #expect(status([:], "Not saved: The folder is read-only.") == "Not saved: The folder is read-only.")
}

@Test func aSampleIsNeverPlannedAndSaysSo() throws {
    var samples = LibraryCatalog()
    samples.loadSamples()
    samples.select(Set(samples.items.map(\.id)))
    samples.setRating(5)
    #expect(samples.items.allSatisfy { $0.path == nil && $0.rating == 5 })
    #expect(samples.sidecarWrites(after: [:]).isEmpty)
    let sample = try #require(samples.items.first)
    #expect(samples.sidecarStatus(for: sample.id, written: [:], failures: [:], writing: [])
        == "Samples have no file, so no sidecar.")
}

/// QB-LIB-M4: one changed photo of 10,000 plans in 10 ms debug, 1 ms release. Timed, so on the perf list
/// (Tests/perf-suites.txt): the merge gate skips it and perf-nightly runs it.
@Test func planWithinBudget() {
    var catalog = LibraryCatalog()
    catalog.load(LibraryFixtures.photos(named: "large").map {
        PhotoItem(id: "/large/\($0.name).jpg", name: $0.name, captureDate: $0.captureDate, color: $0.color,
                  rating: 1, path: "/large/\($0.name).jpg", keywords: ["Large"])
    })
    let written = allWritten(catalog)
    catalog.select(["/large/IMG_05000.jpg"])
    catalog.setRating(4)
    var plan: [SidecarWrite] = []
    let cost = Budget.measure("sidecars plan-one-of-10000") { plan = catalog.sidecarWrites(after: written) }
    #expect(plan.map(\.photoID) == ["/large/IMG_05000.jpg"])
    #expect(cost.median <= 10 * scale)
}

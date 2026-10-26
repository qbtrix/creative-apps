// LibraryCarriedMetadataTests.swift: export-pack LX-4, the writer's metadata
// step (`CarriedMetadata.still`) on SuiteModel's `FakeMetadata`. The writer
// hands the carrier the encoded still, the original file's bytes and the
// policy's dropped properties (`ExportRules.dropped`); no source, an
// unreadable or empty one, or a carrier that can't act leaves the still as
// encoded, with nothing copied. The live carrier is XP-7 (Wire: export-pack:XP-7).
import Foundation
import SuiteKernel
import SuiteModel
import Testing

@testable import LibraryModel

@Suite struct LibraryCarriedMetadataTests {
    let still = Data("encoded still".utf8)
    let original = Data("original bytes".utf8)

    @Test func theDefaultPolicyDropsLocation() throws {
        let carrier = FakeMetadata()
        let dropping = ExportRules.dropped(ExportOptions(folder: "/out").metadata).properties
        let out = CarriedMetadata.still(still, from: "/shoot/IMG_0001.jpg", dropping: dropping, carrier: carrier,
                                        read: { $0 == "/shoot/IMG_0001.jpg" ? original : nil })
        #expect(out == still)
        #expect(carrier.carried.map(\.still) == [still])
        #expect(carrier.carried.map(\.source) == [original])
        #expect(carrier.carried.map(\.dropping) == [dropping])
        #expect(dropping == ExportRules.dropped(.noLocation).properties)
        #expect(!dropping.isEmpty)
    }

    @Test func eachPolicyReachesTheCarrier() {
        for policy in [ExportMetadata.all, .noLocation, .none] {
            let carrier = FakeMetadata()
            let dropping = ExportRules.dropped(policy).properties
            _ = CarriedMetadata.still(still, from: "/a.jpg", dropping: dropping, carrier: carrier, read: { _ in original })
            #expect(carrier.carried.map(\.dropping) == [dropping])
        }
    }

    @Test func noSourceOrAnUnreadableOneCopiesNothing() {
        let carrier = FakeMetadata()
        let dropping = ExportRules.dropped(.noLocation).properties
        #expect(CarriedMetadata.still(still, from: nil, dropping: dropping, carrier: carrier, read: { _ in original }) == still)
        #expect(CarriedMetadata.still(still, from: "/gone.jpg", dropping: dropping, carrier: carrier, read: { _ in nil }) == still)
        #expect(CarriedMetadata.still(still, from: "/empty.jpg", dropping: dropping, carrier: carrier, read: { _ in Data() }) == still)
        #expect(CarriedMetadata.still(still, from: "/missing/\(UUID().uuidString).jpg", dropping: dropping,
                                      carrier: carrier) == still)
        #expect(carrier.carried.isEmpty)
    }

    @Test func aCarrierThatCantActLeavesTheStill() {
        let carrier = FakeMetadata(unavailable: "Metadata can't be copied yet.")
        let out = CarriedMetadata.still(still, from: "/a.jpg", dropping: [], carrier: carrier, read: { _ in original })
        #expect(out == still)
    }

    @Test func theDefaultReadIsTheFileOnDisk() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("lx4-\(UUID().uuidString).jpg").path
        try original.write(to: URL(fileURLWithPath: path))
        defer { try? FileManager.default.removeItem(atPath: path) }
        let carrier = FakeMetadata()
        _ = CarriedMetadata.still(still, from: path, dropping: ["{GPS}"], carrier: carrier)
        #expect(carrier.carried.map(\.source) == [original])
        #expect(carrier.carried.map(\.dropping) == [["{GPS}"]])
    }
}

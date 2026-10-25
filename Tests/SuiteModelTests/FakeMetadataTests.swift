// FakeMetadataTests.swift: export-pack XP-2. `FakeMetadata` records each
// `carrying` call and returns the still unchanged; `SuiteServices` carries one
// by default, so `.fake()` and every existing caller get it.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel
import Testing

@Suite struct FakeMetadataTests {
    @Test func carryingRecordsTheCallAndReturnsTheStill() throws {
        let fake = FakeMetadata()
        let still = Data([1, 2, 3]), source = Data([9, 8])
        let out = try fake.carrying(still, from: source, dropping: ["{GPS}"])
        #expect(out == still)
        #expect(fake.carried.count == 1)
        #expect(fake.carried.first?.still == still)
        #expect(fake.carried.first?.source == source)
        #expect(fake.carried.first?.dropping == ["{GPS}"])
    }

    @Test func callsAreRecordedInOrder() throws {
        let fake = FakeMetadata()
        _ = try fake.carrying(Data([1]), from: Data(), dropping: [])
        _ = try fake.carrying(Data([2]), from: Data(), dropping: ["{Exif}.BodySerialNumber"])
        #expect(fake.carried.map(\.still) == [Data([1]), Data([2])])
    }

    @Test func propertiesAreTheFakesOwn() throws {
        #expect(try FakeMetadata().properties(of: Data([1])).isEmpty)
        #expect(try FakeMetadata(properties: ["{TIFF}.Orientation"]).properties(of: Data()) == ["{TIFF}.Orientation"])
    }

    @Test func unavailableThrowsItsReason() {
        let fake = FakeMetadata(unavailable: "Metadata isn't available yet.")
        #expect(throws: SuiteError.notAvailable("Metadata isn't available yet.")) {
            _ = try fake.carrying(Data([1]), from: Data(), dropping: [])
        }
        #expect(fake.carried.isEmpty)
    }

    @Test func servicesHaveAFakeMetadataByDefault() {
        #expect(SuiteServices.fake().metadata is FakeMetadata)
    }
}

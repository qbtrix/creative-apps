// ExportPickMetadataTests.swift: ExportPick's metadata policy (export-pack,
// the stub field XP-3 builds on): nil unless a host passes one, so existing
// callers read as before, and an explicit policy is part of the pick's value.
// macOS only.
import SuiteKernel
import Testing

@testable import SuiteUI

@Suite struct ExportPickMetadataTests {
    @Test func metadataDefaultsToNil() {
        #expect(ExportPick(format: "png").metadata == nil)
        #expect(ExportPick(format: "jpeg", scale: 2, quality: 0.8).metadata == nil)
    }

    @Test func explicitMetadataIsPartOfThePick() {
        let pick = ExportPick(format: "jpeg", scale: 1, quality: 0.9, metadata: .noLocation)
        #expect(pick.metadata == .noLocation)
        #expect(pick != ExportPick(format: "jpeg", scale: 1, quality: 0.9))
        #expect(pick != ExportPick(format: "jpeg", scale: 1, quality: 0.9, metadata: ExportMetadata.none))
        #expect(pick == ExportPick(format: "jpeg", scale: 1, quality: 0.9, metadata: .noLocation))
    }
}

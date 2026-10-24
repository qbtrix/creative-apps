// RawDecodePlanTests.swift: how much picture a RAW request decodes (shared-raw
// SR-3, slice SR-m, journey MJ-SR). The embedded preview stands in for a
// thumbnail only where it covers the size, a preview drafts at the scale it
// needs, `.full` is every pixel and never draft, and a camera the system
// can't develop gives its preview for thumbnails and a refusal otherwise.
// Written by SR-1/SR-2 against the stubs, turned on by SR-3. Mutations:
// SuiteImaging.SuiteRaw (`.previewCovers`, `.fullIsNotDraft`).
import CoreRaster
import Foundation
import SuiteImaging
import Testing

@Suite struct RawDecodePlanTests {
    /// The fake's DNG row: 64 x 48 with a 32 x 24 preview.
    static func info(developable: Bool = true, preview: RawSize? = RawSize(width: 32, height: 24)) throws -> RawFileInfo {
        RawFileInfo(format: try #require(RawFormat(fileName: "x.dng")), camera: "AfterGlow Test",
                    developable: developable, size: RawSize(width: 64, height: 48),
                    previewSize: preview, baselineStops: 1)
    }

    @Test func sizesHaveALongSide() {
        #expect(RawSize(width: 64, height: 48).longSide == 64)
        #expect(RawSize(width: 24, height: 32).longSide == 32)
    }

    @Test(.disabled("waits on SR-3")) func thePreviewCoversOnlyWhatItCovers() throws {
        let info = try Self.info()
        #expect(RawDecodePlan.plan(.thumbnail(longestSide: 32), info: info) == .embeddedPreview(longestSide: 32))
        #expect(RawDecodePlan.plan(.thumbnail(longestSide: 16), info: info) == .embeddedPreview(longestSide: 16))
        #expect(RawDecodePlan.plan(.thumbnail(longestSide: 64), info: info) == .develop(scale: 1, draft: true))
        let none = try Self.info(preview: nil)
        #expect(RawDecodePlan.plan(.thumbnail(longestSide: 16), info: none) == .develop(scale: 0.25, draft: true))
    }

    @Test(.disabled("waits on SR-3")) func aPreviewDraftsAtItsScale() throws {
        let info = try Self.info()
        #expect(RawDecodePlan.plan(.preview(longestSide: 32), info: info) == .develop(scale: 0.5, draft: true))
        #expect(RawDecodePlan.plan(.preview(longestSide: 4000), info: info) == .develop(scale: 1, draft: true))
    }

    @Test(.disabled("waits on SR-3")) func fullIsEveryPixelNeverDraft() throws {
        #expect(RawDecodePlan.plan(.full, info: try Self.info()) == .develop(scale: 1, draft: false))
        let big = try Self.info(preview: RawSize(width: 64, height: 48))
        #expect(RawDecodePlan.plan(.full, info: big) == .develop(scale: 1, draft: false))
    }

    @Test(.disabled("waits on SR-3")) func undevelopableGivesItsPreviewOrARefusal() throws {
        let info = try Self.info(developable: false)
        let refused = RawDecodePlan.refuse(.undevelopable(camera: "AfterGlow Test"))
        #expect(RawDecodePlan.plan(.thumbnail(longestSide: 32), info: info) == .embeddedPreview(longestSide: 32))
        #expect(RawDecodePlan.plan(.preview(longestSide: 32), info: info) == refused)
        #expect(RawDecodePlan.plan(.full, info: info) == refused)
        #expect(RawDecodePlan.plan(.thumbnail(longestSide: 32), info: try Self.info(developable: false, preview: nil)) == refused)
    }

    /// A grid-sized request on a file whose preview covers it never develops:
    /// this decoder refuses every develop, so the thumbnail must come from the preview.
    @Test(.disabled("waits on SR-3")) func aCoveredThumbnailNeverDevelops() throws {
        let buffer = try SuiteRaw.decode(.bytes(Data(), fileName: "x.DNG"), quality: .thumbnail(longestSide: 32),
                                         decoder: PreviewOnly())
        #expect(buffer.width == 32 && buffer.height == 24)
        #expect(throws: RawRefusal.tooLarge(pixels: -1)) {
            try SuiteRaw.decode(.bytes(Data(), fileName: "x.DNG"), quality: .full, decoder: PreviewOnly())
        }
    }
}

/// The fake decoder with `develop` refused, so a test can tell whether it ran.
struct PreviewOnly: RawDecoding {
    let fake = FakeRawDecoder()
    func info(_ source: RawSource) throws(RawRefusal) -> RawFileInfo { try fake.info(source) }
    func embeddedPreview(_ source: RawSource, longestSide: Int) throws(RawRefusal) -> PixelBuffer {
        try fake.embeddedPreview(source, longestSide: longestSide)
    }
    func develop(_ source: RawSource, scale: Double, draft: Bool) throws(RawRefusal) -> PixelBuffer {
        throw .tooLarge(pixels: -1)
    }
}

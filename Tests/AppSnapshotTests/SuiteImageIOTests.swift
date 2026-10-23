// SuiteImageIOTests.swift (shared-codecs SC-1; packet docs/blueprints/suiteui/features/shared-codecs.md): the
// macOS facts `SuiteImageIO` (Sources/SuiteShell/SuiteImageIO.swift) must get right once SC-4 gives it bodies:
// an Exif-orientation-6 JPEG decodes upright, a Display P3 PNG reaches sRGB output without a colour shift, a
// HEIC round-trips, and a 24 MP JPEG decodes at `longestSide: 512` within 10% of today's time (report-only).
// Written before the adapter exists, so each test names its expectation and records it; SC-2 declares the
// stubs and SC-4 turns these on with the real calls. macOS only.
#if canImport(AppKit)
import Testing

@Suite struct SuiteImageIOTests {
    /// A 4032 x 3024 JPEG stored with Exif orientation 6 decodes 3024 x 4032, its top-left pixel the stored
    /// bottom-left one, and `info` reports the shown size.
    @Test(.disabled("waits on SC-2")) func exifOrientation6DecodesUpright() {
        Issue.record("SuiteImageIO.decode and info on an orientation-6 JPEG: not built yet (SC-2 stubs, SC-4 bodies)")
    }

    /// A Display P3 PNG's pure P3 red decodes into the working space outside sRGB, and encoding it as an sRGB
    /// PNG gives the red sRGB clips it to, within 1/255.
    @Test(.disabled("waits on SC-2")) func displayP3PNGConvertsToSRGB() {
        Issue.record("SuiteImageIO P3 PNG to sRGB: not built yet (SC-2 stubs, SC-4 bodies)")
    }

    /// A buffer encoded as HEIC at quality 0.9 decodes to the same size and within 3/255 of every pixel.
    @Test(.disabled("waits on SC-2")) func heicRoundTrips() {
        Issue.record("SuiteImageIO HEIC encode and decode: not built yet (SC-2 stubs, SC-4 bodies)")
    }

    /// A 24 MP JPEG at `longestSide: 512` decodes within 10% of the time Library's decoder takes today
    /// (report-only, the packet's "no slower" row).
    @Test(.disabled("waits on SC-2")) func thumbnailDecodeTime() {
        Issue.record("SuiteImageIO thumbnail decode time: not measured yet (SC-2 stubs, SC-4 bodies)")
    }
}
#endif

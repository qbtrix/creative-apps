// SystemRawDecoderTests.swift: the Mac's RAW decoder over Core Image
// (shared-raw SR-4, slice SR-m). `tiny-bayer.dng` opens 48 x 64 upright
// (stored 64 x 48, Orientation 6), names "AfterGlow Test" with a 24 x 32
// preview and a +1 stop baseline; the preview is the magenta marker, the
// develop is the raw data's neutral level in linear floats, and both highlight
// patches pass 1.0 once the baseline is applied. `not-raw.nef` refuses
// `.unreadable(NEF)`. Catches a decoder that clips, ignores orientation, hands
// export the preview or gives a generic refusal; the last check runs the row
// through `SuiteRaw`. `decodeTime` is report-only (quality row
// "decode time", perf list): it prints and never fails a slow machine.
// Mutations: SuiteImaging.SystemRawDecoder (`.linearOutput`, `.floatOutput`, `.upright`).
#if canImport(CoreImage)
import CoreRaster
import Foundation
import SuiteImaging
import Testing

@Suite struct SystemRawDecoderTests {
    static let decoder = SystemRawDecoder()
    static let bayer = RawSource.file(TinyDNG.fixture(TinyDNG.Spec.bayer.name))
    static let bayerBytes = RawSource.bytes(
        (try? Data(contentsOf: TinyDNG.fixture(TinyDNG.Spec.bayer.name))) ?? Data(), fileName: TinyDNG.Spec.bayer.name)
    static let nef = RawSource.bytes(TinyDNG.notRaw, fileName: TinyDNG.notRawName)
    static let tolerance = 8.0 / 255

    /// A stored pixel's place once upright: Orientation 6 turns the stored rows into columns, right to left.
    static func upright(x: Int, y: Int) -> (x: Int, y: Int) { (TinyDNG.height - 1 - y, x) }

    /// The pixel at the centre of each highlight patch, upright.
    static func patches(_ buffer: PixelBuffer) throws -> [RGBA] {
        try TinyDNG.patches.map { p in
            let at = upright(x: p.x + 8, y: p.y + 8)
            return try buffer.pixel(x: at.x, y: at.y)
        }
    }

    static func near(_ value: Float, _ want: Double) -> Bool { abs(Double(value) - want) <= tolerance }

    /// The refusal `body` throws, or nil when it doesn't.
    static func refusal(_ body: () throws -> Void) -> RawRefusal? {
        do {
            try body()
            return nil
        } catch {
            return (error as Any) as? RawRefusal
        }
    }

    @Test func suiteRawUsesItOnTheMac() {
        #expect(SuiteRaw.decoder is SystemRawDecoder)
    }

    @Test func theFileOpensUpright() throws {
        let info = try Self.decoder.info(Self.bayer)
        #expect(info.size == RawSize(width: 48, height: 64))
        let full = try Self.decoder.develop(Self.bayer, scale: 1, draft: false)
        #expect(full.width == 48 && full.height == 64)
        // The 0.90 patch sits below the 0.70 one once upright, not beside it.
        let got = try Self.patches(full)
        #expect(got.count == 2 && got[1].r > got[0].r, "\(got)")
    }

    @Test func theInfoNamesTheCameraPreviewAndBaseline() throws {
        for source in [Self.bayer, Self.bayerBytes] {
            let info = try Self.decoder.info(source)
            #expect(info.format.fileExtension == "DNG")
            #expect(info.camera == TinyDNG.camera && info.developable)
            #expect(info.previewSize == RawSize(width: 24, height: 32))
            #expect(info.baselineStops == 1)
        }
    }

    /// `.thumbnail(32)`'s source: the embedded preview, upright, the marker colour, never enlarged.
    @Test func thePreviewIsTheMarker() throws {
        let preview = try Self.decoder.embeddedPreview(Self.bayer, longestSide: 32)
        #expect(preview.width == 24 && preview.height == 32)
        let p = try preview.pixel(x: 12, y: 16)
        #expect(Self.near(p.r, 1) && Self.near(p.g, 0) && Self.near(p.b, 1) && Self.near(p.a, 1), "\(p)")
        let big = try Self.decoder.embeddedPreview(Self.bayer, longestSide: 640)
        #expect(big.width == 24 && big.height == 32)
    }

    /// `.full`'s source: the raw data's neutral level in linear floats, kept above 1 after the baseline.
    @Test func theDevelopIsTheRawDataWithHeadroom() throws {
        let info = try Self.decoder.info(Self.bayer)
        let full = try Self.decoder.develop(Self.bayer, scale: 1, draft: false).exposure(stops: Float(info.baselineStops))
        let got = try Self.patches(full)
        for (p, level) in zip(got, TinyDNG.highlights) {
            let want = level * 2
            #expect(Self.near(p.r, want) && Self.near(p.g, want) && Self.near(p.b, want), "\(p) want \(want)")
            #expect(p.r > 1 && p.g > 1 && p.b > 1, "\(p)")
        }
    }

    /// `.preview(32)`'s source: a draft develop at half scale, upright.
    @Test func thePreviewQualityDrafts() throws {
        let draft = try Self.decoder.develop(Self.bayer, scale: 0.5, draft: true)
        #expect(draft.width == 24 && draft.height == 32)
        let p = try draft.pixel(x: 12, y: 16)
        #expect(p.r.isFinite && p.a == 1, "\(p)")
    }

    @Test func aFileItCantReadRefusesByFormat() {
        let calls: [() throws -> Void] = [
            { _ = try Self.decoder.info(Self.nef) },
            { _ = try Self.decoder.embeddedPreview(Self.nef, longestSide: 32) },
            { _ = try Self.decoder.develop(Self.nef, scale: 1, draft: false) },
        ]
        for call in calls {
            guard case .unreadable(let format)? = Self.refusal(call) else {
                Issue.record("not-raw.nef did not refuse .unreadable")
                continue
            }
            #expect(format.fileExtension == "NEF")
        }
    }

    /// The packet's row through `SuiteRaw`: its plan, baseline step and sentences on the system decoder.
    @Test func theRowThroughSuiteRaw() throws {
        let info = try SuiteRaw.info(Self.bayer)
        #expect(info.camera == TinyDNG.camera && info.size == RawSize(width: 48, height: 64))
        #expect(info.previewSize == RawSize(width: 24, height: 32) && info.baselineStops == 1)
        let thumb = try SuiteRaw.decode(Self.bayer, quality: .thumbnail(longestSide: 32))
        let t = try thumb.pixel(x: 12, y: 16)
        #expect(Self.near(t.r, 1) && Self.near(t.g, 0) && Self.near(t.b, 1), "\(t)")
        let full = try SuiteRaw.decode(Self.bayer, quality: .full)
        for (p, level) in zip(try Self.patches(full), TinyDNG.highlights) {
            #expect(Self.near(p.r, level * 2) && p.r > 1 && p.g > 1 && p.b > 1, "\(p)")
        }
        let preview = try SuiteRaw.decode(Self.bayer, quality: .preview(longestSide: 32))
        #expect(preview.width == 24 && preview.height == 32)
        let refusal = Self.refusal { _ = try SuiteRaw.decode(Self.nef, quality: .full) }
        #expect(refusal?.message == "macOS can't read this raw file (NEF).")
    }

    /// Report only (perf list): `.thumbnail(32)` aims under 5 ms and `.full` under 50 ms on the Mac.
    @Test func decodeTime() throws {
        let clock = ContinuousClock()
        var thumbs: [Duration] = [], fulls: [Duration] = []
        for _ in 0..<5 {
            thumbs.append(try clock.measure { _ = try Self.decoder.embeddedPreview(Self.bayer, longestSide: 32) })
            fulls.append(try clock.measure { _ = try Self.decoder.develop(Self.bayer, scale: 1, draft: false) })
        }
        let thumb = thumbs.sorted().dropFirst(2).first ?? .zero, full = fulls.sorted().dropFirst(2).first ?? .zero
        print("SystemRawDecoder decodeTime: thumbnail(32) median \(thumb) (budget 5 ms), full median \(full) (budget 50 ms) (report only)")
    }
}
#endif

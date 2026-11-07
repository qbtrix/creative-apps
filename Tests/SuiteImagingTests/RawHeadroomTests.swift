// RawHeadroomTests.swift: a RAW file's highlights survive to the sliders
// (shared-raw SR-3, slice SR-m, journey MJ-SR; quality row "headroom"). The
// fake decoder's two patches sit at 0.70 and 0.90 linear and the file's
// baseline is +1 stop, so `SuiteRaw.decode` hands back 1.4 and 1.8; the shared
// list's Exposure -1 brings them to 0.70 and 0.90, more than 20 sRGB levels
// apart, while the same buffer clamped to 8 bits first comes back flat. Also
// the fake's table as the packet's contract comment states it. Written by
// SR-1/SR-2 against the stubs, turned on by SR-3. Mutations:
// SuiteImaging.SuiteRaw (`.baselineApplied`, `.keepsHeadroom`).
import CoreRaster
import CoreRender
import Foundation
import SuiteImaging
import Testing

@Suite struct RawHeadroomTests {
    static let dng = RawSource.bytes(Data(), fileName: "x.DNG")

    /// The red sample at the centre of each highlight patch.
    static func patches(_ buffer: PixelBuffer) throws -> [Float] {
        try TinyDNG.patches.map { try buffer.pixel(x: $0.x + 8, y: $0.y + 8).r }
    }

    /// `buffer` after the shared list's Exposure -1, on the CPU backend.
    static func exposureMinusOne(_ buffer: PixelBuffer) throws -> PixelBuffer {
        let cpu = CPUBackend()
        var surface = try cpu.surface(buffer)
        for step in ImagingProgram.adjustments(AdjustSettings(exposure: -1)) { surface = try cpu.adjusted(surface, step) }
        return try cpu.read(surface)
    }

    /// The 8-bit sRGB level of each patch.
    static func levels(_ buffer: PixelBuffer) throws -> [Int] {
        let out = try ImagingColor.toOutput(buffer, profile: .sRGB, bitDepth: .eight)
        return TinyDNG.patches.map { p in Int(((out.fractions(x: p.x + 8, y: p.y + 8).first ?? -1) * 255).rounded()) }
    }

    /// SR-2: the fake's table is the contract comment's, read straight from the
    /// fake (no `SuiteRaw`, whose bodies are SR-3's).
    @Test func theFakesTableMatchesTheContract() throws {
        let fake = FakeRawDecoder()
        let dng = try fake.info(Self.dng)
        #expect(dng.format.fileExtension == "DNG" && dng.camera == TinyDNG.camera && dng.developable)
        #expect(dng.size == RawSize(width: 64, height: 48) && dng.previewSize == RawSize(width: 32, height: 24))
        #expect(dng.baselineStops == 1)
        let raw = try fake.develop(Self.dng, scale: 1, draft: false)
        #expect(raw.width == 64 && raw.height == 48)
        let got = try Self.patches(raw)
        for (g, want) in zip(got, TinyDNG.highlights) { #expect(abs(Double(g) - want) < 1e-6, "\(got)") }
        let half = try fake.develop(Self.dng, scale: 0.5, draft: true)
        #expect(half.width == 32 && half.height == 24)
        let preview = try fake.embeddedPreview(Self.dng, longestSide: 64)
        #expect(preview.width == 32 && preview.height == 24)
        #expect(try preview.pixel(x: 3, y: 3) == RGBA(r: 1, g: 0, b: 1, a: 1))

        let arw = RawSource.bytes(Data(), fileName: "z.arw")
        let unreleased = try fake.info(arw)
        #expect(unreleased.camera == "Unreleased X1" && !unreleased.developable && unreleased.previewSize != nil)
        #expect(throws: RawRefusal.undevelopable(camera: "Unreleased X1")) { try fake.develop(arw, scale: 1, draft: false) }
        #expect(try fake.embeddedPreview(arw, longestSide: 16).width == 16)

        let nef = RawSource.bytes(TinyDNG.notRaw, fileName: TinyDNG.notRawName)
        do {
            _ = try fake.info(nef)
            Issue.record("the fake read not-raw.nef")
        } catch {
            guard case .unreadable(let format)? = (error as Any) as? RawRefusal else { Issue.record("\(error)"); return }
            #expect(format.fileExtension == "NEF")
        }
    }

    @Test func theInfoIsTheFakesDNGRow() throws {
        let info = try SuiteRaw.info(Self.dng, decoder: FakeRawDecoder())
        #expect(info.format == RawFormat(fileName: "x.dng"))
        #expect(info.camera == TinyDNG.camera && info.developable)
        #expect(info.size == RawSize(width: 64, height: 48) && info.previewSize == RawSize(width: 32, height: 24))
        #expect(info.baselineStops == 1)
    }

    @Test func theDecodeCarriesTheBaseline() throws {
        let buffer = try SuiteRaw.decode(Self.dng, quality: .full, decoder: FakeRawDecoder())
        #expect(buffer.width == 64 && buffer.height == 48)
        let got = try Self.patches(buffer)
        for (g, want) in zip(got, TinyDNG.highlights.map { $0 * 2 }) { #expect(abs(Double(g) - want) < 1e-3, "\(got)") }
    }

    @Test func exposureMinusOneSeparatesThePatches() throws {
        let decoded = try SuiteRaw.decode(Self.dng, quality: .full, decoder: FakeRawDecoder())
        let pulled = try Self.exposureMinusOne(decoded)
        let got = try Self.patches(pulled)
        for (g, want) in zip(got, TinyDNG.highlights) { #expect(abs(Double(g) - want) < 1e-3, "\(got)") }
        let levels = try Self.levels(pulled)
        #expect(levels.count == 2 && levels[1] - levels[0] > 20, "\(levels)")
    }

    /// The trap: an 8-bit step before the slider leaves both patches at white.
    @Test func eightBitsFirstFlattensThem() throws {
        let decoded = try SuiteRaw.decode(Self.dng, quality: .full, decoder: FakeRawDecoder())
        let byte = try ImagingColor.toOutput(decoded, profile: .sRGB, bitDepth: .eight)
        let clipped = try PixelBuffer(rgba8: byte.samples.map { UInt8(clamping: $0) }, width: byte.width, height: byte.height)
        let levels = try Self.levels(try Self.exposureMinusOne(clipped))
        #expect(levels.count == 2 && levels[0] == levels[1], "\(levels)")
    }

    /// The preview comes back as decoded: the marker, no baseline, never enlarged.
    @Test func thePreviewIsTheMarkerWithoutBaseline() throws {
        let preview = try SuiteRaw.decode(Self.dng, quality: .thumbnail(longestSide: 16), decoder: FakeRawDecoder())
        #expect(preview.width == 16 && preview.height == 12)
        let p = try preview.pixel(x: 0, y: 0)
        #expect(p.r == 1 && p.g == 0 && p.b == 1 && p.a == 1)
    }

    @Test func theFakesRefusals() throws {
        let nef = try #require(RawFormat(fileName: "y.NEF"))
        #expect(throws: RawRefusal.unreadable(nef)) {
            try SuiteRaw.decode(.bytes(TinyDNG.notRaw, fileName: "y.NEF"), quality: .full, decoder: FakeRawDecoder())
        }
        let arw = RawSource.bytes(Data(), fileName: "z.ARW")
        let info = try SuiteRaw.info(arw, decoder: FakeRawDecoder())
        #expect(info.camera == "Unreleased X1" && !info.developable && info.previewSize != nil)
        #expect(throws: RawRefusal.undevelopable(camera: "Unreleased X1")) {
            try SuiteRaw.decode(arw, quality: .full, decoder: FakeRawDecoder())
        }
        let thumb = try SuiteRaw.decode(arw, quality: .thumbnail(longestSide: 32), decoder: FakeRawDecoder())
        #expect(thumb.width == 32)
        #expect(throws: RawRefusal.unavailable) { try SuiteRaw.decode(Self.dng, quality: .full, decoder: nil) }
    }
}

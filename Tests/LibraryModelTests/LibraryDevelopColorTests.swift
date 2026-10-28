// LibraryDevelopColorTests.swift: Vibrance and Saturation through the live
// develop renderer (develop packet DV-11, slice DV-e; DV-12 enabled them on
// CoreRaster's vibrance and hue/saturation). A grey stays the same
// grey at either control's ends; Saturation -100 turns a colour into the grey
// of its Rec. 709 luminance and +50 spreads its channels; Vibrance +50 lifts
// a muted colour's chroma more than a saturated one's; Vibrance sits after
// whites and blacks and before the curve, Saturation after the curve; MJ4 walks all of it on the
// live services. Every check goes through `LiveDevelop`, never CoreRaster's
// calls by hand. Runs on Linux and macOS.
@testable import LibraryModel
import CoreRaster
import CoreRender
import Testing

/// A 2 x 2 opaque patch of one sRGB colour.
private func colorPatch(_ r: UInt8, _ g: UInt8, _ b: UInt8) throws -> PixelBuffer {
    try PixelBuffer(rgba8: Array(repeating: [r, g, b, 255], count: 4).flatMap { $0 }, width: 2, height: 2)
}

/// `patch` rendered at `slider` = `value`, its top-left pixel (linear, opaque).
private func rendered(_ patch: PixelBuffer, _ slider: DevelopSlider, _ value: Double) throws -> RGBA {
    try LiveDevelop().render(patch, settings: DevelopSettings.neutral.setting(slider, to: value)).pixel(x: 0, y: 0)
}

/// The spread between a pixel's largest and smallest channel.
private func chroma(_ p: RGBA) -> Float { max(p.r, p.g, p.b) - min(p.r, p.g, p.b) }

/// A pixel's Rec. 709 luminance over its linear channels.
private func luminance(_ p: RGBA) -> Float {
    let w = Histogram.luminanceWeights
    return w.r * p.r + w.g * p.g + w.b * p.b
}

private func near(_ a: RGBA, _ b: RGBA, _ tolerance: Float = 1e-4) -> Bool {
    abs(a.r - b.r) < tolerance && abs(a.g - b.g) < tolerance && abs(a.b - b.b) < tolerance
}

@Suite struct LibraryDevelopColorTests {
    @Test func greyStaysTheSameGrey() throws {
        for level: UInt8 in [26, 128, 230] {
            let grey = try colorPatch(level, level, level)
            let before = try grey.pixel(x: 0, y: 0)
            for slider in [DevelopSlider.vibrance, .saturation] {
                for value in [-100.0, -50, 50, 100] {
                    #expect(near(try rendered(grey, slider, value), before), "\(slider) \(value) on grey \(level)")
                }
            }
        }
    }

    @Test func saturationMinus100IsTheGreyOfItsLuminance() throws {
        let red = try colorPatch(200, 40, 40)
        let y = luminance(try red.pixel(x: 0, y: 0))
        let p = try rendered(red, .saturation, -100)
        #expect(abs(p.r - y) < 1e-4 && abs(p.g - y) < 1e-4 && abs(p.b - y) < 1e-4)
        #expect(abs(p.a - 1) < 1e-4)
    }

    @Test func saturationUpSpreadsTheChannels() throws {
        let red = try colorPatch(180, 90, 80)
        let before = try red.pixel(x: 0, y: 0)
        let up = try rendered(red, .saturation, 50)
        let down = try rendered(red, .saturation, -50)
        #expect(chroma(up) > chroma(before))
        #expect(chroma(down) < chroma(before))
        #expect(up.r > before.r && up.b < before.b)     // red moves away from its luminance
    }

    @Test func vibranceLiftsMutedColoursMore() throws {
        let muted = try colorPatch(140, 120, 110)
        let strong = try colorPatch(220, 40, 30)
        let mutedGain = chroma(try rendered(muted, .vibrance, 50)) - chroma(try muted.pixel(x: 0, y: 0))
        let strongGain = chroma(try rendered(strong, .vibrance, 50)) - chroma(try strong.pixel(x: 0, y: 0))
        #expect(mutedGain > 0)
        #expect(mutedGain > strongGain)
    }

    @Test func vibranceSitsAfterWhitesBlacksBeforeTheCurve() throws {
        let curve = try #require(ToneCurve(points: [DevelopCurvePoint(x: 0, y: 0), DevelopCurvePoint(x: 0.5, y: 0.6),
                                                    DevelopCurvePoint(x: 1, y: 1)]))
        let settings = DevelopSettings.neutral.setting(.whites, to: 20).setting(.vibrance, to: 30)
            .setting(.saturation, to: -20).setting(curve: curve)
        let passes = LiveDevelop.passes(for: settings)
        let whitesAt = passes.firstIndex { if case .shared(.levels) = $0 { true } else { false } }
        let curveAt = passes.firstIndex { if case .shared(.curves) = $0 { true } else { false } }
        #expect(passes.count == 4)
        #expect(whitesAt == 0 && passes.firstIndex(of: .shared(.vibrance(30))) == 1 && curveAt == 2)
        #expect(passes.firstIndex { if case .shared(.hueSaturation) = $0 { true } else { false } } == 3)
        #expect(!LiveDevelop.passes(for: .neutral).contains { if case .shared(.vibrance) = $0 { true } else { false } })
    }

    /// MJ4: a grey survives both controls at their ends, Saturation -100 greys
    /// a red patch to its luminance, and nothing waits on the live services.
    @Test func testVibranceSaturationWalk() throws {
        let grey = try colorPatch(128, 128, 128)
        let before = try grey.pixel(x: 0, y: 0)
        for (vibrance, saturation) in [(100.0, 100.0), (-100, -100), (100, -100), (-100, 100)] {
            let settings = DevelopSettings.neutral.setting(.vibrance, to: vibrance).setting(.saturation, to: saturation)
            #expect(near(try LiveDevelop().render(grey, settings: settings).pixel(x: 0, y: 0), before))
        }
        let red = try colorPatch(200, 40, 40)
        let y = luminance(try red.pixel(x: 0, y: 0))
        #expect(near(try rendered(red, .saturation, -100), RGBA(r: y, g: y, b: y, a: 1)))
        #expect(LiveDevelop.waiting.isEmpty)
        let live = LibraryServices.live(decoder: FakeDecoder(photos: []), writer: FakeJPEGWriter(), store: FakeCatalogStore())
        let catalog = LibraryCatalog(services: live)
        #expect(catalog.sliderHelp(.vibrance) == nil)
        #expect(catalog.sliderHelp(.saturation) == nil)
    }
}

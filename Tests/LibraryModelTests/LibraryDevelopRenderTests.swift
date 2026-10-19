// LibraryDevelopRenderTests.swift: the live develop renderer's checks
// (develop packet DV-5, enabled by DV-6): neutral settings run no pass and
// return the input (QB-LIB-V1), each control alone is its one CoreRaster
// call, every control set runs the packet's pass order and equals the
// CoreRaster calls run by hand bit for bit (QB-LIB-V2), the histogram is of
// the rendered buffer (QB-LIB-V3), and MJ3 walks all of it. `HandPass` is the
// packet's pass list (DV-6 pseudocode) written out here, and
// `LiveDevelop.passes(for:)` must name the same passes in the same order.
// Runs on Linux and macOS.
@testable import LibraryModel
import CoreRaster
import Testing

/// A gradient in sRGB bytes: red across, green down, blue fixed at 128, opaque.
func developGradient(width: Int = 64, height: Int = 48) throws -> PixelBuffer {
    var bytes = [UInt8]()
    bytes.reserveCapacity(width * height * 4)
    for y in 0..<height {
        for x in 0..<width {
            bytes += [UInt8(x * 255 / max(width - 1, 1)), UInt8(y * 255 / max(height - 1, 1)), 128, 255]
        }
    }
    return try PixelBuffer(rgba8: bytes, width: width, height: height)
}

/// Every control set but Vibrance and Saturation (they wait on creative-core, DV-12).
func everyControlButColor() -> DevelopSettings {
    let curve = ToneCurve(points: [DevelopCurvePoint(x: 0, y: 0), DevelopCurvePoint(x: 0.5, y: 0.6),
                                   DevelopCurvePoint(x: 1, y: 1)]) ?? .identity
    let levels = DevelopLevels.neutral.setting(.gamma, to: 1.2).setting(.outBlack, to: 0.02)
    return DevelopSettings.neutral
        .setting(.temperature, to: 30).setting(.tint, to: -10)
        .setting(.exposure, to: 0.5).setting(.contrast, to: 20)
        .setting(.highlights, to: -40).setting(.shadows, to: 25)
        .setting(.whites, to: 20).setting(.blacks, to: -15)
        .setting(curve: curve).setting(levels: levels)
}

/// The packet's pass list, in render order.
enum HandPass: CaseIterable {
    case whiteBalance, exposure, contrast, highlightsShadows, whitesBlacks, curve, levels

    /// The passes `s` needs, in render order; empty when neutral.
    static func passes(for s: DevelopSettings) -> [HandPass] {
        allCases.filter { pass in
            switch pass {
            case .whiteBalance: s.temperature != 0 || s.tint != 0
            case .exposure: s.exposure != 0
            case .contrast: s.contrast != 0
            case .highlightsShadows: s.highlights != 0 || s.shadows != 0
            case .whitesBlacks: s.whites != 0 || s.blacks != 0
            case .curve: !s.curve.isIdentity
            case .levels: s.levels != .neutral
            }
        }
    }

    /// This pass's CoreRaster call on `b`, as the packet's pseudocode spells it.
    func run(_ b: PixelBuffer, _ s: DevelopSettings) throws -> PixelBuffer {
        switch self {
        case .whiteBalance: return try b.whiteBalance(temperature: Float(s.temperature), tint: Float(s.tint))
        case .exposure: return try b.exposure(stops: Float(s.exposure))
        case .contrast: return try b.contrast(Float(s.contrast))
        case .highlightsShadows: return try b.highlightsShadows(highlights: Float(s.highlights), shadows: Float(s.shadows))
        case .whitesBlacks:
            let inWhite = s.whites > 0 ? 1 - 0.25 * s.whites / 100 : 1
            let outWhite = s.whites < 0 ? 1 + 0.25 * s.whites / 100 : 1
            let inBlack = s.blacks < 0 ? 0.25 * -s.blacks / 100 : 0
            let outBlack = s.blacks > 0 ? 0.25 * s.blacks / 100 : 0
            return try b.levels(inBlack: Float(inBlack), inWhite: Float(inWhite), gamma: 1,
                                outBlack: Float(outBlack), outWhite: Float(outWhite), encoding: .sRGB)
        case .curve:
            return try b.curves(points: s.curve.points.map { CurvePoint(x: Float($0.x), y: Float($0.y)) }, encoding: .sRGB)
        case .levels:
            let l = s.levels
            return try b.levels(inBlack: Float(l.inBlack), inWhite: Float(l.inWhite), gamma: Float(l.gamma),
                                outBlack: Float(l.outBlack), outWhite: Float(l.outWhite), encoding: .sRGB)
        }
    }

    /// `order`'s calls run by hand on `buffer`.
    static func runByHand(_ buffer: PixelBuffer, _ s: DevelopSettings, order: [HandPass]) throws -> PixelBuffer {
        try order.reduce(buffer) { try $1.run($0, s) }
    }
}

extension LiveDevelop.Pass {
    /// The hand list's name for this pass; nil for `.color` (DV-12).
    var hand: HandPass? {
        switch self {
        case .whiteBalance: .whiteBalance
        case .exposure: .exposure
        case .contrast: .contrast
        case .highlightsShadows: .highlightsShadows
        case .whitesBlacks: .whitesBlacks
        case .color: nil
        case .curve: .curve
        case .levels: .levels
        }
    }
}

/// `LiveDevelop.passes(for:)` by the hand list's names.
func livePasses(_ s: DevelopSettings) -> [HandPass?] { LiveDevelop.passes(for: s).map(\.hand) }

/// The panel's histogram of `buffer`, straight from CoreRaster.
func handHistogram(_ buffer: PixelBuffer) throws -> HistogramBins {
    let h = try Histogram(of: buffer, bins: 256, encoding: .sRGB)
    return HistogramBins(red: h.red, green: h.green, blue: h.blue,
                         shadowClipped: h.shadowClipped, highlightClipped: h.highlightClipped)
}

@Suite struct LibraryDevelopRenderTests {
    let live = LiveDevelop()

    @Test func neutralRunsNoPassAndReturnsTheInput() throws {
        let gradient = try developGradient()
        #expect(HandPass.passes(for: .neutral).isEmpty)
        #expect(LiveDevelop.passes(for: .neutral).isEmpty)
        #expect(LiveDevelop.passes(for: DevelopSettings.neutral.setting(crop: CropSettings(angle: 0, rect: .full, aspect: .original))).isEmpty)
        #expect(try live.render(gradient, settings: .neutral) == gradient)
        #expect(LiveDevelop.unavailable == nil)
    }

    @Test func eachControlAloneIsItsOnePass() throws {
        let gradient = try developGradient()
        let curve = ToneCurve(points: [DevelopCurvePoint(x: 0, y: 0), DevelopCurvePoint(x: 0.5, y: 0.7),
                                       DevelopCurvePoint(x: 1, y: 1)]) ?? .identity
        let cases: [(DevelopSettings, HandPass)] = [
            (DevelopSettings.neutral.setting(.temperature, to: 40), .whiteBalance),
            (DevelopSettings.neutral.setting(.tint, to: -40), .whiteBalance),
            (DevelopSettings.neutral.setting(.exposure, to: 1), .exposure),
            (DevelopSettings.neutral.setting(.contrast, to: 30), .contrast),
            (DevelopSettings.neutral.setting(.highlights, to: -50), .highlightsShadows),
            (DevelopSettings.neutral.setting(.shadows, to: 50), .highlightsShadows),
            (DevelopSettings.neutral.setting(.whites, to: 50), .whitesBlacks),
            (DevelopSettings.neutral.setting(.blacks, to: -50), .whitesBlacks),
            (DevelopSettings.neutral.setting(curve: curve), .curve),
            (DevelopSettings.neutral.setting(levels: DevelopLevels.neutral.setting(.gamma, to: 1.5)), .levels),
        ]
        for (settings, pass) in cases {
            #expect(HandPass.passes(for: settings) == [pass])
            #expect(livePasses(settings) == [pass])
            let rendered = try live.render(gradient, settings: settings)
            #expect(rendered == (try pass.run(gradient, settings)))
            #expect(rendered != gradient)
        }
    }

    @Test func everyControlRunsInOrderAndMatchesCoreRasterBitForBit() throws {
        let gradient = try developGradient()
        let settings = everyControlButColor()
        let order = HandPass.passes(for: settings)
        #expect(order == [.whiteBalance, .exposure, .contrast, .highlightsShadows, .whitesBlacks, .curve, .levels])
        #expect(livePasses(settings) == order)
        let rendered = try live.render(gradient, settings: settings)
        #expect(rendered == (try HandPass.runByHand(gradient, settings, order: order)))
        let swapped: [HandPass] = [.whiteBalance, .contrast, .exposure, .highlightsShadows, .whitesBlacks, .curve, .levels]
        #expect(rendered != (try HandPass.runByHand(gradient, settings, order: swapped)))
    }

    @Test func exposurePlusOneDoublesLinearGrey() throws {
        let grey = try PixelBuffer(width: 4, height: 4, fill: RGBA(r: 0.18, g: 0.18, b: 0.18, a: 1))
        let pixel = try live.render(grey, settings: DevelopSettings.neutral.setting(.exposure, to: 1)).pixel(x: 1, y: 1)
        #expect(abs(pixel.r - 0.36) < 1e-4 && abs(pixel.g - 0.36) < 1e-4 && abs(pixel.b - 0.36) < 1e-4)
    }

    @Test func temperatureWarmsGreyAndKeepsItsLuminance() throws {
        let grey = try PixelBuffer(width: 4, height: 4, fill: RGBA(r: 0.18, g: 0.18, b: 0.18, a: 1))
        let p = try live.render(grey, settings: DevelopSettings.neutral.setting(.temperature, to: 50)).pixel(x: 0, y: 0)
        let w = Histogram.luminanceWeights
        #expect(p.r > p.b)
        #expect(abs(w.r * p.r + w.g * p.g + w.b * p.b - 0.18) < 1e-3)
    }

    @Test func whitesBrightenAndBlacksDarken() throws {
        let light = try PixelBuffer(rgba8: [230, 230, 230, 255], width: 1, height: 1)   // 0.9 sRGB
        let dark = try PixelBuffer(rgba8: [26, 26, 26, 255], width: 1, height: 1)       // 0.1 sRGB
        let whiter = try live.render(light, settings: DevelopSettings.neutral.setting(.whites, to: 50))
        let blacker = try live.render(dark, settings: DevelopSettings.neutral.setting(.blacks, to: -50))
        #expect(try whiter.pixel(x: 0, y: 0).g > light.pixel(x: 0, y: 0).g)
        #expect(try blacker.pixel(x: 0, y: 0).g < dark.pixel(x: 0, y: 0).g)
    }

    /// DV-6 compares the message with `LiveDevelop.waiting[slider]`; DV-12 turns this into "every control set".
    @Test func vibranceAndSaturationThrowTheirWaitingReason() throws {
        let gradient = try developGradient()
        for slider in [DevelopSlider.vibrance, .saturation] {
            let error = #expect(throws: LibraryError.self) {
                try live.render(gradient, settings: DevelopSettings.neutral.setting(slider, to: 20))
            }
            guard case .renderFailed(let why)? = error else {
                Issue.record("\(slider) didn't fail with renderFailed")
                continue
            }
            #expect(why.contains("creative-core"))
            #expect(why == LiveDevelop.waiting[slider])
        }
    }

    @Test func histogramIsCoreRasterOfTheRenderedBuffer() throws {
        let gradient = try developGradient()
        let rendered = try live.render(gradient, settings: everyControlButColor())
        let bins = try live.histogram(of: rendered)
        #expect(bins == (try handHistogram(rendered)))
        #expect(bins != (try handHistogram(gradient)))
        for channel in [bins.red, bins.green, bins.blue] {
            #expect(channel.count == HistogramBins.binCount)
            #expect(channel.reduce(0, +) == 64 * 48)
        }
    }

    /// MJ3: the render walk on a 64 × 48 gradient.
    @Test func testRenderWalk() throws {
        let gradient = try developGradient()
        #expect(HandPass.passes(for: .neutral).isEmpty)
        #expect(try live.render(gradient, settings: .neutral) == gradient)
        let settings = everyControlButColor()
        let rendered = try live.render(gradient, settings: settings)
        #expect(rendered == (try HandPass.runByHand(gradient, settings, order: HandPass.passes(for: settings))))
        #expect(try live.histogram(of: rendered) == handHistogram(rendered))
    }
}

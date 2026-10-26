// Live/LiveDevelop.swift: the live develop renderer (develop packet DV-6).
// A photo's settings become the CoreRaster calls they need, in one fixed
// order: white balance, exposure, contrast, highlights and shadows, whites
// and blacks, levels, the tone curve, saturation. Exposure, levels, the curve
// and saturation are SuiteImaging's shared list (`ImagingProgram.adjustments`,
// the steps Photo runs, on CoreRender's CPU backend; suite-imaging IM-10b),
// with Library's own tone passes after its exposure step. A control at its
// neutral value runs no pass, so neutral settings return the input untouched.
// The histogram is CoreRaster's, 256 bins over the sRGB values of the buffer
// it is given (the rendered one). Vibrance waits on creative-core (`waiting`):
// a render that needs it throws `.renderFailed` with that reason. After
// the tone, a crop (crop CR-4) turns the buffer by its angle and cuts
// `LiveCrop`'s frame for the buffer's own size out of the turned pixels.
// The photo's orientation (orientation-crop OC-8) faces the pixels first, so
// the crop's rect is in the oriented photo.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import CoreRender
import SuiteImaging

public struct LiveDevelop: DevelopRendering {
    public static let unavailable: String? = nil
    /// Sliders the live renderer can't draw yet, with the reason the row shows.
    /// DV-12 empties it once CoreRaster's vibrance reaches `dev`.
    public static let waiting: [DevelopSlider: String] = [
        .vibrance: "Vibrance waits on creative-core (CoreRaster vibrance)",
    ]

    /// The CoreRaster calls `settings` needs, in render order; empty when neutral.
    public enum Pass: Equatable, Sendable {
        case whiteBalance(temperature: Float, tint: Float), contrast(Float)
        case highlightsShadows(highlights: Float, shadows: Float)
        case whitesBlacks(inBlack: Float, inWhite: Float, outBlack: Float, outWhite: Float)
        case color(vibrance: Float, saturation: Float)                  // DV-12
        /// One step of `ImagingProgram.adjustments`: exposure, levels, the curve or saturation.
        case shared(ToneAdjustment)
    }

    public init() {}

    public static func passes(for s: DevelopSettings) -> [Pass] {
        let shared = ImagingProgram.adjustments(s.adjustSettings).map(Pass.shared)
        let exposure = shared.prefix { if case .shared(.exposure) = $0 { true } else { false } }
        var p: [Pass] = []
        if s.temperature != 0 || s.tint != 0 { p.append(.whiteBalance(temperature: Float(s.temperature), tint: Float(s.tint))) }
        p += exposure
        if s.contrast != 0 { p.append(.contrast(Float(s.contrast))) }
        if s.highlights != 0 || s.shadows != 0 {
            p.append(.highlightsShadows(highlights: Float(s.highlights), shadows: Float(s.shadows)))
        }
        if s.whites != 0 || s.blacks != 0 {
            // sRGB values, at most a quarter of the range: inBlack <= 0.25 < 0.75 <= inWhite, so levels never throws.
            let inWhite = s.whites > 0 ? 1 - 0.25 * s.whites / 100 : 1
            let outWhite = s.whites < 0 ? 1 + 0.25 * s.whites / 100 : 1
            let inBlack = s.blacks < 0 ? 0.25 * -s.blacks / 100 : 0
            let outBlack = s.blacks > 0 ? 0.25 * s.blacks / 100 : 0
            p.append(.whitesBlacks(inBlack: Float(inBlack), inWhite: Float(inWhite),
                                   outBlack: Float(outBlack), outWhite: Float(outWhite)))
        }
        return p + shared.dropFirst(exposure.count)
    }

    /// `passes(for:)` as the steps the loupe's GPU route writes, in the same
    /// order (suite-imaging IM-11); nil while a pass has no step (Vibrance).
    /// Whites and blacks are levels on sRGB values with gamma 1.
    public static func steps(for s: DevelopSettings) -> [ToneAdjustment]? {
        var steps: [ToneAdjustment] = []
        for pass in passes(for: s) {
            switch pass {
            case .whiteBalance(let temperature, let tint): steps.append(.whiteBalance(temperature: temperature, tint: tint))
            case .contrast(let amount): steps.append(.contrast(amount))
            case .highlightsShadows(let highlights, let shadows): steps.append(.highlightsShadows(highlights: highlights, shadows: shadows))
            case .whitesBlacks(let inBlack, let inWhite, let outBlack, let outWhite):
                steps.append(.levels(inBlack: inBlack, inWhite: inWhite, gamma: 1, outBlack: outBlack, outWhite: outWhite, encoding: .sRGB))
            case .color: return nil
            case .shared(let step): steps.append(step)
            }
        }
        return steps
    }

    public func render(_ buffer: PixelBuffer, settings: DevelopSettings) throws -> PixelBuffer {
        for slider in DevelopSlider.allCases where settings.value(slider) != 0 {
            if let why = Self.waiting[slider] { throw LibraryError.renderFailed(why) }
        }
        var b = buffer
        let cpu = CPUBackend()
        for pass in Self.passes(for: settings) {
            do { b = try Self.run(pass, on: b, cpu: cpu) } catch let error as RasterError {
                throw LibraryError.renderFailed("\(error)")
            } catch let error as RenderError {
                throw LibraryError.renderFailed("\(error)")
            }
        }
        b = b.oriented(settings.orientation)
        guard let crop = settings.crop else { return b }
        do {
            let turned = crop.angle == 0 ? b : try b.rotated(degrees: crop.angle, filter: .lanczos3)
            let f = try LiveCrop().frame(crop, photo: PixelSize(width: b.width, height: b.height))
            return try turned.cropped(x: f.x, y: f.y, width: f.width, height: f.height)
        } catch let error as RasterError {
            throw LibraryError.renderFailed("\(error)")
        }
    }

    public func histogram(of buffer: PixelBuffer) throws -> HistogramBins {
        let h = try Histogram(of: buffer, bins: HistogramBins.binCount, encoding: .sRGB)
        return HistogramBins(red: h.red, green: h.green, blue: h.blue,
                             shadowClipped: h.shadowClipped, highlightClipped: h.highlightClipped)
    }

    /// `pass`'s one CoreRaster call; whites and blacks act on sRGB values. A
    /// shared step runs on `cpu`, as the shared list's CPU route runs it.
    private static func run(_ pass: Pass, on b: PixelBuffer, cpu: CPUBackend) throws -> PixelBuffer {
        switch pass {
        case .whiteBalance(let temperature, let tint): try b.whiteBalance(temperature: temperature, tint: tint)
        case .contrast(let amount): try b.contrast(amount)
        case .highlightsShadows(let highlights, let shadows): try b.highlightsShadows(highlights: highlights, shadows: shadows)
        case .whitesBlacks(let inBlack, let inWhite, let outBlack, let outWhite):
            try b.levels(inBlack: inBlack, inWhite: inWhite, gamma: 1, outBlack: outBlack, outWhite: outWhite, encoding: .sRGB)
        case .color: throw LibraryError.renderFailed(waiting[.vibrance] ?? "Vibrance isn't built yet")
        case .shared(let step):
            try {
                let input = try cpu.surface(b)
                defer { cpu.release(input) }
                let output = try cpu.adjusted(input, step)
                defer { cpu.release(output) }
                return try cpu.read(output)
            }()
        }
    }
}

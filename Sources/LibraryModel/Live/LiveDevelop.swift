// Live/LiveDevelop.swift: the live develop renderer (develop packet DV-6).
// A photo's settings become the CoreRender steps they need, in one fixed
// order: white balance, exposure, contrast, highlights and shadows, whites,
// blacks, levels, the tone curve, saturation. Every step is SuiteImaging's
// (suite-imaging IM-13): the sliders are `ToneRules`' list, levels, the curve
// and saturation `ImagingProgram`'s after it, run on CoreRender's CPU backend
// as Photo runs them. A control at its neutral value runs no step, so neutral
// settings return the input untouched.
// The histogram is CoreRaster's, 256 bins over the sRGB values of the buffer
// it is given (the rendered one). Vibrance waits on creative-core (`waiting`):
// a render that needs it throws `.renderFailed` with that reason. After
// the tone, a crop (crop CR-4) turns the buffer by its angle and cuts
// `LiveCrop`'s frame for the buffer's own size out of the turned pixels.
// Between them the kinds (adjust-everywhere AJ-11): Black & White, then
// Invert, SuiteImaging's CPU steps, so the grid, loupe and export all show them.
// The photo's orientation (orientation-crop OC-8) then faces the pixels, so
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

    /// The steps `settings` needs, in render order; empty when neutral.
    public enum Pass: Equatable, Sendable {
        case color(vibrance: Float, saturation: Float)                  // DV-12
        /// One of SuiteImaging's steps.
        case shared(ToneAdjustment)
    }

    public init() {}

    /// `ToneRules`' slider steps (Saturation left to the shared list, so it
    /// runs after the curve), then `ImagingProgram`'s levels, curve and saturation.
    public static func passes(for s: DevelopSettings) -> [Pass] {
        var adjust = s.adjustSettings
        adjust.exposure = 0
        return ImagingProgram.adjustments(adjust, tone: ToneRules.adjustments(s.tone.setting(.saturation, to: 0))).map(Pass.shared)
    }

    /// `passes(for:)` as the steps the loupe's GPU route writes, in the same
    /// order (suite-imaging IM-11); nil while a pass has no step (Vibrance).
    public static func steps(for s: DevelopSettings) -> [ToneAdjustment]? {
        var steps: [ToneAdjustment] = []
        for pass in passes(for: s) {
            switch pass {
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
        b = try Self.kinds(settings.kinds, on: b)
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

    /// `kinds` on `b` through CoreRender's CPU backend; none returns `b` untouched.
    static func kinds(_ kinds: [ImagingKind], on b: PixelBuffer) throws -> PixelBuffer {
        guard !kinds.isEmpty else { return b }
        do {
            let cpu = CPUBackend()
            var s = try cpu.surface(b)
            for step in AdjustKinds.adjustments(kinds) { s = try cpu.adjusted(s, step) }
            return try cpu.read(s)
        } catch {
            throw LibraryError.renderFailed("\(error)")
        }
    }

    public func histogram(of buffer: PixelBuffer) throws -> HistogramBins {
        let h = try Histogram(of: buffer, bins: HistogramBins.binCount, encoding: .sRGB)
        return HistogramBins(red: h.red, green: h.green, blue: h.blue,
                             shadowClipped: h.shadowClipped, highlightClipped: h.highlightClipped)
    }

    /// `pass` run on `cpu`, as the shared list's CPU route runs it.
    private static func run(_ pass: Pass, on b: PixelBuffer, cpu: CPUBackend) throws -> PixelBuffer {
        switch pass {
        case .color: throw LibraryError.renderFailed(waiting[.vibrance] ?? "Vibrance isn't built yet")
        case .shared(let step):
            let input = try cpu.surface(b)
            defer { cpu.release(input) }
            let output = try cpu.adjusted(input, step)
            defer { cpu.release(output) }
            return try cpu.read(output)
        }
    }
}

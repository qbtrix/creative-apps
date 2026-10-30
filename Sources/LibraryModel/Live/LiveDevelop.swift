// Live/LiveDevelop.swift: the live develop renderer (develop packet DV-6).
// A photo's settings become the CoreRender steps they need, in one fixed
// order: white balance, exposure, contrast, highlights and shadows, whites,
// blacks, vibrance, levels, the tone curve, saturation. Every step is
// CoreRender's: the sliders are `ToneRules`' list, then CoreRaster's vibrance
// (DV-12), then levels, the curve and saturation, `ImagingProgram`'s, run on
// CoreRender's CPU backend as Photo runs them, on one surface. A control at its neutral value runs no step, so neutral
// settings return the input untouched.
// Every step works pixel by pixel, so the steps run on the buffer's 256 px
// tiles across the cores (`LiveParallel`) and the tiles go back in place: the
// same pixels as one pass over the whole buffer, a fraction of the time. A
// buffer with fewer tiles than cores (the 512 px preview has four) runs in one
// band of rows per core instead (each band pays the steps' setup again, so no
// more), copied out and back pixel by pixel.
// The histogram is CoreRaster's counts, 256 bins over the sRGB values of the
// buffer it is given (the rendered one), counted by `LiveHistogram`. A slider in `waiting` throws
// `.renderFailed` with its reason; none waits today. After
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
    /// Sliders the live renderer can't draw yet, with the reason the row shows; empty since DV-12.
    public static let waiting: [DevelopSlider: String] = [:]

    /// The steps `settings` needs, in render order; empty when neutral.
    public enum Pass: Equatable, Sendable {
        /// One CoreRender step.
        case shared(ToneAdjustment)
    }

    public init() {}

    /// `ToneRules`' slider steps (Saturation left to the shared list, so it
    /// runs after the curve), vibrance, then `ImagingProgram`'s levels, curve and saturation.
    public static func passes(for s: DevelopSettings) -> [Pass] {
        steps(for: s).map(Pass.shared)
    }

    /// `passes(for:)` as the steps the loupe's GPU route writes, in the same order (suite-imaging IM-11).
    public static func steps(for s: DevelopSettings) -> [ToneAdjustment] {
        var adjust = s.adjustSettings
        adjust.exposure = 0
        var tone = ToneRules.adjustments(s.tone.setting(.saturation, to: 0))
        // ToneRules still holds vibrance back for Photo; CoreRender draws it on both backends.
        if s.vibrance != 0 { tone.append(.vibrance(Float(s.vibrance))) }
        return ImagingProgram.adjustments(adjust, tone: tone)
    }

    /// What the loupe's GPU route writes in one display pass: `steps`, then the kinds (Black & White, Invert) as
    /// `AdjustKinds.program`, the GPU twin of the CPU steps `render` appends.
    public static func program(for s: DevelopSettings) -> [ToneProgram.Operation] {
        steps(for: s).map(ToneProgram.Operation.adjustment) + AdjustKinds.program(s.kinds)
    }

    public func render(_ buffer: PixelBuffer, settings: DevelopSettings) throws -> PixelBuffer {
        for slider in DevelopSlider.allCases where settings.value(slider) != 0 {
            if let why = Self.waiting[slider] { throw LibraryError.renderFailed(why) }
        }
        var b = try Self.run(Self.steps(for: settings) + AdjustKinds.adjustments(settings.kinds), on: buffer)
        b = b.oriented(settings.orientation)
        guard let crop = settings.crop else { return b }
        do {
            let turned = crop.angle == 0 ? b : try b.rotated(degrees: crop.angle, filter: .lanczos3)
            let f = try LiveCrop().frame(crop, photo: PixelSize(width: b.width, height: b.height))
            return try turned.cropped(x: f.x, y: f.y, width: f.width, height: f.height)
        } catch is RasterError {
            throw LibraryError.renderFailed("the crop doesn't fit the photo")
        }
    }

    /// `steps` on `b`, tile by tile (or band by band) across the cores; none returns `b` untouched.
    static func run(_ steps: [ToneAdjustment], on b: PixelBuffer) throws -> PixelBuffer {
        guard !steps.isEmpty else { return b }
        let columns = b.tileColumns, cores = ProcessInfo.processInfo.activeProcessorCount
        do {
            if columns * b.tileRows < cores { return try banded(steps, on: b, bands: min(cores, b.height)) }
            let tiles = try LiveParallel.run(columns * b.tileRows) { i in
                try serial(steps, on: try b.tile(column: i % columns, row: i / columns))
            }
            var out = b
            for (i, tile) in tiles.enumerated() { try out.replaceTile(column: i % columns, row: i / columns, with: tile) }
            return out
        } catch {
            throw LibraryError.renderFailed("the renderer couldn't apply its develop settings")
        }
    }

    /// `steps` on `b` in `bands` bands of rows across the cores, each copied out, developed and copied back.
    static func banded(_ steps: [ToneAdjustment], on b: PixelBuffer, bands: Int) throws -> PixelBuffer {
        let rows = (b.height + bands - 1) / max(bands, 1), width = b.width
        let parts = try LiveParallel.run((b.height + rows - 1) / rows) { i in
            let top = i * rows, height = min(rows, b.height - top)
            var band = try PixelBuffer(width: width, height: height)
            for y in 0..<height { for x in 0..<width { try band.setPixel(x: x, y: y, b.pixel(x: x, y: top + y)) } }
            return try serial(steps, on: band)
        }
        var out = b
        for (i, band) in parts.enumerated() {
            for y in 0..<band.height { for x in 0..<width { try out.setPixel(x: x, y: i * rows + y, band.pixel(x: x, y: y)) } }
        }
        return out
    }

    /// `steps` on `b` through CoreRender's CPU backend, on one surface read once; none returns `b` untouched.
    static func serial(_ steps: [ToneAdjustment], on b: PixelBuffer) throws -> PixelBuffer {
        guard !steps.isEmpty else { return b }
        do {
            let cpu = CPUBackend()
            var s = try cpu.surface(b)
            for step in steps {
                let next = try cpu.adjusted(s, step)
                cpu.release(s)
                s = next
            }
            defer { cpu.release(s) }
            return try cpu.read(s)
        } catch {
            throw LibraryError.renderFailed("the renderer couldn't apply its develop settings")
        }
    }

    public func histogram(of buffer: PixelBuffer) throws -> HistogramBins {
        try LiveHistogram.histogram(of: buffer)
    }
}

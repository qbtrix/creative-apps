// Live/LiveDevelop.swift: the live develop renderer (develop packet DV-6).
// A photo's settings become the CoreRaster calls they need, in one fixed
// order: white balance, exposure, contrast, highlights and shadows, whites
// and blacks, the tone curve, levels. A control at its neutral value runs no
// pass, so neutral settings return the input untouched. The histogram is
// CoreRaster's, 256 bins over the sRGB values of the buffer it is given (the
// rendered one). Vibrance and Saturation wait on creative-core (`waiting`):
// a render that needs either throws `.renderFailed` with that reason. After
// the tone, a crop (crop CR-4) turns the buffer by its angle and cuts
// `LiveCrop`'s frame for the buffer's own size out of the turned pixels.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

public struct LiveDevelop: DevelopRendering {
    public static let unavailable: String? = nil
    /// Sliders the live renderer can't draw yet, with the reason the row shows.
    /// DV-12 empties it once CoreRaster's vibrance and saturation reach `dev`.
    public static let waiting: [DevelopSlider: String] = [
        .vibrance: "Vibrance waits on creative-core (CoreRaster vibrance)",
        .saturation: "Saturation waits on creative-core (CoreRaster saturation)",
    ]

    /// The CoreRaster calls `settings` needs, in render order; empty when neutral.
    public enum Pass: Hashable, Sendable {
        case whiteBalance(temperature: Float, tint: Float), exposure(Float), contrast(Float)
        case highlightsShadows(highlights: Float, shadows: Float)
        case whitesBlacks(inBlack: Float, inWhite: Float, outBlack: Float, outWhite: Float)
        case color(vibrance: Float, saturation: Float)                  // DV-12
        case curve([DevelopCurvePoint]), levels(DevelopLevels)
    }

    public init() {}

    public static func passes(for s: DevelopSettings) -> [Pass] {
        var p: [Pass] = []
        if s.temperature != 0 || s.tint != 0 { p.append(.whiteBalance(temperature: Float(s.temperature), tint: Float(s.tint))) }
        if s.exposure != 0 { p.append(.exposure(Float(s.exposure))) }
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
        if !s.curve.isIdentity { p.append(.curve(s.curve.points)) }
        if s.levels != .neutral { p.append(.levels(s.levels)) }
        return p
    }

    public func render(_ buffer: PixelBuffer, settings: DevelopSettings) throws -> PixelBuffer {
        for slider in DevelopSlider.allCases where settings.value(slider) != 0 {
            if let why = Self.waiting[slider] { throw LibraryError.renderFailed(why) }
        }
        var b = buffer
        for pass in Self.passes(for: settings) {
            do { b = try Self.run(pass, on: b) } catch let error as RasterError {
                throw LibraryError.renderFailed("\(error)")
            }
        }
        guard let crop = settings.crop else { return b }
        do {
            let turned = crop.angle == 0 ? b : try b.rotated(degrees: crop.angle, filter: .lanczos3)
            let f = try LiveCrop().frame(crop, photo: PixelSize(width: buffer.width, height: buffer.height))
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

    /// `pass`'s one CoreRaster call; whites and blacks, the curve and levels act on sRGB values.
    private static func run(_ pass: Pass, on b: PixelBuffer) throws -> PixelBuffer {
        switch pass {
        case .whiteBalance(let temperature, let tint): try b.whiteBalance(temperature: temperature, tint: tint)
        case .exposure(let stops): try b.exposure(stops: stops)
        case .contrast(let amount): try b.contrast(amount)
        case .highlightsShadows(let highlights, let shadows): try b.highlightsShadows(highlights: highlights, shadows: shadows)
        case .whitesBlacks(let inBlack, let inWhite, let outBlack, let outWhite):
            try b.levels(inBlack: inBlack, inWhite: inWhite, gamma: 1, outBlack: outBlack, outWhite: outWhite, encoding: .sRGB)
        case .color: throw LibraryError.renderFailed(waiting[.vibrance] ?? "Vibrance isn't built yet")
        case .curve(let points):
            try b.curves(points: points.map { CurvePoint(x: Float($0.x), y: Float($0.y)) }, encoding: .sRGB)
        case .levels(let l):
            try b.levels(inBlack: Float(l.inBlack), inWhite: Float(l.inWhite), gamma: Float(l.gamma),
                         outBlack: Float(l.outBlack), outWhite: Float(l.outWhite), encoding: .sRGB)
        }
    }
}

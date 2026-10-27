// FilterRules.swift (adjust-everywhere AJ-1 stubs, AJ-5f bodies): the five
// filters over creative-core. `apply` runs core's op on the covered rectangle
// padded by the op's reach (3 sigma for a blur, the distance for motion), then
// mixes result and input by the selection's coverage, so a pixel with coverage
// 0 is copied, never recomputed. Add Noise hashes (x, y, seed, channel), so a
// script repeats exactly. `preview` runs the same filter on a copy whose
// longest side is at most `longestSide`. Linux-safe.
import CoreColor
import CoreRaster
import SuiteKernel

/// The filters' pixel rules.
public enum FilterRules {
    /// The longest side of the copy a sheet's Preview filters.
    public static let previewSide = 1024

    /// One pass of `f` over `pixels`, only where `coverage` is above 0 and mixed by it; nil coverage is
    /// everywhere. Throws for a coverage of another size, or core's error for a picture it can't filter.
    public static func apply(_ f: ImagingFilter, to pixels: PixelBuffer, coverage: Mask?) throws -> PixelBuffer {
        if let coverage, coverage.width != pixels.width || coverage.height != pixels.height {
            throw RasterError.invalid("filter coverage \(coverage.width)x\(coverage.height): must be \(pixels.width)x\(pixels.height)")
        }
        let cover = coverage
        guard let covered = try bounds(cover, pixels) else { return pixels }
        let m = reach(f, pixels)
        let x0 = max(covered.x0 - m, 0), y0 = max(covered.y0 - m, 0)
        let x1 = min(covered.x1 + m, pixels.width), y1 = min(covered.y1 + m, pixels.height)
        let padded = try pixels.cropped(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
        let done = try run(f, padded, x: x0, y: y0)
        var out = pixels
        for y in covered.y0..<covered.y1 {
            for x in covered.x0..<covered.x1 {
                let c = try cover?.coverage(x: x, y: y) ?? 1
                guard c > 0 else { continue }
                let a = try pixels.pixel(x: x, y: y), b = try done.pixel(x: x - x0, y: y - y0)
                try out.setPixel(x: x, y: y, c >= 1 ? b : RGBA(r: a.r + (b.r - a.r) * c, g: a.g + (b.g - a.g) * c,
                                                               b: a.b + (b.b - a.b) * c, a: a.a + (b.a - a.a) * c))
            }
        }
        return out
    }

    /// `apply` on a copy of `pixels` and `coverage` scaled so the longest side is at most `longestSide`.
    public static func preview(_ f: ImagingFilter, to pixels: PixelBuffer, coverage: Mask?,
                               longestSide: Int = previewSide) throws -> PixelBuffer {
        let side = max(pixels.width, pixels.height)
        guard longestSide > 0, side > longestSide else { return try apply(f, to: pixels, coverage: coverage) }
        let scale = Double(longestSide) / Double(side)
        let w = max(1, Int((Double(pixels.width) * scale).rounded())), h = max(1, Int((Double(pixels.height) * scale).rounded()))
        let small = try pixels.resized(width: w, height: h, filter: .bilinear)
        guard let coverage else { return try apply(f.scaled(scale), to: small, coverage: nil) }
        // The coverage sampled at each small pixel's source, carried as alpha into core's mask reader.
        var cells = try PixelBuffer(width: w, height: h)
        for y in 0..<h {
            for x in 0..<w {
                let sx = min(Int(Double(x) / scale), coverage.width - 1), sy = min(Int(Double(y) / scale), coverage.height - 1)
                try cells.setPixel(x: x, y: y, RGBA(r: 0, g: 0, b: 0, a: coverage.coverage(x: sx, y: sy)))
            }
        }
        return try apply(f.scaled(scale), to: small, coverage: Mask(from: cells, .alpha))
    }

    /// The smallest rectangle holding every pixel with coverage above 0 (the whole picture for nil); nil when none.
    static func bounds(_ coverage: Mask?, _ p: PixelBuffer) throws -> (x0: Int, y0: Int, x1: Int, y1: Int)? {
        guard let coverage else { return (0, 0, p.width, p.height) }
        var r = (x0: p.width, y0: p.height, x1: 0, y1: 0)
        for y in 0..<coverage.height {
            for x in 0..<coverage.width where try coverage.coverage(x: x, y: y) > 0 {
                r = (min(r.x0, x), min(r.y0, y), max(r.x1, x + 1), max(r.y1, y + 1))
            }
        }
        return r.x1 > r.x0 ? r : nil
    }

    /// How far past a pixel `f` reads, in whole pixels.
    static func reach(_ f: ImagingFilter, _ p: PixelBuffer) -> Int {
        switch f {
        case .gaussianBlur(let radius): Int((3 * sigma(radius, p)).rounded(.up))
        case .motionBlur(_, let distance): Int(clamped(distance, ImagingFilter.motionDistance).rounded(.up))
        case .sharpen(_, let radius, _): Int((3 * sigma(radius, p)).rounded(.up))
        case .reduceNoise: 8
        case .addNoise: 0
        }
    }

    /// Core's op for `f` on `p`, whose top-left pixel is (`x`, `y`) of the layer (Add Noise hashes layer coordinates).
    static func run(_ f: ImagingFilter, _ p: PixelBuffer, x: Int, y: Int) throws -> PixelBuffer {
        switch f {
        case .gaussianBlur(let radius):
            return try p.gaussianBlur(sigma: sigma(radius, p))
        case .motionBlur(let degrees, let distance):
            return try p.motionBlurred(degrees: clamped(degrees, ImagingFilter.motionDegrees),
                                       distance: clamped(distance, ImagingFilter.motionDistance))
        case .sharpen(let amount, let radius, let threshold):
            return try p.unsharpMask(amount: clamped(amount, ImagingFilter.sharpenAmount) / 100, sigma: sigma(radius, p),
                                     threshold: clamped(threshold, ImagingFilter.sharpenThreshold) / 255)
        case .reduceNoise(let strength, let detail):
            return try p.denoised(strength: clamped(strength, ImagingFilter.percent) / 100,
                                  detail: clamped(detail, ImagingFilter.percent) / 100)
        case .addNoise(let amount, let monochrome, let seed):
            return try noise(p, amount: clamped(amount, ImagingFilter.percent) / 100, monochrome: monochrome, seed: seed, x: x, y: y)
        }
    }

    /// `radius` as core's sigma, kept within the reach core allows on `p` (twice its larger side).
    static func sigma(_ radius: Double, _ p: PixelBuffer) -> Double {
        min(clamped(radius, ImagingFilter.blurRadius), Double(2 * max(p.width, p.height)) / 3)
    }

    static func clamped(_ v: Double, _ r: ClosedRange<Double>) -> Double {
        v.isFinite ? min(max(v, r.lowerBound), r.upperBound) : r.lowerBound
    }

    /// Uniform noise in ±`amount` added to each sRGB-encoded channel and clamped to 0...1 (one value for all
    /// three when `monochrome`); alpha 0 pixels are left alone.
    static func noise(_ p: PixelBuffer, amount: Double, monochrome: Bool, seed: UInt64, x: Int, y: Int) throws -> PixelBuffer {
        guard amount > 0 else { return p }
        var out = p
        for row in 0..<p.height {
            for col in 0..<p.width {
                let q = try p.pixel(x: col, y: row)
                guard q.a > 0 else { continue }
                let s = q.unpremultiplied()
                func shifted(_ v: Float, _ channel: UInt64) -> Float {
                    let n = unit(x: col + x, y: row + y, seed: seed, channel: monochrome ? 0 : channel) * 2 - 1
                    let e = min(max(TransferCurve.encode(Double(v)) + n * amount, 0), 1)
                    return Float(TransferCurve.decode(e))
                }
                try out.setPixel(x: col, y: row, RGBA(r: shifted(s.r, 0), g: shifted(s.g, 1), b: shifted(s.b, 2), a: s.a).premultiplied())
            }
        }
        return out
    }

    /// A value in 0...1 from (x, y, seed, channel): SplitMix64's finalizer over the four mixed together.
    static func unit(x: Int, y: Int, seed: UInt64, channel: UInt64) -> Double {
        var z = seed &+ UInt64(bitPattern: Int64(x)) &* 0x9E37_79B9_7F4A_7C15 &+ UInt64(bitPattern: Int64(y)) &* 0xC2B2_AE3D_27D4_EB4F
            &+ channel &* 0x1656_67B1_9E37_79F9
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Double(z >> 11) / Double(1 << 53)
    }
}

extension ImagingFilter {
    /// The filter for a copy scaled by `s`: pixel lengths scale, percents and the seed don't.
    func scaled(_ s: Double) -> ImagingFilter {
        switch self {
        case .gaussianBlur(let r): .gaussianBlur(radius: r * s)
        case .motionBlur(let d, let l): .motionBlur(degrees: d, distance: l * s)
        case .sharpen(let a, let r, let t): .sharpen(amount: a, radius: max(r * s, Self.sharpenRadius.lowerBound), threshold: t)
        case .reduceNoise, .addNoise: self
        }
    }
}

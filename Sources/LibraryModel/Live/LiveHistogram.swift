// Live/LiveHistogram.swift: the develop panel's histogram, the same counts as
// CoreRaster's `Histogram(of:bins: 256, encoding: .sRGB)` bin for bin, made
// fast (quality gate #5953: a 2,048 px render's histogram within 10 ms in
// release). Core encodes every channel of every pixel with `pow`; here a
// table indexed by the top bits of the clamped value's Float bit pattern holds
// the bin of each run of 8,192 neighbouring floats, and only a run that
// straddles two bins pays the encode. Bands of rows count on every core
// (`LiveParallel`). Invariant: `bin(_:)` is core's formula exactly (encode in
// Double, back to Float, times 256, clamped), so the counts match core's; the
// table assumes only that encode never decreases, which a run's two ends check.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
import CoreRaster

enum LiveHistogram {
    private static let bins = HistogramBins.binCount
    private static let shift: UInt32 = 13
    private static let straddles = UInt16.max
    /// The bin of each run of floats in 0...1, or `straddles` when its two ends land in different bins.
    private static let table: [UInt16] = (0...(Float(1).bitPattern >> shift)).map { run in
        let first = Float(bitPattern: run << shift)
        let last = Float(bitPattern: min((run << shift) | ((1 << shift) - 1), Float(1).bitPattern))
        let bin = Self.bin(first)
        return bin == Self.bin(last) ? UInt16(bin) : straddles
    }

    /// Core's bin of a clamped linear value: its sRGB encoding times the bin count, the last bin holding 1.
    static func bin(_ value: Float) -> Int {
        min(max(Int(Float(TransferCurve.encode(Double(value))) * Float(bins)), 0), bins - 1)
    }

    /// `bin(_:)` through the table; a value outside 0...1 (none reaches here: callers clamp) counts in bin 0.
    static func fastBin(_ value: Float) -> Int {
        let run = Int(value.bitPattern >> shift)
        guard run < table.count, value >= 0 else { return 0 }
        let bin = table[run]
        return bin == straddles ? Self.bin(value) : Int(bin)
    }

    private struct Counts: Sendable {
        var rgb = [Int](repeating: 0, count: 3 * HistogramBins.binCount)
        var shadow = 0, highlight = 0
    }

    /// `buffer`'s counts: transparent pixels skipped, clipping read on the unpremultiplied values before the clamp.
    static func histogram(of buffer: PixelBuffer) throws -> HistogramBins {
        let band = 64, width = buffer.width
        let bands = try LiveParallel.run((buffer.height + band - 1) / band) { i in
            var c = Counts()
            for y in (i * band)..<min((i + 1) * band, buffer.height) {
                for x in 0..<width {
                    let p = try buffer.pixel(x: x, y: y)
                    guard p.a != 0 else { continue }
                    let s = p.unpremultiplied()
                    if s.r <= 0 || s.g <= 0 || s.b <= 0 { c.shadow += 1 }
                    if s.r >= 1 || s.g >= 1 || s.b >= 1 { c.highlight += 1 }
                    c.rgb[fastBin(min(max(s.r, 0), 1))] += 1
                    c.rgb[bins + fastBin(min(max(s.g, 0), 1))] += 1
                    c.rgb[2 * bins + fastBin(min(max(s.b, 0), 1))] += 1
                }
            }
            return c
        }
        var all = Counts()
        for c in bands {
            for k in all.rgb.indices { all.rgb[k] += c.rgb[k] }
            all.shadow += c.shadow
            all.highlight += c.highlight
        }
        return HistogramBins(red: Array(all.rgb[0..<bins]), green: Array(all.rgb[bins..<(2 * bins)]),
                             blue: Array(all.rgb[(2 * bins)...]), shadowClipped: all.shadow, highlightClipped: all.highlight)
    }
}

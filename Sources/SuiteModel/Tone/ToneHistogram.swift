// ToneHistogram.swift: the one shape every histogram view draws, and the
// Levels midtone mapping its handles use. Counting pixels is the engine's
// (CoreRaster's `Histogram`); this only turns counts into display heights
// (the tallest bin at 1, every bin 0 when there are no counts, never NaN) plus
// whether any pixel clips at either end, so Library's develop panel, Photo's
// Levels and the tone curve's backdrop read the same values. LevelsMidtone is
// the inverse of the engine's levels curve at half output: with input black b,
// white w and gamma g, the curve gives 0.5 at b + (w - b) * 0.5^g, so the
// midtone handle sits there and a handle moved to x means g = ln t / ln 0.5.
// Linux-safe, Sendable.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

/// Bin heights scaled so the tallest is 1, and whether any pixel clips.
public struct ToneHistogram: Hashable, Sendable {
    /// One height per bin in 0...1; empty when there is nothing to draw.
    public let heights: [Double]
    /// Some pixel sits at or below black (any channel).
    public let clipsShadows: Bool
    /// Some pixel sits at or above white (any channel).
    public let clipsHighlights: Bool

    /// Nothing to draw and nothing clipped.
    public static let empty = ToneHistogram(heights: [], clipsShadows: false, clipsHighlights: false)

    /// Per-bin counts of one or more channels, summed bin by bin (the
    /// shortest channel sets the bin count), scaled so the tallest is 1.
    /// Negative counts count as 0. No counts at all gives `empty`'s heights.
    public init(channels: [[Int]], shadowClipped: Int = 0, highlightClipped: Int = 0) {
        let bins = channels.map(\.count).min() ?? 0
        let sums = (0..<bins).map { bin in channels.reduce(0) { $0 + max($1[bin], 0) } }
        let tallest = Double(sums.max() ?? 0)
        heights = tallest > 0 ? sums.map { Double($0) / tallest } : []
        clipsShadows = shadowClipped > 0
        clipsHighlights = highlightClipped > 0
    }

    public init(heights: [Double], clipsShadows: Bool, clipsHighlights: Bool) {
        self.heights = heights
        self.clipsShadows = clipsShadows
        self.clipsHighlights = clipsHighlights
    }
}

/// Where the Levels midtone handle sits, and the gamma a handle position
/// means, for the engine's levels curve (gamma over 1 brightens).
public enum LevelsMidtone {
    /// The input the levels curve maps to half output: b + (w - b) * 0.5^gamma.
    /// A non-finite or non-positive gamma counts as 1.
    public static func position(black: Double, white: Double, gamma: Double) -> Double {
        let g = gamma.isFinite && gamma > 0 ? gamma : 1
        return black + (white - black) * pow(0.5, g)
    }

    /// The gamma that puts the midtone handle at `position` between `black`
    /// and `white`, clamped to `range`; 1 when the points are not apart or a value isn't finite.
    public static func gamma(at position: Double, black: Double, white: Double, in range: ClosedRange<Double>) -> Double {
        let span = white - black
        guard span > 0, position.isFinite, black.isFinite else { return min(max(1, range.lowerBound), range.upperBound) }
        let t = min(max((position - black) / span, 1e-6), 1 - 1e-6)
        return min(max(log(t) / log(0.5), range.lowerBound), range.upperBound)
    }
}

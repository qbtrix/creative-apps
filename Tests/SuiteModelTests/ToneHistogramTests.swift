// ToneHistogramTests.swift: SuiteModel's ToneHistogram (channels summed per
// bin, the tallest at 1, never NaN, clip flags from counts) and LevelsMidtone
// (the midtone handle at the input levels maps to half, and back). #3633.
import SuiteModel
import Testing

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

@Test func channelsSumPerBinWithTheTallestAtOne() {
    let counts: [[Int]] = [[1, 0, 3], [1, 2, 3]]
    let shape = ToneHistogram(channels: counts, shadowClipped: 0, highlightClipped: 4)
    let expected: [Double] = [2.0 / 6, 2.0 / 6, 1]
    #expect(shape.heights == expected)
    #expect(!shape.clipsShadows && shape.clipsHighlights)
}

@Test func noCountsDrawNothingAndNeverNaN() {
    let zeros: [[Int]] = [[0, 0], [0, 0]], negative: [[Int]] = [[-5, 2]], ragged: [[Int]] = [[3, 1, 9], [1]]
    let clampedNegative: [Double] = [0, 1], shortest: [Double] = [1]
    #expect(ToneHistogram(channels: zeros).heights.isEmpty)
    #expect(ToneHistogram(channels: []).heights.isEmpty)
    #expect(ToneHistogram(channels: negative).heights == clampedNegative)
    #expect(ToneHistogram(channels: ragged).heights == shortest)
    #expect(ToneHistogram.empty == ToneHistogram(channels: []))
}

@Test func midtoneSitsWhereLevelsGivesHalf() {
    #expect(LevelsMidtone.position(black: 0, white: 1, gamma: 1) == 0.5)
    #expect(abs(LevelsMidtone.position(black: 0.2, white: 0.6, gamma: 1) - 0.4) < 1e-12)
    // Gamma over 1 brightens, so half output comes from a darker input: the handle moves left.
    #expect(abs(LevelsMidtone.position(black: 0, white: 1, gamma: 2) - 0.25) < 1e-12)
    #expect(LevelsMidtone.position(black: 0, white: 1, gamma: .nan) == 0.5)
    // The engine's curve, (t)^(1/g), gives half at the handle.
    let (b, w, g) = (0.1, 0.9, 1.7)
    let t = (LevelsMidtone.position(black: b, white: w, gamma: g) - b) / (w - b)
    #expect(abs(pow(t, 1 / g) - 0.5) < 1e-12)
}

@Test func aMidtonePositionIsTheGammaThatPutsItThere() {
    let range = 0.1...9.99
    for g in [0.5, 1, 2.5] {
        let x = LevelsMidtone.position(black: 0.1, white: 0.8, gamma: g)
        #expect(abs(LevelsMidtone.gamma(at: x, black: 0.1, white: 0.8, in: range) - g) < 1e-9)
    }
    #expect(LevelsMidtone.gamma(at: 0, black: 0, white: 1, in: range) == 9.99)
    #expect(LevelsMidtone.gamma(at: 1, black: 0, white: 1, in: range) == 0.1)
    #expect(LevelsMidtone.gamma(at: 0.5, black: 0.5, white: 0.5, in: range) == 1)
    #expect(LevelsMidtone.gamma(at: .nan, black: 0, white: 1, in: range) == 1)
}

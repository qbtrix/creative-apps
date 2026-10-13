// FrameMappingEdgeTests.swift: edge cases for the frame arithmetic behind
// TimelineStrip: round trips across widths, non-finite x, the label interval
// over a sweep of widths, and keyframe hit-testing ties and out-of-range
// keyframes. No SwiftUI. macOS only.
import SuiteUI
import Testing

@Test(arguments: [0.5, 1, 3, 7.5, 10, 48])
func everyFrameRoundTripsThroughItsX(frameWidth: Double) {
    let mapping = FrameMapping(duration: 240, frameWidth: frameWidth)
    for frame in 0...240 {
        #expect(mapping.frame(atX: mapping.x(forFrame: frame)) == frame)
    }
}

@Test func nonFiniteXStaysInsideTheDuration() {
    let mapping = FrameMapping(duration: 48, frameWidth: 10)
    #expect(mapping.frame(atX: -.infinity) == 0)
    #expect(mapping.frame(atX: .nan) == 0)
    #expect(mapping.frame(atX: -0.0) == 0)
}

@Test func xHalfwayBetweenTicksRoundsAwayFromZero() {
    let mapping = FrameMapping(duration: 48, frameWidth: 10)
    #expect(mapping.frame(atX: 5) == 1)
    #expect(mapping.frame(atX: 4.999) == 0)
    #expect(mapping.frame(atX: 475) == 48)
}

@Test func infiniteFrameWidthCountsAsZero() {
    let mapping = FrameMapping(duration: 48, frameWidth: .infinity)
    #expect(mapping.frameWidth == 0)
    #expect(mapping.contentWidth == 0)
    #expect(mapping.frame(atX: 100) == 0)
}

@Test func zeroDurationHoldsOnlyFrameZero() {
    let mapping = FrameMapping(duration: 0, frameWidth: 10)
    #expect(mapping.contentWidth == 0)
    #expect(mapping.clamp(5) == 0)
    #expect(mapping.frame(atX: 500) == 0)
    #expect(mapping.labelInterval(minimumSpacing: 48) == 1)
}

@Test func labelIntervalIsPositiveAndNeverShrinksAsFramesNarrow() {
    var previous = 1
    for width in stride(from: 64.0, through: 0.05, by: -0.05) {
        let interval = FrameMapping(duration: 10_000, frameWidth: width).labelInterval(minimumSpacing: 48)
        #expect(interval >= previous)
        #expect([1, 2, 5].contains(interval / Int(pow10(below: interval))))
        previous = interval
    }
}

@Test func labelIntervalLeavesAtLeastTheMinimumSpacing() {
    for width in [0.3, 1.0, 2.5, 4.0, 9.6, 24.0, 47.9] {
        let mapping = FrameMapping(duration: 100_000, frameWidth: width)
        #expect(Double(mapping.labelInterval(minimumSpacing: 48)) * width >= 48)
    }
}

@Test func keyframeTieGoesToTheEarlierFrameInTheList() {
    let mapping = FrameMapping(duration: 100, frameWidth: 10)
    #expect(mapping.keyframe(nearX: 105, in: [10, 11], tolerance: 6) == 10)
    #expect(mapping.keyframe(nearX: 105, in: [11, 10], tolerance: 6) == 11)
}

@Test func keyframeToleranceIsInclusiveAndNegativeMatchesNothing() {
    let mapping = FrameMapping(duration: 100, frameWidth: 10)
    #expect(mapping.keyframe(nearX: 106, in: [10], tolerance: 6) == 10)
    #expect(mapping.keyframe(nearX: 106.01, in: [10], tolerance: 6) == nil)
    #expect(mapping.keyframe(nearX: 100, in: [10], tolerance: -1) == nil)
}

@Test func keyframeBelowZeroComesBackAsFrameZero() {
    let mapping = FrameMapping(duration: 100, frameWidth: 10)
    #expect(mapping.keyframe(nearX: 0, in: [-5], tolerance: 6) == 0)
    #expect(mapping.keyframe(nearX: 3, in: [Int.min], tolerance: 6) == 0)
    #expect(mapping.keyframe(nearX: 50, in: [-5], tolerance: 6) == nil)
}

@Test func keyframeAboveTheDurationComesBackAsTheDuration() {
    let mapping = FrameMapping(duration: 100, frameWidth: 10)
    #expect(mapping.keyframe(nearX: 1000, in: [250], tolerance: 6) == 100)
    #expect(mapping.keyframe(nearX: 997, in: [Int.max], tolerance: 6) == 100)
    #expect(mapping.keyframe(nearX: 900, in: [250], tolerance: 6) == nil)
}

@Test func keyframeHitIsAlwaysInsideTheDuration() {
    let mapping = FrameMapping(duration: 48, frameWidth: 10)
    let keyframes = [-1_000, -1, 0, 24, 48, 49, 10_000]
    for x in stride(from: -100.0, through: 600, by: 2.5) {
        if let frame = mapping.keyframe(nearX: x, in: keyframes, tolerance: 6) {
            #expect((0...48).contains(frame))
        }
    }
}

/// The largest power of ten at or below `n`.
private func pow10(below n: Int) -> Int {
    var power = 1
    while power <= n / 10 { power *= 10 }
    return power
}

// FrameMappingTests.swift: the frame arithmetic behind TimelineStrip. No
// SwiftUI here: FrameMapping is plain Swift. macOS only.
import SuiteUI
import Testing

@Test func frameMapsToItsTickX() {
    let mapping = FrameMapping(duration: 100, frameWidth: 8)
    #expect(mapping.x(forFrame: 0) == 0)
    #expect(mapping.x(forFrame: 12) == 96)
    #expect(mapping.contentWidth == 800)
}

@Test func xMapsToTheNearestFrame() {
    let mapping = FrameMapping(duration: 100, frameWidth: 8)
    #expect(mapping.frame(atX: 96) == 12)
    #expect(mapping.frame(atX: 99.9) == 12)
    #expect(mapping.frame(atX: 100) == 13)
    #expect(mapping.frame(atX: 3.9) == 0)
}

@Test func framesClampToZeroThroughDuration() {
    let mapping = FrameMapping(duration: 48, frameWidth: 10)
    #expect(mapping.frame(atX: -50) == 0)
    #expect(mapping.frame(atX: 10_000) == 48)
    #expect(mapping.frame(atX: .infinity) == 48)
    #expect(mapping.x(forFrame: -3) == 0)
    #expect(mapping.x(forFrame: 60) == 480)
    #expect(mapping.clamp(49) == 48)
}

@Test func zeroFrameWidthDoesNotDivideByZero() {
    let mapping = FrameMapping(duration: 48, frameWidth: 0)
    #expect(mapping.frame(atX: 120) == 0)
    #expect(mapping.x(forFrame: 20) == 0)
    #expect(FrameMapping(duration: 48, frameWidth: .nan).frame(atX: 5) == 0)
    #expect(FrameMapping(duration: 48, frameWidth: -4).frameWidth == 0)
}

@Test func negativeDurationCountsAsZero() {
    let mapping = FrameMapping(duration: -5, frameWidth: 10)
    #expect(mapping.duration == 0)
    #expect(mapping.frame(atX: 40) == 0)
}

@Test func labelIntervalGrowsAsFramesNarrow() {
    #expect(FrameMapping(duration: 240, frameWidth: 48).labelInterval(minimumSpacing: 48) == 1)
    #expect(FrameMapping(duration: 240, frameWidth: 20).labelInterval(minimumSpacing: 48) == 5)
    #expect(FrameMapping(duration: 240, frameWidth: 4).labelInterval(minimumSpacing: 48) == 20)
}

@Test func labelIntervalNeverRunsAwayOnAZeroWidth() {
    #expect(FrameMapping(duration: 30, frameWidth: 0).labelInterval(minimumSpacing: 48) == 50)
    #expect(FrameMapping(duration: 0, frameWidth: 0).labelInterval(minimumSpacing: 48) == 1)
    #expect(FrameMapping(duration: .max, frameWidth: 0).labelInterval(minimumSpacing: 48) == .max)
}

@Test func clickNearADiamondPicksTheNearestKeyframe() {
    let mapping = FrameMapping(duration: 100, frameWidth: 10)
    #expect(mapping.keyframe(nearX: 103, in: [0, 10, 11], tolerance: 6) == 10)
    #expect(mapping.keyframe(nearX: 108, in: [0, 10, 11], tolerance: 6) == 11)
    #expect(mapping.keyframe(nearX: 50, in: [0, 10, 11], tolerance: 6) == nil)
    #expect(mapping.keyframe(nearX: 50, in: [], tolerance: 6) == nil)
}

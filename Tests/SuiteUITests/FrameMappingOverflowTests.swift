// FrameMappingOverflowTests.swift: frame(atX:) with a duration near Int.max,
// where Double(duration) rounds up past Int.max. No SwiftUI. macOS only.
import SuiteUI
import Testing

@Test(arguments: [Int.max, Int.max - 1])
func frameAtXNeverTrapsNearIntMax(duration: Int) {
    let mapping = FrameMapping(duration: duration, frameWidth: 10)
    #expect(mapping.frame(atX: 0) == 0)
    #expect(mapping.frame(atX: -1) == 0)
    #expect(mapping.frame(atX: mapping.contentWidth) == duration)
    #expect(mapping.frame(atX: .greatestFiniteMagnitude) == duration)
    #expect(mapping.frame(atX: .infinity) == duration)
    #expect(mapping.frame(atX: 50) == 5)
}

@Test(arguments: [Int.max, Int.max - 1])
func tinyFrameWidthNearIntMaxStaysInsideTheDuration(duration: Int) {
    let mapping = FrameMapping(duration: duration, frameWidth: .leastNonzeroMagnitude)
    #expect(mapping.frame(atX: 1) == duration)
    #expect(mapping.frame(atX: 0) == 0)
}

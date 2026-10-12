// FrameMappingSweepTests.swift: frame(atX:) over durations around 2^53 and
// Int.max, frame widths from subnormal to the largest Double, and x from -inf
// to +inf. The frame always lands in 0...duration and never goes back as x
// grows. No SwiftUI. macOS only.
import SuiteUI
import Testing

private let sweepDurations = [
    0, 1, 48, (1 << 53) - 1, 1 << 53, (1 << 53) + 1, 1 << 62,
    Int.max / 2, Int.max - 1024, Int.max - 512, Int.max - 1, Int.max,
]

private let sweepWidths: [Double] = [
    .leastNonzeroMagnitude, 1e-300, 1e-9, 0.5, 1, 10, 1e300, .greatestFiniteMagnitude,
]

@Test(arguments: sweepDurations)
func frameAtXStaysInsideTheDurationAndNeverGoesBack(duration: Int) {
    for width in sweepWidths {
        let mapping = FrameMapping(duration: duration, frameWidth: width)
        let end = mapping.contentWidth
        let xs: [Double] = [
            -.infinity, -.greatestFiniteMagnitude, -1, -0.0, 0, width, end / 2, end, end.nextUp,
            1e300, .greatestFiniteMagnitude, .infinity,
        ].sorted()
        var previous = 0
        for x in xs {
            let frame = mapping.frame(atX: x)
            #expect((0...duration).contains(frame), "duration \(duration), width \(width), x \(x)")
            #expect(frame >= previous, "duration \(duration), width \(width), x \(x)")
            previous = frame
        }
        #expect(mapping.frame(atX: .infinity) == duration)
    }
}

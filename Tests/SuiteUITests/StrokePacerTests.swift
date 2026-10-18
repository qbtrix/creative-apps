// StrokePacerTests.swift: the pacer's spacing and batching, pen pressure and
// the brush ring's size at the zoom (EK-30, #953).
import Foundation
import Testing

@testable import SuiteUI

@Suite struct StrokePacerTests {
    @Test func spacingIsHalfAFrame() {
        #expect(StrokePacing.spacing(framesPerSecond: 60) == .microseconds(8333))
        #expect(StrokePacing.spacing(framesPerSecond: 120) == .microseconds(4166))
        #expect(StrokePacing.spacing(framesPerSecond: 0) == .microseconds(500_000))
    }

    @MainActor @Test func quickSamplesWaitTogetherInOrder() {
        let pacer = SuiteStrokePacer<Int>(spacing: .milliseconds(50))
        var calls: [[Int]] = []
        for x in 0..<3 { pacer.add(x) { calls.append($0) } }
        #expect(calls == [[0]])
        pacer.stop()
        #expect(calls == [[0], [1, 2]])
    }

    @Test func pressureAndRing() {
        let read = SuitePointerPressure.reading
        #expect(read(true, 1.5) == 1 && read(true, 0.25) == 0.25 && read(true, .nan) == 1 && read(false, 0.1) == 1)
        for (zoom, side) in [(0.25, 16.0), (1, 64), (4, 256)] {
            let ring = BrushCursorMark.frame(point: CGPoint(x: 40, y: 20), diameter: 64, zoom: zoom)
            #expect(ring?.width == CGFloat(side) && ring?.midX == CGFloat(40 * zoom) && ring?.midY == CGFloat(20 * zoom))
        }
        #expect(BrushCursorMark.frame(point: nil, diameter: 64, zoom: 1) == nil)
    }
}

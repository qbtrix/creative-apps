// PhotoStrokePacerTests.swift: StrokePacer hands the window's drag samples to
// the workspace in order, everything that waited for a display frame in one
// call, and the frame's display link does it unasked (when the display is
// awake to show frames). Without a screen each sample applies at once. macOS
// only.
import AppKit
import CoreRaster
import PhotoModel
import Testing

@testable import PhotoApp

@MainActor @Suite struct PhotoStrokePacerTests {
    @Test func samplesWaitingForAFrameArriveTogetherInOrder() {
        let pacer = StrokePacer()
        var calls: [[Double]] = []
        for x in 0..<3 {
            let move = (from: Mask.Point(x: Double(x), y: 0), to: Mask.Point(x: Double(x) + 1, y: 0), pressure: 1.0)
            pacer.add(move) { calls.append($0.map(\.from.x)) }
        }
        if NSScreen.main == nil {
            #expect(calls == [[0], [1], [2]])
        } else {
            #expect(calls.isEmpty)
            if CGDisplayIsAsleep(CGMainDisplayID()) == 0 {
                // The display link runs on the main run loop; a frame is at most 1/24 s.
                for _ in 0..<50 where calls.isEmpty { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
            } else {
                pacer.flush()  // A sleeping display (a locked Mac) shows no frames.
            }
            #expect(calls == [[0, 1, 2]])
        }
        pacer.add((from: Mask.Point(x: 3, y: 0), to: Mask.Point(x: 4, y: 0), pressure: 1)) { calls.append($0.map(\.from.x)) }
        pacer.stop()
        pacer.flush()
        #expect(calls.flatMap { $0 } == [0, 1, 2, 3])
    }
}

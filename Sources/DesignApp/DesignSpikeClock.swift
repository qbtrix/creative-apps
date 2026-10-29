// DesignSpikeClock.swift: SPIKE (spike/one-document, never merged). The playhead the canvas paints at, and a
// 120 Hz player over SuiteKernel's PlaybackTiming. nil (the default) is today's canvas: rest pose, no sampling.
// Setting `frame` also sets DesignWorkspace.spikePlayhead so hit-testing samples the same tree. No product UI.
import DesignModel
import Foundation
import Observation
import SuiteKernel

@MainActor @Observable final class DesignSpikeClock {
    static let shared = DesignSpikeClock()
    var frame: Double? { didSet { DesignWorkspace.spikePlayhead = frame } }
    @ObservationIgnored private var timer: Timer?

    /// Plays frames 0...durationFrames-1 at DesignNodeTime.rate, looping, ticked at 120 Hz.
    // ponytail: Timer stands in for a display link; the spike's tests step frames themselves.
    func play(durationFrames: Int = 121) {
        let began = Date()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 120, repeats: true) { _ in
            MainActor.assumeIsolated {
                let tick = PlaybackTiming.tick(startFrame: 0, elapsed: Date().timeIntervalSince(began),
                                               rate: DesignNodeTime.rate, durationFrames: durationFrames, mode: .once)
                DesignSpikeClock.shared.frame = Double(tick.frame)
            }
        }
    }

    func stop() { timer?.invalidate(); timer = nil; frame = nil }
}

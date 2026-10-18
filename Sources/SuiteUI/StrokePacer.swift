// StrokePacer.swift: SuiteStrokePacer hands a canvas drag's samples to the
// editor at most twice a display frame (EK-30; Photo's pacer is the shape). A sample at least
// `spacing` after the last apply applies at once; quicker ones wait and apply
// together, in order, from the main run loop. `stop()` flushes at drag end.
import AppKit

public enum StrokePacing {
    public static func spacing(framesPerSecond: Int) -> Duration { .microseconds(500_000 / max(framesPerSecond, 1)) }
}

@MainActor public final class SuiteStrokePacer<Move> {
    private var waiting: [Move] = [], apply: ([Move]) -> Void = { _ in }
    private var lastApply: ContinuousClock.Instant?, timerSet = false
    public let spacing: Duration

    public init(spacing: Duration? = nil) {
        self.spacing = spacing ?? StrokePacing.spacing(framesPerSecond: NSScreen.main?.maximumFramesPerSecond ?? 60)
    }

    public func add(_ move: Move, apply: @escaping ([Move]) -> Void) {
        self.apply = apply
        waiting.append(move)
        guard let last = lastApply, ContinuousClock.now - last < spacing else { return flush() }
        guard !timerSet else { return }
        timerSet = true
        let wait = (spacing - (ContinuousClock.now - last)) / .seconds(1)
        RunLoop.main.add(
            Timer(timeInterval: max(wait, 0), repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.timerSet = false; self?.flush() }
            }, forMode: .common)
    }

    public func flush() {
        guard !waiting.isEmpty else { return }
        let batch = waiting
        (waiting, lastApply) = ([], .now)
        apply(batch)
    }

    public func stop() { flush(); lastApply = nil }
}

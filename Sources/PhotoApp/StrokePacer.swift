// StrokePacer.swift: hands canvas drag samples to the workspace as soon as it
// can, at most twice a display frame. While drawing, AppKit's mouse coalescing
// is off, so samples can arrive faster than the screen refreshes (a tablet
// sends 200 or more a second), and each workspace write re-runs the window's
// views and moves the revision. A sample that arrives at least `spacing`
// (half the screen's fastest frame) after the last apply is applied at once,
// so its ink starts on its way within the frame it arrived in; one that comes
// sooner waits with any others until `spacing` has passed, and they are
// applied together as one `drags` call. The pacer keeps each sample with the
// pen pressure and the modifier keys (DragModifiers) it arrived with, never
// merged across samples. `flush()` applies what is waiting now; the window
// calls it before every other intent, so nothing lands out of order, and
// `stop()` flushes at the drag's end. Presentation state only.
import AppKit
import CoreRaster
import PhotoModel

@MainActor final class StrokePacer: NSObject {
    typealias Move = (from: Mask.Point, to: Mask.Point, pressure: Double, modifiers: DragModifiers)
    private var waiting: [Move] = []
    private var apply: ([Move]) -> Void = { _ in }
    private var applied: ContinuousClock.Instant?
    private var scheduled = false
    /// The least time between two applies: half the screen's fastest frame.
    let spacing: Duration

    init(spacing: Duration? = nil) {
        let rate = max(NSScreen.main?.maximumFramesPerSecond ?? 60, 1)
        self.spacing = spacing ?? .microseconds(500_000 / rate)
    }

    /// Applies `move` now, or with every move queued by then once `spacing`
    /// has passed since the last apply.
    func add(_ move: Move, apply: @escaping ([Move]) -> Void) {
        self.apply = apply
        waiting.append(move)
        let since = applied.map { ContinuousClock.now - $0 }
        guard let since, since < spacing else { return flush() }
        guard !scheduled else { return }
        scheduled = true
        let timer = Timer(timeInterval: (spacing - since) / .seconds(1), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.scheduled = false
                self?.flush()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    /// Applies the moves waiting, if any, in order.
    func flush() {
        guard !waiting.isEmpty else { return }
        let moves = waiting
        waiting = []
        applied = .now
        apply(moves)
    }

    /// Applies what is waiting; the next drag's first sample applies at once.
    func stop() {
        flush()
        applied = nil
    }
}

extension DragModifiers {
    /// The keys among `flags` a canvas drag reads: Shift and Option.
    init(flags: NSEvent.ModifierFlags) {
        self.init()
        if flags.contains(.shift) { insert(.shift) }
        if flags.contains(.option) { insert(.option) }
    }
}

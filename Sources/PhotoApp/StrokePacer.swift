// StrokePacer.swift: hands canvas drag samples to the workspace once per
// display frame. While drawing, AppKit's mouse coalescing is off, so samples
// arrive faster than the screen refreshes (a tablet sends 200 or more a
// second), and each workspace write re-runs the window's views and moves the
// revision. The pacer keeps each sample with the pen pressure and the
// modifier keys (DragModifiers) it arrived with, never merged across
// samples, and a display link on the key window's screen applies everything
// that arrived during a frame as one `drags` call, each sample with its own
// keys. `flush()` applies what is waiting now; the window calls it before every other intent, so nothing
// lands out of order, and `stop()` flushes and drops the link at the drag's
// end. Without a screen there is no display link, and each sample applies at
// once. Presentation state only.
import AppKit
import CoreRaster
import PhotoModel

@MainActor final class StrokePacer: NSObject {
    typealias Move = (from: Mask.Point, to: Mask.Point, pressure: Double, modifiers: DragModifiers)
    private var waiting: [Move] = []
    private var apply: ([Move]) -> Void = { _ in }
    private var link: CADisplayLink?

    /// Queues `move` for the next display frame, where `apply` gets it with
    /// every other move queued by then.
    func add(_ move: Move, apply: @escaping ([Move]) -> Void) {
        self.apply = apply
        waiting.append(move)
        if link == nil, let screen = NSScreen.main {
            link = screen.displayLink(target: self, selector: #selector(frame))
            link?.add(to: .main, forMode: .common)
        }
        if link == nil { flush() }
    }

    /// Applies the moves waiting, if any, in order.
    func flush() {
        guard !waiting.isEmpty else { return }
        let moves = waiting
        waiting = []
        apply(moves)
    }

    /// Applies what is waiting and stops the display link.
    func stop() {
        flush()
        link?.invalidate()
        link = nil
    }

    @objc private func frame(_ link: CADisplayLink) { flush() }
}

extension DragModifiers {
    /// The keys among `flags` a canvas drag reads: Shift and Option.
    init(flags: NSEvent.ModifierFlags) {
        self.init()
        if flags.contains(.shift) { insert(.shift) }
        if flags.contains(.option) { insert(.option) }
    }
}

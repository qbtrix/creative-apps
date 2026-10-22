// FrameClock.swift: the suite's one frame clock (shell-media SM-4). Frame n
// shows at n / fps. A GIF delay is a whole number of centiseconds, so each
// delay carries the rounding left by the frames before it: frame n's delay is
// round(100 (n + 1) / fps) - round(100 n / fps), and n frames always sum to
// round(100 n / fps). 30 fps runs 3, 4, 3 and 30 frames make exactly 100 cs.
// Stdlib only, Linux-safe, Sendable.

/// Presentation times and GIF delays at a whole-number frame rate.
public struct FrameClock: Hashable, Sendable {
    /// Frames a second, 1 or more.
    public let fps: Int
    /// The frame whose GIF delay `nextGIFDelay()` returns next.
    public private(set) var frame: Int = 0

    /// Refuses a rate below 1 frame a second.
    public init(fps: Int) throws(SuiteError) {
        guard fps >= 1 else { throw .notAvailable("A frame rate must be at least 1 frame a second, not \(fps).") }
        self.fps = fps
    }

    /// When `frame` shows, in seconds from the first frame: frame / fps.
    public func seconds(of frame: Int) -> Double { Double(frame) / Double(fps) }

    /// The next frame's GIF delay in centiseconds, carrying the rounding so
    /// the delays never drift from the frames' true times.
    public mutating func nextGIFDelay() -> Int {
        let delay = centiseconds(upTo: frame + 1) - centiseconds(upTo: frame)
        frame += 1
        return delay
    }

    /// round(100 n / fps), the time of frame n in whole centiseconds; whole
    /// seconds stay integer so a long run can't lose precision.
    private func centiseconds(upTo n: Int) -> Int {
        let whole = n / fps, part = n % fps
        return 100 * whole + Int((100 * Double(part) / Double(fps)).rounded())
    }
}

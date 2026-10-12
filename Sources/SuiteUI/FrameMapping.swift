// FrameMapping.swift: the arithmetic behind TimelineStrip: frame to x, x to
// frame, the ruler's label interval and keyframe hit-testing. Plain Swift with
// no SwiftUI, so the rules are unit-tested on their own. Invariants: frames
// always come back inside 0...duration, a duration below 0 counts as 0, and a
// frame width of 0 (or below, or NaN) never divides: every x maps to frame 0.
public struct FrameMapping: Equatable, Sendable {
    /// The last frame; frames run 0...duration.
    public let duration: Int
    /// Points per frame.
    public let frameWidth: Double

    public init(duration: Int, frameWidth: Double) {
        self.duration = max(duration, 0)
        self.frameWidth = frameWidth.isFinite ? max(frameWidth, 0) : 0
    }

    /// `frame` moved into 0...duration.
    public func clamp(_ frame: Int) -> Int {
        min(max(frame, 0), duration)
    }

    /// The x of a frame's tick, after clamping the frame.
    public func x(forFrame frame: Int) -> Double {
        Double(clamp(frame)) * frameWidth
    }

    /// The frame whose tick is nearest `x`, clamped to 0...duration.
    public func frame(atX x: Double) -> Int {
        guard frameWidth > 0, !x.isNaN else { return 0 }
        let frame = (x / frameWidth).rounded()
        return Int(min(max(frame, 0), Double(duration)))
    }

    /// The width that holds every frame's tick.
    public var contentWidth: Double { Double(duration) * frameWidth }

    /// How many frames apart the ruler's labels sit: the smallest of 1, 2, 5,
    /// 10, 20, 50, ... frames that spans at least `minimumSpacing` points.
    /// Never 0; it stops at the first interval past the duration, which
    /// labels frame 0 alone.
    public func labelInterval(minimumSpacing: Double) -> Int {
        var magnitude = 1
        // Stops before 5 * magnitude * 10 could overflow Int.
        while magnitude <= Int.max / 100 {
            for step in [1, 2, 5] {
                let interval = step * magnitude
                if Double(interval) * frameWidth >= minimumSpacing || interval > duration { return interval }
            }
            magnitude *= 10
        }
        return max(duration, 1)
    }

    /// The keyframe whose tick is nearest `x`, if it lies within `tolerance`
    /// points of it.
    public func keyframe(nearX x: Double, in keyframes: [Int], tolerance: Double) -> Int? {
        let near = keyframes.map { (frame: $0, distance: abs(self.x(forFrame: $0) - x)) }
            .filter { $0.distance <= tolerance }
        return near.min { $0.distance < $1.distance }?.frame
    }
}

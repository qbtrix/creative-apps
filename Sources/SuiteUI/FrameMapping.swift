// FrameMapping.swift: the arithmetic behind TimelineStrip: frame to x, x to
// frame, the ruler's tick and label steps (labels spaced for their width), the ruler marks inside a visible
// stretch (bounded by its width, never by the duration), which labels end at
// their tick so the last one stays inside the strip, and keyframe
// hit-testing. Plain Swift with
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
        guard frame > 0 else { return 0 }
        // Double(duration) can round up past Int.max, so convert only below it
        // and clamp again in integer space.
        guard frame < Double(duration) else { return duration }
        return min(Int(frame), duration)
    }

    /// The width that holds every frame's tick.
    public var contentWidth: Double { Double(duration) * frameWidth }

    /// How many frames apart the ruler's labels sit: the smallest of 1, 2, 5,
    /// 10, 20, 50, ... frames that spans at least `minimumSpacing` points.
    /// Never 0; it stops at the first interval past the duration, which
    /// labels frame 0 alone.
    public func labelInterval(minimumSpacing: Double) -> Int {
        var magnitude = 1
        // Stops at the first interval that would overflow Int.
        while true {
            for step in [1, 2, 5] {
                let (interval, overflow) = step.multipliedReportingOverflow(by: magnitude)
                if overflow { return max(duration, 1) }
                if Double(interval) * frameWidth >= minimumSpacing || interval > duration { return interval }
            }
            let (next, overflow) = magnitude.multipliedReportingOverflow(by: 10)
            if overflow { return max(duration, 1) }
            magnitude = next
        }
    }

    /// The ruler's ticks and labels whose x lies inside `visibleX`. Ticks sit
    /// at least `tickSpacing` points apart and labels at least `labelSpacing`
    /// (each at least 1), so neither count grows past the visible width over
    /// that spacing, plus one, however long the duration is. Labels also sit
    /// at least `labelWidth(digitWidth:)` apart, so long frame numbers
    /// never overlap and the label step holds still while scrolling.
    public func rulerMarks(
        visibleX: ClosedRange<Double>, tickSpacing: Double, labelSpacing: Double, digitWidth: Double = 0
    ) -> RulerMarks {
        RulerMarks(
            ticks: frames(every: max(tickSpacing, 1), in: visibleX),
            labels: frames(every: max(labelSpacing, labelWidth(digitWidth: digitWidth), 1), in: visibleX)
        )
    }

    /// The room the widest label anywhere in 0...duration needs: the digits
    /// of the last frame, plus one digit of gap, at `digitWidth` points each.
    /// It sizes from the whole duration, not the visible stretch, so the label
    /// step does not jump when scrolling brings a frame with one more digit
    /// into view (#299). 0 when `digitWidth` is 0, below 0 or not finite.
    public func labelWidth(digitWidth: Double) -> Double {
        guard digitWidth.isFinite, digitWidth > 0 else { return 0 }
        return Double(String(duration).count + 1) * digitWidth
    }

    /// Where each of `labels` sits against its tick (#61). A label starts
    /// `padding` points after its tick, unless it would then run past
    /// `trailingRoom` points beyond the last frame's tick: that one ends
    /// `padding` points before its tick instead, so the strip never clips it.
    /// A label is `digitWidth` points per digit. A label that would run into a
    /// following label that ends at its tick is dropped. Order is kept.
    public func rulerLabels(
        _ labels: [Int], digitWidth: Double, padding: Double, trailingRoom: Double
    ) -> [RulerLabel] {
        let digit = digitWidth.isFinite ? max(digitWidth, 0) : 0
        func width(_ frame: Int) -> Double { Double(String(clamp(frame)).count) * digit }
        let placed = labels.map { frame in
            RulerLabel(
                frame: frame,
                endsAtTick: x(forFrame: frame) + padding + width(frame) > contentWidth + trailingRoom
            )
        }
        return placed.indices.compactMap { index in
            let label = placed[index]
            let next = placed.index(after: index)
            guard !label.endsAtTick, next < placed.endIndex, placed[next].endsAtTick else { return label }
            let end = x(forFrame: label.frame) + padding + width(label.frame)
            let nextStart = x(forFrame: placed[next].frame) - padding - width(placed[next].frame)
            return end > nextStart ? nil : label
        }
    }

    /// The multiples of the step for `spacing` whose ticks lie inside `range`.
    private func frames(every spacing: Double, in range: ClosedRange<Double>) -> [Int] {
        guard range.upperBound >= 0, range.lowerBound <= contentWidth else { return [] }
        guard frameWidth > 0 else { return [0] }
        let step = labelInterval(minimumSpacing: spacing)
        let low = frame(nearest: (range.lowerBound / frameWidth).rounded(.up))
        let high = frame(nearest: (range.upperBound / frameWidth).rounded(.down))
        guard low <= high else { return [] }
        let remainder = low % step
        var (frame, overflow) = low.addingReportingOverflow(remainder == 0 ? 0 : step - remainder)
        // Double rounding far from 0 can widen low...high; the width caps it.
        let width = range.upperBound - range.lowerBound
        let limit = width.isFinite ? Int(min(width / spacing, maximumMarks)) + 1 : 0
        var frames: [Int] = []
        while !overflow, frame <= high, frames.count <= limit {
            frames.append(frame)
            (frame, overflow) = frame.addingReportingOverflow(step)
        }
        return frames
    }

    /// A frame count from a whole Double, clamped to 0...duration.
    private func frame(nearest value: Double) -> Int {
        guard value > 0 else { return 0 }
        guard value < Double(duration) else { return duration }
        return min(Int(value), duration)
    }

    /// The keyframe whose tick is nearest `x`, if it lies within `tolerance`
    /// points of it, clamped to 0...duration. A keyframe outside the duration
    /// is drawn pinned to the nearest end, so it is hit there and comes back
    /// as that end's frame.
    public func keyframe(nearX x: Double, in keyframes: [Int], tolerance: Double) -> Int? {
        let near = keyframes.map { (frame: clamp($0), distance: abs(self.x(forFrame: $0) - x)) }
            .filter { $0.distance <= tolerance }
        return near.min { $0.distance < $1.distance }?.frame
    }
}

/// More marks than any screen could show; keeps the Int conversion safe.
private let maximumMarks = 1_000_000.0

/// What the ruler draws in a visible stretch: the frames that get a tick and
/// the frames that get a label, both ascending.
public struct RulerMarks: Equatable, Sendable {
    public let ticks: [Int]
    public let labels: [Int]
}

/// A ruler label's frame, and whether it ends at its tick (trailing-aligned)
/// rather than starting there.
public struct RulerLabel: Equatable, Sendable {
    public let frame: Int
    public let endsAtTick: Bool

    public init(frame: Int, endsAtTick: Bool) {
        self.frame = frame
        self.endsAtTick = endsAtTick
    }
}

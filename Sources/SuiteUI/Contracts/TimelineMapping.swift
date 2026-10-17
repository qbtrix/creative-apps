// TimelineMapping.swift: UC11, the timeline's frame <-> x mapping and ruler
// marks, and FakeTimelineMapping, which labels every 10 frames and draws no
// ticks on purpose. Foundation only; verbatim from blueprint section 5.2. The
// live mapping is FrameMapping.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct TimelineScale: Hashable, Sendable {
    /// The last frame: frames run 0...lastFrame (FrameMapping's `duration`). Below 0 counts as 0.
    public var lastFrame: Int
    public var frameWidth: Double     // points per frame; 0, negative or NaN maps every x to frame 0
    public init(lastFrame: Int, frameWidth: Double) { self.lastFrame = lastFrame; self.frameWidth = frameWidth }
}

public struct RulerMarkSet: Equatable, Sendable {
    public var ticks: [Int]
    public var labels: [Int]
    public init(ticks: [Int], labels: [Int]) { self.ticks = ticks; self.labels = labels }
}

public protocol TimelineMapping: Sendable {
    func x(forFrame frame: Int, scale: TimelineScale) -> Double
    /// Always inside 0...lastFrame.
    func frame(atX x: Double, scale: TimelineScale) -> Int
    /// The key nearest `x` within `tolerance` points, if any.
    func keyframe(nearX x: Double, in keyframes: [Int], tolerance: Double, scale: TimelineScale) -> Int?
    /// Ticks and labels inside the visible stretch only, so a long timeline costs no more than a short one.
    func rulerMarks(visible: ClosedRange<Double>, minimumSpacing: Double, scale: TimelineScale) -> RulerMarkSet
}

/// A label every 10 frames and no ticks.
public struct FakeTimelineMapping: TimelineMapping {
    public init() {}
    public func x(forFrame frame: Int, scale: TimelineScale) -> Double { Double(frame) * max(scale.frameWidth, 0) }
    public func frame(atX x: Double, scale: TimelineScale) -> Int {
        guard scale.frameWidth > 0, x.isFinite else { return 0 }
        return min(max(Int((x / scale.frameWidth).rounded()), 0), max(scale.lastFrame, 0))
    }
    public func keyframe(nearX x: Double, in keyframes: [Int], tolerance: Double, scale: TimelineScale) -> Int? {
        keyframes.first { abs(self.x(forFrame: $0, scale: scale) - x) <= tolerance }
    }
    public func rulerMarks(visible: ClosedRange<Double>, minimumSpacing: Double, scale: TimelineScale) -> RulerMarkSet {
        let lo = frame(atX: visible.lowerBound, scale: scale), hi = frame(atX: visible.upperBound, scale: scale)
        return RulerMarkSet(ticks: [], labels: Array(stride(from: (lo / 10) * 10, through: hi, by: 10)))
    }
}

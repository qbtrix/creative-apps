// DesignNodeTime.swift: SPIKE (spike/one-document, never merged). A node's keyed x, y and opacity
// over the kernel's Keyframe, and the sampled tree the canvas paints and hit-tests at a playhead.
// Keys hold absolute page values (DesignNode.frame is absolute), so sampling a node moves its whole
// subtree by the node's delta, then each child adds its own. `frame` and `opacity` stay the rest pose:
// every Live editor still reads and writes them, which is what the spike measures. Linux-safe.
import SuiteKernel

/// Keyed x, y (frame origin, page points) and opacity; an empty track leaves the rest value.
public struct DesignNodeTime: Codable, Sendable, Hashable {
    public var x: [Keyframe], y: [Keyframe], opacity: [Keyframe]
    public init(x: [Keyframe] = [], y: [Keyframe] = [], opacity: [Keyframe] = []) {
        (self.x, self.y, self.opacity) = (x, y, opacity)
    }
    /// The spike's one rate: 60 fps, so 1 s is frame 60 and the 2 s fixtures end on frame 120.
    public static let rate = FrameRate(whole: 60)
}

/// A sorted track's value at `frame`, linear between keys, held past both ends; nil when empty.
// ponytail: linear only; the real build uses FlareCore.Timeline.value(of:at:) so easing applies.
func sampledValue(_ track: [Keyframe], at frame: Double) -> Double? {
    guard let first = track.first, let last = track.last else { return nil }
    if frame <= Double(first.frame) { return first.value }
    if frame >= Double(last.frame) { return last.value }
    let i = track.firstIndex { Double($0.frame) > frame }!
    let (a, b) = (track[i - 1], track[i])
    return a.value + (b.value - a.value) * (frame - Double(a.frame)) / Double(b.frame - a.frame)
}

extension DesignNode {
    /// This node as it shows at `frame`: children sampled, then the subtree moved to the keyed origin.
    public func sampled(at frame: Double) -> DesignNode {
        var node = self
        if !children.isEmpty { node.children = children.map { $0.sampled(at: frame) } }
        guard let time else { return node }
        let x = sampledValue(time.x, at: frame) ?? self.frame.x, y = sampledValue(time.y, at: frame) ?? self.frame.y
        if x != self.frame.x || y != self.frame.y { node.translate(by: DesignPoint(x: x - self.frame.x, y: y - self.frame.y)) }
        if let opacity = sampledValue(time.opacity, at: frame) { node.opacity = opacity }
        return node
    }
}

extension DesignPage {
    /// The page as it shows at `frame`; the canvas paints `sampled(at:).painted`.
    public func sampled(at frame: Double) -> DesignPage {
        var page = self
        page.nodes = nodes.map { $0.sampled(at: frame) }
        return page
    }
}

extension DesignWorkspace {
    /// Spike only: the playhead the canvas paints and hit-tests at; nil shows the rest pose. Kept out of the
    /// document (not Codable, not Hashable state). A static because the spike has one window.
    nonisolated(unsafe) public static var spikePlayhead: Double?

    /// `hitTest` through the sampled tree at `frame`.
    public func hitTest(_ point: DesignPoint, at frame: Double) -> String? {
        selectedPage?.sampled(at: frame).nodes.hit(at: point)
    }
}

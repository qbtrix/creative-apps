// DesignNodeTime.swift: the node-time contract (one-document, OD-2), frozen. A node's keyed properties over the
// kernel's Keyframe, the document's rate and length, and the sampled tree the canvas paints and hit-tests at a
// playhead. Keys hold absolute page values (DesignNode.frame is absolute), so sampling moves a node's whole subtree
// by the node's delta, then each child adds its own. `frame` and `opacity` stay the rest pose. Values between keys
// come from FlareCore's Timeline, so each key's easing applies. Shipped properties are x, y and opacity; width,
// height, rotation and fill are reserved names a later slice adds as new cases with no format change. A file naming
// a property this build doesn't know fails to decode rather than dropping its keys. Linux-safe.
import FlareCore
import SuiteKernel

/// A property a node can key. Raw values are the file's track names; append only.
public enum DesignKeyProperty: String, Codable, CodingKeyRepresentable, CaseIterable, Sendable {
    case x, y, opacity
}

/// A node's tracks, each sorted by frame; a property with no track shows its rest value.
public struct DesignNodeTime: Codable, Sendable, Hashable {
    public var tracks: [DesignKeyProperty: [Keyframe]]

    /// Keeps the non-empty tracks, each sorted by frame.
    public init(tracks: [DesignKeyProperty: [Keyframe]] = [:]) {
        self.tracks = tracks.filter { !$0.value.isEmpty }.mapValues { $0.sorted { $0.frame < $1.frame } }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(tracks: try container.decode([DesignKeyProperty: [Keyframe]].self, forKey: .tracks))
    }

    /// True with no keys at all: a node with such a time is still.
    public var isEmpty: Bool { tracks.isEmpty }

    /// The track's value at `frame`, eased between keys and held past both ends; nil with no track.
    public func value(of property: DesignKeyProperty, at frame: Double) -> Double? {
        FlareCore.Timeline.value(of: tracks[property] ?? [], at: frame)
    }
}

/// The document's frame rate and length in frames: 60 fps and 300 frames (5 s) unless set.
public struct DesignDocumentTime: Codable, Sendable, Hashable {
    public var rate: FrameRate
    public var durationFrames: Int

    public init(rate: FrameRate = FrameRate(whole: 60), durationFrames: Int = 300) {
        (self.rate, self.durationFrames) = (rate, durationFrames)
    }
}

extension DesignNode {
    /// True when this node or any node under it has keys.
    public var isKeyed: Bool { time != nil || children.contains { $0.isKeyed } }

    /// This node as it shows at `frame`: children sampled, then the subtree moved to the keyed origin.
    public func sampled(at frame: Double) -> DesignNode {
        var node = self
        if !children.isEmpty { node.children = children.map { $0.sampled(at: frame) } }
        guard let time else { return node }
        let x = time.value(of: .x, at: frame) ?? self.frame.x
        let y = time.value(of: .y, at: frame) ?? self.frame.y
        if x != self.frame.x || y != self.frame.y {
            node.translate(by: DesignPoint(x: x - self.frame.x, y: y - self.frame.y))
        }
        if let opacity = time.value(of: .opacity, at: frame) { node.opacity = opacity }
        return node
    }
}

extension DesignPage {
    /// The page as it shows at `frame`.
    public func sampled(at frame: Double) -> DesignPage {
        var page = self
        page.nodes = nodes.map { $0.sampled(at: frame) }
        return page
    }
}

extension DesignWorkspace {
    /// True when no node on any page has keys: the document saves and shows as a still.
    public var isStill: Bool { !pages.contains { $0.nodes.contains { $0.isKeyed } } }
}

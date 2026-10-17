// TimelineTrack.swift: the data of one timeline row, the values a host passes
// to TimelineStrip. A track has a name, keys (a frame and the shape the key
// draws, from its easing), spans of frames (Halo's in and out points, clips)
// and the frames the host has picked. The old `keyframes:` init still works:
// it makes linear keys, and `keyframes` reads the keys' frames, so every
// existing call draws as before. No SwiftUI; from the timeline packet's
// Contract slice.

/// How a key draws, from the easing that leaves it.
public enum TimelineKeyShape: String, Hashable, Sendable { case linear, eased, hold }

/// One key on a track: its frame and its shape.
public struct TimelineKey: Hashable, Sendable {
    public var frame: Int
    public var shape: TimelineKeyShape

    public init(frame: Int, shape: TimelineKeyShape) {
        self.frame = frame
        self.shape = shape
    }
}

/// One row of the timeline: its name, keys, spans of frames and picked frames.
public struct TimelineTrack<ID: Hashable & Sendable>: Identifiable, Hashable, Sendable {
    public let id: ID
    public let name: String
    public let keys: [TimelineKey]
    public let spans: [ClosedRange<Int>]
    /// The frames of the keys the host has picked.
    public let pickedFrames: Set<Int>
    public let isSelected: Bool

    /// The keys' frames, in order.
    public var keyframes: [Int] { keys.map(\.frame) }

    public init(
        id: ID, name: String, keys: [TimelineKey], spans: [ClosedRange<Int>] = [],
        pickedFrames: Set<Int> = [], isSelected: Bool = false
    ) {
        self.id = id
        self.name = name
        self.keys = keys
        self.spans = spans
        self.pickedFrames = pickedFrames
        self.isSelected = isSelected
    }

    /// Each keyframe becomes a linear key; nothing is picked.
    public init(
        id: ID, name: String, keyframes: [Int] = [], spans: [ClosedRange<Int>] = [], isSelected: Bool = false
    ) {
        self.init(
            id: id, name: name, keys: keyframes.map { TimelineKey(frame: $0, shape: .linear) },
            spans: spans, isSelected: isSelected
        )
    }
}

// HaloTimelineReadout.swift: a timeline lane's key count as a journey reads
// it. SuiteUI's lane speaks "3 keyframes" as its accessibility value, which
// XCUITest reads empty (#262), so HaloTimelineView also publishes this text
// as the label of a hidden `halo.timeline.keys` element per lane
// (HaloReadout.swift), named by the layer so a journey finds its lane.

extension HaloTimelineRow {
    /// "Ball: 3 keyframes": the layer's name and the keys its lane draws.
    public var keysReadout: String { "\(name): \(keyFrames.count) keyframes" }
}

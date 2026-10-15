// HaloTimeline.swift: the selected composition's timeline: the playhead and
// its timecode, the layers active at a frame, the rows the viewer's timeline
// strip draws (each with its layer's key frames for the diamonds), and setting a layer's in and out points at the playhead (the
// I and O keys, each one undo step or a refusal under the timeline).
// Linux-safe: no UI imports. The playhead stays in
// 0..<durationFrames; a layer stays visible for at least one frame.

/// One timeline row: a layer's name and the frames it is visible for.
public struct HaloTimelineRow: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    /// From the layer's in point to its out point, the frame it stops showing.
    public let span: ClosedRange<Int>
    public let isSelected: Bool
    /// Every frame any of the layer's tracks has a key on, ascending, once each.
    public let keyFrames: [Int]
}

extension HaloComposition {
    /// The last frame the playhead can show; 0 for an empty composition.
    public var lastFrame: Int { max(0, durationFrames - 1) }

    /// `frame` as hours:minutes:seconds:frames at this frame rate
    /// ("00:00:01:12" for frame 36 at 24 fps). A negative frame shows as 0;
    /// with no positive frame rate every frame counts as frames.
    public func timecode(_ frame: Int) -> String {
        let frame = max(0, frame)
        let fps = max(1, framesPerSecond)
        let seconds = frame / fps
        let parts = [seconds / 3600, seconds / 60 % 60, seconds % 60, frame % fps]
        return parts.map { $0 < 10 ? "0\($0)" : "\($0)" }.joined(separator: ":")
    }

    /// The playhead's timecode, as the viewer's readout shows it.
    public var playheadTimecode: String { timecode(playheadFrame) }

    /// Points per frame that fit every frame into `width` points, so the strip
    /// shows the whole composition; 0 for a width that is not positive.
    public func frameWidth(toFit width: Double) -> Double {
        width > 0 ? width / Double(max(1, durationFrames)) : 0
    }

    /// The layers visible at `frame`, top first.
    public func layers(at frame: Int) -> [HaloLayer] {
        layers.filter { $0.isVisible(at: frame) }
    }

    /// One row per layer, top first, with `selectedLayerID`'s row marked.
    public func timelineRows(selectedLayerID: String?) -> [HaloTimelineRow] {
        layers.map { layer in
            HaloTimelineRow(
                id: layer.id, name: layer.name, span: layer.inFrame...max(layer.inFrame, layer.outFrame),
                isSelected: layer.id == selectedLayerID, keyFrames: layer.keyFrames)
        }
    }
}

extension HaloLayer {
    /// The union of its tracks' key frames, ascending, once each.
    public var keyFrames: [Int] {
        Set(tracks.values.flatMap { $0.map(\.frame) }).sorted()
    }
}

extension HaloProject {
    /// The selected composition's rows for the timeline strip; empty without one.
    public var timelineRows: [HaloTimelineRow] {
        selectedComposition?.timelineRows(selectedLayerID: selectedLayerID) ?? []
    }

    /// Moves the selected composition's playhead to `frame`, clamped to its
    /// frames. Does nothing with no composition selected.
    public mutating func scrub(to frame: Int) {
        updateSelectedComposition { $0.playheadFrame = min(max(frame, 0), $0.lastFrame) }
    }

    /// I: the selected layer starts at the playhead. One step, "Set In
    /// Point". Refused on `halo.timeline` (false) with no selected layer
    /// (`.noLayerSelected`), or when the playhead is at or after its out point
    /// (`.inPointAfterOut`).
    @discardableResult
    public mutating func setSelectedLayerInPoint() -> Bool {
        editSelectedLayer("Set In Point", control: "halo.timeline") { layer, comp in
            guard comp.playheadFrame < layer.outFrame else { throw HaloEditError.inPointAfterOut }
            layer.inFrame = comp.playheadFrame
        }
    }

    /// O: the selected layer shows through the playhead's frame and stops after
    /// it. One step, "Set Out Point". Refused on `halo.timeline` (false) with
    /// no selected layer, or when the playhead is before its in point
    /// (`.outPointBeforeIn`).
    @discardableResult
    public mutating func setSelectedLayerOutPoint() -> Bool {
        editSelectedLayer("Set Out Point", control: "halo.timeline") { layer, comp in
            guard comp.playheadFrame >= layer.inFrame else { throw HaloEditError.outPointBeforeIn }
            layer.outFrame = comp.playheadFrame + 1
        }
    }
}

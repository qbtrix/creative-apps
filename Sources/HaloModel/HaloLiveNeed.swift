// HaloLiveNeed.swift: which live project a viewer leaf shows (CL-probe,
// #4589). The window's live edit holds two: a drag's or inspector scrub's
// preview (the window's project with the latest sample applied) and the
// playing frame (a playback tick, or a ruler scrub). The drawn layers and
// the handles show the preview first. A leaf that shows only the playhead
// and what follows from it (the timeline's playhead, the timecode, the
// transport's frame watch, the viewer's summary and drawn-count readouts)
// shows the playing frame: a value scrub or a viewer drag moves no
// playhead and adds or hides no layer, yet reading its preview re-ran those
// leaves, the 50-lane timeline strip among them, on every refresh of an
// inspector scrub (HB-U2). Each source is a closure and `.playhead` never
// calls `edit`, so such a leaf never reads, and never observes, the preview.
// Linux-safe (HaloLiveNeedTests).

/// What a live viewer leaf needs of the window's live edit.
public enum HaloLiveNeed: Sendable, Hashable, CaseIterable {
    /// The drawn layers and handles: the preview, else the playing frame.
    case drawn
    /// The playhead and what it alone decides: the playing frame.
    case playhead

    /// What a leaf with this need shows of `model`: the preview `edit` gives
    /// (`.drawn` only), else the frame `playing` gives, else `model`.
    public func shown(
        _ model: HaloProject, edit: () -> HaloProject?, playing: () -> HaloProject?
    ) -> HaloProject {
        switch self {
        case .drawn: edit() ?? playing() ?? model
        case .playhead: playing() ?? model
        }
    }
}

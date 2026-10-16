// FlareWindow+Timeline.swift: the router's timeline area
// (FlareWindow+Router.swift). Auto-key toggles recording while a document is
// open; scrubbing, playback and keyframe edits wait for F7a (DK-10) and say so.
import FlareModel

extension FlareWindow {
    /// Acts on a timeline intent: Auto-key only, for now.
    func performTimeline(_ intent: FlareIntent.Timeline) {
        switch intent {
        case .toggleAutoKey: model.toggleAutoKey()
        default: break
        }
    }

    /// Why a timeline intent can't act now; nil for Auto-key with a document open.
    func timelineHelp(_ intent: FlareIntent.Timeline) -> String? {
        switch intent {
        case .toggleAutoKey: model.document == nil ? "Open an animation to key it." : nil
        default: "Not built yet (F7a)."
        }
    }
}

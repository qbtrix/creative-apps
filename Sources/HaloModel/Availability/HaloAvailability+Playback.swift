// Availability/HaloAvailability+Playback.swift: whether the transport and
// playhead commands can act now. Set In Point, Set Out Point and moving the
// playhead are shipped and answer from state only; the transport is not
// built yet (#37), and `viewer-playback` replaces this file whole when it
// is, keeping those three answers. Linux-safe.

extension HaloProject {
    /// Nil when `command` can act now; otherwise why not.
    func playbackHelp(_ command: HaloCommand) -> String? {
        switch command {
        case .setInPoint, .setOutPoint:
            if selectedComposition == nil { return HaloEditError.noComposition.message }
            return selectedLayer == nil ? HaloEditError.noLayerSelected.message : nil
        case .scrub:
            return selectedComposition == nil ? HaloEditError.noComposition.message : nil
        default:
            return "Not built yet (#37)."
        }
    }
}

// Availability/HaloAvailability+Playback.swift: whether the transport and
// playhead commands can act now (#37). Every command needs a composition.
// Play/Pause and Loop also need the clock; the frame steps and Go to Start /
// End are off when the playhead already sits where they would put it. Set In
// Point, Set Out Point and moving the playhead keep W0's state-only answers;
// a playback tick acts whenever a composition is open. Linux-safe.

extension HaloProject {
    /// Nil when `command` can act now; otherwise why not.
    func playbackHelp(_ command: HaloCommand) -> String? {
        guard let comp = selectedComposition else { return HaloEditError.noComposition.message }
        let atStart = comp.playheadFrame <= 0
        let atEnd = comp.playheadFrame >= comp.lastFrame
        switch command {
        case .setInPoint, .setOutPoint:
            return selectedLayer == nil ? HaloEditError.noLayerSelected.message : nil
        case .playPause, .toggleLoop:
            return services.clock.unavailableHelp
        case .previousFrame:
            return atStart ? "Already on the first frame." : nil
        case .goToStart:
            return atStart ? "Already at the start." : nil
        case .nextFrame:
            return atEnd ? "Already on the last frame." : nil
        case .goToEnd:
            return atEnd ? "Already at the end." : nil
        default:
            return nil
        }
    }
}

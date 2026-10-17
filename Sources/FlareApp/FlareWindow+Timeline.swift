// FlareWindow+Timeline.swift: the router's timeline area
// (FlareWindow+Router.swift). Scrubbing, the transport's start, step, end,
// play/pause and loop move the playhead through the Model's playback calls
// while a timeline can play; Auto-key toggles recording while a document is
// open. Start, end and the steps say why while the playhead already stands
// where they'd put it (FlareTransport.help, #1839). Key navigation and the
// key edits have no Model call yet, so they wait for F7a and say so.
import FlareModel

extension FlareWindow {
    /// Acts on a timeline intent.
    func performTimeline(_ intent: FlareIntent.Timeline) {
        switch intent {
        case .scrub(let frame): model.setCurrentFrame(frame)
        case .goToStart: model.goToStart()
        case .goToEnd: model.goToEnd()
        case .step(let delta): model.stepFrame(by: delta)
        case .togglePlay: model.togglePlay()
        case .setLoops(let on): model.setLoops(on)
        case .toggleAutoKey: model.toggleAutoKey()
        case .nextKeyframe, .previousKeyframe, .selectKey, .moveKeys, .endKeyDrag, .removeKeys, .addKey, .removeKey,
            .insertFrames, .removeFrames, .setLabel:
            break
        }
    }

    /// Why a timeline intent can't act now; nil when it can.
    func timelineHelp(_ intent: FlareIntent.Timeline) -> String? {
        switch intent {
        case .scrub, .togglePlay, .setLoops: model.canPlay ? nil : FlareTransport.cannotPlay
        case .goToStart, .goToEnd, .step: FlareTransport.help(for: intent, in: model)
        case .toggleAutoKey: model.document == nil ? "Open an animation to key it." : nil
        case .nextKeyframe, .previousKeyframe, .selectKey, .moveKeys, .endKeyDrag, .removeKeys, .addKey, .removeKey,
            .insertFrames, .removeFrames, .setLabel:
            "Not built yet (F7a)."
        }
    }
}

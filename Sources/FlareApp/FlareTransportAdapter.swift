// FlareTransportAdapter.swift: the transport above the timeline strip
// (draw-key-save DK-11) onto SuiteUI's TransportCapsule, in its own pill in the
// band under the stage (no glass: it sits under the artwork, not over it,
// #1858). Each control is its FlareIntent: the intent's title, `perform` on a
// click, and `help(for:in:)`'s reason while it can't act: no timeline can
// play, or the playhead already stands where a start, end or step would put
// it (#1839). The two steps share one intent identifier, so each gets a
// direction suffix (`flare.timeline.step.back`, `.forward`) and
// `suite.controls` holds no duplicate. The row is only the controls, so it
// fits the narrowest content column (#2101): the status pills (IT-9) live in
// the stage's ViewerStatusBar, the readouts beside it in FlareTimeline, and
// the PlaybackDriver in FlareCanvas. It only reads `model`.
import FlareModel
import SuiteUI
import SwiftUI

struct FlareTransportAdapter: View {
    let model: FlareWorkspace
    let perform: @MainActor (FlareIntent) -> Void

    /// The timeline area's reason while nothing can play (FlareWindow+Timeline.swift).
    nonisolated static let cannotPlay = "Open an animation to play it."

    /// Why a transport intent can't act on `model` now; nil when it can. Start and a back step have nothing to do on
    /// the first frame, end and a forward step on the last; a step still acts there while playing (it pauses) or with
    /// Loop on and more than one frame (it wraps).
    nonisolated static func help(for intent: FlareIntent.Timeline, in model: FlareWorkspace) -> String? {
        guard model.canPlay else { return cannotPlay }
        let atStart = model.currentFrame <= 0
        let atEnd = model.currentFrame >= model.timelineFrames - 1
        let stepWraps = model.isPlaying || (model.loops && model.timelineFrames > 1)
        switch intent {
        case .goToStart: return atStart ? "Already at the first frame." : nil
        case .goToEnd: return atEnd ? "Already at the last frame." : nil
        case .step(let delta) where delta < 0: return atStart && !stepWraps ? "Already at the first frame." : nil
        case .step(let delta) where delta > 0: return atEnd && !stepWraps ? "Already at the last frame." : nil
        case .step: return "A step of no frames changes nothing."
        default: return nil
        }
    }

    /// The intent each transport control sends on `model`.
    nonisolated static func intent(_ button: TransportButton, on model: FlareWorkspace) -> FlareIntent.Timeline {
        switch button {
        case .start: .goToStart
        case .previous: .step(-1)
        case .play: .togglePlay
        case .next: .step(1)
        case .end: .goToEnd
        case .loop: .setLoops(!model.loops)
        }
    }

    /// `button`'s id, title and reason on `model`.
    nonisolated static func control(_ button: TransportButton, on model: FlareWorkspace) -> TransportControl {
        let timeline = intent(button, on: model), intent = FlareIntent.timeline(timeline)
        let suffix = switch button {
        case .previous: ".back"
        case .next: ".forward"
        default: ""
        }
        return TransportControl(id: intent.identifier + suffix, title: intent.title, reason: help(for: timeline, in: model))
    }

    var capsule: TransportCapsule {
        let model = model, perform = perform
        let send = { (button: TransportButton) in perform(.timeline(Self.intent(button, on: model))) }
        return TransportCapsule(
            isPlaying: model.isPlaying, loops: model.loops,
            control: { Self.control($0, on: model) },
            onPlay: { send(.play) }, onStep: { send($0 < 0 ? .previous : .next) },
            onStart: { send(.start) }, onEnd: { send(.end) }, onLoop: { _ in send(.loop) })
    }

    var body: some View { capsule }
}

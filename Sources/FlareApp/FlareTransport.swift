// FlareTransport.swift: the transport above the timeline strip (draw-key-save
// DK-11). A floating ToolbarGroup of Go to Start, Previous Frame, Play/Pause,
// Next Frame, Go to End and Loop, each a ToolbarAction from its FlareIntent:
// the intent's title, `perform` on a click, and `help(for:in:)`'s reason while
// it can't act: no timeline can play, or the playhead already stands where a
// start, end or step would put it (#1839). Play shows pause and reads selected
// while playing; Loop reads selected while on. The two steps share one intent
// identifier, so each gets a direction suffix and `suite.controls` holds no
// duplicate. ToolbarGroup
// takes no accessibility value per action yet, so Play can't read "Playing"
// or "Paused" (needs-ui #1675); its selected state stands in. It owns a
// PlaybackDriver: started when `model.isPlaying` turns true, ticking the model
// through `tick`, and stopped when it turns false or the transport leaves the
// screen. It only reads `model`; TransportCapsule (#340) replaces the group.
import FlareModel
import SuiteUI
import SwiftUI

struct FlareTransport: View {
    let model: FlareWorkspace
    let zoom: Double?
    let perform: @MainActor (FlareIntent) -> Void
    let tick: @MainActor (Double, inout PlaybackTicker) -> Bool

    @State private var driver: PlaybackDriver?

    /// The timeline area's reason while nothing can play (FlareWindow+Timeline.swift).
    static let cannotPlay = "Open an animation to play it."

    /// Why a transport intent can't act on `model` now; nil when it can. Start and a back step have nothing to do on
    /// the first frame, end and a forward step on the last; a step still acts there while playing (it pauses) or with
    /// Loop on and more than one frame (it wraps).
    static func help(for intent: FlareIntent.Timeline, in model: FlareWorkspace) -> String? {
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

    var body: some View {
        ToolbarGroup(actions, axis: .horizontal, style: .floating)
            .onChange(of: model.isPlaying, initial: true) { _, playing in follow(playing: playing) }
            .onDisappear { driver?.stop() }
    }

    /// One button per transport intent, in the transport's order.
    private var actions: [ToolbarAction] {
        let playing = model.isPlaying
        let items: [(FlareIntent.Timeline, String, String, Bool)] = [
            (.goToStart, "backward.end.fill", "", false),
            (.step(-1), "backward.frame.fill", ".back", false),
            (.togglePlay, playing ? "pause.fill" : "play.fill", "", playing),
            (.step(1), "forward.frame.fill", ".forward", false),
            (.goToEnd, "forward.end.fill", "", false),
            (.setLoops(!model.loops), "repeat", "", model.loops),
        ]
        return items.map { timeline, image, suffix, selected in
            let intent = FlareIntent.timeline(timeline)
            return ToolbarAction(
                intent.title, systemImage: image, isSelected: selected,
                unavailableHelp: Self.help(for: timeline, in: model),
                identifier: intent.identifier + suffix
            ) { perform(intent) }
        }
    }

    /// Runs the display link while playing and stops it otherwise.
    private func follow(playing: Bool) {
        guard playing else {
            driver?.stop()
            return
        }
        let tick = tick
        let running = driver ?? PlaybackDriver(onTick: { target, ticker in tick(target, &ticker) })
        driver = running
        running.start()
    }
}

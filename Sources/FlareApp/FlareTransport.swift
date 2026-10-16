// FlareTransport.swift: the transport above the timeline strip (draw-key-save
// DK-11). A floating ToolbarGroup of Go to Start, Previous Frame, Play/Pause,
// Next Frame, Go to End and Loop, each a ToolbarAction from its FlareIntent:
// the intent's title, `perform` on a click, and the timeline's reason while no
// timeline can play. Play shows pause and reads selected while playing; Loop
// reads selected while on. The two steps share one intent identifier, so each
// gets a direction suffix and `suite.controls` holds no duplicate. ToolbarGroup
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

    var body: some View {
        ToolbarGroup(actions, axis: .horizontal, style: .floating)
            .onChange(of: model.isPlaying, initial: true) { _, playing in follow(playing: playing) }
            .onDisappear { driver?.stop() }
    }

    /// One button per transport intent, in the transport's order.
    private var actions: [ToolbarAction] {
        let playing = model.isPlaying
        let items: [(FlareIntent, String, String, Bool)] = [
            (.timeline(.goToStart), "backward.end.fill", "", false),
            (.timeline(.step(-1)), "backward.frame.fill", ".back", false),
            (.timeline(.togglePlay), playing ? "pause.fill" : "play.fill", "", playing),
            (.timeline(.step(1)), "forward.frame.fill", ".forward", false),
            (.timeline(.goToEnd), "forward.end.fill", "", false),
            (.timeline(.setLoops(!model.loops)), "repeat", "", model.loops),
        ]
        let help = model.canPlay ? nil : Self.cannotPlay
        return items.map { intent, image, suffix, selected in
            ToolbarAction(
                intent.title, systemImage: image, isSelected: selected, unavailableHelp: help,
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

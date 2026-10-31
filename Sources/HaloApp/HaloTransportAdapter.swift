// HaloTransportAdapter.swift: the status bar's transport (viewer-playback #37,
// VP-10) onto SuiteUI's TransportCapsule, bare (the bar gives the pill, or the
// row has none). Each control is its HaloCommand, worded by one
// HaloTransportState of the frame on screen (HaloPlayheadShown): its title and
// `unavailableHelp(for:)` reason (command-state CS-8), so a ruler scrub's last
// frame reaches the buttons before the window takes it back and a control's
// ink never disagrees with its disabled state (#4352). The ids stay
// `halo.transport.<start|previous|play|next|end|loop>`, listed in
// `halo.controls` too. HaloTransportButtons is Equatable on that state, so a
// playing frame that leaves every control as it was skips its body. It owns
// the HaloPlaybackDriver: running while `model.playback.playing`, stopped
// otherwise or once the transport leaves the screen, on the `haloRefreshLink`
// the environment gives; each refresh sends `.tick(now)` through `perform`,
// and a playhead that moved while playing is a `playback` frame in the probe
// (HaloProbe).
import HaloModel
import SuiteUI
import SwiftUI

struct HaloTransportAdapter: View {
    let model: HaloProject
    var perform: @MainActor (HaloCommand) -> Void = { _ in }

    @State private var driver: HaloPlaybackDriver?
    @Environment(\.haloRefreshLink) private var makeLink
    @Environment(\.suiteProbeRecorder) private var recorder

    var body: some View {
        HaloPlayheadShown(model: model) { shown in
            HaloTransportButtons(state: HaloTransportState(shown), perform: perform)
                .equatable()
        }
        .onChange(of: model.playback.playing, initial: true) { _, playing in follow(playing: playing) }
        .background {
            HaloPlayheadShown(model: model) { shown in
                Color.clear.onChange(of: shown.selectedComposition?.playheadFrame) {
                    if shown.playback.playing { driver?.frameShown() }
                }
            }
        }
        .onDisappear { driver?.stop() }
    }

    /// Starts the display link while playing and stops it otherwise.
    private func follow(playing: Bool) {
        guard playing else {
            driver?.stop()
            return
        }
        let perform = perform
        let running = driver ?? HaloPlaybackDriver(onTick: { now in perform(.tick(now)) }, makeLink: makeLink)
        running.probe = HaloProbe(recorder)
        driver = running
        running.start()
    }
}

/// The transport for `state`. `perform` (the window's, always acting on its current project) is left out of
/// `==`: a playing frame that leaves every control as it was skips this body.
struct HaloTransportButtons: View, Equatable {
    let state: HaloTransportState
    let perform: @MainActor (HaloCommand) -> Void

    nonisolated static func == (a: Self, b: Self) -> Bool { a.state == b.state }

    /// The command each transport control sends.
    nonisolated static func command(_ button: TransportButton) -> HaloCommand {
        switch button {
        case .start: .goToStart
        case .previous: .previousFrame
        case .play: .playPause
        case .next: .nextFrame
        case .end: .goToEnd
        case .loop: .toggleLoop
        }
    }

    /// `button`'s id, title and reason from `state`.
    nonisolated static func control(_ button: TransportButton, in state: HaloTransportState) -> TransportControl {
        let command = command(button)
        let shown = state.buttons.first { $0.command == command }
        return TransportControl(id: "halo.transport.\(button)", title: shown?.title ?? "",
                                reason: shown.map(\.unavailableHelp) ?? "Nothing to play.")
    }

    var body: some View {
        let perform = perform
        TransportCapsule(
            isPlaying: state.playing, loops: state.loops, pill: false,
            control: { Self.control($0, in: state) },
            onPlay: { perform(.playPause) },
            onStep: { perform($0 < 0 ? .previousFrame : .nextFrame) },
            onStart: { perform(.goToStart) }, onEnd: { perform(.goToEnd) },
            onLoop: { _ in perform(.toggleLoop) })
        .haloControls(TransportButton.allCases.map {
            let control = Self.control($0, in: state)
            return ControlEntry(id: control.id, enabled: control.reason == nil, reason: control.reason)
        })
    }
}

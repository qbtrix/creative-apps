// HaloTransport.swift: the status bar's transport (viewer-playback #37,
// VP-10): five plain SF Symbol buttons and a Loop toggle sending their
// HaloCommand (each button its catalog spec's MenuCommand on the frame on screen, command-state CS-8), disabled with `unavailableHelp(for:)` as the tooltip while the
// Model can't act, and drawn in textTertiary then so they look disabled
// inside the pill. All of it comes from one HaloTransportState of the frame
// on screen (HaloPlayheadShown), so a ruler scrub's last frame reaches the
// buttons before the window takes it back and a button's ink never
// disagrees with its disabled state (#4352). Play shows pause.fill while playing and reads `playLabel`
// as its value. Loop is a button-style Toggle that reads `loopLabel` and
// draws its on state (system highlight, accent ink) so a person can see
// whether looping is on. It owns a SuitePlaybackDriver (SuiteUI): running while
// `model.playback.playing`, stopped otherwise or once the transport leaves
// the screen, on the `haloRefreshLink` the environment gives; each refresh
// sends `.tick(now)` through `perform`, and a playhead that moved while
// playing (the live edit's playing frame, HaloPlayheadShown) is a `playback`
// frame in the probe (HaloProbe). Each
// control takes at least a SuiteSize.pillHit square (24 pt) to click, not
// just its 10 pt glyph, the squares edge to edge so the row stays narrow
// enough for the status bar, until TransportCapsule (#340) replaces it.
import HaloModel
import SuiteUI
import SwiftUI

struct HaloTransport: View {
    let model: HaloProject
    var perform: @MainActor (HaloCommand) -> Void = { _ in }

    @State private var driver: SuitePlaybackDriver?
    @Environment(\.haloRefreshLink) private var makeLink
    @Environment(\.suiteProbeRecorder) private var recorder

    var body: some View {
        // The frame on screen (a live scrub or playing frame, else `model`)
        // decides every button: its enabled state, tooltip and ink come from
        // one HaloTransportState in this pass (#4352).
        HaloPlayheadShown(model: model) { shown in
            HaloPlayButtons(state: HaloTransportState(shown), target: HaloMenuState(project: shown), perform: perform)
                .equatable()
        }
        .onChange(of: model.playback.playing, initial: true) { _, playing in follow(playing: playing) }
        .background {
            HaloPlayheadShown(model: model) { shown in
                Color.clear.onChange(of: shown.selectedComposition?.playheadFrame) {
                    if shown.playback.playing { frameShown() }
                }
            }
        }
        .onDisappear { driver?.stop() }
    }

    /// Each button's SF Symbol; Play's turns to pause while playing.
    nonisolated static func symbol(_ command: HaloCommand, playing: Bool) -> String {
        switch command {
        case .goToStart: "backward.end.fill"
        case .previousFrame: "backward.frame.fill"
        case .playPause: playing ? "pause.fill" : "play.fill"
        case .nextFrame: "forward.frame.fill"
        case .goToEnd: "forward.end.fill"
        default: "repeat"
        }
    }

    /// Each button's control id.
    nonisolated static func id(_ command: HaloCommand) -> String {
        switch command {
        case .goToStart: "halo.transport.start"
        case .previousFrame: "halo.transport.previous"
        case .playPause: "halo.transport.play"
        case .nextFrame: "halo.transport.next"
        case .goToEnd: "halo.transport.end"
        default: "halo.transport.loop"
        }
    }

    /// Starts the display link while playing and stops it otherwise.
    private func follow(playing: Bool) {
        guard playing else {
            driver?.stop()
            return
        }
        let perform = perform
        // The tick never stops the link itself: this view stops it once the Model stops playing.
        let running = driver ?? SuitePlaybackDriver(onTick: { now in perform(.tick(now)); return true }, makeLink: makeLink)
        driver = running
        running.start()
    }

    /// The latest tick moved the playhead: one `playback` frame at the target of the refresh that moved it.
    private func frameShown() {
        let probe = HaloProbe(recorder)
        guard probe.isOn, let target = driver?.lastTarget else { return }
        probe.drew(HaloProbe.playback, at: target)
    }
}

extension EnvironmentValues {
    /// The link the transport's driver and an inspector scrub run on: the main screen's display link. A test
    /// hosting the whole window swaps in a link it fires by hand; no unit test ever starts a real one.
    @Entry var haloRefreshLink: SuitePlaybackDriver.LinkMaker = SuiteScreenLink.make
}

/// The transport's buttons for `state`. `target` is the same frame on screen,
/// which each button's catalog spec reads; it decides nothing `state` doesn't,
/// so it and `perform` (the window's, always acting on its current project)
/// are left out of `==`: a playing frame that leaves every button as it was
/// skips this body.
struct HaloPlayButtons: View, Equatable {
    let state: HaloTransportState
    let target: HaloMenuState
    let perform: @MainActor (HaloCommand) -> Void

    nonisolated static func == (a: Self, b: Self) -> Bool { a.state == b.state }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(state.buttons) { button in
                let help = button.unavailableHelp
                control(for: button)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    // A pill control's hit target: at least pillHit square
                    // (design.md, Symbols and controls), clickable across it.
                    .frame(minWidth: SuiteSize.pillHit, minHeight: SuiteSize.pillHit)
                    .contentShape(Rectangle())
                    .disabled(!button.isEnabled)
                    // Its own ink, so the status bar pill's textSecondary can't
                    // draw a disabled button as live: tertiary while disabled,
                    // accent for Loop while it is on.
                    .foregroundStyle(ink(for: button))
                    .help(help ?? button.title)
                    .accessibilityValue(Text(verbatim: value(for: button.command)))
                    .haloControl(id: HaloTransport.id(button.command), enabled: button.isEnabled, help: help)
            }
        }
    }

    /// Loop is a button-style Toggle, so the system draws its on state;
    /// the rest are plain buttons sending their command, enabled and helped
    /// as their catalog spec says (command-state CS-8).
    @ViewBuilder private func control(for button: HaloTransportState.Button) -> some View {
        if button.command == .toggleLoop {
            Toggle(isOn: Binding(get: { state.loops }, set: { _ in perform(.toggleLoop) })) {
                Label(button.title, systemImage: HaloTransport.symbol(button.command, playing: false))
            }
            .toggleStyle(.button)
            .tint(SuiteColor.accent)
        } else {
            MenuCommand(HaloMenuState.spec(button.command.commandID), on: target, title: button.title,
                        systemImage: HaloTransport.symbol(button.command, playing: state.playing)) { perform(button.command) }
        }
    }

    /// Tertiary while disabled, accent for Loop while on, else secondary.
    private func ink(for button: HaloTransportState.Button) -> Color {
        guard button.isEnabled else { return SuiteColor.textTertiary }
        return button.command == .toggleLoop && state.loops ? SuiteColor.accent : SuiteColor.textSecondary
    }

    /// Play reads "Playing"/"Paused", Loop "On"/"Off"; the others no value.
    private func value(for command: HaloCommand) -> String {
        switch command {
        case .playPause: state.playLabel
        case .toggleLoop: state.loopLabel
        default: ""
        }
    }
}

// HaloTransport.swift: the status bar's transport (viewer-playback #37,
// VP-10): five plain SF Symbol buttons and a Loop toggle sending their
// HaloCommand, disabled with `unavailableHelp(for:)` as the tooltip while the
// Model can't act, and drawn in textTertiary then so they look disabled
// inside the pill. Play shows pause.fill while playing and reads `playLabel`
// as its value. Loop is a button-style Toggle that reads `loopLabel` and
// draws its on state (system highlight, accent ink) so a person can see
// whether looping is on. It owns the HaloPlaybackDriver: running while
// `model.playback.playing`, stopped otherwise or once the transport leaves
// the screen, on the `haloRefreshLink` the environment gives; each refresh
// sends `.tick(now)` through `perform`. Each
// control takes at least a SuiteSize.pillHit square (24 pt) to click, not
// just its 10 pt glyph, the squares edge to edge so the row stays narrow
// enough for the status bar, until TransportCapsule (#340) replaces it.
import HaloModel
import SuiteUI
import SwiftUI

struct HaloTransport: View {
    let model: HaloProject
    var perform: @MainActor (HaloCommand) -> Void = { _ in }

    @State private var driver: HaloPlaybackDriver?
    @Environment(\.haloRefreshLink) private var makeLink

    /// One transport button: its command, SF Symbol and control id.
    private struct Item: Identifiable, Sendable {
        let command: HaloCommand
        let symbol: String
        let id: String
    }

    private static let items = [
        Item(command: .goToStart, symbol: "backward.end.fill", id: "halo.transport.start"),
        Item(command: .previousFrame, symbol: "backward.frame.fill", id: "halo.transport.previous"),
        Item(command: .playPause, symbol: "play.fill", id: "halo.transport.play"),
        Item(command: .nextFrame, symbol: "forward.frame.fill", id: "halo.transport.next"),
        Item(command: .goToEnd, symbol: "forward.end.fill", id: "halo.transport.end"),
        Item(command: .toggleLoop, symbol: "repeat", id: "halo.transport.loop"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Self.items) { item in
                let help = model.unavailableHelp(for: item.command)
                control(for: item)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    // A pill control's hit target: at least pillHit square
                    // (design.md, Symbols and controls), clickable across it.
                    .frame(minWidth: SuiteSize.pillHit, minHeight: SuiteSize.pillHit)
                    .contentShape(Rectangle())
                    .disabled(help != nil)
                    // Its own ink, so the status bar pill's textSecondary can't
                    // draw a disabled button as live: tertiary while disabled,
                    // accent for Loop while it is on.
                    .foregroundStyle(ink(for: item.command, enabled: help == nil))
                    .help(help ?? model.title(for: item.command))
                    .accessibilityValue(Text(verbatim: value(for: item.command)))
                    .haloControl(id: item.id, enabled: help == nil, help: help)
            }
        }
        .onChange(of: model.playback.playing, initial: true) { _, playing in follow(playing: playing) }
        .onDisappear { driver?.stop() }
    }

    /// Loop is a button-style Toggle, so the system draws its on state;
    /// the rest are plain buttons sending their command.
    @ViewBuilder private func control(for item: Item) -> some View {
        if item.command == .toggleLoop {
            Toggle(isOn: Binding(get: { model.playback.loops }, set: { _ in perform(.toggleLoop) })) {
                Label(model.title(for: item.command), systemImage: item.symbol)
            }
            .toggleStyle(.button)
            .tint(SuiteColor.accent)
        } else {
            Button(model.title(for: item.command), systemImage: symbol(for: item)) { perform(item.command) }
        }
    }

    /// Tertiary while disabled, accent for Loop while on, else secondary.
    private func ink(for command: HaloCommand, enabled: Bool) -> Color {
        guard enabled else { return SuiteColor.textTertiary }
        return command == .toggleLoop && model.playback.loops ? SuiteColor.accent : SuiteColor.textSecondary
    }

    /// Play's symbol turns to pause while playing; the rest keep theirs.
    private func symbol(for item: Item) -> String {
        item.command == .playPause && model.playback.playing ? "pause.fill" : item.symbol
    }

    /// Play reads "Playing"/"Paused", Loop "On"/"Off"; the others no value.
    private func value(for command: HaloCommand) -> String {
        switch command {
        case .playPause: model.playLabel
        case .toggleLoop: model.loopLabel
        default: ""
        }
    }

    /// Starts the display link while playing and stops it otherwise.
    private func follow(playing: Bool) {
        guard playing else {
            driver?.stop()
            return
        }
        let perform = perform
        let running = driver ?? HaloPlaybackDriver(onTick: { now in perform(.tick(now)) }, makeLink: makeLink)
        driver = running
        running.start()
    }
}

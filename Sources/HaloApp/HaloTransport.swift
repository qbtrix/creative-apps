// HaloTransport.swift: the status bar's transport (viewer-playback #37,
// VP-10): six plain SF Symbol buttons sending their HaloCommand, disabled
// with `unavailableHelp(for:)` as the tooltip while the Model can't act, and
// drawn in textTertiary then so they look disabled inside the pill. Play
// shows pause.fill while playing and reads `playLabel` as its value; Loop
// reads `loopLabel`. It owns the HaloPlaybackDriver: running while
// `model.playback.playing`, stopped otherwise or once the transport leaves
// the screen; each refresh sends `.tick(now)` through `perform`.
import HaloModel
import SuiteUI
import SwiftUI

struct HaloTransport: View {
    let model: HaloProject
    var perform: @MainActor (HaloCommand) -> Void = { _ in }

    @State private var driver: HaloPlaybackDriver?

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
        HStack(spacing: SuiteSpacing.xs) {
            ForEach(Self.items) { item in
                let help = model.unavailableHelp(for: item.command)
                Button(model.title(for: item.command), systemImage: symbol(for: item)) { perform(item.command) }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .disabled(help != nil)
                    // Its own ink, so the status bar pill's textSecondary can't
                    // draw a disabled button as live: tertiary while disabled.
                    .foregroundStyle(help == nil ? SuiteColor.textSecondary : SuiteColor.textTertiary)
                    .help(help ?? model.title(for: item.command))
                    .accessibilityValue(Text(verbatim: value(for: item.command)))
                    .haloControl(id: item.id, enabled: help == nil, help: help)
            }
        }
        .onChange(of: model.playback.playing, initial: true) { _, playing in follow(playing: playing) }
        .onDisappear { driver?.stop() }
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
        let running = driver ?? HaloPlaybackDriver { now in perform(.tick(now)) }
        driver = running
        running.start()
    }
}

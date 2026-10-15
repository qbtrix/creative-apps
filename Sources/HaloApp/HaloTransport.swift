// HaloTransport.swift: the status bar's transport: plain SF Symbol buttons
// sending their HaloCommand, disabled with `unavailableHelp(for:)` as the
// tooltip while the Model can't act. viewer-playback (#37) replaces it.
import HaloModel
import SuiteUI
import SwiftUI

struct HaloTransport: View {
    let model: HaloProject
    var perform: @MainActor (HaloCommand) -> Void = { _ in }

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
                Button(model.title(for: item.command), systemImage: item.symbol) { perform(item.command) }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .disabled(help != nil)
                    .help(help ?? model.title(for: item.command))
                    .haloControl(id: item.id, enabled: help == nil, help: help)
            }
        }
    }
}

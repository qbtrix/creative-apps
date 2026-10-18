// SuiteTransportSnapshots.swift: TransportCapsule playing, paused, looped and
// with frameCount 0 (every button disabled with the face's reason), stacked
// on the editor panel in Light and Dark. Writes suiteui-transport-light.png
// and suiteui-transport-dark.png, and checks the same stack against
// Golden/chrome/transport-<appearance>.png in the four appearances (EC-12
// commits the baselines). Each button registers `suite.transport.<id>` with
// the reason its tooltip shows, and the timecode's tooltip is the face's
// `timecodeHelp`. SwiftUI builds no accessibility tree for a hosting view
// without an assistive client, so the inventory and the capsule's own items
// stand in for it. macOS only.
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SuiteTransportSnapshots {
    @Test func transportStates() throws {
        try snapshot(TransportSheet(), name: "suiteui-transport-light", scheme: .light)
        try snapshot(TransportSheet(), name: "suiteui-transport-dark", scheme: .dark)
    }

    @Test func transportGolden() {
        let size = CGSize(width: 420, height: 230)
        for appearance in SnapshotAppearance.allCases {
            assertGolden(TransportStack(), size: size, name: "transport", area: "chrome", appearance: appearance)
        }
    }

    @Test func eachButtonRegistersTheReasonItsTooltipShows() throws {
        for state in [TransportStack.paused, TransportStack.empty] {
            let capsule = TransportStack.capsule(state, stepping: FakeTransportStepping())
            let store = SuiteControlStore()
            _ = try #require(render(capsule.environment(\.suiteControlStore, store), scheme: .light))
            let entries = store.inventory.document().controls
            #expect(entries.map(\.id) == capsule.items.map(\.id).sorted())
            for item in capsule.items {
                let entry = entries.first { $0.id == item.id }
                #expect(entry?.reason == item.help, "\(item.id)")
                #expect(entry?.enabled == (item.help == nil), "\(item.id)")
                #expect(item.tooltip == (entry?.reason ?? item.title), "\(item.id)")
            }
            #expect(store.inventory.violations().isEmpty)
        }
    }

    @Test func nothingToPlayDisablesEveryButtonWithTheFacesReason() {
        let capsule = TransportStack.capsule(TransportStack.empty, stepping: FakeTransportStepping())
        #expect(capsule.items.map(\.tooltip) == Array(repeating: "Nothing to play.", count: 6))
        let live = TransportStack.capsule(TransportStack.paused, stepping: FakeTransportStepping())
        #expect(live.items.map(\.tooltip) == ["Go to Start", "Previous Frame", "Play", "Next Frame", "Go to End", "Loop"])
    }

    @Test func playingShowsPauseAndTheTimecodeTooltipIsTheFaces() {
        let capsule = TransportStack.capsule(TransportStack.playing, stepping: HelpedStepping())
        let play = capsule.items.first { $0.id == "suite.transport.play" }
        #expect(play?.title == "Pause")
        #expect(play?.systemImage == "pause.fill")
        #expect(capsule.face.timecodeHelp == HelpedStepping.help)
    }

    @Test func theTimecodeSplitsIntoCurrentAndTotal() {
        let parts = TransportCapsule.timecodeParts("00:12 / 02:00")
        #expect(parts.current == "00:12")
        #expect(parts.total == " / 02:00")
        let bare = TransportCapsule.timecodeParts("--:--")
        #expect(bare.current == "--:--")
        #expect(bare.total.isEmpty)
    }
}

/// The Fake's face plus a timecode tooltip, so the test can tell the tooltip came from the face.
private struct HelpedStepping: TransportStepping {
    static let help = "Seconds:frames at 24 fps."
    private let fake = FakeTransportStepping()
    func stepped(_ state: TransportState, by frames: Int) -> TransportState { fake.stepped(state, by: frames) }
    func toStart(_ state: TransportState) -> TransportState { fake.toStart(state) }
    func toEnd(_ state: TransportState) -> TransportState { fake.toEnd(state) }
    func face(_ state: TransportState) -> TransportFace {
        var face = fake.face(state)
        face.timecodeHelp = Self.help
        return face
    }
}

/// The capsule paused, playing, looped and with nothing to play, one under another.
private struct TransportStack: View {
    static let paused = TransportState(frame: 12, frameCount: 48, fps: 24)
    static let playing = TransportState(frame: 30, frameCount: 48, fps: 24, isPlaying: true)
    static let looped = TransportState(frame: 47, frameCount: 48, fps: 24, loops: true)
    static let empty = TransportState(frame: 0, frameCount: 0, fps: 24)

    static func capsule(_ state: TransportState, stepping: some TransportStepping = SuiteTransport()) -> TransportCapsule {
        TransportCapsule(
            state: state, stepping: stepping, onPlay: {}, onStep: { _ in }, onStart: {}, onEnd: {}, onLoop: { _ in })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.m) {
            ForEach([Self.paused, Self.playing, Self.looped, Self.empty], id: \.self) { Self.capsule($0) }
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SuiteColor.panel)
    }
}

private struct TransportSheet: View {
    var body: some View {
        TransportStack()
            .frame(width: 420, height: 230)
            .padding(SuiteSpacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

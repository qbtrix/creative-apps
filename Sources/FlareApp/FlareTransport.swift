// FlareTransport.swift: the transport above the timeline strip (draw-key-save
// DK-11). A flat row, no glass: it sits in the band under the stage, not over
// the artwork (#1858). Go to Start, Previous Frame, Play/Pause, Next Frame,
// Go to End and Loop, each from its FlareIntent: the intent's title,
// `perform` on a click, and `help(for:in:)`'s reason while it can't act: no
// timeline can play, or the playhead already stands where a start, end or
// step would put it (#1839). The steps and ends are borderless
// SuiteSize.transportButton squares in secondary ink (tertiary while
// disabled); Play is the larger
// round SuiteSize.playButton button, bordered prominent in accentFill with a
// white glyph, showing pause and reading "Playing" (and selected) while
// playing; Loop is a button-style Toggle, so the system draws its whole on
// state. The two steps share one intent identifier, so each gets a direction
// suffix and `suite.controls` holds no duplicate. The row is only the
// controls, so it fits the narrowest content column: the status pills (IT-9)
// live in the stage's one ViewerStatusBar (FlareStage.statusPills), and the
// PlaybackDriver lives in FlareCanvas. A second status bar here made the row
// wider than the column, so it overflowed both sides under the sidebar and
// the inspector (#2101). It only reads `model`; TransportCapsule (#340)
// replaces the row.
import FlareModel
import SuiteUI
import SwiftUI

struct FlareTransport: View {
    let model: FlareWorkspace
    let perform: @MainActor (FlareIntent) -> Void

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

    /// One transport control: its intent, look, title, symbol, control id and why it can't act.
    struct Item: Identifiable {
        enum Kind: Equatable { case step, play, loop }
        let intent: FlareIntent
        let kind: Kind
        let title: String
        let systemImage: String
        let id: String
        let help: String?
    }

    /// The transport's controls on `model`, in order.
    static func items(for model: FlareWorkspace) -> [Item] {
        let rows: [(FlareIntent.Timeline, Item.Kind, String, String)] = [
            (.goToStart, .step, "backward.end.fill", ""),
            (.step(-1), .step, "backward.frame.fill", ".back"),
            (.togglePlay, .play, model.isPlaying ? "pause.fill" : "play.fill", ""),
            (.step(1), .step, "forward.frame.fill", ".forward"),
            (.goToEnd, .step, "forward.end.fill", ""),
            (.setLoops(!model.loops), .loop, "repeat", ""),
        ]
        return rows.map { timeline, kind, image, suffix in
            let intent = FlareIntent.timeline(timeline)
            return Item(
                intent: intent, kind: kind, title: intent.title, systemImage: image,
                id: intent.identifier + suffix, help: help(for: timeline, in: model))
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Self.items(for: model)) { item in
                control(item)
                    .disabled(item.help != nil)
                    // After .disabled, so the tooltip still shows on a disabled control.
                    .help(item.help ?? item.title)
                    .accessibilityLabel(item.title)
                    .suiteControl(id: item.id, enabled: item.help == nil, reason: item.help)
            }
        }
        .fixedSize()
        .accessibilityElement(children: .contain)
    }

    /// Play is the round accentFill button, Loop a button-style Toggle, the rest borderless squares.
    @ViewBuilder private func control(_ item: Item) -> some View {
        let label = Label(item.title, systemImage: item.systemImage).labelStyle(.iconOnly)
        switch item.kind {
        case .play:
            Button { perform(item.intent) } label: {
                label.frame(width: SuiteSize.playButton, height: SuiteSize.playButton)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .tint(SuiteColor.accentFill)
            .padding(.horizontal, SuiteSpacing.xxs)
            .accessibilityValue(Text(verbatim: model.isPlaying ? "Playing" : "Paused"))
            .accessibilityAddTraits(model.isPlaying ? .isSelected : [])
        case .loop:
            Toggle(isOn: Binding(get: { model.loops }, set: { _ in perform(item.intent) })) {
                label.frame(width: SuiteSize.transportButton, height: SuiteSize.transportButton)
            }
            .toggleStyle(.button)
            .tint(SuiteColor.accent)
        case .step:
            Button { perform(item.intent) } label: {
                label.frame(width: SuiteSize.transportButton, height: SuiteSize.transportButton)
                    .contentShape(.rect)
            }
            .buttonStyle(.borderless)
            // Its own ink, tertiary while disabled, so a disabled step can't read as live.
            .foregroundStyle(item.help == nil ? SuiteColor.textSecondary : SuiteColor.textTertiary)
        }
    }
}

// FlareTimeline.swift: the timeline under the stage (draw-key-save DK-10).
// The transport (FlareTransport, DK-11) and the readouts (`timecode` and
// `frameReadout`) sit on one row above a TimelineStrip with one lane per row
// of `timelineRows`: its name and its key frames as diamonds, the playhead on
// `currentFrame`. Dragging the ruler scrubs through `.timeline(.scrub)`, and a
// name selects its layer through `.layers(.select)`. The strip's duration is
// the last frame, and its frames are fitted to the width it is offered less
// the name column, the divider and the trailing room, so every frame shows and
// the lanes never scroll sideways. With no rows it shows `timelineEmptyText`.
// The strip's track buttons come from SuiteUI with no identifier of their own,
// so the strip passes `flare.timeline.track` down to them, as Halo's does.
// XCUITest reads a Text's value as "" (#262), so each readout also carries its
// text as its accessibility label, which journeys and VoiceOver read. It draws
// in primary text: the small monospaced caption in secondary text measured
// 4.20:1 on the panel (#1836).
// It only reads `model`.
import FlareModel
import SuiteUI
import SwiftUI

struct FlareTimeline: View {
    let model: FlareWorkspace
    let zoom: Double?
    let perform: @MainActor (FlareIntent) -> Void
    let tick: @MainActor (Double, inout PlaybackTicker) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            HStack(spacing: SuiteSpacing.m) {
                FlareTransport(model: model, zoom: zoom, perform: perform, tick: tick)
                Spacer(minLength: 0)
                readout(model.timecode, identifier: "flare.timeline.timecode")
                readout(model.frameReadout, identifier: "flare.timeline.frame")
            }
            .padding(.horizontal, SuiteSpacing.m)
            if let text = model.timelineEmptyText {
                Text(text)
                    .font(SuiteFont.caption)
                    .foregroundStyle(SuiteColor.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: SuiteSize.timelineLane)
            } else {
                strip
            }
        }
        .padding(.vertical, SuiteSpacing.s)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Timeline")
        .accessibilityIdentifier("flare.timeline")
    }

    /// One readout, its text also its label; empty with no timeline.
    private func readout(_ text: String?, identifier: String) -> some View {
        Text(text ?? "")
            .font(SuiteFont.timecode)
            .foregroundStyle(SuiteColor.textPrimary)
            .accessibilityLabel(text ?? "")
            .accessibilityIdentifier(identifier)
    }

    private var strip: some View {
        let rows = model.timelineRows
        let selected = model.selectedTimelineRowID
        let tracks = rows.map {
            TimelineTrack(id: $0.layerID, name: $0.name, keyframes: $0.keyFrames, isSelected: $0.layerID == selected)
        }
        let lastFrame = max(model.timelineFrames - 1, 0)
        return GeometryReader { proxy in
            let lanes = max(proxy.size.width - SuiteSize.timelineLabelColumn - 1 - SuiteSpacing.xl, 0)
            TimelineStrip(
                tracks: tracks, duration: lastFrame, frameWidth: lanes / CGFloat(max(lastFrame, 1)),
                playhead: model.currentFrame,
                onScrub: { perform(.timeline(.scrub(frame: $0))) },
                onSelectTrack: { perform(.layers(.select(id: $0))) })
                .accessibilityIdentifier("flare.timeline.track")
        }
        .frame(height: SuiteSize.timelineRuler + SuiteSize.timelineLane * CGFloat(rows.count))
    }
}

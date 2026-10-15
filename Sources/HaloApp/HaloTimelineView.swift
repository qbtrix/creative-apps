// HaloTimelineView.swift: Halo's timeline: a TimelineStrip track per layer,
// its span bar from in to out point and a diamond on each key frame. The
// ruler scrubs, a track selects its layer, a diamond its lane's keys; a click
// gives it focus so HaloViewer's keys reach it. No layers: how to add one.
import HaloModel
import SuiteUI
import SwiftUI

struct HaloTimelineView: View {
    let model: HaloProject
    var perform: @MainActor (HaloCommand) -> Void = { _ in }
    @FocusState private var hasFocus: Bool

    var body: some View {
        let rows = model.timelineRows
        let tracks = rows.map {
            TimelineTrack(id: $0.id, name: $0.name, keyframes: $0.keyFrames, spans: [$0.span], isSelected: $0.isSelected)
        }
        let duration = model.selectedComposition?.durationFrames ?? 0
        VStack(alignment: .leading, spacing: 0) {
            GeometryReader { geometry in
                let lanes = Double(geometry.size.width - SuiteSize.timelineLabelColumn - SuiteSpacing.xl)
                TimelineStrip(
                    tracks: tracks, duration: duration,
                    frameWidth: CGFloat(model.selectedComposition?.frameWidth(toFit: lanes) ?? 1),
                    playhead: model.selectedComposition?.playheadFrame ?? 0,
                    onScrub: { frame in
                        hasFocus = true
                        perform(.scrub(frame))
                    },
                    onSelectKeyframe: { id, frame in
                        hasFocus = true
                        perform(.selectLaneKeys(layerID: id, frame: frame, extending: false))
                    },
                    onSelectTrack: { id in
                        hasFocus = true
                        perform(.selectLayer(id))
                    })
            }
            .frame(height: SuiteSize.timelineRuler + SuiteSize.timelineLane * CGFloat(rows.count))
            if rows.isEmpty {
                Text("No layers yet. Add one from Layer > New.")
                    .font(SuiteFont.caption)
                    .foregroundStyle(SuiteColor.textSecondary)
                    .padding(SuiteSpacing.m)
            }
        }
        .focusable()
        .focused($hasFocus)
        .focusEffectDisabled()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Timeline")
        .accessibilityIdentifier("halo.timeline")
        .help("Drag the ruler to move the playhead. I sets the selected layer's in point, O its out point.")
    }
}

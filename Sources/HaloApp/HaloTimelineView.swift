// HaloTimelineView.swift: Halo's timeline: a TimelineStrip track per layer,
// its span bar from in to out point and a diamond on each key frame. The
// ruler scrubs, a track selects its layer, a diamond its lane's keys (its
// layer while key picking can't act); a click gives it focus so HaloViewer's
// keys reach it. The tooltip is the Model's timelineHelp. No layers: how to add one,
// in the lane under the ruler.
// The strip's track buttons come from SuiteUI with no identifier of their
// own, so the strip passes `halo.timeline.track` down to each of them (#290).
// The strip sits in the column's safe area. HaloTimelineLayout fits its lanes
// to the width the strip is laid out at, measured with onGeometryChange (the
// GeometryReader's width only until then, and in snapshots), less the name
// column, the divider and the trailing room: a container width can count room
// under the inspector, and lanes fitted to it lost their last frames (#1019).
// So every frame and key shows, the strip never scrolls sideways and
// no scroller covers the ruler; the height is the lanes, at least the slot
// minimum, at most 40% of the window's column, and past that the lanes
// scroll vertically so the canvas keeps its room.
import HaloModel
import SuiteUI
import SwiftUI

struct HaloTimelineView: View {
    let model: HaloProject
    var perform: @MainActor (HaloCommand) -> Void = { _ in }
    @FocusState private var hasFocus: Bool
    /// The strip's laid-out width, once measured.
    @State private var stripWidth: Double?
    @Environment(\.suiteSnapshotRendering) private var snapshot

    /// SuiteUI's timeline tokens; the 1 pt is the strip's Divider.
    static let layout = HaloTimelineLayout(
        labelColumn: Double(SuiteSize.timelineLabelColumn), divider: 1, trailingRoom: Double(SuiteSpacing.xl),
        ruler: Double(SuiteSize.timelineRuler), lane: Double(SuiteSize.timelineLane),
        minimumHeight: Double(SuiteSize.timelineSlotMinimum))

    var body: some View {
        let rows = model.timelineRows
        let layout = Self.layout
        Group {
            // ImageRenderer can't draw a ScrollView or measure a container,
            // so snapshots show the whole strip at its uncapped height.
            if snapshot {
                content(rows).frame(
                    height: CGFloat(max(layout.contentHeight(rows: rows.count), layout.minimumHeight)), alignment: .top)
            } else {
                ScrollView(.vertical) { content(rows) }
                    .scrollIndicators(.never, axes: .horizontal)
                    .scrollBounceBehavior(.basedOnSize, axes: [.horizontal, .vertical])
                    .containerRelativeFrame(.vertical, alignment: .top) { length, _ in
                        CGFloat(layout.height(rows: rows.count, available: Double(length)))
                    }
            }
        }
        .focusable()
        .focused($hasFocus)
        .focusEffectDisabled()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Timeline")
        .accessibilityIdentifier("halo.timeline")
        .help(model.timelineHelp)
    }

    private func content(_ rows: [HaloTimelineRow]) -> some View {
        let tracks = rows.map {
            TimelineTrack(id: $0.id, name: $0.name, keyframes: $0.keyFrames, spans: [$0.span], isSelected: $0.isSelected)
        }
        let height = SuiteSize.timelineRuler + SuiteSize.timelineLane * CGFloat(rows.count)
        return VStack(alignment: .leading, spacing: 0) {
            GeometryReader { geometry in
                let lanes = Self.layout.laneFitWidth(strip: stripWidth, container: Double(geometry.size.width))
                TimelineStrip(
                    tracks: tracks, duration: model.selectedComposition?.durationFrames ?? 0,
                    frameWidth: CGFloat(model.selectedComposition?.frameWidth(toFit: lanes) ?? 1),
                    playhead: model.selectedComposition?.playheadFrame ?? 0,
                    onScrub: { frame in
                        hasFocus = true
                        perform(.scrub(frame))
                    },
                    onSelectKeyframe: { id, frame in
                        hasFocus = true
                        perform(model.keyClickCommand(layerID: id, frame: frame))
                    },
                    onSelectTrack: { id in
                        hasFocus = true
                        perform(.selectLayer(id))
                    })
                    .accessibilityIdentifier("halo.timeline.track")
                    .onGeometryChange(for: Double.self) { Double($0.size.width) } action: { stripWidth = $0 }
            }
            .frame(height: height)
            if rows.isEmpty {
                Label("No layers yet. Add one from Layer > New.", systemImage: "square.stack.3d.up")
                    .font(SuiteFont.caption)
                    .foregroundStyle(SuiteColor.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: SuiteSize.timelineLane)
            }
        }
    }
}

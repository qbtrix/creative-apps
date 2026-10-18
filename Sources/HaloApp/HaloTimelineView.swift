// HaloTimelineView.swift: Halo's timeline: a TimelineStrip track per layer,
// its span bar from the in point to the last frame shown and a diamond on each
// key frame. The strip's `duration` is the last frame (`lastFrame`), so the
// ruler ends on it. The ruler scrubs, a name or a click anywhere on a lane
// selects its layer (the strip reports only name and key clicks, so a
// simultaneous tap finds the lane through HaloTimelineLayout.row), a diamond
// picks its lane's keys (its layer while key picking can't act), Shift
// extending the pick (selectLaneKeys); a click gives it focus so HaloViewer's
// keys reach it.
// The strip's context menu holds the five easing presets for the picked keys,
// each disabled with the Model's unavailableHelp as its help while it can't
// act. Plain diamonds until key shapes land (#771). The tooltip is the
// Model's timelineHelp. No layers: how to add one, in the lane under the ruler.
// The strip's track buttons come from SuiteUI with no identifier of their
// own, so the strip passes `halo.timeline.track` down to each of them (#290).
// A lane speaks its key count as its value, which XCUITest reads empty
// (#262), so each row's `keysReadout` ("Ball: 3 keyframes") is also the label
// of a hidden `halo.timeline.keys` element (HaloReadout.swift).
// The strip sits in the column's safe area. HaloTimelineLayout fits its lanes
// to the width the strip is laid out at, measured with onGeometryChange (the
// GeometryReader's width only until then, and in snapshots), less the name
// column, the divider and the trailing room: a container width can count room
// under the inspector, and lanes fitted to it lost their last frames (#1019).
// So every frame and key shows, the strip never scrolls sideways and
// no scroller covers the ruler; the height is the lanes, at least the slot
// minimum, at most 40% of the window's column, and past that the lanes
// scroll vertically so the canvas keeps its room.
import AppKit
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
            TimelineTrack(id: $0.id, name: $0.name, keyframes: $0.keyFrames, spans: [$0.bar], isSelected: $0.isSelected)
        }
        let height = SuiteSize.timelineRuler + SuiteSize.timelineLane * CGFloat(rows.count)
        return VStack(alignment: .leading, spacing: 0) {
            GeometryReader { geometry in
                let lanes = Self.layout.laneFitWidth(strip: stripWidth, container: Double(geometry.size.width))
                TimelineStrip(
                    tracks: tracks, duration: model.selectedComposition?.lastFrame ?? 0,
                    frameWidth: CGFloat(model.selectedComposition?.frameWidth(toFit: lanes) ?? 1),
                    playhead: model.selectedComposition?.playheadFrame ?? 0,
                    onScrub: { frame in
                        hasFocus = true
                        perform(.scrub(frame))
                    },
                    onSelectKeyframe: { id, frame in
                        hasFocus = true
                        perform(keyClick(layerID: id, frame: frame))
                    },
                    onSelectTrack: { id in
                        hasFocus = true
                        perform(.selectLayer(id))
                    })
                    .accessibilityIdentifier("halo.timeline.track")
                    .simultaneousGesture(SpatialTapGesture().onEnded { tap in
                        let hit = Self.layout.row(atX: Double(tap.location.x), y: Double(tap.location.y), rows: rows.count)
                        guard let hit, rows.indices.contains(hit) else { return }
                        hasFocus = true
                        perform(.selectLayer(rows[hit].id))
                    })
                    .contextMenu { easingItems }
                    .onGeometryChange(for: Double.self) { Double($0.size.width) } action: { stripWidth = $0 }
            }
            .frame(height: height)
            .background(alignment: .topLeading) {
                ForEach(rows) { ProbeElement("halo.timeline.keys", label: $0.keysReadout, size: HaloReadout.size) }
            }
            if rows.isEmpty {
                Label("No layers yet. Add one from Layer > New.", systemImage: "square.stack.3d.up")
                    .font(SuiteFont.caption)
                    .foregroundStyle(SuiteColor.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: SuiteSize.timelineLane)
            }
        }
    }

    /// The command a diamond click sends: the Model's pick of that lane's
    /// keys, extended while Shift is held, or its fallback (select the layer)
    /// while key picking can't act.
    private func keyClick(layerID: String, frame: Int) -> HaloCommand {
        let command = model.keyClickCommand(layerID: layerID, frame: frame)
        guard case .selectLaneKeys = command else { return command }
        let extending = NSEvent.modifierFlags.contains(.shift)
        return .selectLaneKeys(layerID: layerID, frame: frame, extending: extending)
    }

    /// The five easing presets for the picked keys, each disabled with why.
    @ViewBuilder private var easingItems: some View {
        ForEach(HaloEasingPreset.allCases, id: \.self) { preset in
            let help = model.unavailableHelp(for: .setEasing(preset))
            Button(preset.title) { perform(.setEasing(preset)) }
                .disabled(help != nil)
                .help(help ?? preset.title)
        }
    }
}

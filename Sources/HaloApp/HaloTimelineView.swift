// HaloTimelineView.swift: Halo's timeline: a TimelineStrip track per layer,
// its span bar from the in point to the last frame shown and a diamond on each
// key frame, drawn picked at the Model's `pickedFrames(of:)`. The strip's
// `duration` is the last frame (`lastFrame`), so the ruler ends on it. The
// ruler scrubs and a name selects its layer. A press on a lane (key-editing
// KE-2) goes through the Model's lanePressCommand in the strip's mode: a key
// picks its lane's keys (plain replaces, Shift extends, Command toggles; its
// layer while key picking can't act), and the bed selects the layer
// (onSelectTrack) and clears the pick. A key drag sends `.moveKeys` per step,
// all under the dragStart taken when it began, then `.endKeyDrag`; ⌘A while
// the strip has focus sends `.selectAllKeys`. A scrub or a name click gives
// the timeline focus so HaloViewer's keys reach it; a lane press leaves the
// focus on the strip, which ⌘A needs.
// The strip's context menu holds the five easing presets for the picked keys
// and Select All Keys, each disabled with the Model's unavailableHelp as its
// help while it can't act. Plain diamonds until key shapes land (#771). The tooltip is the
// Model's timelineHelp. No layers: how to add one, in the lane under the ruler.
// The strip is `halo.timeline.track`; its timelineIdentifierPrefix
// `halo.timeline` gives each name button `halo.timeline.name.<id>`, each lane
// `halo.timeline.lane.<id>` and each key `halo.timeline.key.<id>.<frame>`.
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
// scroll vertically, by wheel and trackpad with no scroller (as Halo's
// inspector), so the canvas keeps its room. Under `-SuitePerfProbe` a
// ruler scrub records a `playhead-scrub` sample and each lane scroll offset a
// `lanes-scroll` frame (HaloProbe).
import HaloModel
import SuiteUI
import SwiftUI

struct HaloTimelineView: View {
    let model: HaloProject
    var perform: @MainActor (HaloCommand) -> Void = { _ in }
    @FocusState private var hasFocus: Bool
    /// The strip's laid-out width, once measured.
    @State private var stripWidth: Double?
    /// The key drag under way: the dragStart its moves fold under.
    @State private var dragStart: Int?
    @Environment(\.suiteSnapshotRendering) private var snapshot
    @Environment(\.suiteProbeRecorder) private var recorder

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
                    // No scroller: with legacy scrollers on crowd's 300 lanes the vertical one's
                    // page areas were unnamed buttons with no identifier to the app audit (#4264).
                    .scrollIndicators(.never)
                    .scrollBounceBehavior(.basedOnSize, axes: [.horizontal, .vertical])
                    .containerRelativeFrame(.vertical, alignment: .top) { length, _ in
                        CGFloat(layout.height(rows: rows.count, available: Double(length)))
                    }
                    .onScrollGeometryChange(for: Double.self) { Double($0.contentOffset.y) } action: { _, _ in
                        HaloProbe(recorder).drew(HaloProbe.lanesScroll)
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
        let tracks = rows.map { row in
            TimelineTrack(
                id: row.id, name: row.name, keys: row.keyFrames.map { TimelineKey(frame: $0, shape: .linear) },
                spans: [row.bar], pickedFrames: model.pickedFrames(of: row.id), isSelected: row.isSelected)
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
                        HaloProbe(recorder).sample(HaloProbe.playheadScrub)
                    },
                    onSelectTrack: { perform(.selectLayer($0)) },
                    onPickKeyframe: { id, frame, mode in
                        if let command = model.lanePressCommand(layerID: id, frame: frame, mode: mode.rawValue) {
                            perform(command)
                        }
                    },
                    onMoveKeyframes: { delta in
                        let start = dragStart ?? model.keyDragStart
                        dragStart = start
                        perform(.moveKeys(by: delta, dragStart: start))
                    },
                    onEndKeyDrag: {
                        dragStart = nil
                        perform(.endKeyDrag)
                    },
                    onSelectAllKeys: { perform(.selectAllKeys) })
                    .accessibilityIdentifier("halo.timeline.track")
                    .environment(\.timelineIdentifierPrefix, "halo.timeline")
                    .contextMenu {
                        easingItems
                        Divider()
                        menuTarget.item(.selectAllKeys)
                    }
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

    /// The five easing presets for the picked keys, each disabled with why.
    @ViewBuilder private var easingItems: some View {
        ForEach(HaloEasingPreset.allCases, id: \.self) { preset in
            menuTarget.item(.setEasing(preset))
        }
    }

    /// Context-menu items built from their catalog specs, as the menu bar's are.
    private var menuTarget: HaloMenuTarget { HaloMenuTarget(model: model, perform: perform) }
}

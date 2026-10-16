// TimelineStrip.swift: the horizontal timeline Flare and Halo share. A fixed
// left column names the tracks; to its right a horizontal scroll area holds a
// frame ruler (TimelineRuler) and one lane per track (TimelineLane), with the
// playhead line (TimelinePlayhead) over both. This file is the layout; each
// part draws in its own file. Lanes show keyframes as diamonds and spans
// (Halo's in and out points) as rounded bars. Tracks are content, so nothing
// here is glass. Values in, closures out: dragging on the ruler calls onScrub,
// clicking a diamond onSelectKeyframe, clicking a name onSelectTrack. All
// frame arithmetic lives in FrameMapping, which clamps, so a closure only ever
// gets a frame inside 0...duration. The ruler draws only the ticks and labels
// inside the scrolled-to stretch, so a long duration costs no more than a
// short one. Moving keyframes by drag is not here yet. The track data is in
// TimelineTrack.swift. The unit, fps, work area, toolbar flag and the pick,
// move, trim, unit and work-area closures are taken and stored; later
// timeline slices act on them.
import SwiftUI

public struct TimelineStrip<ID: Hashable & Sendable>: View {
    private let tracks: [TimelineTrack<ID>]
    private let mapping: FrameMapping
    private let playhead: Int
    private let onScrub: @MainActor (Int) -> Void
    private let onSelectKeyframe: @MainActor (ID, Int) -> Void
    private let onSelectTrack: @MainActor (ID) -> Void
    private let unit: TimeUnit
    private let fps: Int
    private let workArea: ClosedRange<Int>?
    private let toolbar: Bool
    private let onPickKeyframe: @MainActor (ID, Int?, PickMode) -> Void
    private let onMoveKeyframes: @MainActor (Int) -> Void
    private let onEndKeyDrag: @MainActor () -> Void
    private let onTrim: @MainActor (ID, SpanEdge, Int) -> Void
    private let onEndTrim: @MainActor () -> Void
    private let onUnit: @MainActor (TimeUnit) -> Void
    private let onWorkArea: @MainActor (ClosedRange<Int>?) -> Void
    @Environment(\.suiteSnapshotRendering) private var snapshot
    /// The stretch of the lanes the scroll view shows, in mapping x; nil until
    /// it first reports.
    @State private var visibleX: ClosedRange<Double>?

    #if DEBUG
    /// How many times a strip's body ran, over every ID type; the real-window
    /// budget tests count a scrub's.
    static var bodyRuns: Int {
        get { timelineStripBodyRuns }
        set { timelineStripBodyRuns = newValue }
    }
    #endif

    /// `duration` is the last frame and `frameWidth` the points per frame;
    /// `playhead` is the current frame. `unit` and `fps` say how time reads,
    /// `workArea` is the host's work area and `toolbar` shows the strip's own
    /// toolbar. `onPickKeyframe` gets a nil frame when the bed is clicked;
    /// `onMoveKeyframes` gets the frames moved since its last call.
    public init(
        tracks: [TimelineTrack<ID>], duration: Int, frameWidth: CGFloat, playhead: Int,
        unit: TimeUnit = .frames, fps: Int = 0, workArea: ClosedRange<Int>? = nil, toolbar: Bool = false,
        onScrub: @escaping @MainActor (Int) -> Void = { _ in },
        onSelectKeyframe: @escaping @MainActor (ID, Int) -> Void = { _, _ in },
        onSelectTrack: @escaping @MainActor (ID) -> Void = { _ in },
        onPickKeyframe: @escaping @MainActor (ID, Int?, PickMode) -> Void = { _, _, _ in },
        onMoveKeyframes: @escaping @MainActor (Int) -> Void = { _ in },
        onEndKeyDrag: @escaping @MainActor () -> Void = {},
        onTrim: @escaping @MainActor (ID, SpanEdge, Int) -> Void = { _, _, _ in },
        onEndTrim: @escaping @MainActor () -> Void = {},
        onUnit: @escaping @MainActor (TimeUnit) -> Void = { _ in },
        onWorkArea: @escaping @MainActor (ClosedRange<Int>?) -> Void = { _ in }
    ) {
        self.tracks = tracks
        self.mapping = FrameMapping(duration: duration, frameWidth: Double(frameWidth))
        self.playhead = playhead
        self.onScrub = onScrub
        self.onSelectKeyframe = onSelectKeyframe
        self.onSelectTrack = onSelectTrack
        self.unit = unit
        self.fps = fps
        self.workArea = workArea
        self.toolbar = toolbar
        self.onPickKeyframe = onPickKeyframe
        self.onMoveKeyframes = onMoveKeyframes
        self.onEndKeyDrag = onEndKeyDrag
        self.onTrim = onTrim
        self.onEndTrim = onEndTrim
        self.onUnit = onUnit
        self.onWorkArea = onWorkArea
    }

    public var body: some View {
        #if DEBUG
        let _ = Self.bodyRuns += 1
        #endif
        HStack(alignment: .top, spacing: 0) {
            names
            Divider()
            // ImageRenderer can't draw a ScrollView, so snapshots show the
            // lanes clipped at the strip's edge instead.
            if snapshot {
                lanes.frame(maxWidth: .infinity, alignment: .leading).clipped()
            } else {
                ScrollView(.horizontal) { lanes }
                    .onScrollGeometryChange(for: ClosedRange<Double>.self) { geometry in
                        let rect = geometry.visibleRect
                        let low = Double(rect.minX - timelineInset)
                        return low...max(low, Double(rect.maxX - timelineInset))
                    } action: { _, visible in
                        visibleX = visible
                    }
            }
        }
        .frame(height: SuiteSize.timelineRuler + SuiteSize.timelineLane * CGFloat(tracks.count), alignment: .top)
    }

    private var names: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: SuiteSize.timelineRuler)
            ForEach(tracks) { track in
                Button { onSelectTrack(track.id) } label: {
                    Text(track.name)
                        .font(track.isSelected ? SuiteFont.headline : SuiteFont.body)
                        .lineLimit(1)
                        .padding(.horizontal, SuiteSpacing.s)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(height: SuiteSize.timelineLane)
                // `ignoresSafeAreaEdges: []`: a color background ignores every safe-area edge by default,
                // so under a floating sidebar the selected row reached 208 pt left of the strip (#1034).
                .background(track.isSelected ? SuiteColor.accent.opacity(0.15) : Color.clear, ignoresSafeAreaEdges: [])
                .accessibilityAddTraits(track.isSelected ? .isSelected : [])
            }
        }
        .frame(width: SuiteSize.timelineLabelColumn)
    }

    private var lanes: some View {
        VStack(alignment: .leading, spacing: 0) {
            TimelineRuler(mapping: mapping, visibleX: visibleX, playhead: playhead, onScrub: onScrub)
            ForEach(tracks) { track in
                // The strip owns the tap so no closure sits in what `.equatable()` compares.
                TimelineLane(track: track, mapping: mapping).equatable()
                    .contentShape(Rectangle())
                    .modifier(TimelineLaneInput(track: track, mapping: mapping, onSelectKeyframe: onSelectKeyframe))
            }
        }
        .frame(width: CGFloat(mapping.contentWidth) + SuiteSpacing.xl, alignment: .leading)
        .overlay { TimelinePlayhead(mapping: mapping, playhead: playhead).allowsHitTesting(false) }
    }
}

#if DEBUG
/// TimelineStrip.bodyRuns' count: a generic type can't hold a static stored property.
@MainActor private var timelineStripBodyRuns = 0
#endif

/// Room before frame 0, so its diamond and label aren't clipped.
let timelineInset = SuiteSpacing.s

/// The x of a frame's tick inside the lanes.
func tickX(_ mapping: FrameMapping, _ frame: Int) -> CGFloat {
    timelineInset + CGFloat(mapping.x(forFrame: frame))
}

// TimelineStrip.swift: the horizontal timeline Flare and Halo share. The frame
// ruler (TimelineRuler) is pinned along the top, outside both scroll views and
// shifted by the sideways scroll; under it a vertical scroll view holds the
// track names (a fixed left column) and, to their right, a horizontal scroll
// view of one lane per track (TimelineLane). Both stacks are lazy, so a long
// track list builds only the rows in view. The strip's ideal height is the
// toolbar row (when on), the ruler and every lane: a host inside its own
// vertical ScrollView sees every lane, and one that offers less gets lanes
// scrolling under the ruler. TimelineStripLayout holds that arithmetic. The
// playhead line (TimelinePlayhead) sits over the ruler and the lanes. This
// file is the layout; each part draws in its own file. Lanes show keyframes as
// diamonds and spans (Halo's in and out points) as rounded bars. Tracks are
// content, so nothing here is glass. Values in, closures out: dragging on the
// ruler calls onScrub, clicking a diamond onSelectKeyframe, clicking a name
// onSelectTrack. All frame arithmetic lives in FrameMapping, which clamps, so
// a closure only ever gets a frame inside 0...duration. The ruler draws only
// the ticks and labels inside the scrolled-to stretch, so a long duration
// costs no more than a short one. Snapshots offer the lanes and ruler the
// strip's width (#219). Moving keyframes by drag is not here yet. The track
// data is in TimelineTrack.swift. The unit, fps, work area and the pick, move,
// trim, unit and work-area closures are taken and stored; later timeline
// slices act on them.
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
        let layout = TimelineStripLayout(trackCount: tracks.count, toolbar: toolbar)
        VStack(alignment: .leading, spacing: 0) {
            // The toolbar row's room; TL-17 puts the toolbar in it.
            if toolbar { Color.clear.frame(height: layout.toolbarHeight) }
            HStack(spacing: 0) {
                Color.clear.frame(width: SuiteSize.timelineLabelColumn, height: SuiteSize.timelineRuler)
                Divider()
                pinnedRuler(snapshot: snapshot)
            }
            .frame(height: SuiteSize.timelineRuler)
            // ImageRenderer can't draw a ScrollView, so snapshots show the
            // lanes offered the strip's width, clipped at its edge (#219).
            if snapshot {
                HStack(alignment: .top, spacing: 0) {
                    names
                    Divider()
                    GeometryReader { proxy in
                        lanes(width: layout.lanesWidth(
                            contentWidth: mapping.contentWidth, offered: proxy.size.width, snapshot: true))
                    }
                    .clipped()
                }
                .frame(height: layout.lanesHeight, alignment: .top)
            } else {
                // Offered less than the ideal height, the lanes scroll under the pinned ruler.
                ScrollView(.vertical) {
                    HStack(alignment: .top, spacing: 0) {
                        names
                        Divider()
                        ScrollView(.horizontal) {
                            lanes(width: layout.lanesWidth(contentWidth: mapping.contentWidth, offered: 0, snapshot: false))
                        }
                        .onScrollGeometryChange(for: ClosedRange<Double>.self) { geometry in
                            let rect = geometry.visibleRect
                            let low = Double(rect.minX - timelineInset)
                            return low...max(low, Double(rect.maxX - timelineInset))
                        } action: { _, visible in
                            visibleX = visible
                        }
                    }
                }
            }
        }
        // A host inside its own vertical ScrollView proposes no height and gets the ideal one.
        .frame(
            minHeight: layout.toolbarHeight + SuiteSize.timelineRuler, idealHeight: layout.idealHeight,
            maxHeight: layout.idealHeight, alignment: .top
        )
    }

    /// The ruler, outside both scroll views: drawn at the lanes' width and
    /// shifted by the sideways scroll, so its marks sit at x - visibleX.lower
    /// over the lanes. In a snapshot it is offered the strip's width (#219).
    private func pinnedRuler(snapshot: Bool) -> some View {
        let scrollX = (visibleX?.lowerBound ?? -Double(timelineInset)) + Double(timelineInset)
        return GeometryReader { proxy in
            let width = snapshot
                ? max(proxy.size.width, 0) : CGFloat(mapping.contentWidth) + SuiteSpacing.xl
            TimelineRuler(mapping: mapping, visibleX: visibleX, playhead: playhead, onScrub: onScrub)
                .frame(width: width, alignment: .leading)
                .overlay { TimelinePlayhead(mapping: mapping, playhead: playhead).allowsHitTesting(false) }
                .offset(x: snapshot ? 0 : -CGFloat(scrollX))
        }
        .frame(height: SuiteSize.timelineRuler)
        .clipped()
    }

    private var names: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
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

    private func lanes(width: CGFloat) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(tracks) { track in
                // The strip owns the tap so no closure sits in what `.equatable()` compares.
                TimelineLane(track: track, mapping: mapping).equatable()
                    .contentShape(Rectangle())
                    .modifier(TimelineLaneInput(track: track, mapping: mapping, onSelectKeyframe: onSelectKeyframe))
            }
        }
        .frame(width: width, alignment: .leading)
        .overlay { TimelinePlayhead(mapping: mapping, playhead: playhead).allowsHitTesting(false) }
    }
}

/// The strip's layout arithmetic, with no view: the toolbar row, the pinned
/// ruler and the lanes under it (timeline packet, TL-7; TimelineStripLayoutTests).
struct TimelineStripLayout: Equatable, Sendable {
    let trackCount: Int
    let toolbar: Bool

    init(trackCount: Int, toolbar: Bool) {
        self.trackCount = max(trackCount, 0)
        self.toolbar = toolbar
    }

    /// The toolbar row's height: 36 pt when it is on.
    var toolbarHeight: CGFloat { toolbar ? SuiteSize.timelineSlotToolbar : 0 }

    /// Every lane, stacked.
    var lanesHeight: CGFloat { SuiteSize.timelineLane * CGFloat(trackCount) }

    /// The height that shows every lane: toolbar, ruler and lanes.
    var idealHeight: CGFloat { toolbarHeight + SuiteSize.timelineRuler + lanesHeight }

    /// The ruler's top and bottom in the strip: under the toolbar, whatever
    /// the lanes' vertical scroll.
    func rulerFrame(scrollY: CGFloat) -> ClosedRange<CGFloat> {
        toolbarHeight...(toolbarHeight + SuiteSize.timelineRuler)
    }

    /// The rows a lazy stack builds when the strip is offered `offered` points
    /// and the lanes are scrolled `scrollY` down: those in view. Offered the
    /// ideal height or more (or no number), every row.
    func rowsBuilt(offered: CGFloat, scrollY: CGFloat) -> Range<Int> {
        let shown = offered.isNaN ? idealHeight : min(offered, idealHeight)
        let viewport = max(shown - toolbarHeight - SuiteSize.timelineRuler, 0)
        let maxScroll = max(lanesHeight - viewport, 0)
        let y = scrollY.isNaN ? 0 : min(max(scrollY, 0), maxScroll)
        let first = min(Int((y / SuiteSize.timelineLane).rounded(.down)), trackCount)
        let end = min(Int(((y + viewport) / SuiteSize.timelineLane).rounded(.up)), trackCount)
        return first..<max(first, end)
    }

    /// The lanes' width: every frame plus trailing room, or in a snapshot the
    /// width the strip offers them, so ImageRenderer never draws a lane tens
    /// of thousands of points wide (#219).
    func lanesWidth(contentWidth: Double, offered: CGFloat, snapshot: Bool) -> CGFloat {
        snapshot ? max(offered, 0) : CGFloat(contentWidth) + SuiteSpacing.xl
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

// TimelineStrip.swift: the horizontal timeline Flare and Halo share. The frame
// ruler (TimelineRuler) is pinned along the top, outside both scroll views and
// shifted by the sideways scroll; under it a vertical scroll view holds the
// track names (a fixed left column) and, to their right, a horizontal scroll
// view of one lane per track (TimelineLane). Both stacks are lazy, so a long
// track list builds only the rows in view. The strip's ideal height is the
// toolbar row (when on), the ruler and every lane: a host inside its own
// vertical ScrollView sees every lane, and one that offers less gets lanes
// scrolling under the ruler. TimelineStripLayout holds that arithmetic. The
// playhead (TimelinePlayhead) is one layer over the ruler and the lanes. This
// file is the layout; each part draws in its own file. Lanes show keyframes as
// diamonds and spans (Halo's in and out points) as rounded bars. Tracks are
// content, so nothing here is glass. Values in, closures out: dragging on the
// ruler calls onScrub, clicking a diamond onSelectKeyframe, clicking a name
// onSelectTrack. All frame arithmetic lives in FrameMapping, which clamps, so
// a closure only ever gets a frame inside 0...duration. The ruler draws only
// the ticks and labels inside the scrolled-to stretch, so a long duration
// costs no more than a short one. Snapshots offer the lanes and ruler the
// strip's width (#219). Moving keyframes by drag is not here yet. The track
// data is in TimelineTrack.swift. The unit and fps reach the ruler and the
// toolbar's unit chips; the work area reaches the toolbar's Work Area chip and
// the bar on the ruler (TimelineWorkAreaBar, over the playhead), which call
// onUnit and onWorkArea (TL-18). The move and trim closures are taken and
// stored; later timeline slices act on them. The strip owns its zoom (TL-17), a factor over the
// host's frameWidth kept in TimelineZoom's range (1 = fit): Command-plus,
// Command-minus and Command-0 while it has focus (anchored on the playhead),
// a pinch on the lanes (anchored under the pointer) and the toolbar row
// (TimelineToolbar). The lanes scroll sideways by wheel and trackpad, and a
// playhead that leaves the view moves it a page (TimelineZoom.followed).
import SwiftUI

public struct TimelineStrip<ID: Hashable & Sendable>: View {
    private let tracks: [TimelineTrack<ID>]
    /// The host's mapping: zoom 1.
    private let fitMapping: FrameMapping
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
    /// The lanes' visible y range; nil until the vertical scroll view first reports.
    @State private var visibleY: ClosedRange<Double>?
    /// The zoom over the host's frameWidth; 1 is fit.
    @State private var zoom: Double = 1
    /// A pinch under way: the zoom it began at and the view x it anchors.
    @State private var pinch: (zoom: Double, anchorX: Double)?
    @State private var position = ScrollPosition()
    /// The content x a zoom scrolls to once the lanes take their new width.
    @State private var pendingScrollX: Double?

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
        self.fitMapping = FrameMapping(duration: duration, frameWidth: Double(frameWidth))
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
            if toolbar {
                TimelineToolbar(
                    zoom: zoom,
                    controls: TimelineToolbarControls(frameWidth: fitMapping.frameWidth, duration: fitMapping.duration, fps: fps),
                    unit: unit, workArea: workArea, onZoom: { setZoom($0, anchorX: nil) }, onUnit: onUnit,
                    onWorkArea: onWorkArea)
            }
            HStack(spacing: 0) {
                Color.clear.frame(width: SuiteSize.timelineLabelColumn, height: SuiteSize.timelineRuler)
                Divider()
                TimelineRuler(mapping: mapping, visibleX: visibleX, playhead: playhead, unit: unit, fps: fps, onScrub: onScrub)
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
                        .scrollPosition($position)
                        // A zoom's scroll waits for the lanes' new width, or it would be clamped to the old one.
                        .onScrollGeometryChange(for: Double.self) { Double($0.contentSize.width) } action: { _, _ in
                            guard let x = pendingScrollX else { return }
                            pendingScrollX = nil
                            position.scrollTo(x: x)
                        }
                    }
                }
                .onScrollGeometryChange(for: ClosedRange<Double>.self) { geometry in
                    let rect = geometry.visibleRect
                    return Double(rect.minY)...max(Double(rect.minY), Double(rect.maxY))
                } action: { _, visible in
                    visibleY = visible
                }
            }
        }
        .overlay(alignment: .topLeading) { playheadLayer(layout) }
        // Over the playhead, so a work-area handle takes the press before the pill and the scrub.
        .overlay(alignment: .topLeading) { workAreaLayer(layout) }
        // A host inside its own vertical ScrollView proposes no height and gets the ideal one.
        .frame(
            minHeight: layout.toolbarHeight + SuiteSize.timelineRuler, idealHeight: layout.idealHeight,
            maxHeight: layout.idealHeight, alignment: .top
        )
        .focusable(!snapshot, interactions: .edit)
        .onKeyPress(phases: [.down, .repeat]) { press in zoomKey(press) }
        .onChange(of: playhead) { _, frame in follow(frame) }
    }

    /// The host's mapping at the strip's zoom.
    private var mapping: FrameMapping {
        FrameMapping(duration: fitMapping.duration, frameWidth: fitMapping.frameWidth * zoom)
    }

    /// The scrolled offset in TimelineZoom's terms (content x less the inset)
    /// and the view's width; nil until the scroll view first reports.
    private var scroll: (offset: Double, width: Double)? {
        guard let visibleX else { return nil }
        let offset = pendingScrollX.map { $0 - Double(timelineInset) } ?? visibleX.lowerBound
        return (offset, visibleX.upperBound - visibleX.lowerBound)
    }

    /// Command-plus (or Command-equals), Command-minus and Command-0, anchored on the playhead.
    private func zoomKey(_ press: KeyPress) -> KeyPress.Result {
        guard press.modifiers.contains(.command), press.modifiers.isDisjoint(with: [.option, .control]),
            let key = TimelineZoomKey(press.key.character)
        else { return .ignored }
        setZoom(key.zoom(from: zoom, frameWidth: fitMapping.frameWidth), anchorX: nil)
        return .handled
    }

    /// Sets the zoom inside TimelineZoom's range and scrolls so what sits at
    /// the view x `anchorX` (the playhead when nil) stays there.
    private func setZoom(_ value: Double, anchorX: Double?) {
        let new = TimelineZoom.clamped(value, frameWidth: fitMapping.frameWidth)
        guard new != zoom else { return }
        let old = zoom
        zoom = new
        // With no frames past 0 the lanes keep their width, so there is nothing to scroll.
        guard let scroll, fitMapping.duration > 0 else { return }
        let anchor = anchorX
            ?? TimelineZoom.x(ofFrame: playhead, frameWidth: fitMapping.frameWidth, zoom: old, offset: scroll.offset)
        let offset = TimelineZoom.anchoredOffset(scroll.offset, anchorX: anchor, from: old, to: new)
        let lanes = Double(fitMapping.duration) * fitMapping.frameWidth * new + Double(SuiteSpacing.xl)
        pendingScrollX = min(max(offset + Double(timelineInset), 0), max(lanes - scroll.width, 0))
    }

    /// The follow rule: a playhead that leaves the view moves it a page.
    private func follow(_ frame: Int) {
        guard let scroll, pendingScrollX == nil else { return }
        let offset = TimelineZoom.followed(
            scroll.offset, playhead: frame, frameWidth: fitMapping.frameWidth, zoom: zoom, viewport: scroll.width)
        if offset != scroll.offset { position.scrollTo(x: max(offset + Double(timelineInset), 0)) }
    }

    /// A pinch on the lanes: continuous, clamped, anchored under the pointer
    /// where it began.
    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let anchorX = Double(value.startLocation.x - timelineInset) - (scroll?.offset ?? 0)
                let start = pinch ?? (zoom: zoom, anchorX: anchorX)
                pinch = start
                setZoom(start.zoom * Double(value.magnification), anchorX: start.anchorX)
            }
            .onEnded { _ in pinch = nil }
    }

    /// The playhead over the ruler and the lanes, right of the names column and its divider.
    private func playheadLayer(_ layout: TimelineStripLayout) -> some View {
        let scrollX = snapshot ? 0 : (visibleX?.lowerBound).map { $0 + Double(timelineInset) } ?? 0
        let rows = TimelinePlayhead.rows(showing: snapshot ? nil : visibleY, count: tracks.count)
        return TimelinePlayhead(
            mapping: mapping, playhead: playhead, unit: unit, fps: fps,
            scroll: CGPoint(x: scrollX, y: snapshot ? 0 : visibleY?.lowerBound ?? 0),
            keys: TimelinePlayhead.keys(at: mapping.clamp(playhead), in: tracks, rows: rows), onScrub: onScrub
        ).equatable()
            .padding(.top, layout.toolbarHeight)
            .padding(.leading, SuiteSize.timelineLabelColumn + TimelinePlayheadGrab.divider)
    }

    /// The work area's bar and handles on the ruler (TL-18).
    private func workAreaLayer(_ layout: TimelineStripLayout) -> some View {
        let scrollX = snapshot ? 0 : (visibleX?.lowerBound).map { $0 + Double(timelineInset) } ?? 0
        return TimelineWorkAreaBar(mapping: mapping, workArea: workArea, scrollX: scrollX, onWorkArea: onWorkArea)
            .padding(.top, layout.toolbarHeight)
            .padding(.leading, SuiteSize.timelineLabelColumn + TimelinePlayheadGrab.divider)
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
                    .modifier(TimelineLaneInput(track: track, mapping: mapping, actions: TimelineLaneActions(onSelectKeyframe: onSelectKeyframe, onSelectTrack: onSelectTrack, onPickKeyframe: onPickKeyframe)))
            }
        }
        .frame(width: width, alignment: .leading)
        .simultaneousGesture(pinchGesture, isEnabled: !snapshot)
    }
}

/// The strip's zoom keys with Command held: plus (or equals) zooms in a stop,
/// minus out a stop, 0 back to fit (TL-17; TimelineToolbarTests).
enum TimelineZoomKey: Equatable, Sendable {
    case zoomIn, zoomOut, fit

    init?(_ character: Character) {
        switch character {
        case "=", "+": self = .zoomIn
        case "-": self = .zoomOut
        case "0": self = .fit
        default: return nil
        }
    }

    /// The zoom this key asks for from `zoom`, within range.
    func zoom(from zoom: Double, frameWidth: Double) -> Double {
        switch self {
        case .zoomIn: return TimelineZoom.zoomedIn(from: zoom, frameWidth: frameWidth)
        case .zoomOut: return TimelineZoom.zoomedOut(from: zoom, frameWidth: frameWidth)
        case .fit: return TimelineToolbarControls.fitZoom
        }
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

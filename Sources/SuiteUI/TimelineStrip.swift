// TimelineStrip.swift: the horizontal timeline Flare and Halo share. The frame
// ruler (TimelineRuler) is pinned along the top, outside both scroll views and
// shifted by the sideways scroll; under it a vertical scroll view holds the
// track names (a fixed left column) and, to their right, a horizontal scroll
// view of one lane per track (TimelineLaneRow: the lane and its input). The
// names stack is lazy; the lanes stack, laid out at every lane's height inside
// the sideways scroll, builds only the rows the vertical scroll shows
// (`lanesShown`), with clear space for the rest, so a long track list costs the
// rows in view. Each stack sits behind one `.equatable()` (TimelineNameRows,
// TimelineLaneRows) over the tracks and the mapping (and, for the lanes, the
// rows shown), and a row compares only its track and mapping; the playhead and
// the closures a press needs sit in one unobserved TimelineLaneContext the body
// rewrites. So a frame change runs the playhead layer and never re-evaluates a
// ForEach or a lane, even when layout runs ahead of SwiftUI's flush under load
// (#5804). The strip's ideal height is the
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
// onUnit and onWorkArea (TL-18). ⌘A while the strip has focus calls
// onSelectAllKeys when the host passes one (TSA-1, TimelineStrip+Keys). Each lane's input (TimelineLaneInput) calls
// the move closures for a key drag, the trim closures for a clip end and onSlide for a clip's body (TK-4). The strip owns its zoom (TL-17), a factor over the
// host's frameWidth kept in TimelineZoom's range (1 = fit): Command-plus,
// Command-minus and Command-0 while it has focus (anchored on the playhead),
// a pinch on the lanes (anchored under the pointer) and the toolbar row
// (TimelineToolbar). The lanes scroll sideways by wheel and trackpad, and a
// playhead that leaves the view moves it a page (TimelineZoom.followed).
// Neither scroll view shows indicators (#2012): an always-shown AppKit scroller
// reads as an unnamed 11 pt button and sits over the lanes' right edge.
// While the strip (or a control in it) has focus, the zoom keys are also
// hidden shortcuts (TimelineZoomShortcuts): SwiftUI looks for a shortcut in the
// key window before the menu bar, so a host's Zoom In ⌘+ item, enabled or not,
// no longer takes the key first (#2142). The key press handler stays for a
// host with no such item. A host that knows its document's FrameRate passes
// `rate`: the ruler and the pill then read its timecode (";" at drop-frame
// rates), as the host's own readout does, and fps is its nominal rate (FR-u).
// The lanes open scrolled so the playhead is in view (TimelineZoom.followed).
import SuiteKernel
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
    private let rate: FrameRate?
    private let workArea: ClosedRange<Int>?
    private let toolbar: Bool
    private let onPickKeyframe: @MainActor (ID, Int?, PickMode) -> Void
    private let onMoveKeyframes: @MainActor (Int) -> Void
    private let onEndKeyDrag: @MainActor () -> Void
    private let onTrim: @MainActor (ID, SpanEdge, Int) -> Void
    private let onEndTrim: @MainActor () -> Void
    private let onSlide: @MainActor (ID, Int) -> Void
    private let onUnit: @MainActor (TimeUnit) -> Void
    private let onWorkArea: @MainActor (ClosedRange<Int>?) -> Void
    private let onSelectAllKeys: (@MainActor () -> Void)?
    @Environment(\.suiteSnapshotRendering) private var snapshot
    /// The host's prefix for the name buttons' identifiers; nil puts none.
    @Environment(\.timelineIdentifierPrefix) private var idPrefix
    /// The stretch of the lanes the scroll view shows, in mapping x; nil until
    /// it first reports.
    @State private var visibleX: ClosedRange<Double>?
    /// The lanes' visible y range; nil until the vertical scroll view first reports.
    @State private var visibleY: ClosedRange<Double>?
    /// The lane rows that range shows with half a row of margin (TimelineStripLayout.lanesShown), set only when it
    /// changes: the visible rect jitters by fractions of a point while the strip animates in, and a body that read
    /// `visibleY` ran once per jitter.
    @State private var visibleRows: Range<Int>?
    /// The zoom over the host's frameWidth; 1 is fit.
    @State private var zoom: Double = 1
    /// A pinch under way: the zoom it began at and the view x it anchors.
    @State private var pinch: (zoom: Double, anchorX: Double)?
    @State private var position = ScrollPosition()
    /// The content x a zoom scrolls to once the lanes take their new width.
    @State private var pendingScrollX: Double?
    /// The playhead and closures a lane press reads; written each body, never observed (#5804).
    @State private var laneContext = TimelineLaneContext<ID>()
    /// The strip or a control in it has focus: the zoom shortcuts are live.
    @FocusState private var focused: Bool
    #if DEBUG
    @Environment(\.bodyTally) private var bodyTally
    #endif

    #if DEBUG
    /// How many times a strip's body ran, over every ID type; the real-window
    /// budget tests count a scrub's.
    static var bodyRuns: Int { BodyTally.runs(of: TimelineStripBodies.self) }
    #endif

    /// `duration` is the last frame and `frameWidth` the points per frame;
    /// `playhead` is the current frame. `unit` and `fps` say how time reads,
    /// `workArea` is the host's work area and `toolbar` shows the strip's own
    /// toolbar. `onPickKeyframe` gets a nil frame when the bed is clicked;
    /// `onMoveKeyframes` gets the frames moved since its last call, and
    /// `onSlide` a clip body's track and the frames it moved since its last call.
    public init(
        tracks: [TimelineTrack<ID>], duration: Int, frameWidth: CGFloat, playhead: Int,
        unit: TimeUnit = .frames, fps: Int = 0, rate: FrameRate? = nil, workArea: ClosedRange<Int>? = nil, toolbar: Bool = false,
        onScrub: @escaping @MainActor (Int) -> Void = { _ in },
        onSelectKeyframe: @escaping @MainActor (ID, Int) -> Void = { _, _ in },
        onSelectTrack: @escaping @MainActor (ID) -> Void = { _ in },
        onPickKeyframe: @escaping @MainActor (ID, Int?, PickMode) -> Void = { _, _, _ in },
        onMoveKeyframes: @escaping @MainActor (Int) -> Void = { _ in },
        onEndKeyDrag: @escaping @MainActor () -> Void = {},
        onTrim: @escaping @MainActor (ID, SpanEdge, Int) -> Void = { _, _, _ in },
        onEndTrim: @escaping @MainActor () -> Void = {},
        onSlide: @escaping @MainActor (ID, Int) -> Void = { _, _ in },
        onUnit: @escaping @MainActor (TimeUnit) -> Void = { _ in },
        onWorkArea: @escaping @MainActor (ClosedRange<Int>?) -> Void = { _ in },
        onSelectAllKeys: (@MainActor () -> Void)? = nil
    ) {
        self.tracks = tracks
        self.fitMapping = FrameMapping(duration: duration, frameWidth: Double(frameWidth))
        self.playhead = playhead
        self.onScrub = onScrub
        self.onSelectKeyframe = onSelectKeyframe
        self.onSelectTrack = onSelectTrack
        self.unit = unit
        self.fps = rate?.nominal ?? fps
        self.rate = rate
        self.workArea = workArea
        self.toolbar = toolbar
        self.onPickKeyframe = onPickKeyframe
        self.onMoveKeyframes = onMoveKeyframes
        self.onEndKeyDrag = onEndKeyDrag
        self.onTrim = onTrim
        self.onEndTrim = onEndTrim
        self.onSlide = onSlide
        self.onUnit = onUnit
        self.onWorkArea = onWorkArea
        self.onSelectAllKeys = onSelectAllKeys
    }

    public var body: some View {
        #if DEBUG
        let _ = bodyTally.ran(TimelineStripBodies.self)
        #endif
        let layout = TimelineStripLayout(trackCount: tracks.count, toolbar: toolbar)
        let _ = updateLaneContext()
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
                TimelineRuler(mapping: mapping, visibleX: visibleX, playhead: playhead, unit: unit, fps: fps, rate: rate, onScrub: onScrub)
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
                        .scrollIndicators(.never)
                        .onScrollGeometryChange(for: ClosedRange<Double>.self) { geometry in
                            let rect = geometry.visibleRect
                            let low = Double(rect.minX - timelineInset)
                            return low...max(low, Double(rect.maxX - timelineInset))
                        } action: { _, visible in
                            let first = visibleX.map { $0.upperBound <= $0.lowerBound } ?? true
                            visibleX = visible
                            // The first report with a width: open on the playhead's page, not frame 0.
                            if first { follow(playhead, in: (visible.lowerBound, visible.upperBound - visible.lowerBound)) }
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
                .scrollIndicators(.never)
                .onScrollGeometryChange(for: ClosedRange<Double>.self) { geometry in
                    let rect = geometry.visibleRect
                    return Double(rect.minY)...max(Double(rect.minY), Double(rect.maxY))
                } action: { _, visible in
                    visibleY = visible
                    let rows = TimelineStripLayout.lanesShown(visibleY: visible)
                    if rows != visibleRows { visibleRows = rows }
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
        .modifier(
            TimelineStripKeys(
                tracks: tracks, mapping: mapping, onPickKeyframe: onPickKeyframe, onSelectAllKeys: onSelectAllKeys))
        .focused($focused)
        .background {
            if focused && !snapshot {
                TimelineZoomShortcuts { key in
                    setZoom(key.zoom(from: zoom, frameWidth: fitMapping.frameWidth), anchorX: nil)
                }
            }
        }
        .onKeyPress(phases: [.down, .repeat]) { press in zoomKey(press) }
        .onChange(of: playhead) { _, frame in follow(frame) }
    }

    /// Hands the lanes' presses this body's playhead and closures, without re-running a lane.
    private func updateLaneContext() {
        laneContext.playhead = playhead
        laneContext.actions = TimelineLaneActions(
            onSelectKeyframe: onSelectKeyframe, onSelectTrack: onSelectTrack, onPickKeyframe: onPickKeyframe,
            onMoveKeyframes: onMoveKeyframes, onEndKeyDrag: onEndKeyDrag, onTrim: onTrim, onEndTrim: onEndTrim,
            onSlide: onSlide)
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
    private func follow(_ frame: Int, in reported: (offset: Double, width: Double)? = nil) {
        guard let scroll = reported ?? scroll, pendingScrollX == nil else { return }
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
            keys: TimelinePlayhead.keys(at: mapping.clamp(playhead), in: tracks, rows: rows), workArea: workArea,
            rate: rate, onScrub: onScrub
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
        TimelineNameRows(tracks: tracks, idPrefix: idPrefix, context: laneContext).equatable()
            .frame(width: SuiteSize.timelineLabelColumn)
    }

    /// The lanes the stack builds: the rows the vertical scroll shows (`visibleRows`), or every row before it
    /// reports and in a snapshot. The lanes' horizontal scroll view is laid out at every lane's height, so inside
    /// it the lazy stack alone built every lane (500 tracks cost a host ~90 ms a body); the names column, a direct
    /// child of the vertical scroll, is lazy on its own.
    private var lanesShown: Range<Int> {
        let all = 0..<tracks.count
        guard !snapshot, let visibleRows else { return all }
        return visibleRows.clamped(to: all)
    }

    private func lanes(width: CGFloat) -> some View {
        TimelineLaneRows(tracks: tracks, shown: lanesShown, mapping: mapping, context: laneContext, width: width)
            .equatable()
            // Only the lanes' access modifiers read it, so a scroll re-runs those, never a lane's Canvas.
            .environment(\.timelineVisibleX, snapshot ? nil : visibleX)
            .simultaneousGesture(pinchGesture, isEnabled: !snapshot)
    }
}

/// The lane rows, one per shown track, behind one `.equatable()`: Equatable over
/// the tracks, the rows shown, the mapping and the width, so a frame change never re-evaluates the
/// ForEach. A re-evaluated ForEach is not free even when every row compares
/// equal: when the hosting view lays out before SwiftUI's own flush (a frame
/// tick right before AppKit's layout, which a loaded Mac makes common), the
/// stack's layout measures each row by pushing its element into the row, which
/// skips the row's `==` and runs every lane and lane input (#5804).
struct TimelineLaneRows<ID: Hashable & Sendable>: View, Equatable {
    let tracks: [TimelineTrack<ID>]
    /// The rows built (TimelineStrip.lanesShown); clear space stands in for the rest.
    let shown: Range<Int>
    let mapping: FrameMapping
    let context: TimelineLaneContext<ID>
    let width: CGFloat
    #if DEBUG
    @Environment(\.bodyTally) private var bodyTally
    #endif

    var body: some View {
        #if DEBUG
        bodyTally.ran(TimelineLaneRowsBodies.self)
        #endif
        return LazyVStack(alignment: .leading, spacing: 0) {
            // Clear space for the rows scrolled above and below, so the content keeps every lane's height. Only
            // when there are such rows: a zero-height row in the lazy stack made the vertical scroll's visible rect
            // jitter by fractions of a point while the strip slid in, and each report ran this body again.
            if shown.lowerBound > 0 { Color.clear.frame(height: SuiteSize.timelineLane * CGFloat(shown.lowerBound)) }
            ForEach(tracks[shown]) { track in
                TimelineLaneRow(track: track, mapping: mapping, context: context).equatable()
            }
            if shown.upperBound < tracks.count {
                Color.clear.frame(height: SuiteSize.timelineLane * CGFloat(tracks.count - shown.upperBound))
            }
        }
        .frame(width: width, alignment: .leading)
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        // `shown` must compare: without it a scroll skips the body and every row past the first screen stays blank.
        lhs.tracks == rhs.tracks && lhs.shown == rhs.shown && lhs.mapping == rhs.mapping && lhs.context === rhs.context
            && lhs.width == rhs.width
    }
}

/// The key TimelineLaneRows counts its body runs under in BodyTally, over every ID type: the play-tick
/// test reads it, since a frame change must never re-evaluate the lanes' ForEach.
enum TimelineLaneRowsBodies {}

/// The track names, one per track, behind one `.equatable()` for the reason
/// TimelineLaneRows gives; a name's press reads `onSelectTrack` from the context.
struct TimelineNameRows<ID: Hashable & Sendable>: View, Equatable {
    let tracks: [TimelineTrack<ID>]
    let idPrefix: String?
    let context: TimelineLaneContext<ID>

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(tracks) { track in
                let nameID = TimelineLaneSpeech.identifier(idPrefix, "name", track.id)
                Button { context.actions.onSelectTrack(track.id) } label: {
                    Text(track.name)
                        .font(track.isSelected ? SuiteFont.headline : SuiteFont.body)
                        .lineLimit(1)
                        .padding(.horizontal, SuiteSpacing.s)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(TimelineNameStyle(selected: track.isSelected))
                .frame(height: SuiteSize.timelineLane)
                .accessibilityAddTraits(track.isSelected ? .isSelected : [])
                .accessibilityIdentifier(nameID ?? "", isEnabled: nameID != nil)
            }
        }
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.tracks == rhs.tracks && lhs.idPrefix == rhs.idPrefix && lhs.context === rhs.context
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

    /// Every character that is a zoom key, each one shortcut.
    static let characters: [Character] = ["=", "+", "-", "0"]

    /// What the key does, as a menu would name it.
    var title: String {
        switch self {
        case .zoomIn: "Zoom In"
        case .zoomOut: "Zoom Out"
        case .fit: "Zoom to Fit"
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

/// The zoom keys as shortcuts, mounted only while the strip has focus:
/// invisible, out of hit testing, focus and accessibility (the toolbar row's
/// bar and Fit are the visible controls).
private struct TimelineZoomShortcuts: View {
    let onKey: @MainActor (TimelineZoomKey) -> Void

    var body: some View {
        ZStack {
            ForEach(TimelineZoomKey.characters, id: \.self) { character in
                if let key = TimelineZoomKey(character) {
                    Button(key.title) { onKey(key) }
                        .keyboardShortcut(KeyEquivalent(character), modifiers: .command)
                }
            }
        }
        .opacity(0)
        .allowsHitTesting(false)
        .focusable(false)
        .accessibilityHidden(true)
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

    /// The lane rows a lanes' visible y range shows, with half a row of margin each side so a viewport edge that
    /// sits on a row boundary doesn't flip the range as the rect jitters; not clamped to a count (the strip clamps
    /// to its tracks, which can grow after the range was reported).
    static func lanesShown(visibleY: ClosedRange<Double>) -> Range<Int> {
        let lane = Double(SuiteSize.timelineLane)
        let first = max(Int((visibleY.lowerBound / lane - 0.5).rounded(.down)), 0)
        let end = max(Int((visibleY.upperBound / lane + 0.5).rounded(.up)), first)
        return first..<end
    }

    /// The lanes' width: every frame plus trailing room, or in a snapshot the
    /// width the strip offers them, so ImageRenderer never draws a lane tens
    /// of thousands of points wide (#219).
    func lanesWidth(contentWidth: Double, offered: CGFloat, snapshot: Bool) -> CGFloat {
        snapshot ? max(offered, 0) : CGFloat(contentWidth) + SuiteSpacing.xl
    }
}

/// A track name's button: the row fill from TimelineLook.nameRow, so the name
/// shows hover and press like the other rows in the suite (lead rule 10).
struct TimelineNameStyle: ButtonStyle {
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        TimelineNameBody(configuration: configuration, selected: selected)
    }

    private struct TimelineNameBody: View {
        let configuration: ButtonStyleConfiguration
        let selected: Bool
        @State private var hovering = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let row = TimelineLook.nameRow(selected: selected, hovered: hovering && isEnabled, pressed: configuration.isPressed)
            configuration.label
                // `ignoresSafeAreaEdges: []`: a color background ignores every safe-area edge by default,
                // so under a floating sidebar the selected row reached 208 pt left of the strip (#1034).
                .background(fill(row), ignoresSafeAreaEdges: [])
                .onHover { hovering = $0 }
        }

        private func fill(_ row: TimelineLook.NameRow) -> Color {
            switch row {
            case .plain: Color.clear
            case .hovered: SuiteColor.rowHover
            case .pressed: SuiteColor.field
            case .selected: SuiteColor.accent.opacity(0.15)
            }
        }
    }
}

/// One lane with its input: Equatable over the track and the mapping (the
/// context is the strip's one box), so on a frame change the strip's
/// `.equatable()` skips the row and neither the lane nor its input re-runs.
/// No closure sits in what it compares: the lane's presses read the context.
struct TimelineLaneRow<ID: Hashable & Sendable>: View, Equatable {
    let track: TimelineTrack<ID>
    let mapping: FrameMapping
    let context: TimelineLaneContext<ID>

    var body: some View {
        TimelineLane(track: track, mapping: mapping).equatable()
            .contentShape(Rectangle())
            .modifier(TimelineLaneInput(track: track, mapping: mapping, context: context))
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.track == rhs.track && lhs.mapping == rhs.mapping && lhs.context === rhs.context
    }
}

/// The key every TimelineStrip<ID> counts its body runs under in BodyTally.
enum TimelineStripBodies {}

/// Room before frame 0, so its diamond and label aren't clipped.
let timelineInset = SuiteSpacing.s

/// The x of a frame's tick inside the lanes.
func tickX(_ mapping: FrameMapping, _ frame: Int) -> CGFloat {
    timelineInset + CGFloat(mapping.x(forFrame: frame))
}

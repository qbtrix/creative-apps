// TimelineRuler.swift: the frame ruler above TimelineStrip's lanes, pinned
// outside both scroll views: its marks (TimelineRulerMarks) are drawn at the
// lanes' width and shifted by the sideways scroll, inside a clipped view the
// visible width, which carries the drag and the fixed accessibility identifier
// `suite.timeline.ruler`. The marks are only the ticks and labels inside the
// scrolled-to stretch (FrameMapping.rulerMarks), so a long duration costs no
// more than a short one, and they never read the playhead, so a scrub never
// redraws them (#1257). A drag anywhere on it scrubs through the playhead's
// TimelineScrubSender, so it sends only changed frames; VoiceOver reads and
// steps the playhead frame. A snapshot offers the marks the strip's width (#219).
// TL-18: labels read in the host's unit, spaced from the widest label
// (TimelineRulerLabels); the work area is a bar on the lower 6 pt with two
// 16 pt handles (TimelineWorkAreaBar, laid over the playhead by the strip).
import SwiftUI

struct TimelineRuler: View {
    let mapping: FrameMapping
    /// The stretch of the lanes the scroll view shows, in mapping x; nil until
    /// it first reports.
    let visibleX: ClosedRange<Double>?
    let playhead: Int
    let unit: TimeUnit
    let fps: Int
    let onScrub: @MainActor (Int) -> Void
    @Environment(\.suiteSnapshotRendering) private var snapshot
    @State private var sender = TimelineScrubSender()

    #if DEBUG
    /// How many times the ruler's marks were drawn; the real-window budget tests count a scrub's.
    static var bodyRuns = 0
    #endif

    var body: some View {
        // The content x at the ruler's leading edge.
        let scrollX = snapshot ? 0 : (visibleX?.lowerBound ?? -Double(timelineInset)) + Double(timelineInset)
        return GeometryReader { proxy in
            TimelineRulerMarks(mapping: mapping, visibleX: visibleX, unit: unit, fps: fps).equatable()
                .frame(width: snapshot ? max(proxy.size.width, 0) : CGFloat(mapping.contentWidth) + SuiteSpacing.xl,
                       alignment: .leading)
                .offset(x: -CGFloat(scrollX))
        }
        .frame(height: SuiteSize.timelineRuler)
        .clipped()
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
            let frame = mapping.frame(atX: Double(drag.location.x - timelineInset) + scrollX)
            sender.send(frame, from: playhead, to: onScrub)
        }.onEnded { _ in sender.end() })
        .accessibilityElement()
        .accessibilityLabel("Frame Ruler")
        .accessibilityValue("Frame \(mapping.clamp(playhead))")
        .accessibilityAdjustableAction { direction in
            let frame = mapping.clamp(playhead)
            switch direction {
            case .increment: onScrub(frame < mapping.duration ? frame + 1 : frame)
            case .decrement: onScrub(frame > 0 ? frame - 1 : frame)
            @unknown default: break
            }
        }
        .accessibilityIdentifier("suite.timeline.ruler")
    }
}

/// The ruler's ticks and labels: Equatable over the mapping and the visible
/// stretch, so the strip skips it when only the playhead moved.
struct TimelineRulerMarks: View {
    let mapping: FrameMapping
    let visibleX: ClosedRange<Double>?
    let unit: TimeUnit
    let fps: Int

    var body: some View {
        #if DEBUG
        TimelineRuler.bodyRuns += 1
        #endif
        let mapping = mapping
        let visibleX = visibleX
        let rules = TimelineRulerLabels(mapping: mapping, unit: unit, fps: fps)
        return Canvas { context, size in
            let shown = visibleX ?? 0...Double(min(size.width, SuiteSize.timelineRulerSpan))
            let marks = mapping.rulerMarks(
                visibleX: shown, tickSpacing: Double(SuiteSize.timelineTickSpacing),
                labelSpacing: Double(SuiteSize.timelineLabelSpacing)
            )
            // A label past the strip's trailing edge ends at its tick instead (#61).
            let placed = rules.placed(rules.frames(visibleX: shown))
            let labels = Set(placed.map(\.frame))
            var ticks = Path()
            for frame in Set(marks.ticks).union(labels) {
                let x = tickX(mapping, frame)
                ticks.move(to: CGPoint(x: x, y: size.height * (labels.contains(frame) ? 0.4 : 0.7)))
                ticks.addLine(to: CGPoint(x: x, y: size.height))
            }
            for placement in placed {
                let x = tickX(mapping, placement.frame)
                let label = Text(placement.text).font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText)
                if placement.endsAtTick {
                    context.draw(label, at: CGPoint(x: x - SuiteSpacing.xxs, y: 0), anchor: .topTrailing)
                } else {
                    context.draw(label, at: CGPoint(x: x + SuiteSpacing.xxs, y: 0), anchor: .topLeading)
                }
            }
            ticks.move(to: CGPoint(x: 0, y: size.height))
            ticks.addLine(to: CGPoint(x: size.width, y: size.height))
            context.stroke(ticks, with: .color(SuiteColor.separator), lineWidth: 1)
        }
    }
}

extension TimelineRulerMarks: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.mapping == rhs.mapping && lhs.visibleX == rhs.visibleX && lhs.unit == rhs.unit && lhs.fps == rhs.fps
    }
}

/// A ruler label: its frame, its text, and the mapping-x stretch it covers.
struct TimelineRulerLabel: Equatable, Sendable {
    let frame: Int, text: String, endsAtTick: Bool, minX: Double, maxX: Double
}

/// The ruler's labels in the host's unit, with no view: the step spans the
/// label spacing and the widest label in 0...duration plus a character, so
/// labels never overlap; in timecode TimelineTime.labelStep puts them on whole
/// seconds once the step reaches fps / 2 (TimelineRulerUnitTests).
struct TimelineRulerLabels: Equatable, Sendable {
    let mapping: FrameMapping
    let unit: TimeUnit
    let fps: Int

    static let digit = Double(SuiteSize.timelineLabelDigit), padding = Double(SuiteSpacing.xxs)

    func text(_ frame: Int) -> String {
        TimelineTime.label(frame: frame, fps: fps, unit: unit)
    }

    /// The room the widest label needs, plus one character of gap.
    var labelWidth: Double {
        Double(max(text(mapping.duration).count, text(mapping.clamp(max(fps, 1) - 1)).count) + 1) * Self.digit
    }

    /// The labelled frames whose ticks lie inside `visibleX`.
    func frames(visibleX: ClosedRange<Double>) -> [Int] {
        let width = mapping.frameWidth
        guard width > 0 else { return [0] }
        guard visibleX.upperBound >= 0, visibleX.lowerBound <= mapping.contentWidth else { return [] }
        let low = whole((visibleX.lowerBound / width).rounded(.up))
        let high = whole((visibleX.upperBound / width).rounded(.down))
        guard low <= high else { return [] }
        let step = mapping.labelInterval(minimumSpacing: max(Double(SuiteSize.timelineLabelSpacing), labelWidth))
        return TimelineTime.labelFrames(in: low...high, step: step, fps: fps, unit: unit)
    }

    /// Each frame's label against its tick; one that would run into the next is dropped.
    func placed(_ frames: [Int]) -> [TimelineRulerLabel] {
        let trailing = mapping.contentWidth + Double(SuiteSpacing.xl - timelineInset)
        let all = frames.map { frame -> TimelineRulerLabel in
            let label = text(frame)
            let width = Double(label.count) * Self.digit, x = mapping.x(forFrame: frame)
            let ends = x + Self.padding + width > trailing
            let minX = ends ? x - Self.padding - width : x + Self.padding
            return TimelineRulerLabel(frame: frame, text: label, endsAtTick: ends, minX: minX, maxX: minX + width)
        }
        return all.indices.compactMap { index in
            index + 1 < all.count && all[index].maxX > all[index + 1].minX ? nil : all[index]
        }
    }

    /// A whole Double as a frame inside 0...duration, never past Int's range.
    private func whole(_ value: Double) -> Int {
        guard value > 0 else { return 0 }
        return value < Double(mapping.duration) ? min(Int(value), mapping.duration) : mapping.duration
    }
}

/// A work-area handle drag as a value: the live span, trimmed by
/// SuiteTimelineEditing; Escape cancels it (TimelineRulerUnitTests).
struct TimelineWorkAreaDrag: Equatable, Sendable {
    let start: ClosedRange<Int>
    let edge: SpanEdge
    private(set) var span: ClosedRange<Int>
    private(set) var cancelled = false

    init(start: ClosedRange<Int>, edge: SpanEdge) {
        self.start = start
        self.edge = edge
        self.span = start
    }

    /// The handle at content x `x`; true when the span changed.
    mutating func move(toX x: Double, mapping: FrameMapping) -> Bool {
        guard !cancelled else { return false }
        let new = SuiteTimelineEditing().trimmed(start, edge: edge, to: mapping.frame(atX: x), lastFrame: mapping.duration)
        guard new != span else { return false }
        span = new
        return true
    }

    mutating func cancel() {
        cancelled = true
        span = start
    }

    /// What release sends: the new span, or nil when cancelled or unchanged.
    func released() -> ClosedRange<Int>? { cancelled || span == start ? nil : span }
}

/// Where the work area draws and takes a press, in view x (content x less
/// `scrollX`), with no view (TimelineRulerUnitTests).
struct TimelineWorkAreaGeometry: Equatable, Sendable {
    let mapping: FrameMapping
    let span: ClosedRange<Int>
    let scrollX: Double

    /// The bar is the ruler's lower 6 pt; a handle is the 16 pt key token.
    static let barHeight = SuiteSpacing.xs + SuiteSpacing.xxs, handle = SuiteSize.timelineKeyframeHit

    func x(_ edge: SpanEdge) -> CGFloat {
        tickX(mapping, edge == .start ? span.lowerBound : span.upperBound) - CGFloat(scrollX)
    }

    func contentX(_ x: CGFloat) -> Double { Double(x - timelineInset) + scrollX }

    func barRect(width: CGFloat) -> CGRect {
        let low = max(x(.start), 0), high = min(x(.end), max(width, 0))
        return CGRect(x: low, y: SuiteSize.timelineRuler - Self.barHeight, width: max(high - low, 0), height: Self.barHeight)
    }

    func handleRect(_ edge: SpanEdge) -> CGRect {
        CGRect(x: x(edge) - Self.handle / 2, y: SuiteSize.timelineRuler - Self.handle, width: Self.handle, height: Self.handle)
    }

    /// The handle a press at view x `x` grabs: the nearer, the end on a tie.
    func edge(atX x: CGFloat) -> SpanEdge? {
        let start = abs(x - self.x(.start)), end = abs(x - self.x(.end))
        guard min(start, end) <= Self.handle / 2 else { return nil }
        return start < end ? .start : .end
    }

    /// Only the handles take a press, so the rest of the ruler still scrubs.
    var handles: Path {
        var path = Path(handleRect(.start))
        path.addRect(handleRect(.end))
        return path
    }
}

/// The work area's bar and handles. A drag draws live (only a sample that
/// moves the span writes state), sends onWorkArea once on release, and
/// nothing after Escape.
struct TimelineWorkAreaBar: View {
    let mapping: FrameMapping
    let workArea: ClosedRange<Int>?
    /// The content x at the bar's leading edge.
    let scrollX: Double
    let onWorkArea: @MainActor (ClosedRange<Int>?) -> Void
    @State private var drag: TimelineWorkAreaDrag?
    @FocusState private var focused: Bool

    var body: some View {
        if let area = drag?.span ?? workArea.map({ mapping.clamp($0.lowerBound)...mapping.clamp($0.upperBound) }) {
            let geometry = TimelineWorkAreaGeometry(mapping: mapping, span: area, scrollX: scrollX)
            Canvas { context, size in
                context.fill(Path(geometry.barRect(width: size.width)), with: .color(SuiteColor.accent.opacity(0.4)))
                for edge in [SpanEdge.start, .end] {
                    let grip = geometry.handleRect(edge).insetBy(dx: (TimelineWorkAreaGeometry.handle - SuiteSpacing.xs) / 2, dy: 0)
                    context.fill(Path(roundedRect: grip, cornerRadius: SuiteSpacing.xxs), with: .color(SuiteColor.accent))
                }
            }
            .frame(height: SuiteSize.timelineRuler)
            .clipped()
            .contentShape(geometry.handles)
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                if drag == nil {
                    guard let edge = geometry.edge(atX: value.startLocation.x) else { return }
                    drag = TimelineWorkAreaDrag(start: area, edge: edge)
                }
                guard var live = drag, live.move(toX: geometry.contentX(value.location.x), mapping: mapping) else { return }
                drag = live
            }.onEnded { _ in
                if let span = drag?.released() { onWorkArea(span) }
                drag = nil
            })
            .focusable(drag != nil, interactions: .edit)
            .focused($focused)
            .focusEffectDisabled()
            .onChange(of: drag != nil) { _, dragging in focused = dragging }
            .onKeyPress(.escape) {
                guard var live = drag, !live.cancelled else { return .ignored }
                live.cancel()
                drag = live
                return .handled
            }
            .accessibilityHidden(true)
        }
    }
}

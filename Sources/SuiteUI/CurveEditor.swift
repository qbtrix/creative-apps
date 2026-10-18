// CurveEditor.swift: the Studio easing curve editor, a flat rounded well that
// plots one easing curve in unit coordinates (x 0...1 is time, y is progress):
// a quarter grid, the dashed linear reference, the two Bezier handles on their
// arms, the curve as one vector path, and a preview dot riding it (hidden
// under `suiteReduceMotion`, which a probe host sees as the `preview-stopped`
// mark of series `curve-preview`). Drag a handle, or focus the well and nudge
// the focused handle with the arrow keys (Shift for ten times as far); Tab and
// Shift-Tab move between the handles, and a drag focuses the handle it moved.
// A handle's x stays in 0...1 (dragged or nudged); y may overshoot. Nudges and
// the handles' spoken values go through an EasingHandleNudging (UC15b),
// SuiteEasingHandleNudging unless a gallery swaps in the Fake. Values go out
// only through `onMove` and `onEnd`, with one `onEnd` per drag and per nudge
// through an EditRun (CurveEnds), so the host makes each one undo step. Under
// a probe host each drag sample reports series `curve-drag` (CurveProbe, SP7).
// Knows no Model. The math (plot range, mapping, preview point, nudges, the
// clamp) is static and tested in CurveEditorTests. A handle shows a grab
// pointer and an accent rim under the pointer, and fills accent with a ring
// while focused or dragged. Owns presentation state only: focus, the hovered
// handle, the drag's range and the gesture's run.
import SwiftUI

/// One of the two handles of a cubic Bezier easing.
public enum EasingHandleIndex: Int, CaseIterable, Sendable {
    case first = 1, second = 2
}

public struct CurveEditor: View {
    private let samples: [CGPoint]
    private let handles: (CGPoint, CGPoint)?
    private let dimmedHandles: Bool
    private let id: String
    private let nudging: any EasingHandleNudging
    private let onMove: @MainActor (EasingHandleIndex, CGPoint) -> Void
    private let onEnd: @MainActor () -> Void
    @State private var focused: EasingHandleIndex?
    @State private var dragging: (handle: EasingHandleIndex, range: ClosedRange<CGFloat>)?
    @State private var hovered: EasingHandleIndex?
    @State private var ends = CurveEnds()
    @FocusState private var hasFocus: Bool
    @Environment(\.suiteReduceMotion) private var reduceMotion
    @Environment(\.curveProbe) private var probe

    /// `samples` and `handles` are in unit coordinates. `dimmedHandles` draws
    /// the handles at 40% (a hold segment). `focusedHandle` starts with that
    /// handle ringed, as after a click. `id` prefixes the accessibility
    /// identifiers: `<id>`, `<id>.handle1`, `<id>.handle2`. `nudging` decides
    /// the arrow nudges and the handles' spoken values.
    public init(
        samples: [CGPoint], handles: (CGPoint, CGPoint)?, dimmedHandles: Bool = false,
        focusedHandle: EasingHandleIndex? = nil, id: String = "suite.curve",
        nudging: any EasingHandleNudging = SuiteEasingHandleNudging(),
        onMove: @escaping @MainActor (EasingHandleIndex, CGPoint) -> Void, onEnd: @escaping @MainActor () -> Void
    ) {
        self.samples = samples
        self.handles = handles
        self.dimmedHandles = dimmedHandles
        self.id = id
        self.nudging = nudging
        self.onMove = onMove
        self.onEnd = onEnd
        _focused = State(initialValue: focusedHandle)
    }

    public var body: some View {
        GeometryReader { geo in
            let plot = CGRect(origin: .zero, size: geo.size).insetBy(dx: SuiteSpacing.m, dy: SuiteSpacing.m)
            let range = dragging?.range ?? Self.plotRange(including: handles.map { [$0.0, $0.1] } ?? [])
            ZStack {
                Canvas { context, _ in draw(in: context, plot: plot, range: range) }
                    .accessibilityHidden(true)
                if !reduceMotion, !samples.isEmpty {
                    TimelineView(.animation) { timeline in
                        let phase = Self.previewPhase(at: timeline.date.timeIntervalSinceReferenceDate)
                        Circle()
                            .fill(.primary)
                            .frame(width: SuiteSize.curvePreviewDot, height: SuiteSize.curvePreviewDot)
                            .position(Self.viewPoint(Self.previewPoint(samples: samples, phase: phase), in: plot, range: range))
                    }
                    .accessibilityHidden(true)
                }
                if let handles {
                    handle(.first, at: handles.0, plot: plot, range: range)
                    handle(.second, at: handles.1, plot: plot, range: range)
                }
            }
        }
        .frame(height: SuiteSize.curveEditor)
        .background(SuiteColor.field)
        .clipShape(RoundedRectangle(cornerRadius: SuiteRadius.medium))
        .focusable()
        .focused($hasFocus)
        .onChange(of: hasFocus) { _, has in focused = has ? (focused ?? .first) : nil }
        // AppKit may report Shift-Tab as the back-tab character (U+0019).
        .onKeyPress(keys: [.tab, KeyEquivalent("\u{19}")]) { press in
            press.modifiers.contains(.shift) || press.key != .tab
                ? step(to: .first, from: .second) : step(to: .second, from: .first)
        }
        .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow]) { press in nudge(press) }
        .onChange(of: reduceMotion, initial: true) { _, reduced in
            guard let probe, let name = Self.previewMark(reduceMotion: reduced, hasSamples: !samples.isEmpty) else { return }
            probe.mark(ProbeMark(name: name, series: CurveProbe.previewSeries, time: ProcessInfo.processInfo.systemUptime))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Easing Curve")
        .accessibilityIdentifier(id)
    }

    private func draw(in context: GraphicsContext, plot: CGRect, range: ClosedRange<CGFloat>) {
        func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint { Self.viewPoint(CGPoint(x: x, y: y), in: plot, range: range) }
        var grid = Path()
        for q in stride(from: CGFloat(0), through: 1, by: 0.25) {
            grid.move(to: at(q, range.lowerBound))
            grid.addLine(to: at(q, range.upperBound))
            grid.move(to: at(0, q))
            grid.addLine(to: at(1, q))
        }
        context.stroke(grid, with: .color(SuiteColor.separator), lineWidth: 0.5)
        let reference = Path { $0.addLines([at(0, 0), at(1, 1)]) }
        context.stroke(
            reference, with: .color(SuiteColor.secondaryText.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        if let handles {
            var arms = Path()
            arms.addLines([at(0, 0), at(handles.0.x, handles.0.y)])
            arms.addLines([at(1, 1), at(handles.1.x, handles.1.y)])
            context.stroke(arms, with: .color(SuiteColor.secondaryText), lineWidth: 1)
        }
        context.stroke(
            Self.curvePath(samples, in: plot, range: range), with: .color(.primary),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    }

    private func handle(
        _ index: EasingHandleIndex, at point: CGPoint, plot: CGRect, range: ClosedRange<CGFloat>
    ) -> some View {
        let look = Self.handleLook(active: focused == index || dragging?.handle == index, hovered: hovered == index)
        return Circle()
            .fill(look.fill)
            .overlay(Circle().strokeBorder(look.stroke, lineWidth: 1.5))
            .overlay {
                if look.ring { Circle().strokeBorder(SuiteColor.accent, lineWidth: 2).padding(-SuiteSpacing.xs) }
            }
            .frame(width: SuiteSize.curveHandle, height: SuiteSize.curveHandle)
            .frame(width: SuiteSize.curveHandleHit, height: SuiteSize.curveHandleHit)
            .contentShape(Circle())
            .opacity(dimmedHandles ? 0.4 : 1)
            .onHover { hovered = $0 ? index : (hovered == index ? nil : hovered) }
            .pointerStyle(dragging?.handle == index ? .grabActive : .grabIdle)
            .position(Self.viewPoint(point, in: plot, range: range))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let frozen = dragging?.range ?? range
                        dragging = (index, frozen)
                        focused = index
                        hasFocus = true
                        if !ends.isOpen { _ = ends.dragged() }
                        let eventTime = ProcessInfo.processInfo.systemUptime
                        onMove(index, Self.handlePoint(Self.unitPoint(drag.location, in: plot, range: frozen)))
                        report(eventTime)
                    }
                    .onEnded { _ in
                        dragging = nil
                        if ends.released() { onEnd() }
                    }
            )
            .help("Handle \(index.rawValue)")
            .accessibilityElement()
            .accessibilityLabel("Handle \(index.rawValue)")
            .accessibilityValue(nudging.describe(PlanePoint(x: Double(point.x), y: Double(point.y))))
            .suiteControl(id: "\(id).handle\(index.rawValue)", enabled: true, reason: nil)
    }

    /// A drag sample, shown by the next main-actor turn after the move (the
    /// host's update has run by then).
    private func report(_ eventTime: Double) {
        guard let probe else { return }
        Task { @MainActor in
            probe.record(CurveProbe.sample(eventTime: eventTime, shownAt: ProcessInfo.processInfo.systemUptime))
        }
    }

    /// Tab moves focus from handle 1 to 2 and Shift-Tab back; past either end
    /// focus leaves the well as usual.
    private func step(to next: EasingHandleIndex, from current: EasingHandleIndex) -> KeyPress.Result {
        guard focused == current else { return .ignored }
        focused = next
        return .handled
    }

    private func nudge(_ press: KeyPress) -> KeyPress.Result {
        guard let index = focused, let handles else { return .ignored }
        let (dx, dy): (Int, Int) =
            switch press.key {
            case .leftArrow: (-1, 0)
            case .rightArrow: (1, 0)
            case .upArrow: (0, 1)
            default: (0, -1)
            }
        let point = index == .first ? handles.0 : handles.1
        let moved = nudging.nudged(
            PlanePoint(x: Double(point.x), y: Double(point.y)), dx: dx, dy: dy, coarse: press.modifiers.contains(.shift))
        onMove(index, CGPoint(x: moved.x, y: moved.y))
        if ends.nudged() { onEnd() }
        return .handled
    }
}

extension CurveEditor {
    /// How a handle draws: filled accent and ringed while focused or dragged;
    /// an accent rim under the pointer, so it reads as grabbable before the
    /// press; a primary rim on the panel fill at rest.
    public struct HandleLook: Equatable, Sendable {
        public let fill: Color
        public let stroke: Color
        public let ring: Bool
    }

    nonisolated public static func handleLook(active: Bool, hovered: Bool) -> HandleLook {
        active
            ? HandleLook(fill: SuiteColor.accent, stroke: SuiteColor.accent, ring: true)
            : HandleLook(fill: SuiteColor.panel, stroke: hovered ? SuiteColor.accent : Color.primary, ring: false)
    }

    /// The y range the well shows: -0.25...1.25, widened to take in every
    /// finite point. Always at least 1.5 tall, so mapping never divides by 0.
    nonisolated public static func plotRange(including points: [CGPoint]) -> ClosedRange<CGFloat> {
        let ys = points.map(\.y).filter(\.isFinite)
        return min(-0.25, ys.min() ?? 0)...max(1.25, ys.max() ?? 1)
    }

    /// A unit point's position in `plot`, y up.
    nonisolated public static func viewPoint(_ point: CGPoint, in plot: CGRect, range: ClosedRange<CGFloat>) -> CGPoint {
        let span = max(range.upperBound - range.lowerBound, 1)
        return CGPoint(
            x: plot.minX + point.x * plot.width, y: plot.minY + (range.upperBound - point.y) / span * plot.height)
    }

    /// The unit point under `location` in `plot`; an empty plot gives (0, 0).
    nonisolated public static func unitPoint(_ location: CGPoint, in plot: CGRect, range: ClosedRange<CGFloat>) -> CGPoint {
        guard plot.width > 0, plot.height > 0 else { return .zero }
        let span = range.upperBound - range.lowerBound
        return CGPoint(
            x: (location.x - plot.minX) / plot.width, y: range.upperBound - (location.y - plot.minY) / plot.height * span)
    }

    /// The curve as one vector path: a move to the first sample, then a line
    /// to each of the others.
    nonisolated public static func curvePath(_ samples: [CGPoint], in plot: CGRect, range: ClosedRange<CGFloat>) -> Path {
        Path { path in
            guard !samples.isEmpty else { return }
            path.addLines(samples.map { viewPoint($0, in: plot, range: range) })
        }
    }

    /// Where the preview dot sits at `phase` 0...1 along the samples (out of
    /// range phases clamp); (0, 0) for no samples.
    nonisolated public static func previewPoint(samples: [CGPoint], phase: Double) -> CGPoint {
        guard !samples.isEmpty else { return .zero }
        let t = min(max(phase.isFinite ? phase : 0, 0), 1) * Double(samples.count - 1)
        let i = Int(t)
        guard i + 1 < samples.count else { return samples[samples.count - 1] }
        let f = CGFloat(t - Double(i))
        let (a, b) = (samples[i], samples[i + 1])
        return CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
    }

    /// The preview's phase at `seconds`: a 1.2 s run along the curve, then a
    /// 0.4 s rest at its end, looping.
    nonisolated public static func previewPhase(at seconds: Double) -> Double {
        guard seconds.isFinite else { return 0 }
        let t = seconds.truncatingRemainder(dividingBy: 1.6)
        return min(max(t, 0) / 1.2, 1)
    }

    /// A handle's point: x clamped to 0...1 (a non-finite x is 0), y as given
    /// (a non-finite y is 0), so a drag past the well's edge stops at it.
    nonisolated public static func handlePoint(_ point: CGPoint) -> CGPoint {
        let x = point.x.isFinite ? min(max(point.x, 0), 1) : 0
        return CGPoint(x: x, y: point.y.isFinite ? point.y : 0)
    }

    /// Whether the preview dot is stopped: `preview-stopped` under Reduce
    /// Motion, `preview-playing` otherwise; nil with no curve to ride.
    nonisolated static func previewMark(reduceMotion: Bool, hasSamples: Bool) -> String? {
        guard hasSamples else { return nil }
        return reduceMotion ? "preview-stopped" : "preview-playing"
    }

    /// `point` nudged `dx` and `dy` steps of 0.01 (0.1 when `coarse`), the
    /// moved axis snapped to that step; x stays in 0...1 either way.
    nonisolated public static func nudged(_ point: CGPoint, dx: Int, dy: Int, coarse: Bool) -> CGPoint {
        let step = coarse ? 0.1 : 0.01
        let clamped = handlePoint(point)
        var x = Double(clamped.x)
        var y = Double(clamped.y)
        if dx != 0 { x = ScrubValue.snapped(x + Double(dx) * step, to: step, in: 0...1) }
        if dy != 0 { y = ScrubValue.snapped(y + Double(dy) * step, to: step, in: -.greatestFiniteMagnitude...(.greatestFiniteMagnitude)) }
        return CGPoint(x: x, y: y)
    }

    /// "x 0.42, y 0.00": a handle's accessibility value.
    nonisolated public static func describe(_ point: CGPoint) -> String {
        let two = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(2))
        return "x \(Double(point.x).formatted(two)), y \(Double(point.y).formatted(two))"
    }
}

/// The easing handles' nudges and spoken values (UC15b) over CurveEditor's
/// static math: x clamps to 0...1, y is free.
public struct SuiteEasingHandleNudging: EasingHandleNudging {
    public init() {}

    public func nudged(_ handle: PlanePoint, dx: Int, dy: Int, coarse: Bool) -> PlanePoint {
        let p = CurveEditor.nudged(CGPoint(x: handle.x, y: handle.y), dx: dx, dy: dy, coarse: coarse)
        return PlanePoint(x: Double(p.x), y: Double(p.y))
    }

    public func describe(_ handle: PlanePoint) -> String { CurveEditor.describe(CGPoint(x: handle.x, y: handle.y)) }
}

/// One gesture, one end, for CurveEditor, over the suite's EditRun: a drag's
/// samples open one run and its release closes it; a nudge is a change and
/// an end in one call. CurveEditorTests drive it.
struct CurveEnds: Equatable, Sendable {
    private(set) var run = EditRun()

    var isOpen: Bool { run.isOpen }
    var ends: Int { run.ends }

    /// A drag sample; true when it opened the run.
    mutating func dragged() -> Bool { run.change() }

    /// The drag's release: true exactly once per drag.
    mutating func released() -> Bool { run.end() }

    /// An arrow nudge: true, once.
    mutating func nudged() -> Bool {
        _ = run.change()
        return run.end()
    }
}

/// Where a CurveEditor reports its drag samples (series `curve-drag`, SP7)
/// and its preview's marks (series `curve-preview`, SJ20); a probe host sets
/// it, and nil records nothing.
struct CurveProbe: Sendable {
    static let dragSeries = "curve-drag"
    static let previewSeries = "curve-preview"
    let record: @MainActor @Sendable (ProbeSample) -> Void
    let mark: @MainActor @Sendable (ProbeMark) -> Void

    static func sample(eventTime: Double, shownAt: Double) -> ProbeSample {
        ProbeSample(series: dragSeries, eventTime: eventTime, shownAt: shownAt)
    }
}

extension EnvironmentValues {
    /// Where a CurveEditor reports its probe samples and marks; nil records nothing.
    var curveProbe: CurveProbe? {
        get { self[CurveProbeKey.self] }
        set { self[CurveProbeKey.self] = newValue }
    }
}

private struct CurveProbeKey: EnvironmentKey {
    static let defaultValue: CurveProbe? = nil
}

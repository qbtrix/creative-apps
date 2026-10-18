// ToneCurveEditor.swift: the tone curve editor, CurveEditor's look generalised
// to any number of points: a square unit plot (x input, y output, 0...1) in
// the same rounded well, a faint histogram behind, the quarter grid, the
// dashed identity and a dot per point. The host passes the points and the
// engine-sampled curve; this view holds no curve math. Click to add a point
// and drag it, drag a point to move it, drag a middle one out of the well or
// press Delete to remove it; arrows nudge the focused point (Shift ten times
// as far), Tab and Shift-Tab step between points. Values go out through
// `onChange` during a gesture and one `onEnd` after it (and after each nudge
// or delete), so each is one undo step: ToneCurveGesture keeps the suite's
// EditRun, so a press that changed nothing ends nothing. A drag's changes
// report probe series `curve-drag` (SP7) to the window's probe sink. Knows no
// Model. The point math is static and tested in ToneCurveEditorTests, and
// SuiteCurvePointEditing is its CurvePointEditing conformance (UC15); mapping,
// the curve path and nudge steps are CurveEditor's statics. Under Increase
// Contrast the well gets an outline. Every point is listed in `suite.controls`.
// Owns presentation state only: focus and the gesture.
import SwiftUI

public struct ToneCurveEditor: View {
    private let points: [CGPoint]
    private let samples: [CGPoint]
    private let histogram: [Double]
    private let id: String
    private let onChange: @MainActor ([CGPoint]) -> Void
    private let onEnd: @MainActor () -> Void
    @State private var focused: Int?
    @State private var gesture = ToneCurveGesture()
    @FocusState private var hasFocus: Bool
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.scrubProbe) private var probe

    /// `points`: unit control points sorted by x, the ends at x 0 and 1. `samples`: the engine's curve
    /// through them. `histogram`: bin heights at any scale, drawn normalised to the tallest; empty draws
    /// none. `focusedPoint` starts ringed, as after a click. `id` prefixes `<id>`, `<id>.point1`, ...
    public init(
        points: [CGPoint], samples: [CGPoint], histogram: [Double] = [], focusedPoint: Int? = nil,
        id: String = "suite.toneCurve", onChange: @escaping @MainActor ([CGPoint]) -> Void,
        onEnd: @escaping @MainActor () -> Void
    ) {
        self.points = points
        self.samples = samples
        self.histogram = histogram
        self.id = id
        self.onChange = onChange
        self.onEnd = onEnd
        _focused = State(initialValue: focusedPoint)
    }

    public var body: some View {
        GeometryReader { geo in
            let plot = Self.plot(in: geo.size)
            ZStack {
                Canvas { context, _ in draw(in: context, plot: plot) }
                    .accessibilityHidden(true)
                ForEach(points.indices, id: \.self) { point($0, plot: plot) }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { dragged($0, plot: plot, size: geo.size) }
                    .onEnded { _ in
                        if gesture.released() { onEnd() }
                    }
            )
        }
        .frame(height: SuiteSize.curveEditor)
        .background(SuiteColor.field)
        .overlay {
            if contrast == .increased {
                RoundedRectangle(cornerRadius: SuiteRadius.medium).strokeBorder(SuiteColor.outline)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: SuiteRadius.medium))
        .focusable()
        .focused($hasFocus)
        .onChange(of: hasFocus) { _, has in focused = has ? (focused ?? 0) : nil }
        // AppKit may report Shift-Tab as the back-tab character (U+0019).
        .onKeyPress(keys: [.tab, KeyEquivalent("\u{19}")]) { press in
            step(by: press.modifiers.contains(.shift) || press.key != .tab ? -1 : 1)
        }
        .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow]) { press in nudge(press) }
        .onKeyPress(keys: [.delete, .deleteForward]) { _ in delete() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tone Curve")
        .suiteControl(id: id, enabled: true, reason: nil)
    }

    private func draw(in context: GraphicsContext, plot: CGRect) {
        func path(_ units: [CGPoint]) -> Path { CurveEditor.curvePath(units, in: plot, range: 0...1) }
        let bins = Self.histogramPoints(histogram)
        if !bins.isEmpty { context.fill(path([.zero] + bins + [CGPoint(x: 1, y: 0)]), with: .color(SuiteColor.valueFill)) }
        var grid = Path()
        for q: CGFloat in [0, 0.25, 0.5, 0.75, 1] {
            grid.addPath(path([CGPoint(x: q, y: 0), CGPoint(x: q, y: 1)]))
            grid.addPath(path([CGPoint(x: 0, y: q), CGPoint(x: 1, y: q)]))
        }
        context.stroke(grid, with: .color(SuiteColor.separator), lineWidth: 0.5)
        context.stroke(
            path([.zero, CGPoint(x: 1, y: 1)]), with: .color(SuiteColor.secondaryText.opacity(0.5)),
            style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        context.stroke(path(samples), with: .color(.primary), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    }

    private func point(_ index: Int, plot: CGRect) -> some View {
        // While dragged the moved point is the active one, unless it is out of the well (removed).
        let drag = gesture.drag
        let active = drag?.index.map { $0 == index && drag?.start.count == points.count } ?? (focused == index)
        let unit = points[index]
        return Circle()
            .fill(active ? SuiteColor.accent : SuiteColor.panel)
            .strokeBorder(active ? SuiteColor.accent : Color.primary, lineWidth: 1.5)
            .frame(width: SuiteSize.curveHandle, height: SuiteSize.curveHandle)
            .padding(SuiteSpacing.xs)
            .overlay { if active { Circle().strokeBorder(SuiteColor.accent, lineWidth: 2) } }
            .frame(width: SuiteSize.curveHandleHit, height: SuiteSize.curveHandleHit)
            .position(CurveEditor.viewPoint(unit, in: plot, range: 0...1))
            .help("Point \(index + 1)")
            .accessibilityElement()
            .accessibilityLabel("Point \(index + 1)")
            .accessibilityValue(CurveEditor.describe(unit))
            .suiteControl(id: Self.pointID(id, index), enabled: true, reason: nil)
    }

    /// The first event picks the point (a hit) or adds one (a miss); later ones move it from where it
    /// began, or remove it while the pointer is out of the well.
    private func dragged(_ value: DragGesture.Value, plot: CGRect, size: CGSize) {
        if gesture.drag == nil {
            if let added = gesture.pressed(at: value.startLocation, points: points, in: plot) { onChange(added) }
            focused = gesture.drag?.index ?? focused
            hasFocus = true
        }
        guard let next = gesture.dragged(to: value.location, by: value.translation, in: plot, well: size) else { return }
        // The event's time on the uptime clock the probe compares against.
        let eventTime = ProcessInfo.processInfo.systemUptime - Date().timeIntervalSince(value.time)
        onChange(next)
        report(eventTime)
    }

    /// The drag sample, shown by the next main-actor turn after the change (the host's update has run by then).
    private func report(_ eventTime: Double) {
        guard let probe else { return }
        Task { @MainActor in
            probe.record(Self.sample(eventTime: eventTime, shownAt: ProcessInfo.processInfo.systemUptime))
        }
    }

    /// Tab moves to the next point and Shift-Tab back; past either end focus leaves the well.
    private func step(by offset: Int) -> KeyPress.Result {
        guard let index = focused, points.indices.contains(index + offset) else { return .ignored }
        focused = index + offset
        return .handled
    }

    private func nudge(_ press: KeyPress) -> KeyPress.Result {
        guard let index = focused, points.indices.contains(index) else { return .ignored }
        let dx = press.key == .rightArrow ? 1 : press.key == .leftArrow ? -1 : 0
        let dy = press.key == .upArrow ? 1 : press.key == .downArrow ? -1 : 0
        guard gesture.keyed() else { return .ignored }
        onChange(Self.nudged(index, dx: dx, dy: dy, coarse: press.modifiers.contains(.shift), in: points))
        onEnd()
        return .handled
    }

    /// Removes the focused middle point; focus stays at its index, now the next point.
    private func delete() -> KeyPress.Result {
        guard let index = focused, let next = Self.removed(index, from: points), gesture.keyed() else { return .ignored }
        onChange(next)
        onEnd()
        return .handled
    }
}

extension ToneCurveEditor {
    /// The closest two neighbouring points may sit in x.
    nonisolated public static let minimumGap: CGFloat = 0.01
    /// How far past the well's edge a drag must go to remove a middle point, so a drag that only
    /// overshoots the edge keeps it.
    nonisolated public static let outOfWellMargin: CGFloat = SuiteSpacing.s
    /// The probe series a point drag reports (SP7, QB-S6).
    nonisolated static let dragSeries = "curve-drag"

    /// The `suite.controls` and accessibility identifier of point `index`: `<id>.point1`, ...
    nonisolated public static func pointID(_ id: String, _ index: Int) -> String { "\(id).point\(index + 1)" }

    nonisolated static func sample(eventTime: Double, shownAt: Double) -> ProbeSample {
        ProbeSample(series: dragSeries, eventTime: eventTime, shownAt: shownAt)
    }

    /// The square the curve is drawn in: the largest inside the well's inset, centred.
    nonisolated public static func plot(in size: CGSize) -> CGRect {
        let side = max(min(size.width, size.height) - 2 * SuiteSpacing.m, 0)
        return CGRect(x: (size.width - side) / 2, y: (size.height - side) / 2, width: side, height: side)
    }

    /// `points` with `point` inserted in x order (y held to 0...1) and its index; nil when it isn't
    /// finite, falls outside the ends, or comes within `minimumGap` of a neighbour in x.
    nonisolated public static func added(_ point: CGPoint, to points: [CGPoint]) -> (points: [CGPoint], index: Int)? {
        guard point.x.isFinite, point.y.isFinite, let index = points.firstIndex(where: { $0.x > point.x }), index > 0,
            point.x - points[index - 1].x >= minimumGap, points[index].x - point.x >= minimumGap
        else { return nil }
        var next = points
        next.insert(CGPoint(x: point.x, y: min(max(point.y, 0), 1)), at: index)
        return (next, index)
    }

    /// `points` with point `index` at `point`: y held to 0...1, x `minimumGap` inside its neighbours,
    /// the ends kept at x 0 and 1. A missing index or a non-finite point changes nothing.
    nonisolated public static func moved(_ index: Int, to point: CGPoint, in points: [CGPoint]) -> [CGPoint] {
        guard points.indices.contains(index), point.x.isFinite, point.y.isFinite else { return points }
        let x = index == 0 ? 0 : index == points.count - 1 ? 1
            : min(max(point.x, points[index - 1].x + minimumGap), points[index + 1].x - minimumGap)
        var next = points
        next[index] = CGPoint(x: x, y: min(max(point.y, 0), 1))
        return next
    }

    /// `points` without point `index`; nil for an end (they can't be removed) or a missing index.
    nonisolated public static func removed(_ index: Int, from points: [CGPoint]) -> [CGPoint]? {
        guard index > 0, index < points.count - 1 else { return nil }
        var next = points
        next.remove(at: index)
        return next
    }

    /// Point `index` nudged by CurveEditor's steps (0.01, or 0.1 when `coarse`), then held as `moved` holds it.
    nonisolated public static func nudged(_ index: Int, dx: Int, dy: Int, coarse: Bool, in points: [CGPoint]) -> [CGPoint] {
        guard points.indices.contains(index) else { return points }
        return moved(index, to: CurveEditor.nudged(points[index], dx: dx, dy: dy, coarse: coarse), in: points)
    }

    /// The point nearest `location` (view space) within half a handle's hit size, or nil.
    nonisolated public static func hitIndex(at location: CGPoint, of points: [CGPoint], in plot: CGRect) -> Int? {
        func distance(_ i: Int) -> CGFloat {
            let p = CurveEditor.viewPoint(points[i], in: plot, range: 0...1)
            return hypot(p.x - location.x, p.y - location.y)
        }
        return points.indices.filter { distance($0) <= SuiteSize.curveHandleHit / 2 }.min { distance($0) < distance($1) }
    }

    /// Whether `location` is more than `outOfWellMargin` past a well of `size`: a middle point
    /// dragged there is removed.
    nonisolated public static func isOutOfWell(_ location: CGPoint, size: CGSize) -> Bool {
        let m = outOfWellMargin
        return location.x < -m || location.y < -m || location.x > size.width + m || location.y > size.height + m
    }

    /// The histogram's outline in unit coordinates: each bin's top over its centre, the tallest at y 1,
    /// negative and non-finite bins at 0. Empty when no bin is above 0.
    nonisolated public static func histogramPoints(_ bins: [Double]) -> [CGPoint] {
        let heights = bins.map { $0.isFinite ? max($0, 0) : 0 }
        guard let top = heights.max(), top > 0 else { return [] }
        let count = Double(heights.count)
        return heights.enumerated().map { CGPoint(x: (Double($0.offset) + 0.5) / count, y: $0.element / top) }
    }
}

/// One pointer gesture on a ToneCurveEditor and its key edits, with no view,
/// over the suite's EditRun: a press adds a point in x order (the first
/// change) or picks the one under it, its drag moves that point from where it
/// began or removes a middle one past the well's margin, and the release ends
/// the run once when anything changed. A nudge or a Delete is a change and an
/// end in one call; keys wait while a drag is held. ToneCurveEditorTests drive it.
struct ToneCurveGesture: Equatable, Sendable {
    /// The point moved (nil: the press hit none and added none), the points and its view position at the press.
    struct Drag: Equatable, Sendable {
        let index: Int?
        let start: [CGPoint]
        let anchor: CGPoint
    }

    private(set) var drag: Drag?
    private(set) var run = EditRun()

    /// The press at `location`: picks the point there, or adds one and returns the points with it.
    mutating func pressed(at location: CGPoint, points: [CGPoint], in plot: CGRect) -> [CGPoint]? {
        if let hit = ToneCurveEditor.hitIndex(at: location, of: points, in: plot) {
            drag = Drag(index: hit, start: points, anchor: CurveEditor.viewPoint(points[hit], in: plot, range: 0...1))
            return nil
        }
        guard let added = ToneCurveEditor.added(CurveEditor.unitPoint(location, in: plot, range: 0...1), to: points)
        else {
            drag = Drag(index: nil, start: points, anchor: .zero)
            return nil
        }
        drag = Drag(index: added.index, start: added.points, anchor: location)
        _ = run.change()
        return added.points
    }

    /// The pointer at `location`, `translation` from the press: the points to send, or nil when the
    /// press picked no point or the pointer hasn't moved.
    mutating func dragged(to location: CGPoint, by translation: CGSize, in plot: CGRect, well size: CGSize) -> [CGPoint]? {
        guard let drag, let index = drag.index, translation != .zero else { return nil }
        let at = CGPoint(x: drag.anchor.x + translation.width, y: drag.anchor.y + translation.height)
        let out = ToneCurveEditor.isOutOfWell(location, size: size)
        let removed = out ? ToneCurveEditor.removed(index, from: drag.start) : nil
        _ = run.change()
        return removed ?? ToneCurveEditor.moved(index, to: CurveEditor.unitPoint(at, in: plot, range: 0...1), in: drag.start)
    }

    /// The release: true exactly once for a gesture that changed the points.
    mutating func released() -> Bool {
        drag = nil
        return run.end()
    }

    /// A nudge or a Delete: true, once, unless a drag is held.
    mutating func keyed() -> Bool {
        guard drag == nil else { return false }
        _ = run.change()
        return run.end()
    }
}

/// ToneCurveEditor's point rules as UC15's CurvePointEditing, in unit points
/// and, for `isOutOfWell`, view points: sorted adds, x held between
/// neighbours, the ends kept, nudges of 0.01 (Shift 0.1) and the well's margin.
public struct SuiteCurvePointEditing: CurvePointEditing {
    public init() {}

    public func added(_ point: PlanePoint, to points: [PlanePoint]) -> (points: [PlanePoint], index: Int)? {
        guard let added = ToneCurveEditor.added(Self.cg(point), to: points.map(Self.cg)) else { return nil }
        return (added.points.map(Self.plane), added.index)
    }

    public func moved(_ index: Int, to point: PlanePoint, in points: [PlanePoint]) -> [PlanePoint] {
        ToneCurveEditor.moved(index, to: Self.cg(point), in: points.map(Self.cg)).map(Self.plane)
    }

    public func removed(_ index: Int, from points: [PlanePoint]) -> [PlanePoint]? {
        ToneCurveEditor.removed(index, from: points.map(Self.cg))?.map(Self.plane)
    }

    public func nudged(_ index: Int, dx: Int, dy: Int, coarse: Bool, in points: [PlanePoint]) -> [PlanePoint] {
        ToneCurveEditor.nudged(index, dx: dx, dy: dy, coarse: coarse, in: points.map(Self.cg)).map(Self.plane)
    }

    public func isOutOfWell(_ location: PlanePoint, extent: PlaneExtent) -> Bool {
        ToneCurveEditor.isOutOfWell(Self.cg(location), size: CGSize(width: extent.width, height: extent.height))
    }

    private static func cg(_ p: PlanePoint) -> CGPoint { CGPoint(x: p.x, y: p.y) }
    private static func plane(_ p: CGPoint) -> PlanePoint { PlanePoint(x: Double(p.x), y: Double(p.y)) }
}

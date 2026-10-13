// ToneCurveEditor.swift: the tone curve editor, CurveEditor's look generalised
// to any number of points: a square unit plot (x input, y output, 0...1) in
// the same rounded well, a faint histogram behind, the quarter grid, the
// dashed identity and a dot per point. The host passes the points and the
// engine-sampled curve; this view holds no curve math. Click to add a point
// and drag it, drag a point to move it, drag a middle one out of the well or
// press Delete to remove it; arrows nudge the focused point (Shift ten times
// as far), Tab and Shift-Tab step between points. Values go out through
// `onChange` during a gesture and one `onEnd` after it (and after each nudge
// or delete), so each is one undo step. Knows no Model. The point math is
// static and tested in ToneCurveEditorTests; mapping, the curve path and
// nudge steps are CurveEditor's statics. Under Increase Contrast the well
// gets an outline. Owns presentation state only: focus and the gesture.
import SwiftUI

public struct ToneCurveEditor: View {
    private let points: [CGPoint]
    private let samples: [CGPoint]
    private let histogram: [Double]
    private let id: String
    private let onChange: @MainActor ([CGPoint]) -> Void
    private let onEnd: @MainActor () -> Void
    @State private var focused: Int?
    /// The point moved (nil: the click added none), the points and its view position at the start.
    @State private var drag: (index: Int?, start: [CGPoint], anchor: CGPoint, changed: Bool)?
    @FocusState private var hasFocus: Bool
    @Environment(\.colorSchemeContrast) private var contrast

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
                        if drag?.changed == true { onEnd() }
                        drag = nil
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
        .accessibilityIdentifier(id)
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
            .accessibilityIdentifier("\(id).point\(index + 1)")
    }

    /// The first event picks the point (a hit) or adds one (a miss); later ones move it from where it
    /// began, or remove it while the pointer is out of the well.
    private func dragged(_ value: DragGesture.Value, plot: CGRect, size: CGSize) {
        if drag == nil {
            if let hit = Self.hitIndex(at: value.startLocation, of: points, in: plot) {
                drag = (hit, points, CurveEditor.viewPoint(points[hit], in: plot, range: 0...1), false)
            } else if let added = Self.added(CurveEditor.unitPoint(value.startLocation, in: plot, range: 0...1), to: points) {
                drag = (added.index, added.points, value.startLocation, true)
                onChange(added.points)
            } else {
                drag = (nil, points, .zero, false)
            }
            focused = drag?.index ?? focused
            hasFocus = true
        }
        guard let start = drag?.start, let index = drag?.index, let anchor = drag?.anchor, value.translation != .zero
        else { return }
        let at = CGPoint(x: anchor.x + value.translation.width, y: anchor.y + value.translation.height)
        let removed = Self.isOutOfWell(value.location, size: size) ? Self.removed(index, from: start) : nil
        drag?.changed = true
        onChange(removed ?? Self.moved(index, to: CurveEditor.unitPoint(at, in: plot, range: 0...1), in: start))
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
        onChange(Self.nudged(index, dx: dx, dy: dy, coarse: press.modifiers.contains(.shift), in: points))
        onEnd()
        return .handled
    }

    /// Removes the focused middle point; focus stays at its index, now the next point.
    private func delete() -> KeyPress.Result {
        guard let index = focused, let next = Self.removed(index, from: points) else { return .ignored }
        onChange(next)
        onEnd()
        return .handled
    }
}

extension ToneCurveEditor {
    /// The closest two neighbouring points may sit in x.
    nonisolated public static let minimumGap: CGFloat = 0.01

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

    /// Whether `location` has left a well of `size`: a middle point dragged there is removed.
    nonisolated public static func isOutOfWell(_ location: CGPoint, size: CGSize) -> Bool {
        !CGRect(origin: .zero, size: size).contains(location)
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

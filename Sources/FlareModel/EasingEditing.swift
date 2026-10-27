// EasingEditing.swift: the contract between the easing editor's views and the
// state behind them (docs/blueprints/flare-easing-editor.md). A segment is the
// stretch of one property track from a keyframe to the next one; its curve is
// the start keyframe's FlareCore `Easing`. The UI track builds against
// `FakeEasingEditing`; FlareWorkspace conforms for real.
//
// Invariants every conformer keeps:
// - handle x is clamped to 0...1, handle y is not (overshoot is allowed); a
//   non-finite point changes nothing
// - consecutive `moveEasingHandle` calls for the same handle are one undo step
//   until `endEasingHandleDrag()`; every other edit is its own undo step
// - handles, moves, samples and presets are SuiteKernel's `EaseCurve` and
//   `EasePreset`, called directly; Flare keeps no curve math of its own
import FlareCore
import SuiteKernel

/// One animated stretch of a property track: from the keyframe at
/// `startFrame` to the next keyframe on the same track at `endFrame`.
public struct EasingSegment: Hashable, Sendable, Identifiable {
    public let property: String
    public let startFrame: Int
    public let endFrame: Int

    public init(property: String, startFrame: Int, endFrame: Int) {
        self.property = property
        self.startFrame = startFrame
        self.endFrame = endFrame
    }

    public var id: Self { self }

    /// The row's span, saying its numbers are frames: "frames 0–24".
    public var frameSpan: String { "frames \(startFrame)\u{2013}\(endFrame)" }
    /// The row's whole title, its property's inspector name then its span: "X, frames 0–24".
    public var title: String { "\(FakeProperties.title(property)), \(frameSpan)" }
}

/// The two control points of a cubic Bezier easing.
public enum EasingHandle: Int, CaseIterable, Sendable {
    case first = 1, second = 2

    /// The scrub row's label for one coordinate: "X1", "Y1", "X2", "Y2".
    public func label(_ axis: EasingAxis) -> String {
        "\(axis == .x ? "X" : "Y")\(rawValue)"
    }

    /// The scrub row's tooltip: which handle, which axis, and its range.
    public func help(_ axis: EasingAxis) -> String {
        let handle = self == .first ? "First" : "Second"
        return switch axis {
        case .x: "\(handle) handle, horizontal (time, 0 to 1)"
        case .y: "\(handle) handle, vertical (progress, -1 to 2)"
        }
    }
}

/// One coordinate of a handle: x is time (0...1), y is progress, which may
/// overshoot (-1...2).
public enum EasingAxis: CaseIterable, Sendable {
    case x, y

    /// The range its scrub row covers.
    public var range: ClosedRange<Double> { self == .x ? 0...1 : -1...2 }
}

/// The preset chips, in the order the editor shows them.
public typealias EasingPreset = EasePreset

public protocol EasingEditing: Sendable {
    /// The selected layer's segments, sorted by property, then start frame.
    var easingSegments: [EasingSegment] { get }
    /// The segment the editor shows; nil when none is selected.
    var selectedEasingSegment: EasingSegment? { get }
    /// The selected segment's easing; nil when no segment is selected.
    var currentEasing: Easing? { get }
    var canUndo: Bool { get }
    /// Why the selected segment's easing can't be changed right now, for the
    /// disabled curve, preset chips and scrub rows; nil when edits apply.
    var easingUnavailableReason: String? { get }

    /// Selects one of `easingSegments`; any other segment is ignored.
    mutating func selectEasingSegment(_ segment: EasingSegment)
    /// Gives the selected segment a preset's easing, as one undo step.
    mutating func setEasingPreset(_ preset: EasingPreset)
    /// Moves a handle of the selected segment to `point` (x clamped to 0...1).
    /// A linear or hold segment becomes a cubic Bezier from (0,0) and (1,1).
    mutating func moveEasingHandle(_ handle: EasingHandle, to point: Point)
    /// Ends a handle drag, so the next move starts a new undo step.
    mutating func endEasingHandleDrag()
    /// `count` points (x, eased y) evenly spaced over 0...1 for drawing the
    /// selected segment's curve; empty with no selection or a count below 2.
    func easingCurveSamples(count: Int) -> [Point]
    /// Undoes the last edit; nothing to undo is a no-op.
    mutating func undo()
}

extension EasingEditing {
    /// The preset whose easing equals the current one, for the active chip.
    public var currentEasingPreset: EasingPreset? {
        currentEasing.flatMap(EasePreset.init)
    }

    /// Whether the KEYFRAMES header shows: only over rows, so a layer with no
    /// keys shows the EASING header and its hint alone (#1861).
    public var showsKeyframesHeader: Bool { !easingSegments.isEmpty }

    /// Where the editor draws the two handles; nil with no selection.
    public var currentEasingHandles: (first: Point, second: Point)? {
        currentEasing.map(EaseCurve.handlePair(of:))
    }

    /// The current easing with `handle` moved to `point` by the kernel; nil
    /// with no selection or a non-finite point, which changes nothing.
    func movedEasing(_ handle: EasingHandle, to point: Point) -> Easing? {
        guard point.x.isFinite, point.y.isFinite, let easing = currentEasing else { return nil }
        return EaseCurve.moving(handle.rawValue - 1, to: point, in: easing)
    }

    /// The kernel's samples of the selected segment's curve; none with no
    /// selection or below 2 points, which draw no line.
    public func easingCurveSamples(count: Int) -> [Point] {
        guard count >= 2, let easing = currentEasing else { return [] }
        return EaseCurve.samples(of: easing, count: count)
    }
}

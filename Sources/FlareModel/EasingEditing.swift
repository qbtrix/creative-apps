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
// - `easingCurveSamples` are FlareCore's `Easing.value(at:)`, never a copy of it
import FlareCore

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
}

/// The two control points of a cubic Bezier easing.
public enum EasingHandle: Int, CaseIterable, Sendable {
    case first = 1, second = 2
}

/// The preset chips, in the order the editor shows them.
public enum EasingPreset: String, CaseIterable, Sendable {
    case linear, ease, easeIn, easeOut, easeInOut, hold

    public var title: String {
        switch self {
        case .linear: "Linear"
        case .ease: "Ease"
        case .easeIn: "Ease In"
        case .easeOut: "Ease Out"
        case .easeInOut: "Ease In-Out"
        case .hold: "Hold"
        }
    }

    public var easing: Easing {
        switch self {
        case .linear: .linear
        case .ease: .ease
        case .easeIn: .easeIn
        case .easeOut: .easeOut
        case .easeInOut: .easeInOut
        case .hold: .hold
        }
    }
}

public protocol EasingEditing: Sendable {
    /// The selected layer's segments, sorted by property, then start frame.
    var easingSegments: [EasingSegment] { get }
    /// The segment the editor shows; nil when none is selected.
    var selectedEasingSegment: EasingSegment? { get }
    /// The selected segment's easing; nil when no segment is selected.
    var currentEasing: Easing? { get }
    var canUndo: Bool { get }

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
        EasingPreset.allCases.first { $0.easing == currentEasing }
    }

    /// Where the editor draws the two handles; nil with no selection.
    public var currentEasingHandles: (first: Point, second: Point)? {
        currentEasing.map(EasingCurve.handles(of:))
    }
}

/// The pure curve math both conformers share, so the Fake and the real model
/// cannot drift apart.
public enum EasingCurve {
    /// The control points of `easing`; linear and hold sit at (0,0) and (1,1).
    public static func handles(of easing: Easing) -> (first: Point, second: Point) {
        guard case let .cubicBezier(x1, y1, x2, y2) = easing else {
            return (Point(x: 0, y: 0), Point(x: 1, y: 1))
        }
        return (Point(x: x1, y: y1), Point(x: x2, y: y2))
    }

    /// `easing` with one handle moved to `point`, x clamped to 0...1; nil
    /// when the point is not finite.
    public static func moving(_ easing: Easing, _ handle: EasingHandle, to point: Point) -> Easing? {
        guard point.x.isFinite, point.y.isFinite else { return nil }
        var (first, second) = handles(of: easing)
        let moved = Point(x: min(max(point.x, 0), 1), y: point.y)
        switch handle {
        case .first: first = moved
        case .second: second = moved
        }
        return .cubicBezier(x1: first.x, y1: first.y, x2: second.x, y2: second.y)
    }

    /// `count` points of `easing` evenly spaced over 0...1, or none when
    /// `count` is below 2.
    public static func samples(of easing: Easing, count: Int) -> [Point] {
        guard count >= 2 else { return [] }
        let last = Double(count - 1)
        return (0..<count).map { i in
            let x = Double(i) / last
            return Point(x: x, y: easing.value(at: x))
        }
    }
}

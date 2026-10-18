// ScrubValue.swift: the number rules behind ScrubField and the bar slider
// (drag sideways to change a value, step it from the keyboard, how far the
// fill reaches) and ViewerStatusBar and the editor's zoom commands (the zoom
// readout, fit, and the zoom in and out stops), plus ScrubTrack, the
// non-linear track a bar slider can move along. No SwiftUI, like
// NumericInput, so the rules are unit-tested on their own. Invariants: every
// result is inside its range and never NaN, whatever the drag distance, step
// or modifier; a step that is zero, negative or not finite means "no
// snapping", never a trap.
import Foundation

public enum ScrubValue {
    /// The value after dragging `points` sideways from `start`: one `step` per
    /// point times `multiplier`, snapped to that grid and clamped to `range`.
    public static func dragged(
        from start: Double, by points: Double, step: Double, multiplier: Double = 1, in range: ClosedRange<Double>
    ) -> Double {
        let unit = step * multiplier
        guard unit.isFinite, unit > 0, points.isFinite else { return NumericInput.clamp(start, to: range) }
        return snapped(start + points * unit, to: unit, in: range)
    }

    /// `value` rounded to the nearest multiple of `unit`, then clamped. A unit
    /// like 0.1 divides by its whole reciprocal (10), so 15 steps give 1.5,
    /// not 1.5000000000000002.
    public static func snapped(_ value: Double, to unit: Double, in range: ClosedRange<Double>) -> Double {
        guard unit.isFinite, unit > 0, value.isFinite else { return NumericInput.clamp(value, to: range) }
        let steps = (value / unit).rounded()
        let inverse = (1 / unit).rounded()
        let snapped = unit < 1 && inverse.isFinite && abs(1 / unit - inverse) < 1e-9 ? steps / inverse : steps * unit
        return NumericInput.clamp(snapped.isFinite ? snapped : value, to: range)
    }

    /// Drag speed for the held keys: Option is fine (a tenth of a step per
    /// point) and wins over Shift, which is coarse (ten steps per point).
    public static func multiplier(shift: Bool, option: Bool) -> Double {
        option ? 0.1 : shift ? 10 : 1
    }

    /// The value after pressing `key` with focus: one step up or down (Shift
    /// ten, Option a tenth), or the range's ends for Home and End.
    public static func pressed(
        _ key: ScrubKey, from value: Double, step: Double, shift: Bool = false, option: Bool = false,
        in range: ClosedRange<Double>
    ) -> Double {
        switch key {
        case .home: range.lowerBound
        case .end: range.upperBound
        case .increment, .decrement:
            // Ten steps from where it is (45 to 55), snapped to the step, or a
            // tenth of one snapped to that finer grid.
            stepped(value, by: key == .increment ? 1 : -1, unit: step * multiplier(shift: shift, option: option), step: step, in: range)
        }
    }

    /// The track position after pressing `key` on a bar slider over `track`
    /// (the arrows, VoiceOver's adjustable action and the Slider
    /// representation all come here): Home and End go to the track's ends,
    /// and an arrow moves `track.step` times the modifier's multiplier
    /// through `track.stepped(_:by:)`, so a track that owns its step (#591,
    /// Photo's gamma detent) decides it. With no `stepped` the result is
    /// exactly `pressed(_:from:step:shift:option:in:)` on the track.
    public static func pressed(
        _ key: ScrubKey, from position: Double, shift: Bool = false, option: Bool = false, on track: ScrubTrack
    ) -> Double {
        let unit = track.step * multiplier(shift: shift, option: option)
        guard key == .increment || key == .decrement, unit.isFinite, unit > 0 else {
            return pressed(key, from: position, step: track.step, shift: shift, option: option, in: track.positions)
        }
        let next = track.stepped(position, by: key == .increment ? unit : -unit)
        return NumericInput.clamp(next.isFinite ? next : position, to: track.positions)
    }

    static func stepped(
        _ value: Double, by direction: Double, unit: Double, step: Double, in range: ClosedRange<Double>
    ) -> Double {
        guard unit.isFinite, unit > 0 else { return NumericInput.clamp(value, to: range) }
        return snapped(value + direction * unit, to: min(unit, step), in: range)
    }

    /// How far along `range` a bar slider's fill reaches, 0...1; 0 for an
    /// empty range or a value that isn't finite.
    public static func fraction(_ value: Double, in range: ClosedRange<Double>) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0, span.isFinite, value.isFinite else { return 0 }
        return min(max((value - range.lowerBound) / span, 0), 1)
    }

    /// The step for a field that names none: the largest power of ten not
    /// above a hundredth of the range, so 0...100 steps by 1, -180...180 by 1,
    /// -5...5 by 0.1 and 0...1 by 0.01. An empty or infinite range steps by 1.
    public static func defaultStep(for range: ClosedRange<Double>) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span.isFinite, span > 0 else { return 1 }
        let step = pow(10, log10(span / 100).rounded(.down))
        return step.isFinite && step > 0 ? step : 1
    }
}

/// A key a focused scrub field or bar slider takes: the arrows step, Home and
/// End jump to the ends.
public enum ScrubKey: Sendable {
    case increment, decrement, home, end
}

/// The track a bar slider moves along when it isn't its value's range: drags,
/// keys and the fill move through `positions` in `step`s, and `value` turns a
/// position back into the value it sets (which may snap, as a detent does).
/// `stepped`, when set, owns the discrete step (arrows, VoiceOver, the
/// Slider representation): it takes a position and a signed delta in
/// positions (the modifier already folded in) and returns the next position,
/// so a press can leave a detent a drag would snap back into (#591). Drags
/// never use it.
public struct ScrubTrack: Sendable {
    public let positions: ClosedRange<Double>
    public let step: Double
    public let position: @Sendable (Double) -> Double
    public let value: @Sendable (Double) -> Double
    public let stepped: (@Sendable (Double, Double) -> Double)?

    public init(
        positions: ClosedRange<Double>, step: Double, position: @escaping @Sendable (Double) -> Double,
        value: @escaping @Sendable (Double) -> Double, stepped: (@Sendable (Double, Double) -> Double)? = nil
    ) {
        self.positions = positions
        self.step = step
        self.position = position
        self.value = value
        self.stepped = stepped
    }
}

extension ScrubTrack: TrackStepping {
    public func position(of value: Double) -> Double { position(value) }

    public func value(at position: Double) -> Double { value(position) }

    /// The track's own step, or today's: `direction` from `position`,
    /// snapped to the finer of its size and `step`, clamped to `positions`.
    public func stepped(_ position: Double, by direction: Double) -> Double {
        if let own = self.stepped { return own(position, direction) }
        return ScrubValue.stepped(position, by: direction < 0 ? -1 : 1, unit: abs(direction), step: step, in: positions)
    }
}

public enum ViewerZoom {
    /// "51%": a zoom scale as a whole percent; "–" when it isn't a positive
    /// finite number. Past a million percent it reads the cap, never traps.
    public static func percentText(_ scale: Double) -> String {
        guard scale.isFinite, scale > 0 else { return "–" }
        return "\(Int(min(scale * 100, 1_000_000).rounded()))%"
    }

    /// The scale CanvasSurface draws an artboard at inside a viewer of `size`:
    /// fit inside `inset` on every side, never above 100%, 0 when nothing fits.
    /// Non-positive artboard sides count as 1 point, as CanvasSurface does.
    public static func fitScale(
        artboard: CGSize, in size: CGSize, inset: CGFloat = SuiteSize.canvasInset
    ) -> Double {
        let room = CGSize(width: size.width - 2 * inset, height: size.height - 2 * inset)
        guard room.width > 0, room.height > 0, room.width.isFinite, room.height.isFinite else { return 0 }
        let scale = min(room.width / max(artboard.width, 1), room.height / max(artboard.height, 1), 1)
        return scale.isFinite ? Double(scale) : 0
    }

    /// The stops Zoom In and Zoom Out step through, smallest first.
    public static let stops: [Double] = [0.05, 0.1, 0.25, 1.0 / 3, 0.5, 2.0 / 3, 1, 1.5, 2, 3, 4, 6, 8, 12, 16, 32]

    /// The next stop above `scale`, or the largest; 100% for a scale that
    /// isn't a positive finite number.
    public static func zoomedIn(from scale: Double) -> Double {
        guard scale.isFinite, scale > 0 else { return 1 }
        return stops.first { $0 > scale * 1.001 } ?? stops[stops.count - 1]
    }

    /// The next stop below `scale`, or the smallest; 100% for a scale that
    /// isn't a positive finite number.
    public static func zoomedOut(from scale: Double) -> Double {
        guard scale.isFinite, scale > 0 else { return 1 }
        return stops.last { $0 < scale / 1.001 } ?? stops[0]
    }
}

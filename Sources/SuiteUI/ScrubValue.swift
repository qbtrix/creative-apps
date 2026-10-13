// ScrubValue.swift: the number rules behind ScrubField (drag sideways to
// change a value) and ViewerStatusBar and the editor's zoom commands (the zoom
// readout, fit, and the zoom in and out stops). No SwiftUI, like
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

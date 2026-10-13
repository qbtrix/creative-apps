// GammaTrack.swift: the logarithmic slider track for Levels gamma. A track
// position t in -1...1 is gamma 10^t, so the identity gamma 1 sits at the
// midpoint and 0.1...1 gets as much travel as 1...10. Only the track is
// logarithmic: AdjustmentSettings still stores gamma itself over gammaRange.
// The slider drags through snappedGamma, whose detent band around the
// midpoint gives exactly 1, so a drag back to the middle undoes the edit.
// The band is a fixed number of drag points wide (detentPoints), not a share
// of the track, so it is as easy to hit at any inspector width.
// Invariants: both directions clamp to their range, NaN gives the identity,
// and the endpoints and midpoint map exactly. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

public enum GammaTrack {
    /// log10 of AdjustmentSettings.gammaRange's bounds.
    public static let positionRange: ClosedRange<Double> = -1...1

    /// The track position for `gamma`, clamped to `positionRange`. NaN and
    /// values at or below zero give the nearest end (NaN: the midpoint).
    public static func position(ofGamma gamma: Double) -> Double {
        guard !gamma.isNaN else { return 0 }
        guard gamma > 0 else { return positionRange.lowerBound }
        return clamp(log10(gamma))
    }

    /// The gamma at track position `position`, which is clamped first; NaN
    /// gives the identity, 1.
    public static func gamma(atPosition position: Double) -> Double {
        guard !position.isNaN else { return 1 }
        let t = clamp(position)
        // Exact at the ends and the midpoint, whatever pow rounds to.
        switch t {
        case positionRange.lowerBound: return 0.1
        case 0: return 1
        case positionRange.upperBound: return 10
        default: return pow(10, t)
        }
    }

    /// How far the track moves per point of sideways drag (the bar slider's
    /// step: a scrub moves one step per point), and per arrow key.
    public static let step = 0.01

    /// Half the width of the midpoint detent in points of drag: a release
    /// within this many points of the centre is gamma 1. Wide enough to hit on
    /// purpose; the gammas it hides (about 0.91 to 1.10) are still typeable.
    public static let detentPoints = 4.0

    /// Half the width of the midpoint detent in track units: detentPoints of
    /// drag at `step` per point.
    public static let detent = detentPoints * step

    /// The gamma a drag to `position` sets: exactly 1 inside the detent
    /// (|position| <= detent), otherwise gamma(atPosition:).
    public static func snappedGamma(atPosition position: Double) -> Double {
        abs(position) <= detent ? 1 : gamma(atPosition: position)
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, positionRange.lowerBound), positionRange.upperBound)
    }
}

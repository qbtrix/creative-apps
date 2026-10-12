// GammaTrack.swift: the logarithmic slider track for Levels gamma. A track
// position t in -1...1 is gamma 10^t, so the identity gamma 1 sits at the
// midpoint and 0.1...1 gets as much travel as 1...10. Only the track is
// logarithmic: AdjustmentSettings still stores gamma itself over gammaRange.
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

    private static func clamp(_ value: Double) -> Double {
        min(max(value, positionRange.lowerBound), positionRange.upperBound)
    }
}

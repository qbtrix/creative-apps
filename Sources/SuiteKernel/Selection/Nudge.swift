// Nudge.swift (EK-10): the one arrow-key nudge rule every app shares. A press
// moves the selection by one step, Shift by the large step, and every press
// of one run on one selection folds under the same history key.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The arrow-key nudge: the delta a press moves by and the run key it folds under.
public enum Nudge {
    /// The offset one press of `d` moves by: `step` (1 point by default), or
    /// `largeStep` (10) when `large` (Shift is down). Up is negative y.
    public static func delta(_ d: Direction, large: Bool, step: Double = 1, largeStep: Double = 10) -> Point {
        let amount = large ? largeStep : step
        switch d {
        case .left: return Point(x: -amount, y: 0)
        case .right: return Point(x: amount, y: 0)
        case .up: return Point(x: 0, y: -amount)
        case .down: return Point(x: 0, y: amount)
        }
    }

    /// The history key a run of nudges records under: `base` plus the ids, so
    /// the same edit on the same selection folds into one step and a new
    /// edit or selection starts a new one.
    public static func runKey(_ base: String, _ ids: [some Hashable & CustomStringConvertible]) -> String {
        base + ":" + ids.map(\.description).joined(separator: "\u{1F}")
    }
}

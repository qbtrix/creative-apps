// PresetNavigating.swift: UC4 (SJ15), arrow-key focus moves in a preset grid,
// and FakePresetNavigating, which wraps at the edges on purpose (the live rule
// stops). Foundation only; verbatim from blueprint section 5.2.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public protocol PresetNavigating: Sendable {
    /// The preset an arrow key moves focus to in a grid of `count` presets in `columns` columns; nil at an edge.
    func neighbor(of index: Int, _ arrow: GridArrow, count: Int, columns: Int) -> Int?
}

/// Wraps instead of stopping at the edges (the live rule stops), so a UI built on it must not rely on wrapping.
public struct FakePresetNavigating: PresetNavigating {
    public init() {}
    public func neighbor(of index: Int, _ arrow: GridArrow, count: Int, columns: Int) -> Int? {
        guard count > 0, columns > 0, (0..<count).contains(index) else { return nil }
        let delta = switch arrow { case .left: -1; case .right: 1; case .up: -columns; case .down: columns }
        return ((index + delta) % count + count) % count
    }
}

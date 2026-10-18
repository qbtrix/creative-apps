// ValueScrubbing.swift: UC1 (SJ11, SJ12, SP1), scrubbing, stepping and typing a
// numeric inspector value, and FakeValueScrubbing, which is linear and
// unsnapped on purpose. Foundation only; verbatim from blueprint section 5.2.
// ScrubKey is the existing enum in ScrubValue.swift.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct ScrubSpec: Hashable, Sendable {
    public var range: ClosedRange<Double>
    public var step: Double
    public var decimals: Int
    public var unit: String
    public init(range: ClosedRange<Double>, step: Double, decimals: Int = 2, unit: String = "") {
        self.range = range; self.step = step; self.decimals = decimals; self.unit = unit
    }
}

/// A non-linear track (Photo's log gamma): the bar moves in positions, the
/// field shows values; `stepped` is #591's track-owned discrete step.
public protocol TrackStepping: Sendable {
    func position(of value: Double) -> Double
    func value(at position: Double) -> Double
    func stepped(_ position: Double, by direction: Double) -> Double
}

public protocol ValueScrubbing: Sendable {
    /// Press-and-drag scrubs relative to `start`: one step per point, ⇧ ×10, ⌥ ×0.1; clamped and snapped.
    func dragged(from start: Double, by points: Double, modifiers: KeyModifiers, spec: ScrubSpec) -> Double
    /// Arrows step (⇧ coarse, ⌥ fine), Home and End jump to the ends; on a track the track steps.
    func pressed(_ key: ScrubKey, from value: Double, modifiers: KeyModifiers, spec: ScrubSpec,
                 track: (any TrackStepping)?) -> Double
    /// The typed text when the field closes. Text that isn't a number keeps `old`.
    func committed(_ text: String, opening: String, old: Double, spec: ScrubSpec) -> Double
    /// How far the bar's fill reaches, 0...1.
    func fraction(_ value: Double, spec: ScrubSpec) -> Double
    /// What the row shows ("45°") and what VoiceOver reads ("45 degrees").
    func text(_ value: Double, spec: ScrubSpec) -> String
    func spoken(_ value: Double, spec: ScrubSpec) -> String
}

/// Linear and unsnapped, two decimals: enough to build and snapshot a row before the live rules are wired.
public struct FakeValueScrubbing: ValueScrubbing {
    public init() {}
    private func clamp(_ v: Double, _ r: ClosedRange<Double>) -> Double { v.isFinite ? min(max(v, r.lowerBound), r.upperBound) : r.lowerBound }
    private func mult(_ m: KeyModifiers) -> Double { m.contains(.option) ? 0.1 : m.contains(.shift) ? 10 : 1 }
    public func dragged(from start: Double, by points: Double, modifiers: KeyModifiers, spec: ScrubSpec) -> Double {
        clamp(start + points * spec.step * mult(modifiers), spec.range)
    }
    public func pressed(_ key: ScrubKey, from value: Double, modifiers: KeyModifiers, spec: ScrubSpec,
                        track: (any TrackStepping)?) -> Double {
        switch key {
        case .home: return spec.range.lowerBound
        case .end: return spec.range.upperBound
        case .increment, .decrement:
            let direction: Double = key == .increment ? 1 : -1
            if let track { return clamp(track.value(at: track.stepped(track.position(of: value), by: direction)), spec.range) }
            return clamp(value + direction * spec.step * mult(modifiers), spec.range)
        }
    }
    public func committed(_ text: String, opening: String, old: Double, spec: ScrubSpec) -> Double {
        Double(String(text.filter { $0 != " " })).map { clamp($0, spec.range) } ?? old
    }
    public func fraction(_ value: Double, spec: ScrubSpec) -> Double {
        let span = spec.range.upperBound - spec.range.lowerBound
        return span > 0 ? clamp((value - spec.range.lowerBound) / span, 0...1) : 0
    }
    public func text(_ value: Double, spec: ScrubSpec) -> String { "\(value)\(spec.unit)" }
    public func spoken(_ value: Double, spec: ScrubSpec) -> String { spec.unit.isEmpty ? "\(value)" : "\(value) \(spec.unit)" }
}

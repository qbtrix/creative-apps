// BrushSettings.swift: a brush's settings and its saved presets
// (editor-kernel EK-29 stubs, EK-28 bodies). Size in points, hardness,
// opacity, flow and spacing as percentages; every change arrives as one
// `BrushEdit`, clamps to its range and ignores NaN. A preset is a named set
// of settings that round-trips through JSON.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One change a brush's settings can take: the size in points, or the
/// hardness, opacity, flow or spacing percentage.
public enum BrushEdit: Hashable, Sendable {
    case size(Double), hardness(Double), opacity(Double), flow(Double), spacing(Double)
}

/// A brush's settings: `size` is the diameter in points; `hardness` (100 a
/// hard edge, 0 soft from the centre), `opacity`, `flow` (how much each dab
/// lays down) and `spacing` (the gap between dabs, of the size) are percentages.
public struct BrushSettings: Hashable, Codable, Sendable {
    /// The diameter, then the four percentages.
    public var size: Double, hardness: Double, opacity: Double, flow: Double, spacing: Double

    /// The ranges `apply` clamps to: `size` for the diameter in points,
    /// `percent` for hardness, opacity, flow and spacing.
    public static let ranges: (size: ClosedRange<Double>, percent: ClosedRange<Double>) = (1...500, 0...100)

    /// Settings with the given values (default a 20-point hard brush at full
    /// opacity and flow, dabs a quarter of the size apart).
    public init(size: Double = 20, hardness: Double = 100, opacity: Double = 100, flow: Double = 100, spacing: Double = 25) {
        (self.size, self.hardness, self.opacity, self.flow, self.spacing) = (size, hardness, opacity, flow, spacing)
    }

    /// Applies one edit; true when a value changed. The value is clamped to
    /// `ranges`; NaN changes nothing.
    public mutating func apply(_ edit: BrushEdit) -> Bool {
        let target: (WritableKeyPath<BrushSettings, Double>, Double, ClosedRange<Double>)
        switch edit {
        case .size(let v): target = (\.size, v, Self.ranges.size)
        case .hardness(let v): target = (\.hardness, v, Self.ranges.percent)
        case .opacity(let v): target = (\.opacity, v, Self.ranges.percent)
        case .flow(let v): target = (\.flow, v, Self.ranges.percent)
        case .spacing(let v): target = (\.spacing, v, Self.ranges.percent)
        }
        let (key, value, range) = target
        guard !value.isNaN else { return false }
        let clamped = Swift.min(range.upperBound, Swift.max(range.lowerBound, value))
        guard self[keyPath: key] != clamped else { return false }
        self[keyPath: key] = clamped
        return true
    }
}

/// A named, saved set of brush settings.
public struct BrushPreset: Hashable, Codable, Sendable, Identifiable {
    /// The preset's stable id and the name the preset list shows.
    public var id: String, name: String
    /// The settings the preset restores.
    public var settings: BrushSettings

    /// A preset from its id, name and settings.
    public init(id: String, name: String, settings: BrushSettings) {
        (self.id, self.name, self.settings) = (id, name, settings)
    }
}

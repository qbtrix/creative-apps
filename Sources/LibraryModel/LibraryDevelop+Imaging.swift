// LibraryDevelop+Imaging.swift: Library's develop values on SuiteImaging
// (suite-imaging IM-10). DevelopLevels is SuiteImaging's AdjustLevels and
// DevelopCurvePoint its AdjustCurvePoint (typealiases in
// Contracts/DevelopValues.swift), so a catalog's keys never change; this file
// gives the levels Library's rows (the five fields, their 0...255 row units,
// the clamping setters), ToneCurve its conversions to and from AdjustCurve,
// and DevelopSettings the AdjustSettings LiveDevelop's shared list runs.
// Linux-safe.
import SuiteImaging

extension AdjustLevels {
    /// One levels row. The raw value is the row's label.
    public enum Field: String, CaseIterable, Sendable {
        case inBlack = "Black Point", gamma = "Midtones", inWhite = "White Point"
        case outBlack = "Output Black", outWhite = "Output White"

        /// The row's unit over the stored value: the points show 0...255, gamma itself.
        public var rowScale: Double { self == .gamma ? 1 : 255 }
    }

    /// Neutral levels: black 0, white 1, gamma 1.
    public init() { self = .neutral }

    /// The catalog's names for the stored values, sRGB values in 0...1.
    public var inBlack: Double { inputBlack }
    public var inWhite: Double { inputWhite }
    public var outBlack: Double { outputBlack }
    public var outWhite: Double { outputWhite }

    public func value(_ field: Field) -> Double {
        switch field {
        case .inBlack: inputBlack
        case .gamma: gamma
        case .inWhite: inputWhite
        case .outBlack: outputBlack
        case .outWhite: outputWhite
        }
    }

    /// Clamped to the field's range; NaN or infinity gives the neutral value. The
    /// black and white points stay at least `pointGap` apart: the one being moved stops there.
    public func setting(_ field: Field, to value: Double) -> AdjustLevels {
        let wanted = value.isFinite ? value : Self.neutral.value(field)
        var copy = self
        switch field {
        case .inBlack: copy.inputBlack = min(max(wanted, 0), inputWhite - Self.pointGap)
        case .gamma: copy.gamma = min(max(wanted, Self.gammaRange.lowerBound), Self.gammaRange.upperBound)
        case .inWhite: copy.inputWhite = min(max(wanted, inputBlack + Self.pointGap), 1)
        case .outBlack: copy.outputBlack = min(max(wanted, 0), 1)
        case .outWhite: copy.outputWhite = min(max(wanted, 0), 1)
        }
        return copy
    }

    /// The field in its row's units (0...255 for the points).
    public func row(_ field: Field) -> Double { value(field) * field.rowScale }

    /// The field set from its row's units, stored in 0...1 (the catalog's units).
    public func setting(_ field: Field, row value: Double) -> AdjustLevels {
        setting(field, to: value / field.rowScale)
    }
}

extension ToneCurve {
    /// The same points as SuiteImaging's curve; ToneCurve's points always pass
    /// AdjustCurve's repair (ends at 0 and 1, gaps of 0.01 over its 1/255).
    public var adjustCurve: AdjustCurve { AdjustCurve(points: points) }

    /// SuiteImaging's curve under ToneCurve's rules: its ends pinned to x = 0
    /// and 1, points closer than `minGap` dropped. An AdjustCurve always has 2
    /// finite points, so the identity fallback never shows.
    public init(_ curve: AdjustCurve) {
        self = ToneCurve(points: curve.points) ?? .identity
    }
}

extension DevelopSettings {
    /// The SuiteImaging value for these settings' exposure, levels, curve and
    /// saturation, the parts `ImagingProgram.adjustments` runs (IM-10b).
    public var adjustSettings: AdjustSettings {
        AdjustSettings(exposure: exposure, levels: levels, curve: curve.adjustCurve,
                       hueSaturation: AdjustHueSaturation(hue: 0, saturation: saturation, lightness: 0))
    }
}

// ToneSettings.swift (tone-controls TC-1 values and stubs, TC-7 coding and clamping): the suite's one
// tone and sharpen adjustment, the value Photo and Library both store. `setting` clamps to the slider's
// range and refuses NaN; the coding is by hand, with Library's ten Develop keys. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One slider. The raw value is the JSON key and the `tone.set` param.
public enum ToneSlider: String, CaseIterable, Codable, Sendable {
    case temperature, tint, exposure, brightness, contrast, highlights, shadows, whites, blacks, vibrance, saturation
    case sharpenAmount, sharpenRadius, sharpenThreshold
    /// The row's label: "Temperature", "Amount", ...
    public var title: String {
        switch self {
        case .sharpenAmount: "Amount"
        case .sharpenRadius: "Radius"
        case .sharpenThreshold: "Threshold"
        default: rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }
    /// The section the row sits in.
    public var group: ToneGroup {
        switch self {
        case .temperature, .tint: .whiteBalance
        case .exposure, .brightness, .contrast, .highlights, .shadows, .whites, .blacks: .tone
        case .vibrance, .saturation: .presence
        case .sharpenAmount, .sharpenRadius, .sharpenThreshold: .sharpen
        }
    }
    /// Exposure −5...5 stops; Amount 0...300 %; Radius 0.5...3 px; Threshold 0...50 levels; the rest −100...100.
    public var range: ClosedRange<Double> {
        switch self {
        case .exposure: -5...5
        case .sharpenAmount: 0...300
        case .sharpenRadius: 0.5...3
        case .sharpenThreshold: 0...50
        default: -100...100
        }
    }
    /// The value that leaves the picture unchanged: 0, Radius 1.
    public var neutral: Double { self == .sharpenRadius ? 1 : 0 }
    /// One arrow-key step: Exposure 0.01, Radius 0.1, the rest 1.
    public var step: Double { self == .exposure ? 0.01 : self == .sharpenRadius ? 0.1 : 1 }
}

/// The four sections, in the order the rows show them.
public enum ToneGroup: String, CaseIterable, Sendable {
    case whiteBalance, tone, presence, sharpen
    /// "White Balance", "Tone", "Presence", "Sharpen".
    public var title: String { self == .whiteBalance ? "White Balance" : rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
    /// The group's sliders, in row order.
    public var sliders: [ToneSlider] { ToneSlider.allCases.filter { $0.group == self } }
}

/// Edit instructions, never pixels; neutral renders the picture unchanged. Coded by hand: a neutral slider
/// writes no key, a missing key reads neutral, and the ten Develop keys are Library's own.
public struct ToneSettings: Hashable, Codable, Sendable {
    /// The sliders off neutral; a neutral slider is never stored, so equal settings compare equal.
    private var values: [ToneSlider: Double] = [:]
    /// Every slider at its neutral value.
    public static let neutral = ToneSettings()
    public init() {}
    /// The slider's value, its neutral when unset.
    public func value(_ s: ToneSlider) -> Double { values[s] ?? s.neutral }
    /// A copy with `s` at `v`, clamped to the slider's range; NaN keeps the old value.
    public func setting(_ s: ToneSlider, to v: Double) -> ToneSettings {
        guard !v.isNaN else { return self }
        let clamped = min(max(v, s.range.lowerBound), s.range.upperBound)
        var copy = self
        copy.values[s] = clamped == s.neutral ? nil : clamped
        return copy
    }
    /// A copy with group `g`'s sliders at neutral; nil resets every group.
    public func reset(_ g: ToneGroup?) -> ToneSettings {
        var copy = self
        copy.values = values.filter { g != nil && $0.key.group != g }
        return copy
    }
    /// Whether group `g` (every group when nil) leaves the picture unchanged.
    public func isNeutral(_ g: ToneGroup?) -> Bool { !values.keys.contains { g == nil || $0.group == g } }

    /// A slider's JSON key, its raw value: the ten Develop sliders' keys are Library's own (`DevelopSettings`'
    /// `exposure`, `contrast`, ..., `saturation`), so a catalog written today decodes as is.
    private struct Key: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(_ slider: ToneSlider) { stringValue = slider.rawValue }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    /// Each key present is read through `setting`, so it is clamped; a missing key reads neutral and a key
    /// that is no slider (Library's crop, curve, levels) is ignored.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        var s = ToneSettings()
        for slider in ToneSlider.allCases {
            if let v = try c.decodeIfPresent(Double.self, forKey: Key(slider)) { s = s.setting(slider, to: v) }
        }
        self = s
    }

    /// Only the sliders off neutral, so neutral writes `{}` and a new slider adds no key to old files.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: Key.self)
        for slider in ToneSlider.allCases where value(slider) != slider.neutral {
            try c.encode(value(slider), forKey: Key(slider))
        }
    }
}

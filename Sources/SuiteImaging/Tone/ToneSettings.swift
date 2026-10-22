// ToneSettings.swift (tone-controls TC-1 values and stubs, TC-7 coding and clamping): the suite's one
// tone and sharpen adjustment, the value Photo and Library both store. TC-1 stubs: `setting` doesn't
// clamp, and Codable is synthesized until TC-7 codes Library's ten Develop keys by hand. Linux-safe.
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

/// Edit instructions, never pixels; neutral renders the picture unchanged. Coded by hand (TC-7): a neutral
/// slider writes no key, a missing key reads neutral, and the ten Develop keys are Library's own.
public struct ToneSettings: Hashable, Codable, Sendable {
    /// The sliders off neutral; a neutral slider is never stored, so equal settings compare equal.
    private var values: [ToneSlider: Double] = [:]
    /// Every slider at its neutral value.
    public static let neutral = ToneSettings()
    public init() {}
    /// The slider's value, its neutral when unset.
    public func value(_ s: ToneSlider) -> Double { values[s] ?? s.neutral }
    /// A copy with `s` at `v`. Stub: TC-7 clamps `v` to the range and keeps the old value for NaN.
    public func setting(_ s: ToneSlider, to v: Double) -> ToneSettings {
        var copy = self
        copy.values[s] = v == s.neutral ? nil : v
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
}

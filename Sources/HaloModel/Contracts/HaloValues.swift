// Contracts/HaloValues.swift: the key values every Halo contract speaks
// (properties, keys, easing presets, text); the document values and the
// refusal types sit in HaloDocumentValues.swift. Linux-safe.
// FlareCore's keyframe, easing, matrix and point are used as they are (never
// mirrored), under Halo names so HaloApp never has to import FlareCore, whose
// Path and Color clash with SwiftUI's.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore

public typealias HaloKeyframe = FlareCore.Keyframe
public typealias HaloEasing = FlareCore.Easing
public typealias HaloMatrix = FlareCore.Matrix
public typealias HaloPoint = FlareCore.Point

/// An animatable layer property. The raw value is the track key in
/// `HaloLayer.tracks`; x, y, scaleX, scaleY, rotation and opacity are the
/// names FlareCore's `Layer.sample` uses, anchorX and anchorY are Halo's own.
public enum HaloProperty: String, CaseIterable, Codable, Sendable {
    case x, y, scaleX, scaleY, rotation, opacity, anchorX, anchorY

    /// The inspector row's label.
    public var title: String {
        switch self {
        case .x: "Position X"
        case .y: "Position Y"
        case .scaleX: "Scale X"
        case .scaleY: "Scale Y"
        case .rotation: "Rotation"
        case .opacity: "Opacity"
        case .anchorX: "Anchor X"
        case .anchorY: "Anchor Y"
        }
    }

    /// The values a row accepts; a write outside is clamped, never refused.
    public var range: ClosedRange<Double> {
        switch self {
        case .x, .y, .anchorX, .anchorY: -100_000...100_000
        case .scaleX, .scaleY: -100...100
        case .rotation: -36_000...36_000
        case .opacity: 0...1
        }
    }

    /// One arrow-key step; Shift is ten, Option a tenth (ScrubField's rule).
    public var step: Double {
        switch self {
        case .x, .y, .anchorX, .anchorY, .rotation: 1
        case .scaleX, .scaleY, .opacity: 0.01
        }
    }

    /// What the row shows per stored unit: scale and opacity are stored as
    /// factors (1 = 100%) and shown in percent.
    public var displayFactor: Double {
        switch self {
        case .scaleX, .scaleY, .opacity: 100
        case .x, .y, .anchorX, .anchorY, .rotation: 1
        }
    }

    /// The unit `InspectorSliderRow` shows after the value.
    public var unit: String {
        switch self {
        case .x, .y, .anchorX, .anchorY: " px"
        case .scaleX, .scaleY, .opacity: "%"
        case .rotation: "°"
        }
    }

    /// Places shown: one for pixels, whole for percent and degrees
    /// (docs/design.md, Editor shell).
    public var decimals: Int {
        switch self {
        case .x, .y, .anchorX, .anchorY: 1
        case .scaleX, .scaleY, .opacity, .rotation: 0
        }
    }

    /// The stored value for what a person typed in the row ("45", "45°",
    /// " 50 %"): the number before the unit, divided by `displayFactor`. Nil
    /// when it isn't a number, so the row keeps its value and says why.
    public func parse(_ text: String) -> Double? {
        let trimmed = text.filter { !$0.isWhitespace }
        let number = trimmed.hasSuffix(unit.filter { !$0.isWhitespace })
            ? String(trimmed.dropLast(unit.filter { !$0.isWhitespace }.count)) : trimmed
        guard let value = Double(number), value.isFinite else { return nil }
        return value / displayFactor
    }

    /// The value as the row shows it and VoiceOver reads it: "960.0 px",
    /// "100%", "45°"; "–" for a value that isn't finite.
    public func text(_ value: Double) -> String {
        guard value.isFinite else { return "–" }
        let shown = value * displayFactor
        if decimals == 0 { return "\(Int(shown.rounded()))\(unit)" }
        return "\((shown * 10).rounded() / 10)\(unit)"
    }
}

/// Whether a property is animated, and whether a key sits at the playhead.
/// HaloApp maps it one to one onto SuiteUI's `KeyState`.
public enum HaloKeyState: Sendable, Hashable {
    /// No track, or a track with one key: the value is that key's.
    case notAnimated
    /// Two or more keys, none at the playhead.
    case animated
    /// Two or more keys and one at the playhead.
    case keyedHere
}

/// One inspector row: a property of the selected layer at the playhead.
public struct HaloPropertyRow: Identifiable, Sendable, Hashable {
    public var id: HaloProperty { property }
    public var property: HaloProperty
    public var value: Double
    public var text: String
    public var keyState: HaloKeyState
    public init(property: HaloProperty, value: Double, text: String, keyState: HaloKeyState) {
        self.property = property; self.value = value; self.text = text; self.keyState = keyState
    }
}

/// One key: which layer, which property, which frame.
public struct HaloKeyRef: Hashable, Sendable, Codable {
    public var layerID: String
    public var property: HaloProperty
    public var frame: Int
    public init(layerID: String, property: HaloProperty, frame: Int) {
        self.layerID = layerID; self.property = property; self.frame = frame
    }
}

/// The easing presets the menu, the chips and the timeline diamonds name.
/// Each is FlareCore's own `Easing` value; a curve matching none is custom.
public enum HaloEasingPreset: String, CaseIterable, Sendable {
    case linear, easeIn, easeOut, easeInOut, hold

    public var title: String {
        switch self {
        case .linear: "Linear"
        case .easeIn: "Ease In"
        case .easeOut: "Ease Out"
        case .easeInOut: "Ease In and Out"
        case .hold: "Hold"
        }
    }

    public var easing: HaloEasing {
        switch self {
        case .linear: .linear
        case .easeIn: .easeIn
        case .easeOut: .easeOut
        case .easeInOut: .easeInOut
        case .hold: .hold
        }
    }

    /// The preset `easing` equals; nil for a custom curve.
    public init?(_ easing: HaloEasing) {
        guard let match = Self.allCases.first(where: { $0.easing == easing }) else { return nil }
        self = match
    }
}

/// A text layer's words and size (tier 2, #430). Color is the layer's.
/// `width` and `height` are the line box `TextRasterizing.measure` gave when
/// the words or size last changed (HaloTextEdits sets them through
/// `services.text`), so the viewer, hit testing, the default anchor and the
/// rendered pixels all use one box, and a saved file keeps its layout.
public struct HaloTextContent: Codable, Sendable, Hashable {
    public var string: String
    /// In composition pixels.
    public var fontSize: Double
    /// The measured line box; an estimate (0.6 em a character) until measured.
    public var width: Double
    public var height: Double
    public init(string: String = "Text", fontSize: Double = 72, width: Double? = nil, height: Double? = nil) {
        self.string = string; self.fontSize = fontSize
        self.width = width ?? fontSize * 0.6 * Double(max(string.count, 1))
        self.height = height ?? fontSize
    }
}

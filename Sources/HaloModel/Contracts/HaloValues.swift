// Contracts/HaloValues.swift: the key values every Halo contract speaks
// (properties, keys, easing presets, text) and the edit, refusal and file
// errors; the document values sit in HaloDocumentValues.swift. Linux-safe.
// FlareCore's keyframe, easing, matrix and point are used as they are (never
// mirrored), under Halo names so HaloApp never has to import FlareCore, whose
// Path and Color clash with SwiftUI's.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
import SuiteKernel

public typealias HaloKeyframe = FlareCore.Keyframe
public typealias HaloEasing = FlareCore.Easing
public typealias HaloMatrix = FlareCore.Matrix
public typealias HaloPoint = FlareCore.Point

/// An animatable layer property. The raw value is the track key in
/// `HaloLayer.tracks`; x, y, scaleX, scaleY, rotation and opacity are the
/// names FlareCore's `Layer.sample` uses, anchorX and anchorY are Halo's own.
/// trimStart, trimEnd and trimOffset (HK-5) are a shape's stroke trim:
/// fractions of the outline, the offset in turns. The five style values (layer-styles HY-1) are a drop
/// shadow's distance, size and opacity and an outer glow's size and opacity, keyed like opacity.
public enum HaloProperty: String, CaseIterable, Codable, Sendable {
    case x, y, scaleX, scaleY, rotation, opacity, anchorX, anchorY
    case trimStart, trimEnd, trimOffset
    case shadowDistance, shadowSize, shadowOpacity, glowSize, glowOpacity

    /// The transform rows the inspector, the timeline and `key.*` list; the
    /// trims key through the stroke editor (`trims`), so they are left out.
    public static let allCases: [HaloProperty] = [.x, .y, .scaleX, .scaleY, .rotation, .opacity, .anchorX, .anchorY]

    /// A stroke's trim, keyed like position (HK-5).
    public static let trims: [HaloProperty] = [.trimStart, .trimEnd, .trimOffset]

    /// A layer style's keyable values (HY-1); their rows show only while the layer has that effect.
    public static let styles: [HaloProperty] = [.shadowDistance, .shadowSize, .shadowOpacity, .glowSize, .glowOpacity]

    /// What `key.*`, the property commands, the lane and the easing pick list: the transforms, then the styles.
    public static let keyable: [HaloProperty] = allCases + styles

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
        case .trimStart: "Trim Start"
        case .trimEnd: "Trim End"
        case .trimOffset: "Trim Offset"
        case .shadowDistance: "Shadow Distance"
        case .shadowSize: "Shadow Size"
        case .shadowOpacity: "Shadow Opacity"
        case .glowSize: "Glow Size"
        case .glowOpacity: "Glow Opacity"
        }
    }

    /// The values a row accepts; a write outside is clamped, never refused.
    public var range: ClosedRange<Double> {
        switch self {
        case .x, .y, .anchorX, .anchorY: -100_000...100_000
        case .scaleX, .scaleY: -100...100
        case .rotation: -36_000...36_000
        case .opacity, .trimStart, .trimEnd, .shadowOpacity, .glowOpacity: 0...1
        case .trimOffset: -100...100
        case .shadowDistance: 0...1_000
        case .shadowSize, .glowSize: 0...250
        }
    }

    /// One arrow-key step; Shift is ten, Option a tenth (ScrubField's rule).
    public var step: Double {
        switch self {
        case .x, .y, .anchorX, .anchorY, .rotation, .shadowDistance, .shadowSize, .glowSize: 1
        case .scaleX, .scaleY, .opacity, .trimStart, .trimEnd, .shadowOpacity, .glowOpacity: 0.01
        case .trimOffset: 1.0 / 360
        }
    }

    /// What the row shows per stored unit: scale and opacity are stored as
    /// factors (1 = 100%) and shown in percent.
    public var displayFactor: Double {
        switch self {
        case .scaleX, .scaleY, .opacity, .trimStart, .trimEnd, .shadowOpacity, .glowOpacity: 100
        case .x, .y, .anchorX, .anchorY, .rotation, .shadowDistance, .shadowSize, .glowSize: 1
        case .trimOffset: 360
        }
    }

    /// The unit `InspectorSliderRow` shows after the value.
    public var unit: String {
        switch self {
        case .x, .y, .anchorX, .anchorY, .shadowDistance, .shadowSize, .glowSize: " px"
        case .scaleX, .scaleY, .opacity, .trimStart, .trimEnd, .shadowOpacity, .glowOpacity: "%"
        case .rotation, .trimOffset: "°"
        }
    }

    /// Places shown: one for pixels, whole for percent and degrees
    /// (docs/design.md, Editor shell).
    public var decimals: Int {
        switch self {
        case .x, .y, .anchorX, .anchorY, .shadowDistance, .shadowSize, .glowSize: 1
        case .scaleX, .scaleY, .opacity, .rotation, .trimStart, .trimEnd, .trimOffset, .shadowOpacity, .glowOpacity: 0
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

/// Why an edit was refused. `message` is the text the window shows.
public enum HaloEditError: Error, Sendable, Hashable {
    case noComposition
    case noLayerSelected
    case unknownLayer(String)
    case notANumber(HaloProperty)
    /// The layer's name, for the message.
    case parentCycle(String)
    case inPointAfterOut
    case outPointBeforeIn
    case emptyName
    case emptyText
    case noKeySelected
    case notBuilt(String)
    /// A refusal already in words, such as ExportRules' sentence for alpha on H.264.
    case refused(String)

    public var message: String {
        switch self {
        case .noComposition: "Create a composition first."
        case .noLayerSelected: "Select a layer first."
        case .unknownLayer: "That layer no longer exists."
        case .notANumber(let p): "\(p.title) needs a number."
        case .parentCycle(let name): "\(name) can't follow a layer that follows it."
        case .inPointAfterOut: "The in point must come before the out point."
        case .outPointBeforeIn: "The out point must come after the in point."
        case .emptyName: "Enter a name."
        case .emptyText: "Enter some text."
        case .noKeySelected: "Pick a key in the EASING list first."
        case .notBuilt(let what): "\(what) isn't built yet."
        case .refused(let sentence): sentence
        }
    }
}

/// A refused edit, kept until the next edit or a dismissal, with the
/// control that refused it so the window shows the message under that row.
public struct HaloRefusal: Sendable, Hashable {
    /// The refusing control's identifier ("halo.inspector.row.rotation").
    public var control: String
    public var message: String
    public init(control: String, message: String) { self.control = control; self.message = message }
}

/// Why a project file didn't open. The open project stays as it was.
public enum HaloFileError: Error, Sendable, Hashable {
    case notAHaloFile
    case newerVersion(Int)
    case damaged(String)
    case tooLarge

    public var message: String {
        switch self {
        case .notAHaloFile: "This file isn't a Halo project."
        case .newerVersion(let v): "This project was saved by a newer Halo (format \(v)). Update Halo to open it."
        case .damaged(let detail): "This project is damaged: \(detail)."
        case .tooLarge: "This project is larger than Halo can open (64 MB)."
        }
    }
}

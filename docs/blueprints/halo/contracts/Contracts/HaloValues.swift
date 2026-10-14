// Contracts/HaloValues.swift: the value types every Halo contract speaks.
// Linux-safe. FlareCore's keyframe, easing, matrix and point are used as they
// are (never mirrored), under Halo names so HaloApp never has to import
// FlareCore, whose Path and Color clash with SwiftUI's.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
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

/// One layer as the viewer and the renderer draw it at a frame.
public struct HaloDrawItem: Sendable, Hashable {
    public var layerID: String
    public var kind: HaloLayerKind
    /// The layer's own box in layer space: a solid's rectangle (the whole
    /// composition when it has none), a shape's ellipse box, a text's line box.
    public var bounds: HaloLayerRect
    /// Layer space to composition space, parents included.
    public var matrix: HaloMatrix
    /// 0...1, the layer's own sampled opacity (parents don't pass it on).
    public var opacity: Double
    public var color: HaloLayerColor
    public var blendMode: BlendMode
    /// The words of a text layer; nil otherwise.
    public var text: HaloTextContent?
    public init(
        layerID: String, kind: HaloLayerKind, bounds: HaloLayerRect, matrix: HaloMatrix, opacity: Double,
        color: HaloLayerColor, blendMode: BlendMode, text: HaloTextContent? = nil
    ) {
        self.layerID = layerID; self.kind = kind; self.bounds = bounds; self.matrix = matrix
        self.opacity = opacity; self.color = color; self.blendMode = blendMode; self.text = text
    }
}

/// What one frame of a composition draws, bottom layer first. Nulls and
/// layers outside their in and out points are absent.
public struct HaloDrawList: Sendable, Hashable {
    public var width: Int
    public var height: Int
    public var frame: Int
    public var items: [HaloDrawItem]
    public init(width: Int, height: Int, frame: Int, items: [HaloDrawItem]) {
        self.width = width; self.height = height; self.frame = frame; self.items = items
    }

    /// The list with one layer moved by `delta` composition pixels: the live
    /// preview of a viewer drag before mouse-up. Other layers are untouched.
    public func offsetting(_ layerID: String, by delta: HaloPoint) -> HaloDrawList {
        var copy = self
        for i in copy.items.indices where copy.items[i].layerID == layerID {
            copy.items[i].matrix = HaloMatrix.translation(x: delta.x, y: delta.y) * copy.items[i].matrix
        }
        return copy
    }
}

/// The document part of a project: what undo restores and a file holds.
/// Selection rides along so undo puts it back; the playhead lives in each
/// composition and is restored with it.
public struct HaloDocumentState: Codable, Sendable, Hashable {
    public var compositions: [HaloComposition]
    public var selectedCompositionID: String?
    public var selectedLayerID: String?
    /// The number in the next composition id; only goes up.
    public var nextCompositionNumber: Int
    /// The number in the next layer id ("comp-1-layer-7"); only goes up, so a
    /// deleted or duplicated layer never makes two layers share an id.
    public var nextLayerNumber: Int
    public init(
        compositions: [HaloComposition] = [], selectedCompositionID: String? = nil, selectedLayerID: String? = nil,
        nextCompositionNumber: Int = 1, nextLayerNumber: Int = 1
    ) {
        self.compositions = compositions; self.selectedCompositionID = selectedCompositionID
        self.selectedLayerID = selectedLayerID; self.nextCompositionNumber = nextCompositionNumber
        self.nextLayerNumber = nextLayerNumber
    }
}

/// One undo step: its name ("New Layer") and the document before it.
public struct HaloHistoryEntry: Sendable, Hashable {
    public var name: String
    public var before: HaloDocumentState
    /// Steps with the same non-nil key in a row share one entry (a scrub).
    public var coalesceKey: String?
    public init(name: String, before: HaloDocumentState, coalesceKey: String? = nil) {
        self.name = name; self.before = before; self.coalesceKey = coalesceKey
    }
}

/// Undo and redo stacks, newest last. Only a `ProjectHistory` changes them.
public struct HaloHistory: Sendable, Hashable {
    public var undo: [HaloHistoryEntry]
    public var redo: [HaloHistoryEntry]
    public init(undo: [HaloHistoryEntry] = [], redo: [HaloHistoryEntry] = []) {
        self.undo = undo; self.redo = redo
    }
    /// "Undo New Layer"; nil when there is nothing to undo.
    public var undoTitle: String? { undo.last.map { "Undo \($0.name)" } }
    /// "Redo New Layer"; nil when there is nothing to redo.
    public var redoTitle: String? { redo.last.map { "Redo \($0.name)" } }
}

/// Where playback is after a tick.
public struct HaloPlaybackTick: Sendable, Hashable {
    public var frame: Int
    /// True once play-once has shown the last frame; the window stops then.
    public var ended: Bool
    public init(frame: Int, ended: Bool) { self.frame = frame; self.ended = ended }
}

/// What Render… writes (tier 2, #429).
public struct HaloRenderSettings: Sendable, Hashable {
    public enum Format: String, CaseIterable, Sendable { case pngSequence, movie }
    public var format: Format
    /// Half size: width and height halved, then rounded down to even (movie
    /// encoders need even sizes), at least 2. The plan carries the pixel size.
    public var halfSize: Bool
    public init(format: Format, halfSize: Bool = false) { self.format = format; self.halfSize = halfSize }
}

/// The frames one render writes and what each is called.
public struct HaloRenderPlan: Sendable, Hashable {
    public var width: Int
    public var height: Int
    public var framesPerSecond: Int
    /// Composition frames in order, 0 through the last.
    public var frames: [Int]
    /// "Intro_0001.png" for each frame of a PNG sequence; one "Intro.mp4" for a movie.
    public var fileNames: [String]
    public init(width: Int, height: Int, framesPerSecond: Int, frames: [Int], fileNames: [String]) {
        self.width = width; self.height = height; self.framesPerSecond = framesPerSecond
        self.frames = frames; self.fileNames = fileNames
    }
}

/// How a render ended.
public enum HaloRenderOutcome: Sendable, Hashable {
    case finished(frames: Int)
    /// Stopped by Cancel after writing `frames` frames.
    case cancelled(frames: Int)
    case failed(frame: Int, message: String)
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

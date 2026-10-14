// AnimateContracts.swift: inspector rows, timeline, easing and onion (blueprint
// flare.md, 6.2). Its `EasingEditing` is `KeyframeEasing` here, since
// EasingEditing.swift owns that name; both share its `EasingPreset` enum.
import FlareCore

public enum KeyState: Hashable, Sendable {
    case notAnimated       // no track or one key (section 2); stopwatch idle
    case animated          // two or more keys, none at the playhead
    case keyedHere         // two or more keys, one at the playhead
}

public struct AnimatedProperty: Hashable, Sendable {
    public var name: String            // "x", "y", "scaleX", "scaleY", "rotation", "opacity"
    public var title: String           // "X", "Rotation"
    public var value: Double?          // nil = "Mixed" across a multi-selection
    public var range: ClosedRange<Double>
    public var unit: String            // "pt", "×", "°", "%"
    public var decimals: Int
    public var keyState: KeyState
    public init(name: String, title: String, value: Double?, range: ClosedRange<Double>,
                unit: String, decimals: Int, keyState: KeyState) {
        self.name = name; self.title = title; self.value = value; self.range = range
        self.unit = unit; self.decimals = decimals; self.keyState = keyState
    }
}

public protocol PropertyAnimating: Sendable {
    func properties(_ document: Document, owner: LayerOwner, layerIDs: [String],
                    frame: Int) -> [AnimatedProperty]
    /// Coalescible. Sets `value` of one property on each layer at `frame` by the
    /// rule in section 2: a not-animated property edits its one key (or adds a key
    /// at the playhead when `autoKey` is on); an animated one keys the playhead.
    func setValue(_ value: Double, of property: String, owner: LayerOwner, layerIDs: [String],
                  frame: Int, autoKey: Bool, coalesceKey: String?,
                  in engine: inout CommandEngine) throws
    /// Grouped "Animate <Title>" or "Stop Animating <Title>" (section 2's stopwatch rule).
    func toggleAnimated(_ property: String, owner: LayerOwner, layerID: String, frame: Int,
                        lastFrame: Int, in engine: inout CommandEngine) throws
    /// Single: adds or removes the key at `frame`.
    func toggleKey(_ property: String, owner: LayerOwner, layerID: String, frame: Int,
                   in engine: inout CommandEngine) throws
    /// Grouped "Set Fill". Applies to every shape of the selected layers, or to the
    /// direct-selected items.
    func setFill(_ fill: Fill, of items: [StageAddress], in engine: inout CommandEngine) throws
    /// Grouped "Set Stroke".
    func setStroke(_ stroke: Stroke?, of items: [StageAddress], in engine: inout CommandEngine) throws
}

public struct KeyRef: Hashable, Sendable {
    public var layerID: String
    public var property: String?       // nil = the layer's summary key (every track at that frame)
    public var frame: Int
    public init(layerID: String, property: String?, frame: Int) {
        self.layerID = layerID; self.property = property; self.frame = frame
    }
}

public struct TimelineRow: Hashable, Sendable {
    public var layerID: String
    public var name: String
    public var isVisible: Bool, isLocked: Bool
    public var keyFrames: [Int]                  // summary diamonds
    public var segments: [ClosedRange<Int>]      // tweens between keys
    public var easedSegments: [Int: Easing]      // start frame -> easing
    public init(layerID: String, name: String, isVisible: Bool, isLocked: Bool, keyFrames: [Int],
                segments: [ClosedRange<Int>], easedSegments: [Int: Easing]) {
        self.layerID = layerID; self.name = name; self.isVisible = isVisible; self.isLocked = isLocked
        self.keyFrames = keyFrames; self.segments = segments; self.easedSegments = easedSegments
    }
}

public protocol KeyframeEditing: Sendable {
    func rows(_ document: Document, owner: LayerOwner) -> [TimelineRow]
    func labels(_ document: Document, sceneID: String) -> [String: Int]
    /// Coalescible. Throws, changing nothing, when a key would land on another key.
    func moveKeys(_ keys: Set<KeyRef>, by delta: Int, owner: LayerOwner,
                  coalesceKey: String?, in engine: inout CommandEngine) throws
    /// Grouped "Delete Keyframe".
    func removeKeys(_ keys: Set<KeyRef>, owner: LayerOwner, in engine: inout CommandEngine) throws
    /// Single ("Insert Frame"). Grows the scene when a shifted key would pass its last frame.
    func insertFrames(_ count: Int, at frame: Int, layerIDs: [String], owner: LayerOwner,
                      in engine: inout CommandEngine) throws
    /// Single ("Remove Frame").
    func removeFrames(_ count: Int, at frame: Int, layerIDs: [String], owner: LayerOwner,
                      in engine: inout CommandEngine) throws
    /// Single. A nil name removes the label at `frame`.
    func setLabel(_ name: String?, at frame: Int, sceneID: String, in engine: inout CommandEngine) throws
}

/// Easing on the segment that starts at a key.
public protocol KeyframeEasing: Sendable {
    var presets: [EasingPreset] { get }
    /// `count` points of the curve in 0...1 time, for drawing the editor.
    func curve(_ easing: Easing, count: Int) -> [Point]
    /// Coalescible.
    func setEasing(_ easing: Easing, at key: KeyRef, owner: LayerOwner,
                   coalesceKey: String?, in engine: inout CommandEngine) throws
}

public struct OnionSettings: Hashable, Sendable {
    public var isOn: Bool
    public var before: Int, after: Int
    public var falloff: Double
    public init(isOn: Bool = false, before: Int = 2, after: Int = 2, falloff: Double = 0.5) {
        self.isOn = isOn; self.before = before; self.after = after; self.falloff = falloff
    }
}

public struct Ghost: Equatable, Sendable {
    public enum Side: Hashable, Sendable { case before, after }
    public var frame: Int
    public var side: Side
    public var opacity: Double
    public var items: [StageItem]
    public init(frame: Int, side: Side, opacity: Double, items: [StageItem]) {
        self.frame = frame; self.side = side; self.opacity = opacity; self.items = items
    }
}

public protocol OnionSkinning: Sendable {
    /// Honors `settings.before`, `.after` and `.falloff` exactly (the fake too).
    func ghosts(_ document: Document, sceneID: String, layerIDs: [String], frame: Int,
                settings: OnionSettings) -> [Ghost]
    /// Positions of the layer's origin for every frame, for the dotted path and ticks.
    func motionPath(_ document: Document, owner: LayerOwner, layerID: String) -> [Point]
}

// Contracts/HaloContracts.swift: one protocol per Halo use case, so the
// views (on the fakes) and the logic (the live types) are built in parallel.
// Reads take values; writes take the composition `inout` and throw
// `HaloEditError`, leaving it unchanged when they throw. None of them records
// undo: HaloProject wraps each write in `edit(_:coalesceKey:_:)`, which hands
// the state before it to `ProjectHistory`. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

/// What every service shares: whether its controls can act yet.
public protocol HaloService: Sendable {
    /// Nil once the use case works; otherwise the tooltip of every control
    /// that needs it, which stays disabled (CLAUDE.md, no dead controls).
    var unavailableHelp: String? { get }
}

extension HaloService {
    public var unavailableHelp: String? { nil }
}

/// #37: the viewer's picture of a composition at a frame.
public protocol FrameDrawing: HaloService {
    /// Every layer visible at `frame`, bottom first, at its sampled transform
    /// through its parents. Nulls never appear; a layer in a parent cycle
    /// draws as if it had no parent.
    func drawList(_ composition: HaloComposition, at frame: Int) -> HaloDrawList
}

/// #38: where a layer is at a frame, through its parents.
public protocol LayerPlacing: HaloService {
    /// The property's value at `frame`: its track sampled with FlareCore's
    /// `Timeline.value(of:at:)`, or the layer's default with no track. Nil for
    /// an unknown layer.
    func value(_ property: HaloProperty, of layerID: String, in composition: HaloComposition, at frame: Int) -> Double?
    /// Layer space to composition space, parents applied outermost last. Nil
    /// for an unknown layer.
    func worldMatrix(of layerID: String, in composition: HaloComposition, at frame: Int) -> HaloMatrix?
    /// The layers `layerID` may follow: every other layer except those that
    /// already follow it, in timeline order.
    func parentCandidates(for layerID: String, in composition: HaloComposition) -> [String]
}

/// #38: the inspector's TRANSFORM rows, the stopwatch and the key diamond.
public protocol PropertyKeying: HaloService {
    /// One row per property in `HaloProperty.allCases` order; empty for an
    /// unknown layer.
    func rows(for layerID: String, in composition: HaloComposition, at frame: Int) -> [HaloPropertyRow]
    /// Not animated: sets the one value (key at frame 0, or the static value).
    /// Animated: writes a key at `frame`. NaN or infinity throws
    /// `.notANumber`; other values clamp to `property.range`.
    func setValue(
        _ value: Double, for property: HaloProperty, of layerID: String, at frame: Int,
        in composition: inout HaloComposition) throws
    /// The stopwatch. Off to on: keys at `frame` and at the last frame with
    /// the current value (so the row turns animated). On to off: drops the
    /// track and keeps the value at `frame`.
    func toggleAnimation(
        _ property: HaloProperty, of layerID: String, at frame: Int, in composition: inout HaloComposition) throws
    /// The diamond: adds a key at `frame` with the sampled value, or removes
    /// the one there. A track left with one key is not animated.
    func toggleKey(
        _ property: HaloProperty, of layerID: String, at frame: Int, in composition: inout HaloComposition) throws
    /// Parent picker. Nil clears it. A cycle throws `.parentCycle`. The child
    /// keeps its place on screen at `frame` (its position is rewritten in the
    /// parent's space).
    func setParent(
        _ parentID: String?, of layerID: String, at frame: Int, in composition: inout HaloComposition) throws
}

/// #207: drag a layer in the viewer to key its position.
public protocol ViewerDragging: HaloService {
    /// The topmost layer under `point` (composition pixels) that draws at
    /// `frame`. Nulls are never hit; nil over empty space.
    func hit(_ composition: HaloComposition, at frame: Int, point: HaloPoint) -> String?
    /// Mouse-up: moves the layer by `delta` in composition pixels, writing
    /// its x and y through `PropertyKeying`'s rule (keys when animated). A
    /// zero delta changes nothing and does not throw.
    func commitMove(
        _ layerID: String, by delta: HaloPoint, at frame: Int, in composition: inout HaloComposition) throws
}

/// #428: ease keys.
public protocol KeyEasing: HaloService {
    /// Every key of the layer, by property then frame: the timeline's diamonds.
    func keys(of layerID: String, in composition: HaloComposition) -> [HaloKeyRef]
    /// The easing from `key` to the next key; nil when the key doesn't exist.
    func easing(of key: HaloKeyRef, in composition: HaloComposition) -> HaloEasing?
    /// Sets `easing` on every key in `keys`. Empty throws `.noKeySelected`;
    /// a key that doesn't exist throws `.unknownLayer` and changes nothing.
    func setEasing(_ easing: HaloEasing, on keys: Set<HaloKeyRef>, in composition: inout HaloComposition) throws
}

/// #208: undo and redo of whole-document steps.
public protocol ProjectHistory: HaloService {
    /// How many steps undo keeps; the oldest drops past it.
    var limit: Int { get }
    /// Adds a step named `name` whose undo returns `before`, and clears redo.
    /// With a non-nil `coalesceKey` equal to the newest step's, the newest
    /// step keeps its own `before` and nothing is added.
    func record(_ name: String, before: HaloDocumentState, coalesceKey: String?, in history: inout HaloHistory)
    /// The state to return to, moving the step onto redo with `current`.
    /// Nil when there is nothing to undo.
    func undo(_ current: HaloDocumentState, in history: inout HaloHistory) -> HaloDocumentState?
    /// The state to go forward to, moving the step back onto undo. Nil when
    /// there is nothing to redo.
    func redo(_ current: HaloDocumentState, in history: inout HaloHistory) -> HaloDocumentState?
}

/// #209: the project file.
public protocol ProjectFiles: HaloService {
    /// JSON with sorted keys and `"format": "halo"`, `"version": 1`.
    func encode(_ state: HaloDocumentState) throws -> Data
    /// Checks everything `encode` promises (unique composition ids and
    /// names, in point before out point, sizes and rates in range, sorted
    /// unique keys, no parent cycle) and throws `HaloFileError` otherwise.
    func decode(_ data: Data) throws -> HaloDocumentState
}

/// #37: which frame to show while playing.
public protocol PlaybackClock: HaloService {
    /// The frame `elapsed` seconds after play began on `startFrame`. Loop
    /// wraps to 0; play-once stops on the last frame with `ended` true.
    func tick(
        startFrame: Int, elapsed: Double, framesPerSecond: Int, durationFrames: Int, loops: Bool) -> HaloPlaybackTick
}

/// #451, #430: a frame as pixels (CoreRaster), the reference the viewer and
/// every rendered file must match.
public protocol FrameRendering: HaloService {
    /// Renders `list` at 1/`scale` size (1 = full). `text` draws text layers;
    /// with nil they are skipped and counted in `skippedLayerCount`.
    func render(_ list: HaloDrawList, scale: Int, text: (any TextRasterizing)?) throws -> HaloRenderedFrame
}

/// #430: words to pixels. HaloApp supplies the CoreText one; tests use a fake.
public protocol TextRasterizing: Sendable {
    /// The text in `color` on a transparent buffer just big enough for it,
    /// linear light, premultiplied; its (0, 0) is the line box's top left.
    func rasterize(_ text: HaloTextContent, color: HaloLayerColor) throws -> PixelBuffer
}

/// #429: where rendered frames go. HaloApp supplies the PNG and movie writers.
public protocol RenderSink {
    mutating func begin(_ plan: HaloRenderPlan) throws
    mutating func write(_ frame: HaloRenderedFrame, named fileName: String) throws
    /// Called once, after the last frame or on cancel (`cancelled` true),
    /// when the sink removes a partly written movie.
    mutating func finish(cancelled: Bool) throws
}

/// #429: render a whole composition to files.
public protocol CompositionRendering: HaloService {
    /// The frames and names for `settings`. Throws `.noComposition` for a
    /// composition with no frames.
    func plan(_ composition: HaloComposition, settings: HaloRenderSettings) throws -> HaloRenderPlan
    /// Sends every planned frame to `sink` in order, checking `isCancelled`
    /// before each one. A sink error stops at that frame.
    func run(
        _ plan: HaloRenderPlan, of composition: HaloComposition, into sink: inout some RenderSink,
        isCancelled: () -> Bool
    ) -> HaloRenderOutcome
}

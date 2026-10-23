// Contracts/HaloDocumentValues.swift: the document values every Halo contract
// speaks: what a frame draws, the document undo restores and a file holds,
// an undo entry, a playback tick and the render settings, plan and outcome.
// The key values and the refusal types sit in HaloValues.swift; the undo
// stacks, on the kernel's History, in HaloHistory+Kernel.swift. Linux-safe.
import CoreRaster
import FlareCore
import SuiteKernel

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
    /// HG-1: the layer's gradient in a unit box over `bounds`; nil fills
    /// `color`. HaloDrawRules carries it from the layer (HG-6).
    public var gradient: Fill?
    /// HS-5: a shape layer's spec, drawn in `bounds`; nil keeps the ellipse.
    public var shape: ShapeSpec?
    /// HK-5: a shape layer's stroke, its trim sampled at the frame; nil draws none.
    public var stroke: VectorStroke?
    /// PH-1: a solid's picture and its box and focus; nil draws `color`. HaloDrawRules fills them in PH-5.
    public var placedAsset: PlacedAsset?
    public var placedImage: PlacedImage?
    public init(
        layerID: String, kind: HaloLayerKind, bounds: HaloLayerRect, matrix: HaloMatrix, opacity: Double,
        color: HaloLayerColor, blendMode: BlendMode, text: HaloTextContent? = nil, gradient: Fill? = nil,
        shape: ShapeSpec? = nil, stroke: VectorStroke? = nil, placedAsset: PlacedAsset? = nil, placedImage: PlacedImage? = nil
    ) {
        self.layerID = layerID; self.kind = kind; self.bounds = bounds; self.matrix = matrix
        self.opacity = opacity; self.color = color; self.blendMode = blendMode; self.text = text
        self.gradient = gradient; self.shape = shape; self.stroke = stroke
        self.placedAsset = placedAsset; self.placedImage = placedImage
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
    /// The exact rate each frame is timed by (`seconds(ofFrame:)`); `framesPerSecond` is its whole rate.
    public var frameRate: FrameRate
    /// Composition frames in order, 0 through the last.
    public var frames: [Int]
    /// "Intro_0001.png" for each frame of a PNG sequence; one "Intro.mp4" for a movie.
    public var fileNames: [String]
    public init(width: Int, height: Int, framesPerSecond: Int, frameRate: FrameRate? = nil, frames: [Int], fileNames: [String]) {
        self.width = width; self.height = height; self.framesPerSecond = framesPerSecond
        self.frameRate = frameRate ?? FrameRate(whole: framesPerSecond)
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

// StageContracts.swift: the shared contract values and the stage's draw and
// hit contracts (docs/blueprints/flare.md, sections 6.1 and 6.2).
import FlareCore

/// Where a stage item lives: the layer list, the layer, the item, and the
/// instance indices walked from the scene layer down to it.
public struct StageAddress: Hashable, Sendable {
    public enum Item: Hashable, Sendable { case shape(Int), text(Int), instance(Int) }
    public var owner: LayerOwner
    public var layerID: String
    public var item: Item
    public var instancePath: [Int]
    public init(owner: LayerOwner, layerID: String, item: Item, instancePath: [Int] = []) {
        self.owner = owner; self.layerID = layerID; self.item = item; self.instancePath = instancePath
    }
}

/// One thing to draw, in scene space (y-down, like the exporters).
/// Text items are listed (so counts and warnings see them) but carry an empty path in v1.
public struct StageItem: Equatable, Sendable {
    public var address: StageAddress
    public var path: FlarePath          // curves kept; never flattened for drawing
    public var fill: Fill?, stroke: Stroke?
    public var transform: Matrix
    public var opacity: Double          // 0...1, already multiplied down the instance chain
    public var isText: Bool
    public init(address: StageAddress, path: FlarePath, fill: Fill?, stroke: Stroke?,
                transform: Matrix, opacity: Double, isText: Bool = false) {
        self.address = address; self.path = path; self.fill = fill; self.stroke = stroke
        self.transform = transform; self.opacity = opacity; self.isText = isText
    }
}

public struct StageDrawList: Equatable, Sendable {
    public var width: Double, height: Double
    public var background: FlareColor
    public var items: [StageItem]       // paint order, bottom first
    public var hiddenTextCount: Int     // drives the "Text not shown (n)" pill
    public init(width: Double, height: Double, background: FlareColor,
                items: [StageItem], hiddenTextCount: Int = 0) {
        self.width = width; self.height = height; self.background = background
        self.items = items; self.hiddenTextCount = hiddenTextCount
    }
}

public struct DragModifiers: OptionSet, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let shift = DragModifiers(rawValue: 1)    // constrain
    public static let option = DragModifiers(rawValue: 2)   // from center, break handles
}

public struct CanvasPreset: Hashable, Sendable {
    public var name: String
    public var width: Double, height: Double
    public var fps: Int, durationFrames: Int
    public init(name: String, width: Double, height: Double, fps: Int, durationFrames: Int) {
        self.name = name; self.width = width; self.height = height
        self.fps = fps; self.durationFrames = durationFrames
    }
    public static let hd1080 = CanvasPreset(name: "1080p 16:9", width: 1920, height: 1080, fps: 24, durationFrames: 120)
    public static let square = CanvasPreset(name: "Square", width: 1080, height: 1080, fps: 24, durationFrames: 120)
    public static let vertical = CanvasPreset(name: "Vertical 9:16", width: 1080, height: 1920, fps: 30, durationFrames: 150)
    public static let web = CanvasPreset(name: "Web 550 × 400", width: 550, height: 400, fps: 24, durationFrames: 48)
    public static let all: [CanvasPreset] = [hd1080, square, vertical, web]
}

/// The stage picture at a frame.
public protocol StageRendering: Sendable {
    /// `editing` is the symbol being edited in place; nil draws the scene.
    func drawList(_ document: Document, sceneID: String, frame: Int,
                  editing symbolID: String?) -> StageDrawList
}

/// What is under the pointer, inside a marquee, and the selection's bounds. `editing` is the symbol being edited in
/// place, as in `StageRendering`: its own items are hit, never the scene's (#641); nil hits the scene.
public protocol StageHitTesting: Sendable {
    /// `tolerance` is in scene points (the app passes 4 pt divided by zoom).
    /// Hidden and locked layers and text items are never hit.
    func hit(_ document: Document, sceneID: String, frame: Int, editing symbolID: String?, at point: Point,
             tolerance: Double) -> StageAddress?
    func marquee(_ document: Document, sceneID: String, frame: Int, editing symbolID: String?, rect: Rect) -> [StageAddress]
    /// World bounds including stroke width; nil for an empty selection.
    func bounds(_ document: Document, sceneID: String, frame: Int, editing symbolID: String?,
                of items: [StageAddress]) -> Rect?
}

extension StageHitTesting {
    /// The scene's items, no symbol edited.
    public func hit(_ document: Document, sceneID: String, frame: Int, at point: Point, tolerance: Double) -> StageAddress? {
        hit(document, sceneID: sceneID, frame: frame, editing: nil, at: point, tolerance: tolerance)
    }
    public func marquee(_ document: Document, sceneID: String, frame: Int, rect: Rect) -> [StageAddress] {
        marquee(document, sceneID: sceneID, frame: frame, editing: nil, rect: rect)
    }
    public func bounds(_ document: Document, sceneID: String, frame: Int, of items: [StageAddress]) -> Rect? {
        bounds(document, sceneID: sceneID, frame: frame, editing: nil, of: items)
    }
}

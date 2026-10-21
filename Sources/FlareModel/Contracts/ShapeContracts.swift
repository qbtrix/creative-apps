// ShapeContracts.swift: tool gestures to shapes, direct selection and the
// Edit menu (docs/blueprints/flare.md, section 6.2).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
import SuiteKernel

public struct ShapeDraft: Equatable, Sendable {
    public var tool: FlareTool
    public var shape: FlareShape
    /// The pen's contour and stage scale (SuiteKernel's `PenDraft`); `pen` reads it for the Pen, and the fields below
    /// are views of it.
    var penStore: PenDraft
    public var anchors: [Point] { penStore.contour.anchors.map(\.point) }  // pen only; empty for primitives
    /// Pen anchors made by a drag: those with a handle.
    public var smoothAnchors: Set<Int> {
        Set(penStore.contour.anchors.indices.filter { penStore.contour.anchors[$0].handleOut != nil
            || penStore.contour.anchors[$0].handleIn != nil })
    }
    public var isClosed: Bool { penStore.contour.closed }
    /// Pen only: the fit scale of its latest click, stage points per scene point.
    public var stageScale: Double {
        get { penStore.scale }
        set { penStore.scale = newValue }
    }
    public init(tool: FlareTool, shape: FlareShape, anchors: [Point] = [],
                smoothAnchors: Set<Int> = [], isClosed: Bool = false, stageScale: Double = 1) {
        self.tool = tool; self.shape = shape
        penStore = PenDraft(contour: Self.contour(of: shape, anchors: anchors, smooth: smoothAnchors, closed: isClosed),
                            scale: stageScale)
    }
}

/// What a handle drag on the selection box asks for, in scene space.
public enum BoxGesture: Hashable, Sendable {
    case move(dx: Double, dy: Double)
    case scale(handle: Int, to: Point)      // handle 0...7 clockwise from top-left
    case rotate(degrees: Double)
}

public protocol ShapeBuilding: Sendable {
    /// Why `tool` can't draw yet, or nil; the rail shows it as the disabled reason.
    func unavailableHelp(for tool: FlareTool) -> String?
    func draft(_ tool: FlareTool, from start: Point, to end: Point, modifiers: DragModifiers,
               previous: ShapeDraft?) -> ShapeDraft?
    /// Grouped "Add Rectangle", "Add Ellipse" or "Add Path". Adds the draft as a new layer of `owner` (a scene, or
    /// the symbol edited in place) above `aboveLayerID` and returns the new layer's id. Throws on a locked layer.
    func commit(_ draft: ShapeDraft, owner: LayerOwner, aboveLayerID: String?,
                in engine: inout CommandEngine) throws -> String
    /// The layer values a box gesture would give, for the live preview and the commit.
    func boxResult(_ gesture: BoxGesture, layers: [String], document: Document, sceneID: String,
                   frame: Int, box: Rect) -> [String: [String: Double]]
    /// Grouped "Move", "Scale" or "Rotate": writes `boxResult` through the
    /// not-animated / animated rule of section 2.
    func commitBox(_ gesture: BoxGesture, layers: [String], sceneID: String, frame: Int, box: Rect,
                   autoKey: Bool, in engine: inout CommandEngine) throws
    /// Grouped "Edit Path" (direct select).
    func setPath(_ path: FlarePath, of item: StageAddress, in engine: inout CommandEngine) throws
    /// Grouped "Move" (direct select of whole items) by (`dx`, `dy`) in the items' layer space, not scene points.
    func translate(_ items: [StageAddress], dx: Double, dy: Double, in engine: inout CommandEngine) throws
    /// Grouped "Delete".
    func delete(_ items: [StageAddress], in engine: inout CommandEngine) throws
    /// Grouped "Duplicate". Returns the new layer ids.
    func duplicate(layers: [String], owner: LayerOwner, in engine: inout CommandEngine) throws -> [String]
    /// The layers as a registry envelope list for the pasteboard (no engine change).
    func copy(layers: [String], owner: LayerOwner, from document: Document) throws -> Data
    /// Grouped "Paste". Decodes only through `CommandRegistry.builtIn`; returns new layer ids. Like `commit`,
    /// throws on an `aboveLayerID` that is missing or locked.
    func paste(_ data: Data, owner: LayerOwner, aboveLayerID: String?, offset: Double,
               in engine: inout CommandEngine) throws -> [String]
}

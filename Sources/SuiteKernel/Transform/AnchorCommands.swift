// Transform/AnchorCommands.swift (anchor-parenting AN-1 shape, AN-4 bodies):
// the three anchor and parent commands any app with layers registers.
// `transform.set-anchor` moves a layer's anchor and keeps it in place unless
// told not to, `layer.set-parent` makes a layer follow another (or nothing)
// through `LayerFollow.setFollow(keepingPlace:)`, and `layer.new-null` adds an
// empty layer to parent to. Ids, titles, schemas and examples are the contract.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// What `transform.set-anchor` needs from an app: each layer's placement and
/// box in layer space, and the one write that records an undo step.
public protocol AnchorTarget: AnyObject {
    /// The layer's placement; nil for an unknown id.
    func placement(of id: String) -> Placement?
    /// The layer's bounds in its own space; nil for an unknown id.
    func bounds(of id: String) -> Rect?
    /// Sets the layer's placement as one undo step; keys when the property is keyed and auto-key is on.
    func setPlacement(_ p: Placement, of id: String) throws
}

/// What `layer.set-parent` and `layer.new-null` need from an app: its layer
/// tree, each layer's local matrix, the inverse (a world matrix back into a
/// placement with the anchor unchanged), and a way to add a null.
public protocol ParentTarget: AnyObject {
    /// The app's layer payload.
    associatedtype Payload: LayerPayload
    /// The one layer tree; a set is one undo step.
    var layerTree: LayerTree<Payload> { get set }
    /// The layer's placement in its parent as a matrix.
    func local(_ node: LayerNode<Payload>) -> Matrix
    /// Writes `world` (the layer's new local matrix) back into the node's placement, anchor unchanged.
    func keepPlace(_ node: inout LayerNode<Payload>, world: Matrix)
    /// Adds an empty layer named `named` and answers its id.
    func newNull(named: String) throws -> String
}

/// The anchor and parent specs, their params, and the runner an app's catalog forwards to.
public enum AnchorCommands {
    /// The targets one run acts on; either may be nil when the app has no such layers.
    public struct Targets {
        /// The layers whose anchors move.
        public var anchor: (any AnchorTarget)?
        /// The layer tree whose follow links change.
        public var parent: (any ParentTarget)?
        /// Both targets, either optional.
        public init(anchor: (any AnchorTarget)?, parent: (any ParentTarget)?) {
            (self.anchor, self.parent) = (anchor, parent)
        }
    }

    /// `transform.set-anchor`: the anchor at `{x, y}` or at one of the box's nine points; keeps place unless `keepPlace` is false.
    public struct SetAnchorParams: Codable, Sendable { public var id: String; public var x, y: Double?; public var at: BoxAnchor?; public var keepPlace: Bool? }
    /// `layer.set-parent`: `parent` nil or null clears the link.
    public struct SetParentParams: Codable, Sendable { public var id: String; public var parent: String? }
    /// `layer.new-null`: an optional name.
    public struct NewNullParams: Codable, Sendable { public var name: String? }

    /// The three specs, in the packet's order; each run forwards to `run`.
    public static let specs: [CommandSpec<Targets>] = [
        .typed("transform.set-anchor", title: "Set Anchor",
               summary: "Moves a layer's anchor, the point it turns and scales about, keeping the layer in place unless keepPlace is false.",
               kind: .edit, params: SetAnchorParams.self,
               schema: .object(["id": .string("The layer's id."), "x": .optional(.number("Anchor x in layer space.")),
                                "y": .optional(.number("Anchor y in layer space.")),
                                "at": .optional(.string("One of the box's nine points.", oneOf: BoxAnchor.allCases.map(\.rawValue))),
                                "keepPlace": .optional(.boolean)], required: ["id", "x", "y", "at", "keepPlace"]),
               example: .object(["id": .string("layer-1"), "at": .string("center")])) { (t: inout Targets, p: SetAnchorParams) throws -> JSONValue in
            try run("transform.set-anchor", JSONValue(encoding: p), anchor: t.anchor, parent: t.parent)
        },
        .typed("layer.set-parent", title: "Set Parent",
               summary: "Makes a layer follow another layer, or nothing when parent is null, keeping it in place on screen.",
               kind: .edit, params: SetParentParams.self,
               schema: .object(["id": .string("The layer's id."), "parent": .optional(.string("The parent layer's id; omit or null to clear."))],
                               required: ["id", "parent"]),
               example: .object(["id": .string("layer-2"), "parent": .string("layer-1")])) { (t: inout Targets, p: SetParentParams) throws -> JSONValue in
            try run("layer.set-parent", JSONValue(encoding: p), anchor: t.anchor, parent: t.parent)
        },
        .typed("layer.new-null", title: "New Null",
               summary: "Adds an empty layer, drawn only as its mark, for other layers to follow.",
               kind: .edit, params: NewNullParams.self,
               schema: .object(["name": .optional(.string("The null's name.", maxLength: 128))], required: ["name"]),
               example: .object(["name": .string("Null 1")])) { (t: inout Targets, p: NewNullParams) throws -> JSONValue in
            try run("layer.new-null", JSONValue(encoding: p), anchor: t.anchor, parent: t.parent)
        },
    ]

    /// Runs command `id` with JSON `params` on the targets; answers the new null's id for
    /// `layer.new-null`, null otherwise. A refusal is `failed` with a sentence and writes nothing.
    @discardableResult
    public static func run(_ id: String, _ params: JSONValue, anchor: (any AnchorTarget)?, parent: (any ParentTarget)?) throws -> JSONValue {
        guard specs.contains(where: { $0.id == id }) else { throw CatalogError.unknownCommand(id) }
        func decoded<P: Decodable>(_ type: P.Type) throws -> P {
            do { return try params.decode(type) } catch { throw CatalogError.malformedParams(id: id, [CommandSpec<Targets>.issue(error)]) }
        }
        if id == "transform.set-anchor" {
            guard let anchor else { throw CatalogError.unavailable(id: id, why: "This document has no layers with anchors.") }
            try setAnchor(anchor, decoded(SetAnchorParams.self))
            return .null
        }
        guard let parent else { throw CatalogError.unavailable(id: id, why: "This document has no layers to parent.") }
        if id == "layer.set-parent" {
            try setParent(parent, decoded(SetParentParams.self))
            return .null
        }
        // layer.new-null: the app adds the empty layer at its canvas centre.
        return .string(try parent.newNull(named: decoded(NewNullParams.self).name ?? "Null"))
    }

    /// `transform.set-anchor`: the point from `at` (on the layer's box) or `x` and `y`, then one write.
    static func setAnchor(_ target: any AnchorTarget, _ p: SetAnchorParams) throws {
        let id = "transform.set-anchor"
        guard let placement = target.placement(of: p.id) else { throw CatalogError.failed(id: id, message: "There is no layer \(p.id).") }
        let point: Point
        if let at = p.at {
            guard let box = target.bounds(of: p.id) else { throw CatalogError.failed(id: id, message: "Layer \(p.id) has no bounds.") }
            point = Placement.anchorPoint(at: at, in: box)
        } else if let x = p.x, let y = p.y, x.isFinite, y.isFinite {
            point = Point(x: x, y: y)
        } else {
            throw CatalogError.failed(id: id, message: "Give the anchor as x and y, or as one of the box's nine points.")
        }
        var loose = placement
        (loose.anchorX, loose.anchorY) = (point.x, point.y)
        try target.setPlacement(p.keepPlace ?? true ? placement.movingAnchor(to: point) : loose, of: p.id)
    }

    /// `layer.set-parent` through `LayerFollow.setFollow`, keeping the layer in place; one tree write.
    static func setParent<T: ParentTarget>(_ target: T, _ p: SetParentParams) throws {
        var tree = target.layerTree
        do {
            try tree.setFollow(p.id, p.parent, local: { target.local($0) },
                               keepingPlace: { node, placed in target.keepPlace(&node, world: placed) })
        } catch {
            throw CatalogError.failed(id: "layer.set-parent", message: sentence(error, p))
        }
        target.layerTree = tree
    }

    /// A follow refusal in words.
    static func sentence(_ refusal: TreeRefusal, _ p: SetParentParams) -> String {
        switch refusal {
        case .unknown(let id): "There is no layer \(id)."
        case .cycle: "Layer \(p.parent ?? p.id) already follows \(p.id), so \(p.id) can't follow it."
        default: "\(refusal)"
        }
    }
}

// FlarePlacement+Kernel.swift (anchor-parenting AN-10): FlareCore's transform and parent as SuiteKernel's `Placement`
// and `LayerFollow`. The three `AnchorCommands` run on a `FlarePlacementTarget`, the edited owner's layers at one
// frame, which records what the kernel writes; the workspace then applies that as FlareCore commands in one undo step:
// `SetLayerParent` for a changed follow link, a key per changed placement property (the inspector's rule), and an
// `AddLayer` for a new null at the canvas centre. Clearing or changing a parent also keeps the layer in place at each
// key of its old parent chain, so the old parent's motion stays baked in. New shapes key their anchor at their centre.
#if canImport(Glibc)
import Glibc  // atan2
#elseif canImport(Musl)
import Musl
#elseif canImport(Darwin)
import Darwin
#endif
import FlareCore
import SuiteKernel

extension LiveShapes {
    /// The tracks a new shape keys once at frame 0 for its anchor, beside `positionKeys`.
    static let anchorKeys = ["anchorX", "anchorY"]

    /// The frame-0 keys of a new shape drawn in `box`: its position and its anchor both at the box's centre, so the
    /// path stays where it was drawn and turns about that centre; the origin without a box.
    static func newShapeKeys(in box: Rect?) -> [(property: String, value: Double)] {
        let c = box.map { Placement.anchorPoint(at: .center, in: $0) } ?? Point(x: 0, y: 0)
        return Array(zip(positionKeys, [c.x, c.y])) + Array(zip(anchorKeys, [c.x, c.y]))
    }
}

/// The edited owner's layers at `frame` as the kernel's anchor and parent targets; it collects the kernel's writes.
final class FlarePlacementTarget: AnchorTarget, ParentTarget {
    let layers: [Layer], frame: Int, taken: Set<String>
    var placements: [String: Placement]
    var layerTree: LayerTree<FlareLayerPayload>
    /// The layers whose placement the kernel wrote.
    private(set) var moved: Set<String> = []
    /// The nulls `layer.new-null` asked for, in order.
    private(set) var nulls: [Layer] = []

    init(_ layers: [Layer], frame: Int, taken: Set<String>) {
        (self.layers, self.frame, self.taken) = (layers, frame, taken)
        placements = Dictionary(layers.map { ($0.id, $0.placement(at: Double(frame)).transform) }, uniquingKeysWith: { a, _ in a })
        layerTree = FlareWorkspace.layerTree(layers)
    }

    func placement(of id: String) -> Placement? { placements[id] }

    /// The union of the layer's shape bounds in its own space; nil for an unknown or empty layer.
    func bounds(of id: String) -> Rect? {
        let boxes = layers.first { $0.id == id }?.shapes.compactMap(\.bounds) ?? []
        return boxes.first.map { first in
            boxes.dropFirst().reduce(first) {
                Rect(minX: min($0.minX, $1.minX), minY: min($0.minY, $1.minY), maxX: max($0.maxX, $1.maxX), maxY: max($0.maxY, $1.maxY))
            }
        }
    }

    func setPlacement(_ p: Placement, of id: String) throws {
        guard placements[id] != nil else { throw CatalogError.failed(id: "transform.set-anchor", message: "There is no layer \(id).") }
        placements[id] = p
        moved.insert(id)
    }

    func local(_ node: LayerNode<FlareLayerPayload>) -> Matrix { placements[node.id]?.matrix ?? .identity }

    func keepPlace(_ node: inout LayerNode<FlareLayerPayload>, world: Matrix) {
        guard let p = placements[node.id] else { return }
        placements[node.id] = Self.placement(world, keeping: p)
        moved.insert(node.id)
    }

    func newNull(named: String) throws -> String {
        var n = 1
        while taken.contains("null-\(n)") || nulls.contains(where: { $0.id == "null-\(n)" }) { n += 1 }
        nulls.append(Layer(id: "null-\(n)", name: named))
        return "null-\(n)"
    }

    /// The placement whose matrix is `m`, with `p`'s anchor: the anchor lands on (x, y), the turn is the nearest to
    /// `p`'s, and skew is dropped. A zero x scale takes the turn from the y axis.
    static func placement(_ m: Matrix, keeping p: Placement) -> Placement {
        var out = p
        let at = m.apply(Point(x: p.anchorX, y: p.anchorY))
        (out.x, out.y) = (at.x, at.y)
        let sx = (m.a * m.a + m.b * m.b).squareRoot()
        let turn = sx > 0 ? atan2(m.b, m.a) : atan2(-m.c, m.d)
        let degrees = turn * 180 / .pi
        out.rotation = degrees + 360 * ((p.rotation - degrees) / 360).rounded()
        out.scaleX = sx
        out.scaleY = sx > 0 ? m.determinant / sx : (m.c * m.c + m.d * m.d).squareRoot()
        return out
    }
}

extension FlareWorkspace {
    /// FlareCore's placement tracks, in the order `placementValues` lists them.
    static let placementKeys = ["x", "y", "scaleX", "scaleY", "rotation", "anchorX", "anchorY"]

    static func placementValues(_ p: Placement) -> [Double] { [p.x, p.y, p.scaleX, p.scaleY, p.rotation, p.anchorX, p.anchorY] }

    /// transform.set-anchor, layer.set-parent and layer.new-null, forwarded to `AnchorCommands`.
    static let anchorCommands: [CommandSpec<FlareWorkspace>] = AnchorCommands.specs.map { spec in
        let (id, title) = (spec.id, spec.title)
        return .typed(id, title: title, summary: spec.summary, kind: spec.kind, params: JSONValue.self, schema: nullableParent(spec.params),
                      result: spec.result, example: spec.example, availability: { noScene($0).map(Availability.unavailable) ?? .available }) {
            (w: inout FlareWorkspace, p: JSONValue) throws -> JSONValue in try w.runAnchor(id, title, p)
        }
    }

    /// `schema` with its `parent` also taking null, which clears the link as layer.set-parent's summary says; the
    /// kernel's schema takes only a string there. Unchanged without a `parent`.
    static func nullableParent(_ schema: ParamSchema) -> ParamSchema {
        guard case .object(var top) = schema.json, case .object(var properties)? = top["properties"],
              case .object(var parent)? = properties["parent"] else { return schema }
        parent["type"] = .array([.string("string"), .string("null")])
        properties["parent"] = .object(parent)
        top["properties"] = .object(properties)
        var widened = schema
        widened.json = .object(top)
        return widened
    }

    /// Runs anchor command `id` on the edited owner at the playhead (and, for a parent change, at each key of the old
    /// parent chain), then applies the writes as one undo step named `title`. A refusal changes nothing.
    mutating func runAnchor(_ id: String, _ title: String, _ params: JSONValue) throws -> JSONValue {
        guard let owner = propertyOwner, let layers = ownerLayers else { throw CatalogError.unavailable(id: id, why: FlareLayerError.noDocument.message) }
        let frames = [currentFrame] + Self.bakeFrames(id, params, layers).filter { $0 != currentFrame }
        let targets = frames.map { FlarePlacementTarget(layers, frame: $0, taken: takenLayerNames) }
        let results = try targets.map { try AnchorCommands.run(id, params, anchor: $0, parent: $0) }
        guard let first = targets.first else { return .null }
        let (properties, autoKey, frame, baked) = (services.properties, autoKey, currentFrame, frames.count > 1)
        let centre = selectedScene.map { Point(x: $0.width / 2, y: $0.height / 2) } ?? Point(x: 0, y: 0)
        let moved = targets.reduce(Set<String>()) { $0.union($1.moved) }
        try attempt(id) { w in
            w.applyGroup(title, selection: first.nulls.first.map { .layer($0.id) } ?? .keep) { engine in
                for layer in layers where first.layerTree.node(layer.id)?.followsID != layer.parentID {
                    try engine.perform(SetLayerParent(owner: owner, layerID: layer.id, parentID: first.layerTree.node(layer.id)?.followsID))
                }
                for layer in layers where moved.contains(layer.id) {
                    let rows = targets.map { t in
                        (t.frame, Self.placementValues(layer.placement(at: Double(t.frame)).transform),
                         Self.placementValues(t.placements[layer.id] ?? layer.placement(at: Double(t.frame)).transform))
                    }
                    for (k, property) in Self.placementKeys.enumerated()
                    where rows.contains(where: { abs($0.2[k] - $0.1[k]) > 1e-9 }) {
                        for (at, _, values) in rows {
                            if baked {
                                try engine.perform(SetKeyframe(owner: owner, layerID: layer.id, property: property,
                                                               keyframe: Keyframe(frame: at, value: values[k])))
                            } else {
                                try properties.setValue(values[k], of: property, owner: owner, layerIDs: [layer.id], frame: frame,
                                                        autoKey: autoKey, coalesceKey: nil, in: &engine)
                            }
                        }
                    }
                }
                for null in first.nulls {
                    try engine.perform(AddLayer(owner: owner, layer: null))
                    for (property, value) in zip(LiveShapes.positionKeys, [centre.x, centre.y]) {
                        try engine.perform(SetKeyframe(owner: owner, layerID: null.id, property: property,
                                                       keyframe: Keyframe(frame: 0, value: value)))
                    }
                }
            }
        }
        return results.first ?? .null
    }

    /// The frames besides the playhead a `layer.set-parent` keeps its layer in place at: every key of the layer's
    /// current parent chain, so unparenting keeps the motion the old parent gave it. Empty for the other commands.
    static func bakeFrames(_ id: String, _ params: JSONValue, _ layers: [Layer]) -> [Int] {
        guard id == "layer.set-parent", let p = try? params.decode(AnchorCommands.SetParentParams.self) else { return [] }
        let byID = Dictionary(layers.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var frames = Set<Int>(), seen = Set<String>(), next = byID[p.id]?.parentID
        while let parent = next, seen.insert(parent).inserted, let layer = byID[parent] {
            frames.formUnion(layer.tracks.values.flatMap { $0.map(\.frame) })
            next = layer.parentID
        }
        return frames.sorted()
    }
}

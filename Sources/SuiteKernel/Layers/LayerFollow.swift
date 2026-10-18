// LayerFollow.swift (EK-13): the follow link of the one layer tree. A layer
// whose `followsID` names another composes that layer's placement before its
// own, so moving the followed layer carries it along. The link is separate
// from nesting: any layer in the tree may follow any other, never itself and
// never one that already follows it, however deep. Changing the link keeps
// the layer where it is on screen.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore

extension LayerTree {
    /// True when `id` follows `ancestor`, directly or through others. False
    /// for an unknown id, and for a layer and itself.
    public func follows(_ id: String, _ ancestor: String) -> Bool {
        var seen: Set<String> = [id]
        var next = node(id)?.followsID
        while let current = next, seen.insert(current).inserted {
            if current == ancestor { return true }
            next = node(current)?.followsID
        }
        return false
    }

    /// The node's placement on the page: the followed layer's world placement
    /// first, then the node's own `local`. Identity for an unknown id. A
    /// broken file's cycle stops at the first layer seen twice.
    public func worldPlacement(of id: String, local: (LayerNode<Payload>) -> Matrix) -> Matrix {
        var chain: [Matrix] = []
        var seen: Set<String> = []
        var next: String? = id
        while let current = next, seen.insert(current).inserted, let node = node(current) {
            chain.append(local(node))
            next = node.followsID
        }
        // chain runs node to farthest ancestor; the ancestor applies last.
        return chain.reduce(Matrix.identity) { world, placement in placement * world }
    }

    /// Makes `id` follow `parent` (nil: nothing). Refuses an unknown id or
    /// parent, and a parent that is `id` or follows it at any depth. The layer
    /// keeps its place on screen: `keepingPlace` gets the local placement that
    /// puts it where it was under the new parent. When the new parent's
    /// placement can't be inverted, the local placement stays as it is.
    public mutating func setFollow(_ id: String, _ parent: String?, local: (LayerNode<Payload>) -> Matrix,
                                   keepingPlace: (inout LayerNode<Payload>, Matrix) -> Void) throws(TreeRefusal) {
        guard node(id) != nil else { throw .unknown(id) }
        if let parent {
            guard node(parent) != nil else { throw .unknown(parent) }
            if parent == id || follows(parent, id) { throw .cycle(id) }
        }
        let world = worldPlacement(of: id, local: local)
        let parentWorld = parent.map { worldPlacement(of: $0, local: local) } ?? .identity
        let placed = (try? parentWorld.inverted()).map { $0 * world }
        _ = update(id) { node in
            node.followsID = parent
            if let placed { keepingPlace(&node, placed) }
        }
    }
}

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
        var next = followNode(id)?.followsID
        while let current = next, seen.insert(current).inserted {
            if current == ancestor { return true }
            next = followNode(current)?.followsID
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
        while let current = next, seen.insert(current).inserted, let node = followNode(current) {
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
        guard followNode(id) != nil else { throw .unknown(id) }
        if let parent {
            guard followNode(parent) != nil else { throw .unknown(parent) }
            if parent == id || follows(parent, id) { throw .cycle(id) }
        }
        let world = worldPlacement(of: id, local: local)
        let parentWorld = parent.map { worldPlacement(of: $0, local: local) } ?? .identity
        let placed = (try? parentWorld.inverted()).map { $0 * world }
        Self.editFollow(&roots, id) { node in
            node.followsID = parent
            if let placed { keepingPlace(&node, placed) }
        }
    }

    /// The node with `id` anywhere in the tree, nil when there is none.
    private func followNode(_ id: String) -> LayerNode<Payload>? {
        var stack = roots
        while let node = stack.popLast() {
            if node.id == id { return node }
            stack.append(contentsOf: node.children)
        }
        return nil
    }

    /// Runs `body` on the node with `id` among `nodes` or below; true once found.
    @discardableResult
    private static func editFollow(_ nodes: inout [LayerNode<Payload>], _ id: String,
                                   _ body: (inout LayerNode<Payload>) -> Void) -> Bool {
        for index in nodes.indices {
            if nodes[index].id == id {
                body(&nodes[index])
                return true
            }
            if editFollow(&nodes[index].children, id, body) { return true }
        }
        return false
    }
}

// LayerTree.swift (EK-2 stub, EK-12 body, EK-13 the follow link): the one
// layer tree every app keeps: nesting, back-to-front order, hide and lock
// cascades, a follow link. `rows(expanded:)` already walks, so the gallery
// draws the fixture's tree; every edit is a stub that changes nothing.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// What an app stores in a layer: its own kind, and whether it can hold children.
public protocol LayerPayload: Hashable & Sendable {
    /// True for a group, frame or other container another layer can move into.
    var holdsChildren: Bool { get }
}

/// One layer: its id, name, hide and lock flags, children (back to front),
/// the id of the layer it follows, and the app's payload.
public struct LayerNode<Payload: LayerPayload>: Hashable, Sendable, Identifiable {
    /// The layer's id, unique in its tree.
    public var id: String
    /// The name the layers panel shows.
    public var name: String
    /// True when the layer itself is hidden (its descendants inherit it).
    public var isHidden: Bool
    /// True when the layer itself is locked (its descendants inherit it).
    public var isLocked: Bool
    /// The children, back to front.
    public var children: [LayerNode]
    /// The id of the layer whose placement this one composes with, if any.
    public var followsID: String?
    /// The app's own data for the layer.
    public var payload: Payload
    /// A layer; visible, unlocked, childless and following nothing unless given.
    public init(id: String, name: String, isHidden: Bool = false, isLocked: Bool = false,
                children: [LayerNode] = [], followsID: String? = nil, payload: Payload) {
        self.id = id
        self.name = name
        self.isHidden = isHidden
        self.isLocked = isLocked
        self.children = children
        self.followsID = followsID
        self.payload = payload
    }
}

/// One row of the layers panel: a node flattened with its depth and what it inherits.
public struct LayerRow: Hashable, Sendable {
    /// The node's id.
    public var id: String
    /// The node's name.
    public var name: String
    /// How many ancestors the node has: 0 for a root.
    public var depth: Int
    /// The node's own hidden flag.
    public var isHidden: Bool
    /// The node's own locked flag.
    public var isLocked: Bool
    /// True when an ancestor is hidden, so the row shows dimmed.
    public var inheritsHidden: Bool
    /// True when an ancestor is locked.
    public var inheritsLocked: Bool
    /// True when the node's payload holds children (the row has a disclosure).
    public var holdsChildren: Bool
    /// True when the row is open, showing its children below it.
    public var isExpanded: Bool

}

/// One arrange command on layers among their siblings.
public enum ArrangeStep: Sendable {
    /// To the front of its siblings, one place forward, one place back, to the back.
    case bringToFront, bringForward, sendBackward, sendToBack
}

/// Why the tree refused an edit; each case names the id it refused.
public enum TreeRefusal: Error, Equatable {
    /// No node has the id; the destination is the node or below it; the
    /// destination holds no children; it is effectively locked; a follow cycle.
    case unknown(String), intoItself(String), notAContainer(String), locked(String), cycle(String)
}

/// A tree of layers: roots back to front, each with its children.
public struct LayerTree<Payload: LayerPayload>: Hashable, Sendable {
    /// The top-level layers, back to front.
    public var roots: [LayerNode<Payload>]
    /// A tree of `roots`.
    public init(_ roots: [LayerNode<Payload>] = []) {
        self.roots = roots
    }
    /// The node with `id`, nil when there is none. Stub: nil.
    public func node(_ id: String) -> LayerNode<Payload>? { nil }
    /// The ids from the root down to `id`'s parent, nil for an unknown id. Stub: nil.
    public func ancestors(of id: String) -> [String]? { nil }
    /// The panel's rows, front to back as a panel lists them, descending into
    /// every node whose id is in `expanded`.
    public func rows(expanded: Set<String>) -> [LayerRow] {
        var out: [LayerRow] = []
        Self.walk(roots, depth: 0, hidden: false, locked: false, expanded: expanded, into: &out)
        return out
    }
    /// Every id, front to back, descendants after their parent. Stub: none.
    public var frontToBack: [String] { [] }
    /// True when the node or an ancestor is hidden. Stub: false.
    public func isEffectivelyHidden(_ id: String) -> Bool { false }
    /// True when the node or an ancestor is locked. Stub: false.
    public func isEffectivelyLocked(_ id: String) -> Bool { false }
    /// Edits the node with `id` in place; false when there is none. Stub: false.
    public mutating func update(_ id: String, _ body: (inout LayerNode<Payload>) -> Void) -> Bool { false }
    /// Moves `id` into `parent` (nil: the roots) at `index`, clamped to the
    /// count. Stub: moves nothing.
    public mutating func move(_ id: String, into parent: String?, at index: Int) throws(TreeRefusal) {}
    /// Arranges `ids` among their siblings by `step`. Stub: nothing.
    public mutating func arrange(_ step: ArrangeStep, _ ids: [String]) throws(TreeRefusal) {}
    /// Groups `ids` under a new node named `name` with id `mint()`, returning
    /// that id. Stub: returns a minted id and changes nothing.
    public mutating func group(_ ids: [String], name: String, payload: Payload, mint: () -> String) throws(TreeRefusal) -> String {
        mint()
    }
    /// Replaces the group `id` with its children. Stub: nothing.
    public mutating func ungroup(_ id: String) throws(TreeRefusal) {}
    /// Copies `ids` with fresh ids from `mint`, each in front of its original;
    /// returns the copies' ids. Stub: none.
    public mutating func duplicate(_ ids: [String], mint: () -> String) -> [String] { [] }
    /// True when `id` follows `ancestor`, directly or through others (EK-13). Stub: false.
    public func follows(_ id: String, _ ancestor: String) -> Bool { false }
    /// The node's placement composed along its follow chain (EK-13). Stub: identity.
    public func worldPlacement(of id: String, local: (LayerNode<Payload>) -> Matrix) -> Matrix { .identity }
    /// Makes `id` follow `parent` (nil: nothing), keeping its world place
    /// through `keepingPlace` (EK-13). Stub: nothing.
    public mutating func setFollow(_ id: String, _ parent: String?, local: (LayerNode<Payload>) -> Matrix,
                                   keepingPlace: (inout LayerNode<Payload>, Matrix) -> Void) throws(TreeRefusal) {}
    /// Appends `nodes` front to back, then the children of each expanded one.
    private static func walk(_ nodes: [LayerNode<Payload>], depth: Int, hidden: Bool, locked: Bool,
                             expanded: Set<String>, into out: inout [LayerRow]) {
        for node in nodes.reversed() {
            let open = expanded.contains(node.id)
            out.append(LayerRow(id: node.id, name: node.name, depth: depth, isHidden: node.isHidden,
                                isLocked: node.isLocked, inheritsHidden: hidden, inheritsLocked: locked,
                                holdsChildren: node.payload.holdsChildren, isExpanded: open))
            if open {
                walk(node.children, depth: depth + 1, hidden: hidden || node.isHidden,
                     locked: locked || node.isLocked, expanded: expanded, into: &out)
            }
        }
    }
}

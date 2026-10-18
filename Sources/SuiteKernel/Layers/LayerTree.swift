// LayerTree.swift (EK-2 stub, EK-12 body, EK-13 the follow link): the one
// layer tree every app keeps: nesting, back-to-front order, hide and lock
// cascades, moves into a parent with refusals, arrange, group, ungroup and
// duplicate. The follow link (`follows`, `worldPlacement`, `setFollow`)
// stays a stub until EK-13.
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
    /// The node with `id`, nil when there is none.
    public func node(_ id: String) -> LayerNode<Payload>? { chain(id)?.last }
    /// The ids from the root down to `id`'s parent, nil for an unknown id.
    public func ancestors(of id: String) -> [String]? { chain(id)?.dropLast().map(\.id) }
    /// The panel's rows, front to back as a panel lists them, descending into
    /// every node whose id is in `expanded`.
    public func rows(expanded: Set<String>) -> [LayerRow] {
        var out: [LayerRow] = []
        Self.walk(roots, depth: 0, hidden: false, locked: false, expanded: expanded, into: &out)
        return out
    }
    /// Every id, front to back, descendants after their parent.
    public var frontToBack: [String] {
        var out: [String] = []
        Self.collect(roots, into: &out)
        return out
    }
    /// True when the node or an ancestor is hidden.
    public func isEffectivelyHidden(_ id: String) -> Bool { chain(id)?.contains { $0.isHidden } ?? false }
    /// True when the node or an ancestor is locked.
    public func isEffectivelyLocked(_ id: String) -> Bool { chain(id)?.contains { $0.isLocked } ?? false }
    /// Edits the node with `id` in place; false when there is none.
    public mutating func update(_ id: String, _ body: (inout LayerNode<Payload>) -> Void) -> Bool {
        guard let path = path(to: id) else { return false }
        return Self.edit(&roots, path[...], body) != nil
    }
    /// Moves `id` into `parent` (nil: the roots) at `index`, clamped to the
    /// count. Refuses an unknown id or parent, a parent that is `id` or below
    /// it, one that holds no children, and one that is effectively locked.
    public mutating func move(_ id: String, into parent: String?, at index: Int) throws(TreeRefusal) {
        guard node(id) != nil else { throw .unknown(id) }
        if let parent {
            guard let destination = node(parent) else { throw .unknown(parent) }
            if parent == id || ancestors(of: parent)?.contains(id) == true { throw .intoItself(parent) }
            guard destination.payload.holdsChildren else { throw .notAContainer(parent) }
            guard !isEffectivelyLocked(parent) else { throw .locked(parent) }
        }
        guard let moving = remove(id) else { throw .unknown(id) }
        _ = editChildren(of: parent) { kids in kids.insert(moving, at: min(max(index, 0), kids.count)) }
    }
    /// Arranges `ids` among their siblings by `step`; the ids keep their order
    /// among themselves, and one already at the end it moves toward stays.
    public mutating func arrange(_ step: ArrangeStep, _ ids: [String]) throws(TreeRefusal) {
        var parents: [String?] = []
        for id in ids {
            guard let line = ancestors(of: id) else { throw .unknown(id) }
            if !parents.contains(line.last) { parents.append(line.last) }
        }
        let picked = Set(ids)
        for parent in parents {
            _ = editChildren(of: parent) { kids in Self.arranged(&kids, step, picked) }
        }
    }
    /// Groups `ids` under a new node named `name` with id `mint()`, in the
    /// place of the frontmost one, keeping their order; returns that id.
    public mutating func group(_ ids: [String], name: String, payload: Payload, mint: () -> String) throws(TreeRefusal) -> String {
        for id in ids where node(id) == nil { throw .unknown(id) }
        let picked = Set(ids)
        let order = frontToBack.filter { id in
            picked.contains(id) && !(ancestors(of: id) ?? []).contains(where: picked.contains)
        }
        guard let front = order.first, let line = ancestors(of: front) else { throw .unknown(ids.first ?? "") }
        let parent = line.last
        let siblings = parent.map { node($0)?.children ?? [] } ?? roots
        let at = siblings.prefix { $0.id != front }.filter { !picked.contains($0.id) }.count
        var members: [LayerNode<Payload>] = []
        for id in order.reversed() {
            if let member = remove(id) { members.append(member) }
        }
        let made = LayerNode(id: mint(), name: name, children: members, payload: payload)
        _ = editChildren(of: parent) { kids in kids.insert(made, at: min(at, kids.count)) }
        return made.id
    }
    /// Replaces the group `id` with its children, in their order.
    public mutating func ungroup(_ id: String) throws(TreeRefusal) {
        guard let target = node(id), let line = ancestors(of: id) else { throw .unknown(id) }
        guard target.payload.holdsChildren else { throw .notAContainer(id) }
        _ = editChildren(of: line.last) { kids in
            guard let index = kids.firstIndex(where: { $0.id == id }) else { return }
            kids.replaceSubrange(index...index, with: target.children)
        }
    }
    /// Copies `ids` with fresh ids from `mint` (descendants too), each in
    /// front of its original; returns the copies' ids. Unknown ids are skipped.
    public mutating func duplicate(_ ids: [String], mint: () -> String) -> [String] {
        var out: [String] = []
        for id in ids {
            guard let original = node(id), let line = ancestors(of: id) else { continue }
            let copy = Self.copied(original, mint: mint)
            let placed = editChildren(of: line.last) { kids -> Bool in
                guard let index = kids.firstIndex(where: { $0.id == id }) else { return false }
                kids.insert(copy, at: index + 1)
                return true
            }
            if placed == true { out.append(copy.id) }
        }
        return out
    }
    /// The nodes from the root down to `id`, nil for an unknown id.
    private func chain(_ id: String) -> [LayerNode<Payload>]? {
        guard let path = path(to: id) else { return nil }
        var out: [LayerNode<Payload>] = []
        var level = roots
        for index in path {
            guard level.indices.contains(index) else { return nil }
            out.append(level[index])
            level = level[index].children
        }
        return out
    }
    /// The child indexes from the roots down to `id`, nil for an unknown id.
    private func path(to id: String) -> [Int]? { Self.path(to: id, in: roots) }
    private static func path(to id: String, in nodes: [LayerNode<Payload>]) -> [Int]? {
        for (index, node) in nodes.enumerated() {
            if node.id == id { return [index] }
            if let rest = path(to: id, in: node.children) { return [index] + rest }
        }
        return nil
    }
    /// Runs `body` on the node at `path`; nil when the path leads nowhere.
    private static func edit<R>(_ nodes: inout [LayerNode<Payload>], _ path: ArraySlice<Int>,
                                _ body: (inout LayerNode<Payload>) -> R) -> R? {
        guard let index = path.first, nodes.indices.contains(index) else { return nil }
        if path.count == 1 { return body(&nodes[index]) }
        return edit(&nodes[index].children, path.dropFirst(), body)
    }
    /// Runs `body` on the children of `parent` (nil: the roots); nil for an unknown parent.
    private mutating func editChildren<R>(of parent: String?, _ body: (inout [LayerNode<Payload>]) -> R) -> R? {
        guard let parent else { return body(&roots) }
        guard let path = path(to: parent) else { return nil }
        return Self.edit(&roots, path[...]) { body(&$0.children) }
    }
    /// Takes the node with `id` out of the tree and returns it.
    private mutating func remove(_ id: String) -> LayerNode<Payload>? {
        guard let line = ancestors(of: id) else { return nil }
        let taken = editChildren(of: line.last) { kids -> LayerNode<Payload>? in
            guard let index = kids.firstIndex(where: { $0.id == id }) else { return nil }
            return kids.remove(at: index)
        }
        return taken ?? nil
    }
    /// Reorders one sibling list by `step`, moving the `picked` ids.
    private static func arranged(_ kids: inout [LayerNode<Payload>], _ step: ArrangeStep, _ picked: Set<String>) {
        switch step {
        case .bringToFront:
            kids = kids.filter { !picked.contains($0.id) } + kids.filter { picked.contains($0.id) }
        case .sendToBack:
            kids = kids.filter { picked.contains($0.id) } + kids.filter { !picked.contains($0.id) }
        case .bringForward:
            for index in kids.indices.reversed() where picked.contains(kids[index].id) {
                let to = min(index + 1, kids.count - 1)
                if to != index, !picked.contains(kids[to].id) { kids.swapAt(index, to) }
            }
        case .sendBackward:
            for index in kids.indices where picked.contains(kids[index].id) {
                let to = max(index - 1, 0)
                if to != index, !picked.contains(kids[to].id) { kids.swapAt(index, to) }
            }
        }
    }
    /// A copy of `node` with fresh ids from `mint`, the node's own first.
    private static func copied(_ node: LayerNode<Payload>, mint: () -> String) -> LayerNode<Payload> {
        var copy = node
        copy.id = mint()
        copy.children = node.children.map { copied($0, mint: mint) }
        return copy
    }
    /// Appends the ids of `nodes` front to back, each before its descendants.
    private static func collect(_ nodes: [LayerNode<Payload>], into out: inout [String]) {
        for node in nodes.reversed() {
            out.append(node.id)
            collect(node.children, into: &out)
        }
    }
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

// DesignNode.swift: the node tree on a Design page and the flattened rows the Layers sidebar draws.
// Linux-safe value types. Node ids are unique across the file; only frames and groups hold children.

/// A node's rectangle in page points.
public struct DesignRect: Sendable, Hashable {
    public var x, y, width, height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        (self.x, self.y, self.width, self.height) = (x, y, width, height)
    }
}

public enum DesignNodeKind: String, CaseIterable, Sendable {
    case frame, group, rectangle, ellipse, text, instance

    /// The SF Symbol for this kind's sidebar row.
    public var systemImage: String {
        switch self {
        case .frame: "number"
        case .group: "square.dashed"
        case .rectangle: "rectangle"
        case .ellipse: "circle"
        case .text: "textformat"
        case .instance: "square.on.square"
        }
    }

    public var defaultName: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }

    /// Whether other nodes can be moved inside this one.
    public var holdsChildren: Bool { self == .frame || self == .group }
}

public struct DesignNode: Identifiable, Sendable, Hashable {
    public let id: String
    public var name: String
    public var kind: DesignNodeKind
    public var frame: DesignRect
    public var children: [DesignNode]
    public var isHidden, isLocked: Bool

    public init(
        id: String, name: String, kind: DesignNodeKind, frame: DesignRect,
        children: [DesignNode] = [], isHidden: Bool = false, isLocked: Bool = false
    ) {
        (self.id, self.name, self.kind, self.frame) = (id, name, kind, frame)
        (self.children, self.isHidden, self.isLocked) = (children, isHidden, isLocked)
    }
}

/// One visible row of the Layers tree: a node at its nesting depth.
public struct DesignRow: Identifiable, Sendable, Hashable {
    public let node: DesignNode
    public let depth: Int  // 0 at the top level, one more per enclosing parent

    public var id: String { node.id }
}

/// Why a tree or page edit was refused.
public enum DesignTreeError: Error, Equatable, Sendable {
    case unknownID(String), notAContainer(String), intoItself(String)
    case emptyName, lastPage
}

extension [DesignNode] {
    /// Rows in display order. A node's children show only when its id is in `expanded`.
    func rows(expanded: Set<String>, depth: Int = 0) -> [DesignRow] {
        flatMap { node -> [DesignRow] in
            let children = expanded.contains(node.id) ? node.children.rows(expanded: expanded, depth: depth + 1) : []
            return [DesignRow(node: node, depth: depth)] + children
        }
    }

    func node(_ id: String) -> DesignNode? {
        for node in self {
            if node.id == id { return node }
            if let found = node.children.node(id) { return found }
        }
        return nil
    }

    /// Applies `change` to the node with `id`; returns whether it was found.
    mutating func update(_ id: String, _ change: (inout DesignNode) -> Void) -> Bool {
        for index in indices {
            if self[index].id == id { change(&self[index]); return true }
            if self[index].children.update(id, change) { return true }
        }
        return false
    }

    /// Appends `node` at the top level, or to `parentID`'s children when that node holds children.
    mutating func add(_ node: DesignNode, to parentID: String?) throws(DesignTreeError) {
        guard let parentID else { return append(node) }
        guard let parent = self.node(parentID) else { throw .unknownID(parentID) }
        guard parent.kind.holdsChildren else { throw .notAContainer(parentID) }
        _ = update(parentID) { $0.children.append(node) }
    }

    /// Removes and returns the node with `id`, wherever it is nested.
    mutating func remove(_ id: String) -> DesignNode? {
        if let index = firstIndex(where: { $0.id == id }) { return remove(at: index) }
        for index in indices { if let found = self[index].children.remove(id) { return found } }
        return nil
    }
}

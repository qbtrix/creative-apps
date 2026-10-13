// DesignNode.swift: the node tree on a Design page, the plain geometry and color
// types it is made of, and the flattened rows the Layers sidebar draws. Linux-safe
// value types. Node ids are unique across the file; only frames and groups hold
// children.
//
// Coordinates: every node's frame is in absolute page points with a top-left
// origin, children included. Moving a container shifts its whole subtree by the
// same delta; resizing one never touches its children.
// Order: paint order is depth first (a node, then its children, siblings back to
// front in array order); hit order is the reverse. Hit testing skips a node that
// is hidden or locked together with its subtree.

/// A point on a page, in points from its top-left corner.
public struct DesignPoint: Sendable, Hashable, Codable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        (self.x, self.y) = (x, y)
    }

    var isFinite: Bool { x.isFinite && y.isFinite }
}

/// A node's rectangle in page points.
public struct DesignRect: Sendable, Hashable, Codable {
    public var x, y, width, height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        (self.x, self.y, self.width, self.height) = (x, y, width, height)
    }

    /// The rectangle a drag from `a` to `b` covers, whichever way it goes. With `square`
    /// both sides are the longer one and the rectangle grows away from `a`.
    public init(from a: DesignPoint, to b: DesignPoint, square: Bool = false) {
        var (dx, dy) = (b.x - a.x, b.y - a.y)
        if square {
            let side = Swift.max(dx.magnitude, dy.magnitude)
            (dx, dy) = (dx < 0 ? -side : side, dy < 0 ? -side : side)
        }
        self.init(x: Swift.min(a.x, a.x + dx), y: Swift.min(a.y, a.y + dy), width: dx.magnitude, height: dy.magnitude)
    }

    public var maxX: Double { x + width }
    public var maxY: Double { y + height }

    /// Whether `point` is inside; the edges count.
    public func contains(_ point: DesignPoint) -> Bool {
        point.x >= x && point.x <= maxX && point.y >= y && point.y <= maxY
    }

    /// Where `handle` sits: a corner, or the middle of a side.
    public func point(of handle: DesignHandle) -> DesignPoint {
        let (h, v) = handle.direction
        return DesignPoint(x: x + width * Double(h + 1) / 2, y: y + height * Double(v + 1) / 2)
    }

    /// This rectangle with `handle` dragged by `delta`: a corner moves its two edges, a side one.
    /// `keepAspect` (corners only) keeps width:height and follows the axis that changed more in
    /// relative terms; `fromCenter` moves the opposite edges by the negative delta, so the center
    /// stays. Width and height never go below 1 and never flip. A non-finite delta returns `self`.
    public func resized(_ handle: DesignHandle, by delta: DesignPoint, keepAspect: Bool, fromCenter: Bool) -> DesignRect {
        guard delta.isFinite else { return self }
        let (h, v) = handle.direction
        let grow = fromCenter ? 2.0 : 1.0
        var newWidth = width + Double(h) * delta.x * grow
        var newHeight = height + Double(v) * delta.y * grow
        if keepAspect, handle.isCorner, width > 0, height > 0 {
            let (scaleX, scaleY) = (newWidth / width, newHeight / height)
            let scale = Swift.max((scaleX - 1).magnitude >= (scaleY - 1).magnitude ? scaleX : scaleY, 1 / width, 1 / height)
            (newWidth, newHeight) = (width * scale, height * scale)
        }
        (newWidth, newHeight) = (Swift.max(newWidth, 1), Swift.max(newHeight, 1))
        func origin(_ start: Double, _ length: Double, _ newLength: Double, _ side: Int) -> Double {
            if fromCenter, side != 0 { return start + (length - newLength) / 2 }
            return side < 0 ? start + length - newLength : start
        }
        return DesignRect(
            x: origin(x, width, newWidth, h), y: origin(y, height, newHeight, v), width: newWidth, height: newHeight)
    }
}

/// A selection handle of a node's frame: the four corners and the four side midpoints.
public enum DesignHandle: String, CaseIterable, Sendable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left

    /// Which edge the handle moves on each axis: -1 left or top, 0 neither, 1 right or bottom.
    var direction: (x: Int, y: Int) {
        switch self {
        case .topLeft: (-1, -1)
        case .top: (0, -1)
        case .topRight: (1, -1)
        case .right: (1, 0)
        case .bottomRight: (1, 1)
        case .bottom: (0, 1)
        case .bottomLeft: (-1, 1)
        case .left: (-1, 0)
        }
    }

    var isCorner: Bool { direction.x != 0 && direction.y != 0 }
}

/// Plain 8-bit sRGB. ponytail: bytes only; CoreColor's Color3 replaces this with #21.
public struct DesignColor: Sendable, Hashable, Codable {
    public var red, green, blue: UInt8

    public init(_ red: UInt8, _ green: UInt8, _ blue: UInt8) {
        (self.red, self.green, self.blue) = (red, green, blue)
    }

    /// Frames.
    public static let white = DesignColor(255, 255, 255)
    /// Text.
    public static let black = DesignColor(0, 0, 0)
    /// Every other shape.
    public static let shape = DesignColor(217, 217, 217)
}

public enum DesignNodeKind: String, CaseIterable, Sendable, Codable {
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

    /// A new node's fill: white for frames, black for text, light grey for the rest.
    public var defaultFill: DesignColor {
        switch self {
        case .frame: .white
        case .text: .black
        case .group, .rectangle, .ellipse, .instance: .shape
        }
    }

    /// The size a click with the tool creates.
    public var defaultSize: (width: Double, height: Double) {
        self == .text ? (120, 24) : (100, 100)
    }
}

public struct DesignNode: Identifiable, Sendable, Hashable, Codable {
    public let id: String
    public var name: String
    public var kind: DesignNodeKind
    public var frame: DesignRect
    public var children: [DesignNode]
    public var isHidden, isLocked: Bool
    /// The shape's fill; a text node's color.
    public var fill: DesignColor
    /// A text node's text; empty for every other kind.
    public var text: String

    public init(
        id: String, name: String, kind: DesignNodeKind, frame: DesignRect,
        children: [DesignNode] = [], isHidden: Bool = false, isLocked: Bool = false,
        fill: DesignColor? = nil, text: String = ""
    ) {
        (self.id, self.name, self.kind, self.frame) = (id, name, kind, frame)
        (self.children, self.isHidden, self.isLocked) = (children, isHidden, isLocked)
        (self.fill, self.text) = (fill ?? kind.defaultFill, text)
    }

    /// Shifts this node and everything under it by `delta`.
    mutating func translate(by delta: DesignPoint) {
        frame.x += delta.x
        frame.y += delta.y
        for index in children.indices { children[index].translate(by: delta) }
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
    case emptyName, lastPage, alreadyExists(String)
    case locked(String), notText(String), emptyText
}

/// Modifier keys that change a drag: Shift constrains (square, aspect), Option works from the center.
public struct DesignModifiers: OptionSet, Sendable, Hashable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let shift = DesignModifiers(rawValue: 1)
    public static let option = DesignModifiers(rawValue: 2)
}

public enum DesignDirection: Sendable, CaseIterable { case up, down, left, right }

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

    /// The ids of the nodes enclosing `id`, outermost first; nil when `id` is not in the tree.
    func ancestors(of id: String) -> [String]? {
        for node in self {
            if node.id == id { return [] }
            if let path = node.children.ancestors(of: id) { return [node.id] + path }
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

    /// The topmost visible, unlocked node under `point`: later siblings first, a node's children
    /// before the node itself. A hidden or locked node hides its whole subtree.
    func hit(at point: DesignPoint) -> String? {
        for node in reversed() where !node.isHidden && !node.isLocked {
            if let inner = node.children.hit(at: point) { return inner }
            if node.frame.contains(point) { return node.id }
        }
        return nil
    }

    /// The deepest visible, unlocked frame under `point`, in the same order as `hit(at:)`.
    func deepestFrame(containing point: DesignPoint) -> String? {
        for node in reversed() where !node.isHidden && !node.isLocked {
            if let inner = node.children.deepestFrame(containing: point) { return inner }
            if node.kind == .frame, node.frame.contains(point) { return node.id }
        }
        return nil
    }
}

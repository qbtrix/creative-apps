// DesignNode.swift: the node tree on a Design page, the plain geometry and color
// types it is made of, and the tree flattened into rows under an expanded set
// (DesignRow; the tests read the tree through it, the Layers panel walks
// `children` itself, both in `frontToBack` order). Linux-safe value types. Node
// ids are unique across the file; only frames and groups hold children.
//
// Coordinates: every node's frame is in absolute page points with a top-left
// origin, children included. Moving a container shifts its whole subtree by the
// same delta; resizing one never touches its children.
// Order: paint order is depth first (a node, then its children, siblings back to
// front in array order); hit order is the reverse. Hit testing skips a node that
// is hidden or locked together with its subtree. The Layers list runs front to
// back: the frontmost sibling on top, each node's children under it; the rows
// come from SuiteKernel's LayerTree (DesignNode+Kernel).

import SuiteKernel

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

    /// The rectangle a drag from `a` to `b` covers, whichever way it goes. A drawing tool's
    /// Shift square comes from the kernel's `ShapeRules.dragged` (DesignDrawing).
    public init(from a: DesignPoint, to b: DesignPoint) {
        let (dx, dy) = (b.x - a.x, b.y - a.y)
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

    /// Whether this rectangle is under three handles across on either side, for handles `size`
    /// points across. Then the side handles would pile onto the corners and onto each other.
    public func isCompact(handleSize size: Double) -> Bool {
        width < 3 * size || height < 3 * size
    }

    /// The handles a selection of this rectangle shows, each with its center, for handles `size`
    /// points across, unturned: all eight on the corners and side midpoints and the rotate knob above
    /// the top (the centres of the kernel's `BoxMath.handles`), or for a compact rectangle the knob
    /// and only the corners, each pushed out by half a handle so it sits outside and leaves the
    /// inside readable.
    public func handles(size: Double) -> [DesignHandle: DesignPoint] {
        var shown: [DesignHandle: DesignPoint] = [:]
        let compact = isCompact(handleSize: size)
        for (handle, square) in BoxMath.handles(of: kernelRect, size: size) {
            guard let handle = DesignHandle(handle), !compact || handle.isCorner || handle == .rotate else { continue }
            let (h, v) = compact && handle.isCorner ? handle.direction : (0, 0)
            shown[handle] = DesignPoint(x: (square.minX + square.maxX + Double(h) * size) / 2,
                                        y: (square.minY + square.maxY + Double(v) * size) / 2)
        }
        return shown
    }

    /// This rectangle with `handle` dragged by `delta`: the kernel's `BoxMath.resized`, Shift
    /// for `keepAspect` and Option for `fromCenter`. A corner moves its two edges, a side one.
    /// `keepAspect` (corners only) keeps width:height and follows the axis that changed more in
    /// relative terms; `fromCenter` moves the opposite edges by the negative delta, so the center
    /// stays. Width and height never go below 1 and never flip. A non-finite delta returns `self`.
    public func resized(_ handle: DesignHandle, by delta: DesignPoint, keepAspect: Bool, fromCenter: Bool) -> DesignRect {
        var modifiers: DesignModifiers = []
        if keepAspect { modifiers.insert(.shift) }
        if fromCenter { modifiers.insert(.option) }
        return resized(handle, by: delta, modifiers: modifiers)
    }

    /// `resized(_:by:keepAspect:fromCenter:)` with Shift and Option read from `modifiers`.
    func resized(_ handle: DesignHandle, by delta: DesignPoint, modifiers: DesignModifiers) -> DesignRect {
        let edit = modifiers.editModifiers
        return DesignRect(BoxMath.resized(kernelRect, handle.editorHandle, by: Point(x: delta.x, y: delta.y), modifiers: edit))
    }

    /// This rectangle as the kernel's edges.
    var kernelRect: Rect { Rect(minX: x, minY: y, maxX: maxX, maxY: maxY) }

    /// The rectangle the kernel's edges `rect` cover.
    init(_ rect: Rect) {
        self.init(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
    }
}

/// A selection handle of a node's frame: the four corners, the four side midpoints and the
/// rotate knob above the top. Each is the kernel's `EditorHandle` of the same name; the kernel's
/// inside is no Design handle.
public enum DesignHandle: String, CaseIterable, Sendable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left, rotate

    /// The kernel's handle of this name.
    var editorHandle: EditorHandle {
        switch self {
        case .topLeft: .topLeft
        case .top: .top
        case .topRight: .topRight
        case .right: .right
        case .bottomRight: .bottomRight
        case .bottom: .bottom
        case .bottomLeft: .bottomLeft
        case .left: .left
        case .rotate: .rotate
        }
    }

    /// The Design handle of the kernel's `handle`; nil for its inside.
    init?(_ handle: EditorHandle) {
        switch handle {
        case .topLeft: self = .topLeft
        case .top: self = .top
        case .topRight: self = .topRight
        case .right: self = .right
        case .bottomRight: self = .bottomRight
        case .bottom: self = .bottom
        case .bottomLeft: self = .bottomLeft
        case .left: self = .left
        case .rotate: self = .rotate
        case .inside: return nil
        }
    }

    /// Which edge the handle moves on each axis: -1 left or top, 0 neither, 1 right or bottom; the
    /// knob moves none.
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
        case .rotate: (0, 0)
        }
    }

    var isCorner: Bool { editorHandle.isCorner }
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

    /// Whether the color reads dark: its weighted brightness (299 R + 587 G + 114 B, per mille)
    /// is under the 0...255 midpoint. Integer math, no libm. The text editor picks the light
    /// highlight behind dark ink and the dark one behind light ink by it.
    public var isDark: Bool {
        299 * Int(red) + 587 * Int(green) + 114 * Int(blue) < 128_000
    }
}

public enum DesignNodeKind: String, CaseIterable, Sendable, Codable {
    case frame, group, rectangle, ellipse, text, instance, shape

    /// The SF Symbol for this kind's sidebar row.
    public var systemImage: String {
        switch self {
        case .frame: "number"
        case .group: "square.dashed"
        case .rectangle: "rectangle"
        case .ellipse: "circle"
        case .text: "textformat"
        case .instance: "square.on.square"
        case .shape: "star"
        }
    }

    public var defaultName: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }

    /// Whether other nodes can be moved inside this one.
    public var holdsChildren: Bool { self == .frame || self == .group }

    /// Whether a node of this kind can show a placed picture: rectangles and frames (placed-images PD-1).
    public var holdsPicture: Bool { self == .frame || self == .rectangle }

    /// A new node's fill: white for frames, black for text, light grey for the rest.
    public var defaultFill: DesignColor {
        switch self {
        case .frame: .white
        case .text: .black
        case .group, .rectangle, .ellipse, .instance, .shape: .shape
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
    /// How round a rectangle's or frame's corners are, in points; 0 is square. The canvas draws
    /// at most `maxCornerRadius` (DesignCorners), so a later resize never needs to change it.
    public var cornerRadius: Double
    /// How opaque the layer draws, 0...1; 1 is fully opaque.
    public var opacity: Double
    /// The outline drawn centered on the shape's edge; nil draws none. Boxed with the extras: the kernel's
    /// stroke (join, cap, dash) is too big to keep inline (DesignNodeStackTests).
    public var stroke: DesignStroke? {
        get { extras.value.stroke }
        set { extras.value.stroke = newValue }
    }
    /// How a text node's text is set; every other kind keeps `.default`.
    public var textStyle: DesignTextStyle
    /// The kernel's gradient fill, its points in the node's unit box (0...1 across its frame), so a
    /// resize never touches it; nil paints `fill` (solid). Written only when set (gradient-fill DG-1).
    public var gradient: Fill? {
        get { extras.value.gradient }
        set { extras.value.gradient = newValue }
    }
    /// The kernel's picture this rectangle or frame shows in its frame (the frame is the picture's box);
    /// nil for none, and always nil on other kinds. Written only when set (placed-images PD-1).
    public var placedAsset: PlacedAsset? {
        get { extras.value.placedAsset }
        set { extras.value.placedAsset = newValue }
    }
    /// The point of the picture (unit, 0.5 centre) its cover crop keeps in view. Written only when not the centre.
    public var placedFocus: Point {
        get { extras.value.placedFocus }
        set { extras.value.placedFocus = newValue }
    }
    /// The turn, clockwise degrees about the frame's centre, (-180, 180]; `frame` stays the unturned box,
    /// so snapping, resize and the layer list never see it. Written only when not 0 (transform DT-1).
    public var rotation: Double = 0
    /// Mirrored left to right and top to bottom about the frame's centre. Written only when set.
    public var flipX = false, flipY = false
    /// A shape node's polygon, star, line or arrow, drawn in `frame` by ShapeRules; nil for every other
    /// kind. Written only when set (shape-tools DS-1).
    public var shape: ShapeSpec? {
        get { extras.value.shape }
        set { extras.value.shape = newValue }
    }
    /// The stroke, gradient, shape spec and picture, on the heap so a node stays small on a thread's stack (DesignNodeExtras).
    private var extras = DesignNodeExtrasBox()

    /// The focus a new picture starts with, and the one a file without the key opens with.
    static let centreFocus = Point(x: 0.5, y: 0.5)

    public init(
        id: String, name: String, kind: DesignNodeKind, frame: DesignRect,
        children: [DesignNode] = [], isHidden: Bool = false, isLocked: Bool = false,
        fill: DesignColor? = nil, text: String = "", cornerRadius: Double = 0,
        opacity: Double = 1, stroke: DesignStroke? = nil, textStyle: DesignTextStyle = .default,
        gradient: Fill? = nil, placedAsset: PlacedAsset? = nil, placedFocus: Point? = nil
    ) {
        (self.id, self.name, self.kind, self.frame) = (id, name, kind, frame)
        (self.children, self.isHidden, self.isLocked) = (children, isHidden, isLocked)
        (self.fill, self.text, self.cornerRadius) = (fill ?? kind.defaultFill, text, cornerRadius)
        (self.opacity, self.textStyle) = (opacity, textStyle)
        if stroke != nil { self.stroke = stroke }  // a plain node keeps the shared empty box
        if gradient != nil { self.gradient = gradient }
        if kind.holdsPicture, placedAsset != nil { self.placedAsset = placedAsset }
        if let placedFocus, placedFocus != Self.centreFocus { self.placedFocus = placedFocus }
    }

    /// `node` with every field kept and the id replaced (duplicate, paste). A field added to
    /// DesignNode is copied here too.
    public init(id: String, copying node: DesignNode) {
        self.init(
            id: id, name: node.name, kind: node.kind, frame: node.frame, children: node.children,
            isHidden: node.isHidden, isLocked: node.isLocked, fill: node.fill, text: node.text,
            cornerRadius: node.cornerRadius, opacity: node.opacity, stroke: node.stroke, textStyle: node.textStyle)
        extras = node.extras
        rotation = node.rotation
        (flipX, flipY) = (node.flipX, node.flipY)
    }

    /// Decodes a node; a field a file written before it existed lacks takes its default: square
    /// corners, fully opaque, no stroke, the default text style, no gradient, no picture, upright and unmirrored, no shape spec.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(String.self, forKey: .id), name: container.decode(String.self, forKey: .name),
            kind: container.decode(DesignNodeKind.self, forKey: .kind), frame: container.decode(DesignRect.self, forKey: .frame),
            children: container.decode([DesignNode].self, forKey: .children),
            isHidden: container.decode(Bool.self, forKey: .isHidden), isLocked: container.decode(Bool.self, forKey: .isLocked),
            fill: container.decode(DesignColor.self, forKey: .fill), text: container.decode(String.self, forKey: .text),
            cornerRadius: container.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? 0,
            opacity: container.decodeIfPresent(Double.self, forKey: .opacity) ?? 1,
            stroke: Self.stroke(in: container),
            textStyle: container.decodeIfPresent(DesignTextStyle.self, forKey: .textStyle) ?? .default,
            gradient: container.decodeIfPresent(Fill.self, forKey: .gradient),
            placedAsset: container.decodeIfPresent(PlacedAsset.self, forKey: .placedAsset),
            placedFocus: container.decodeIfPresent(Point.self, forKey: .placedFocus))
        rotation = try container.decodeIfPresent(Double.self, forKey: .rotation) ?? 0
        flipX = try container.decodeIfPresent(Bool.self, forKey: .flipX) ?? false
        flipY = try container.decodeIfPresent(Bool.self, forKey: .flipY) ?? false
        if let shape = try container.decodeIfPresent(ShapeSpec.self, forKey: .shape) { self.shape = shape }
    }

    /// The stroke as saved now (the kernel's), else as a file written before stroke-style saved it: a colour in
    /// 0...255 bytes and a width, with the default join and cap; nil when there is none.
    private static func stroke(in container: KeyedDecodingContainer<CodingKeys>) throws -> DesignStroke? {
        if let stroke = try? container.decodeIfPresent(DesignStroke.self, forKey: .stroke) { return stroke }
        return try container.decodeIfPresent(OldStroke.self, forKey: .stroke).map { DesignStroke(color: $0.color, width: $0.width) }
    }

    /// A stroke as files before stroke-style held it.
    private struct OldStroke: Decodable { var color: DesignColor; var width: Double }

    /// The file's keys, one per stored field.
    enum CodingKeys: String, CodingKey {
        case id, name, kind, frame, children, isHidden, isLocked, fill, text, cornerRadius, opacity, stroke, textStyle
        case gradient, placedAsset, placedFocus, rotation, flipX, flipY, shape
    }

    /// Encodes a node as before transforms, adding the turn, each mirror, a shape's spec, a picture and a moved
    /// focus only when set, so a file of upright nodes is written byte for byte as an older build wrote it.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(kind, forKey: .kind)
        try container.encode(frame, forKey: .frame)
        try container.encode(children, forKey: .children)
        try container.encode(isHidden, forKey: .isHidden)
        try container.encode(isLocked, forKey: .isLocked)
        try container.encode(fill, forKey: .fill)
        try container.encode(text, forKey: .text)
        try container.encode(cornerRadius, forKey: .cornerRadius)
        try container.encode(opacity, forKey: .opacity)
        try container.encodeIfPresent(stroke, forKey: .stroke)
        try container.encode(textStyle, forKey: .textStyle)
        try container.encodeIfPresent(gradient, forKey: .gradient)
        try container.encodeIfPresent(placedAsset, forKey: .placedAsset)
        if placedFocus != Self.centreFocus { try container.encode(placedFocus, forKey: .placedFocus) }
        if rotation != 0 { try container.encode(rotation, forKey: .rotation) }
        if flipX { try container.encode(flipX, forKey: .flipX) }
        if flipY { try container.encode(flipY, forKey: .flipY) }
        try container.encodeIfPresent(shape, forKey: .shape)
    }

    /// Shifts this node and everything under it by `delta`.
    mutating func translate(by delta: DesignPoint) {
        frame.x += delta.x
        frame.y += delta.y
        for index in children.indices { children[index].translate(by: delta) }
    }
}

/// One row of the tree flattened under an expanded set: a node at its nesting depth.
public struct DesignRow: Identifiable, Sendable, Hashable {
    public let node: DesignNode
    public let depth: Int  // 0 at the top level, one more per enclosing parent

    public var id: String { node.id }
}

/// Why a tree or page edit was refused.
public enum DesignTreeError: Error, Equatable, Sendable, CustomStringConvertible {
    case unknownID(String), notAContainer(String), intoItself(String)
    case emptyName, lastPage, alreadyExists(String)
    case locked(String), notText(String), emptyText
    /// The node's kind has no corners to round (DesignCorners).
    case noCorners(String)

    /// Plain words for a command catalog's refusal (the CLI, MCP), never the case name.
    public var description: String {
        switch self {
        case .unknownID(let id): DesignRefusal.unknownID(id).help
        case .notAContainer(let id): DesignRefusal.notAContainer(id).help
        case .intoItself(let id): DesignRefusal.intoItself(id).help
        case .emptyName: DesignRefusal.emptyName.help
        case .lastPage: "A file keeps at least one page."
        case .alreadyExists(let id): "\(id) is already in this file."
        case .locked(let id): DesignRefusal.locked(id).help
        case .notText(let id): DesignRefusal.notText(id).help
        case .emptyText: "Text can't be empty."
        case .noCorners(let id): DesignRefusal.noCorners(id).help
        }
    }
}

/// Modifier keys that change a drag: Shift constrains (square, aspect), Option works from the center.
public struct DesignModifiers: OptionSet, Sendable, Hashable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let shift = DesignModifiers(rawValue: 1)
    public static let option = DesignModifiers(rawValue: 2)

    /// The kernel's modifiers: Shift and Option. `noSnap` stays Design's.
    var editModifiers: EditModifiers {
        var modifiers: EditModifiers = []
        if contains(.shift) { modifiers.insert(.shift) }
        if contains(.option) { modifiers.insert(.option) }
        return modifiers
    }
}

public enum DesignDirection: Sendable, CaseIterable { case up, down, left, right }

extension [DesignNode] {
    /// These siblings as the Layers panel lists them: frontmost first, the reverse of paint order.
    public var frontToBack: [DesignNode] { reversed() }

    /// Rows in display order: siblings frontmost first, each node's children under it, shown only
    /// when its id is in `expanded`. The kernel's `LayerTree.rows` walks the tree; each row
    /// carries the node with that id.
    func rows(expanded: Set<String>) -> [DesignRow] {
        let nodes = byID
        return layerTree.rows(expanded: expanded).compactMap { row in
            nodes[row.id].map { DesignRow(node: $0, depth: row.depth) }
        }
    }

    /// Every node in the tree by id.
    private var byID: [String: DesignNode] {
        var out: [String: DesignNode] = [:]
        var stack = self
        while let node = stack.popLast() {
            out[node.id] = node
            stack += node.children
        }
        return out
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

    /// The ids of every node that encloses any of `ids`, in one walk of the tree, however many
    /// ids there are (a marquee or a duplicate of thousands of layers asks for them all at once).
    func ancestors(ofAny ids: Set<String>) -> Set<String> {
        var found = Set<String>(), path: [String] = []
        func walk(_ nodes: [DesignNode]) {
            for node in nodes {
                if ids.contains(node.id) { found.formUnion(path) }
                guard !node.children.isEmpty else { continue }
                path.append(node.id)
                walk(node.children)
                path.removeLast()
            }
        }
        walk(self)
        return found
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
            if node.contains(point) { return node.id }
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

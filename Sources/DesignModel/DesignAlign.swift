// DesignAlign.swift: the six align edges and Object > Align for the single
// selected layer (#417). Each edge moves the layer, with its subtree, so that
// edge lines up with the same edge of its align bounds: the nearest enclosing
// frame, or the page's bounds for a layer in no frame. A group is not a bound;
// a layer in a group aligns to the frame around the group. The bounds and the
// hidden-ancestor test live on DesignPage, so LiveAligning (several layers,
// Distribute) reuses the one-layer rule on a page without the workspace.
//
// Invariants:
// - Each command is one undo step named after it ("Align Left"), never merged
//   with the next, through the same editNode path the inspector's frame edits use.
// - `alignHelp` is nil exactly when `alignLayer` would move the layer, so a
//   command that is off never changes anything. The target is computed from the
//   bounds and the layer's size only, so a repeat lands on the same value.
// Linux-safe: no UI imports.

/// One of the six align commands: three horizontal, three vertical.
public enum DesignAlignEdge: String, CaseIterable, Sendable {
    case left, center, right, top, middle, bottom

    /// The command's name, its menu title and its undo step: "Align Left".
    public var title: String {
        switch self {
        case .left: "Align Left"
        case .center: "Align Center"
        case .right: "Align Right"
        case .top: "Align Top"
        case .middle: "Align Middle"
        case .bottom: "Align Bottom"
        }
    }

    /// The SF Symbol for the command.
    public var systemImage: String {
        switch self {
        case .left: "align.horizontal.left"
        case .center: "align.horizontal.center"
        case .right: "align.horizontal.right"
        case .top: "align.vertical.top"
        case .middle: "align.vertical.center"
        case .bottom: "align.vertical.bottom"
        }
    }

    /// Why the command is off when the layer already sits there.
    var alreadyHelp: String {
        switch self {
        case .left: "The layer is already at the left edge."
        case .center: "The layer is already centered."
        case .right: "The layer is already at the right edge."
        case .top: "The layer is already at the top edge."
        case .middle: "The layer is already in the middle."
        case .bottom: "The layer is already at the bottom edge."
        }
    }

    /// Where `frame`'s origin goes so this edge lines up with `bounds`' same edge.
    func origin(of frame: DesignRect, in bounds: DesignRect) -> DesignPoint {
        switch self {
        case .left: DesignPoint(x: bounds.x, y: frame.y)
        case .center: DesignPoint(x: bounds.x + (bounds.width - frame.width) / 2, y: frame.y)
        case .right: DesignPoint(x: bounds.maxX - frame.width, y: frame.y)
        case .top: DesignPoint(x: frame.x, y: bounds.y)
        case .middle: DesignPoint(x: frame.x, y: bounds.y + (bounds.height - frame.height) / 2)
        case .bottom: DesignPoint(x: frame.x, y: bounds.maxY - frame.height)
        }
    }
}

extension DesignPage {
    /// What node `id` aligns inside on its own: its nearest enclosing frame, or the page's bounds
    /// when no frame encloses it. Nil for an id not on this page.
    func alignBounds(_ id: String) -> DesignRect? {
        guard let path = nodes.ancestors(of: id) else { return nil }
        let frame = path.reversed().lazy.compactMap { nodes.node($0) }.first { $0.kind == .frame }
        return frame?.frame ?? DesignRect(x: 0, y: 0, width: frameWidth, height: frameHeight)
    }

    /// Where `node`'s origin goes for `edge` aligned on its own; nil when the bounds are unknown or
    /// the result isn't finite.
    func alignOrigin(_ edge: DesignAlignEdge, of node: DesignNode) -> DesignPoint? {
        guard let bounds = alignBounds(node.id) else { return nil }
        let target = edge.origin(of: node.frame, in: bounds)
        return target.isFinite ? target : nil
    }

    /// Whether a node enclosing `id` (not `id` itself) is hidden.
    func hasHiddenAncestor(_ id: String) -> Bool {
        nodes.ancestors(of: id)?.contains { nodes.node($0)?.isHidden == true } == true
    }
}

extension DesignWorkspace {
    /// What node `id` aligns inside: its nearest enclosing frame, or its page's bounds when no
    /// frame encloses it. Nil for an id on no page.
    public func alignBounds(_ id: String) -> DesignRect? {
        page(holding: id)?.alignBounds(id)
    }

    /// Why `edge` can't align the selected layer now, or nil when it can.
    public func alignHelp(_ edge: DesignAlignEdge) -> String? {
        guard let node = selectedNode else { return "Select a layer to align it." }
        if let multipleSelectionHelp { return multipleSelectionHelp }
        if editingTextID != nil { return "Finish editing the text first." }
        if let lockHelp = lockHelp(node.id) { return lockHelp }
        if page(holding: node.id)?.hasHiddenAncestor(node.id) == true { return "Show the group around this layer to align it." }
        guard let target = alignOrigin(edge, of: node) else { return "The layer can't be aligned." }
        return target == DesignPoint(x: node.frame.x, y: node.frame.y) ? edge.alreadyHelp : nil
    }

    /// Why each align command is off now, keyed by edge; an edge left out can run.
    public var alignHelps: [DesignAlignEdge: String] {
        Dictionary(uniqueKeysWithValues: DesignAlignEdge.allCases.compactMap { edge in alignHelp(edge).map { (edge, $0) } })
    }

    /// Moves the selected layer so `edge` lines up with its align bounds: one undo step named
    /// after the command. Does nothing when `alignHelp(edge)` gives a reason.
    public mutating func alignLayer(_ edge: DesignAlignEdge) {
        guard alignHelp(edge) == nil, let node = selectedNode, let target = alignOrigin(edge, of: node) else { return }
        let delta = DesignPoint(x: target.x - node.frame.x, y: target.y - node.frame.y)
        // alignHelp nil means the id is known and unlocked, so editNode can't refuse it.
        try? editNode(node.id, named: edge.title) { $0.translate(by: delta) }
    }

    private func alignOrigin(_ edge: DesignAlignEdge, of node: DesignNode) -> DesignPoint? {
        page(holding: node.id)?.alignOrigin(edge, of: node)
    }

    private func page(holding id: String) -> DesignPage? {
        pages.first { $0.nodes.node(id) != nil }
    }
}

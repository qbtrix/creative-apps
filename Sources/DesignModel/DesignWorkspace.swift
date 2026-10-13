// DesignWorkspace.swift: the state behind Design's window: pages with their node
// trees, the selected page and node, the expanded Layers rows, the tool, the
// inline text edit and the undo history. Linux-safe. DesignApp changes it only
// through the methods here and in the extensions beside it (DesignHistory,
// DesignCanvasEditing, DesignDrawing, DesignText, DesignFile).
//
// Invariants:
// - An open file keeps a page; a selected node is on the selected page; ids are
//   never reused within a file (undo restores the id counters as a max).
// - `held` holds exactly the page and node ids on the pages; every change that
//   adds or removes an id updates it, so minting never walks the tree (#433).
// - Every node frame is absolute page points, children included (DesignNode).
// - Every document edit records exactly one named undo step (DesignHistory). A
//   refused call (it throws, names an unknown id, hits a locked node, or changes
//   nothing) records nothing and leaves the workspace as it was.
// - Selection, expansion, tool and zoom are not edits. Undo restores the
//   selection an edit had, but not the expanded rows.
// - Every palette tool acts through `drag(from:to:modifiers:)` and `endDrag()`; a
//   tool that does nothing there stays disabled with `unavailableHelp`
//   (DesignToolsTests checks this).

/// A page of a design file: one canvas holding a tree of nodes.
public struct DesignPage: Identifiable, Sendable, Hashable, Codable {
    public let id: String
    public var name: String
    /// The page's default frame size in points.
    public var frameWidth: Double
    public var frameHeight: Double
    /// Top-level nodes, back to front.
    public var nodes: [DesignNode] = []

    /// The tree as rows, frontmost first among siblings: each node, then its children when its id
    /// is in `expanded`.
    public func visibleRows(expanded: Set<String>) -> [DesignRow] {
        nodes.rows(expanded: expanded)
    }

    /// "1440 × 1024 pt": the frame size in whole points.
    public var sizeText: String {
        func whole(_ value: Double) -> Int { value.isFinite ? Int(Swift.max(Swift.min(value, 1e9), -1e9).rounded()) : 0 }
        return "\(whole(frameWidth)) × \(whole(frameHeight)) pt"
    }
}

/// The tools on Design's tool palette.
public enum DesignTool: String, CaseIterable, Sendable {
    case move, frame, rectangle, ellipse, text, pen

    /// Why the palette shows this tool disabled, as its tooltip; nil once the
    /// tool works. Set it to nil in the change that makes `drag` do something.
    public var unavailableHelp: String? {
        switch self {
        case .move, .frame, .rectangle, .ellipse, .text: nil
        case .pen: "Drawing paths isn't built yet."
        }
    }

    public var isEnabled: Bool { unavailableHelp == nil }

    /// The kind of node this tool draws; nil for Move and Pen.
    public var nodeKind: DesignNodeKind? {
        switch self {
        case .frame: .frame
        case .rectangle: .rectangle
        case .ellipse: .ellipse
        case .text: .text
        case .move, .pen: nil
        }
    }
}

public struct DesignWorkspace: Sendable, Equatable {
    /// Pages of the open file; empty when no file is open.
    public internal(set) var pages: [DesignPage] = []
    public internal(set) var selectedPageID: String?
    public internal(set) var selectedNodeID: String?
    public internal(set) var expandedNodeIDs: Set<String> = []
    public internal(set) var tool: DesignTool = .move
    /// The text node being edited inline, and its live text (DesignText).
    public internal(set) var editingTextID: String?
    public internal(set) var textDraft = ""
    /// How far from a selection handle, in document points, still grabs it.
    public private(set) var handleTolerance = 6.0
    var pageCount = 0
    var nodeCount = 0
    /// Every page and node id, kept current with the pages (DesignHeldIDs).
    var held = DesignHeldIDs()
    var history = DesignHistory()
    /// The pointer gesture between its first `drag` and `endDrag`.
    var gesture: DesignGesture?
    /// A text node placed by a Text click, until its edit commits or cancels.
    var placedText: DesignPlacedText?

    public init() {}

    public var isOpen: Bool { !pages.isEmpty }

    public var selectedPage: DesignPage? {
        pages.first { $0.id == selectedPageID }
    }

    public var selectedNode: DesignNode? { selectedNodeID.flatMap { selectedPage?.nodes.node($0) } }

    /// The selected page's tree as rows under the current expanded set, as the Layers panel shows it.
    public var layerRows: [DesignRow] { selectedPage?.visibleRows(expanded: expandedNodeIDs) ?? [] }

    /// Opens a new file with one desktop-sized page holding a "Desktop" frame the size of the page.
    /// Over an open file it is the undo step "New File", so Undo brings the old file back.
    public mutating func newFile() {
        endDrag()
        commitTextEdit()
        let before = snapshot
        let wasOpen = isOpen
        (pages, pageCount, nodeCount) = ([], 0, 0)
        held.replace(with: [])
        let page = nextPage()
        (pages, selectedPageID, selectedNodeID, expandedNodeIDs) = ([page], page.id, nil, [])
        if wasOpen { record("New File", before: before, swapsDocument: true) }
    }

    /// Replaces the document with `pages` (the file codec opens a file through this): selects the
    /// first page, clears the history, any drag or inline edit and the expanded rows, and starts
    /// the id counters past the highest "page-N" and "node-N" in the file. Ids at or past the cap
    /// don't move the counters, but minting skips them, so a new id never repeats one (#296).
    mutating func load(_ pages: [DesignPage]) {
        self.pages = pages
        held.scan(pages)
        (selectedPageID, selectedNodeID, expandedNodeIDs) = (pages.first?.id, nil, [])
        (history, gesture, placedText) = (DesignHistory(), nil, nil)
        (editingTextID, textDraft) = (nil, "")
        func highest(_ prefix: String, _ ids: [String]) -> Int {
            // Numbers this large never come from a counter, and +1 on them would overflow.
            ids.compactMap { $0.hasPrefix(prefix) ? Int($0.dropFirst(prefix.count)) : nil }.filter { (0..<1_000_000_000).contains($0) }.max() ?? 0
        }
        func nodeIDs(_ nodes: [DesignNode]) -> [String] { nodes.flatMap { [$0.id] + nodeIDs($0.children) } }
        pageCount = highest("page-", pages.map(\.id))
        nodeCount = highest("node-", pages.flatMap { nodeIDs($0.nodes) })
    }

    /// Appends a page named after its number, holding the same "Desktop" frame New File seeds,
    /// and selects it. No-op with no file open.
    public mutating func addPage() {
        guard isOpen else { return }
        commitTextEdit()
        let before = snapshot
        let page = nextPage()
        pages.append(page)
        selectPage(page.id)
        record("Add Page", before: before)
    }

    public mutating func renamePage(_ id: String, to name: String) throws(DesignTreeError) {
        guard !name.allSatisfy(\.isWhitespace) else { throw .emptyName }
        guard let index = pages.firstIndex(where: { $0.id == id }) else { throw .unknownID(id) }
        let before = snapshot
        pages[index].name = name
        record("Rename Page", before: before)
    }

    /// Whether Delete Page can act: a page is selected and it is not the file's last one.
    public var canDeletePage: Bool { selectedPage != nil && pages.count > 1 }

    /// Deletes a page; the last page is refused. Deleting the selected page selects its neighbor.
    /// Undo brings the page back with its nodes and the selection it had.
    public mutating func deletePage(_ id: String) throws(DesignTreeError) {
        guard let index = pages.firstIndex(where: { $0.id == id }) else { throw .unknownID(id) }
        guard pages.count > 1 else { throw .lastPage }
        commitTextEdit()
        let before = snapshot
        held.remove(pages.remove(at: index))
        if selectedPageID == id { selectPage(pages[Swift.min(index, pages.count - 1)].id) }
        record("Delete Page", before: before)
    }

    /// Selects a page by id and clears the node selection, even when the page is already
    /// selected, so clicking its row deselects the layer. An unknown id is ignored.
    public mutating func selectPage(_ id: String) {
        guard pages.contains(where: { $0.id == id }) else { return }
        commitTextEdit()
        (selectedPageID, selectedNodeID) = (id, nil)
    }

    /// Selects the page or node `id` names; a node on another page switches to that page.
    /// A selected node's enclosing rows expand so its own row shows. An unknown id is ignored.
    public mutating func selectItem(_ id: String) {
        if pages.contains(where: { $0.id == id }) { return selectPage(id) }
        guard let page = pages.first(where: { $0.nodes.node(id) != nil }) else { return }
        commitTextEdit()
        selectedPageID = page.id
        selectedNodeID = id
        expandAncestors(of: id, in: page.nodes)
    }

    /// Clears the node selection; the page stays selected.
    public mutating func deselect() {
        commitTextEdit()
        selectedNodeID = nil
    }

    /// Expands every node that encloses `id` in `nodes`, so `id`'s own Layers row shows.
    mutating func expandAncestors(of id: String, in nodes: [DesignNode]) {
        expandedNodeIDs.formUnion(nodes.ancestors(of: id) ?? [])
    }

    /// Whether `id`'s Layers row shows its children.
    public func isExpanded(_ id: String) -> Bool { expandedNodeIDs.contains(id) }

    /// Shows or hides a node's children in Layers. Refused for an id on no page. Collapsing a
    /// row that encloses the selection selects that row, so the selection never hides (#121).
    public mutating func setExpanded(_ id: String, _ isExpanded: Bool) throws(DesignTreeError) {
        guard pages.contains(where: { $0.nodes.node(id) != nil }) else { throw .unknownID(id) }
        guard !isExpanded else {
            expandedNodeIDs.insert(id)
            return
        }
        expandedNodeIDs.remove(id)
        if let selected = selectedNodeID, selectedPage?.nodes.ancestors(of: selected)?.contains(id) == true {
            selectItem(id)
        }
    }

    /// Flips a node's Layers disclosure. Refused for an id on no page.
    public mutating func toggleExpanded(_ id: String) throws(DesignTreeError) {
        try setExpanded(id, !isExpanded(id))
    }

    /// Adds a node of `kind` to the selected page, inside `parentID` or at the top, and selects it.
    /// Every enclosing row expands, so the new node's row shows. A text node starts as "Text".
    @discardableResult
    public mutating func addNode(
        _ kind: DesignNodeKind, frame: DesignRect, in parentID: String? = nil
    ) throws(DesignTreeError) -> String {
        let before = snapshot
        let id = try insertNode(kind, frame: frame, in: parentID)
        record("Add \(kind.defaultName)", before: before)
        return id
    }

    /// `addNode` without the undo step: the gestures use it, and record their own.
    mutating func insertNode(_ kind: DesignNodeKind, frame: DesignRect, in parentID: String?) throws(DesignTreeError) -> String {
        guard let pageIndex = pages.firstIndex(where: { $0.id == selectedPageID }) else {
            throw .unknownID(selectedPageID ?? "")
        }
        // Take the id only once the parent accepts the node, so a refused add changes nothing.
        let number = nextNodeNumber()
        let node = DesignNode(
            id: "node-\(number)", name: kind.defaultName, kind: kind, frame: frame, text: kind == .text ? "Text" : "")
        try pages[pageIndex].nodes.add(node, to: parentID)
        nodeCount = number
        held.insert(node.id)
        expandAncestors(of: node.id, in: pages[pageIndex].nodes)
        selectedNodeID = node.id
        return node.id
    }

    /// Moves a node to the end of `parentID`'s children (nil: its page's top). Refused into a non-container or its own subtree.
    /// Every enclosing row expands, so the moved node's row shows.
    public mutating func moveNode(_ id: String, into parentID: String?) throws(DesignTreeError) {
        guard let pageIndex = pages.firstIndex(where: { $0.nodes.node(id) != nil }),
            let node = pages[pageIndex].nodes.node(id)
        else { throw .unknownID(id) }
        if let parentID, parentID == id || node.children.node(parentID) != nil { throw .intoItself(parentID) }
        // Edit a copy, so a refused destination leaves the page unchanged.
        var nodes = pages[pageIndex].nodes
        _ = nodes.remove(id)
        try nodes.add(node, to: parentID)
        let before = snapshot
        pages[pageIndex].nodes = nodes
        expandAncestors(of: id, in: nodes)
        record("Move Layer", before: before)
    }

    public mutating func renameNode(_ id: String, to name: String) throws(DesignTreeError) {
        guard !name.allSatisfy(\.isWhitespace) else { throw .emptyName }
        try updateNode(id, named: "Rename Layer") { $0.name = name }
    }

    public mutating func setNodeHidden(_ id: String, _ isHidden: Bool) throws(DesignTreeError) {
        try updateNode(id, named: isHidden ? "Hide Layer" : "Show Layer") { $0.isHidden = isHidden }
    }

    public mutating func setNodeLocked(_ id: String, _ isLocked: Bool) throws(DesignTreeError) {
        try updateNode(id, named: isLocked ? "Lock Layer" : "Unlock Layer") { $0.isLocked = isLocked }
    }

    /// Sets a node's frame, as the inspector's X, Y, W and H do. A non-finite part keeps its old
    /// value and width and height stay at least 1. Changing x or y moves the node's subtree with
    /// it; changing the size leaves its children. A run of changes to one node is one step.
    public mutating func setNodeFrame(_ id: String, x: Double, y: Double, width: Double, height: Double) throws(DesignTreeError) {
        guard let old = findNode(id)?.frame else { throw .unknownID(id) }
        let new = DesignRect(
            x: x.isFinite ? x : old.x, y: y.isFinite ? y : old.y,
            width: width.isFinite ? Swift.max(width, 1) : old.width, height: height.isFinite ? Swift.max(height, 1) : old.height)
        try editNode(id, named: "Change Frame", coalescing: "frame-\(id)") { node in
            node.translate(by: DesignPoint(x: new.x - old.x, y: new.y - old.y))
            node.frame = new
        }
    }

    /// Sets a node's fill (a text node's color). Refused for a locked node. A run is one step.
    public mutating func setFill(_ id: String, _ color: DesignColor) throws(DesignTreeError) {
        try editNode(id, named: "Change Fill", coalescing: "fill-\(id)") { $0.fill = color }
    }

    public mutating func selectTool(_ tool: DesignTool) {
        endDrag()
        commitTextEdit()
        self.tool = tool
    }

    /// Sets how far from a handle a press still grabs it, in document points. The window keeps it
    /// at a constant screen size by dividing by the zoom. Ignores non-finite or non-positive values.
    public mutating func setHandleTolerance(_ points: Double) {
        if points.isFinite, points > 0 { handleTolerance = points }
    }

    // MARK: Editing helpers

    /// The node `id` on any page.
    func findNode(_ id: String) -> DesignNode? {
        pages.lazy.compactMap { $0.nodes.node(id) }.first
    }

    /// Changes node `id` as one named step; unlike `editNode`, a locked node can change.
    private mutating func updateNode(_ id: String, named name: String, _ change: (inout DesignNode) -> Void) throws(DesignTreeError) {
        guard findNode(id) != nil else { throw .unknownID(id) }
        let before = snapshot
        _ = pages.update(id, change)
        record(name, before: before)
    }

    /// Changes the unlocked node `id` as one named step; an unknown or locked id throws first.
    /// With a `coalescing` key a run of calls with the same key is one step.
    mutating func editNode(
        _ id: String, named name: String, coalescing: String? = nil, _ change: (inout DesignNode) -> Void
    ) throws(DesignTreeError) {
        guard let node = findNode(id) else { throw .unknownID(id) }
        guard !node.isLocked else { throw .locked(id) }
        let before = snapshot
        _ = pages.update(id, change)
        record(name, before: before, coalescing: coalescing)
    }

    /// The next desktop-sized page, seeded with a "Desktop" frame the size of the page.
    /// New File and Add Page both start their page here.
    private mutating func nextPage() -> DesignPage {
        pageCount = held.firstFree("page-", after: pageCount)
        var page = DesignPage(id: "page-\(pageCount)", name: "Page \(pageCount)", frameWidth: 1440, frameHeight: 1024)
        let size = DesignRect(x: 0, y: 0, width: page.frameWidth, height: page.frameHeight)
        nodeCount = held.firstFree("node-", after: nodeCount)
        page.nodes = [DesignNode(id: "node-\(nodeCount)", name: "Desktop", kind: .frame, frame: size)]
        held.insert(page.id)
        held.insert("node-\(nodeCount)")
        return page
    }

    /// The first number past the node counter whose "node-N" no page or node holds yet.
    private func nextNodeNumber() -> Int {
        held.firstFree("node-", after: nodeCount)
    }
}

extension [DesignPage] {
    /// Applies `change` to the node `id` on whichever page holds it; returns whether it was found.
    mutating func update(_ id: String, _ change: (inout DesignNode) -> Void) -> Bool {
        for index in indices {
            if self[index].nodes.update(id, change) { return true }
        }
        return false
    }
}

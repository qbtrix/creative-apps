// DesignWorkspace.swift: the state behind Design's window: pages with their
// node trees, the selected page and node, the expanded Layers rows and the
// tool. Linux-safe. DesignApp changes it only through the methods here.
// Invariants: an open file keeps a page; a selected node is on the selected
// page; ids are never reused within a file.

/// A page of a design file: one canvas holding a tree of nodes.
public struct DesignPage: Identifiable, Sendable, Hashable {
    public let id: String
    public var name: String
    /// The page's default frame size in points.
    public var frameWidth: Double
    public var frameHeight: Double
    /// Top-level nodes, back to front.
    public var nodes: [DesignNode] = []

    /// The Layers rows: each node, then its children when its id is in `expanded`.
    public func visibleRows(expanded: Set<String>) -> [DesignRow] {
        nodes.rows(expanded: expanded)
    }
}

/// The tools on Design's tool palette.
public enum DesignTool: String, CaseIterable, Sendable {
    case move, frame, rectangle, text, pen
}

/// A page `deletePage` removed, with where it sat and the selection before the delete;
/// `restorePage` takes it back.
public struct DeletedPage: Sendable, Equatable {
    public let page: DesignPage
    public let index: Int
    public let selectedPageID: String?
    public let selectedNodeID: String?
    let file: Int
}

public struct DesignWorkspace: Sendable, Equatable {
    /// Pages of the open file; empty when no file is open.
    public private(set) var pages: [DesignPage] = []
    public private(set) var selectedPageID: String?
    public private(set) var selectedNodeID: String?
    public private(set) var expandedNodeIDs: Set<String> = []
    public private(set) var tool: DesignTool = .move
    private var pageCount = 0
    private var nodeCount = 0
    /// Bumped by each New File, so a page deleted from an earlier file cannot come back into this one.
    private var fileGeneration = 0

    public init() {}

    public var isOpen: Bool { !pages.isEmpty }

    public var selectedPage: DesignPage? {
        pages.first { $0.id == selectedPageID }
    }

    public var selectedNode: DesignNode? { selectedNodeID.flatMap { selectedPage?.nodes.node($0) } }

    /// The selected page's Layers rows under the current expanded set.
    public var layerRows: [DesignRow] { selectedPage?.visibleRows(expanded: expandedNodeIDs) ?? [] }

    /// Opens a new file with one desktop-sized page holding a "Desktop" frame the size of the page.
    public mutating func newFile() {
        (pageCount, nodeCount) = (0, 0)
        fileGeneration += 1
        var page = nextPage()
        let size = DesignRect(x: 0, y: 0, width: page.frameWidth, height: page.frameHeight)
        page.nodes = [DesignNode(id: nextNodeID(), name: "Desktop", kind: .frame, frame: size)]
        (pages, selectedPageID, selectedNodeID, expandedNodeIDs) = ([page], page.id, nil, [])
    }

    /// Appends an empty page named after its number and selects it. No-op with no file open.
    public mutating func addPage() {
        guard isOpen else { return }
        let page = nextPage()
        pages.append(page)
        selectPage(page.id)
    }

    public mutating func renamePage(_ id: String, to name: String) throws(DesignTreeError) {
        guard !name.allSatisfy(\.isWhitespace) else { throw .emptyName }
        guard let index = pages.firstIndex(where: { $0.id == id }) else { throw .unknownID(id) }
        pages[index].name = name
    }

    /// Whether Delete Page can act: a page is selected and it is not the file's last one.
    public var canDeletePage: Bool { selectedPage != nil && pages.count > 1 }

    /// Deletes a page; the last page is refused. Deleting the selected page selects its neighbor.
    /// Returns what `restorePage` needs to undo the delete.
    @discardableResult
    public mutating func deletePage(_ id: String) throws(DesignTreeError) -> DeletedPage {
        guard let index = pages.firstIndex(where: { $0.id == id }) else { throw .unknownID(id) }
        guard pages.count > 1 else { throw .lastPage }
        let deleted = DeletedPage(
            page: pages[index], index: index, selectedPageID: selectedPageID,
            selectedNodeID: selectedNodeID, file: fileGeneration)
        pages.remove(at: index)
        if selectedPageID == id { selectPage(pages[Swift.min(index, pages.count - 1)].id) }
        return deleted
    }

    /// Undoes `deletePage`: puts the page back at its index (clamped to the page count) with
    /// its nodes and ids, and restores the selection the delete changed. Refused once another
    /// file is opened, or when the page is already back.
    public mutating func restorePage(_ deleted: DeletedPage) throws(DesignTreeError) {
        let id = deleted.page.id
        guard isOpen, deleted.file == fileGeneration else { throw .unknownID(id) }
        guard !pages.contains(where: { $0.id == id }) else { throw .alreadyExists(id) }
        pages.insert(deleted.page, at: Swift.min(deleted.index, pages.count))
        if let pageID = deleted.selectedPageID, pages.contains(where: { $0.id == pageID }) {
            selectPage(pageID)
            if let nodeID = deleted.selectedNodeID, selectedPage?.nodes.node(nodeID) != nil {
                selectedNodeID = nodeID
            }
        }
    }

    /// Redoes a Delete Page that `restorePage` undid. Refused once another file is opened, so
    /// a stale redo cannot delete the new file's page that reuses the id.
    @discardableResult
    public mutating func redoDeletePage(_ deleted: DeletedPage) throws(DesignTreeError) -> DeletedPage {
        guard deleted.file == fileGeneration else { throw .unknownID(deleted.page.id) }
        return try deletePage(deleted.page.id)
    }

    /// Selects a page by id and clears the node selection, even when the page is already
    /// selected, so clicking its row deselects the layer. An unknown id is ignored.
    public mutating func selectPage(_ id: String) {
        guard pages.contains(where: { $0.id == id }) else { return }
        (selectedPageID, selectedNodeID) = (id, nil)
    }

    /// Selects the page or node `id` names; a node on another page switches to that page.
    /// A selected node's enclosing rows expand so its own row shows. An unknown id is ignored.
    public mutating func selectItem(_ id: String) {
        if pages.contains(where: { $0.id == id }) { return selectPage(id) }
        guard let page = pages.first(where: { $0.nodes.node(id) != nil }) else { return }
        selectedPageID = page.id
        selectedNodeID = id
        expandAncestors(of: id, in: page.nodes)
    }

    /// Expands every node that encloses `id` in `nodes`, so `id`'s own Layers row shows.
    private mutating func expandAncestors(of id: String, in nodes: [DesignNode]) {
        expandedNodeIDs.formUnion(nodes.ancestors(of: id) ?? [])
    }

    /// Whether `id`'s Layers row shows its children.
    public func isExpanded(_ id: String) -> Bool { expandedNodeIDs.contains(id) }

    /// Shows or hides a node's children in Layers. Refused for an id on no page.
    public mutating func setExpanded(_ id: String, _ isExpanded: Bool) throws(DesignTreeError) {
        guard pages.contains(where: { $0.nodes.node(id) != nil }) else { throw .unknownID(id) }
        if isExpanded { expandedNodeIDs.insert(id) } else { expandedNodeIDs.remove(id) }
    }

    /// Flips a node's Layers disclosure. Refused for an id on no page.
    public mutating func toggleExpanded(_ id: String) throws(DesignTreeError) {
        try setExpanded(id, !isExpanded(id))
    }

    /// Adds a node of `kind` to the selected page, inside `parentID` or at the top, and selects it.
    /// Every enclosing row expands, so the new node's row shows.
    @discardableResult
    public mutating func addNode(
        _ kind: DesignNodeKind, frame: DesignRect, in parentID: String? = nil
    ) throws(DesignTreeError) -> String {
        guard let pageIndex = pages.firstIndex(where: { $0.id == selectedPageID }) else {
            throw .unknownID(selectedPageID ?? "")
        }
        // Take the id only once the parent accepts the node, so a refused add changes nothing.
        let node = DesignNode(id: "node-\(nodeCount + 1)", name: kind.defaultName, kind: kind, frame: frame)
        try pages[pageIndex].nodes.add(node, to: parentID)
        _ = nextNodeID()
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
        pages[pageIndex].nodes = nodes
        expandAncestors(of: id, in: nodes)
    }

    public mutating func renameNode(_ id: String, to name: String) throws(DesignTreeError) {
        guard !name.allSatisfy(\.isWhitespace) else { throw .emptyName }
        try updateNode(id) { $0.name = name }
    }

    public mutating func setNodeHidden(_ id: String, _ isHidden: Bool) throws(DesignTreeError) {
        try updateNode(id) { $0.isHidden = isHidden }
    }

    public mutating func setNodeLocked(_ id: String, _ isLocked: Bool) throws(DesignTreeError) {
        try updateNode(id) { $0.isLocked = isLocked }
    }

    public mutating func selectTool(_ tool: DesignTool) {
        self.tool = tool
    }

    private mutating func updateNode(_ id: String, _ change: (inout DesignNode) -> Void) throws(DesignTreeError) {
        guard let index = pages.firstIndex(where: { $0.nodes.node(id) != nil }) else { throw .unknownID(id) }
        _ = pages[index].nodes.update(id, change)
    }

    private mutating func nextPage() -> DesignPage {
        pageCount += 1
        return DesignPage(id: "page-\(pageCount)", name: "Page \(pageCount)", frameWidth: 1440, frameHeight: 1024)
    }

    private mutating func nextNodeID() -> String {
        nodeCount += 1
        return "node-\(nodeCount)"
    }
}

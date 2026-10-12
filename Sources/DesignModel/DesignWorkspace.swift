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

public struct DesignWorkspace: Sendable, Equatable {
    /// Pages of the open file; empty when no file is open.
    public private(set) var pages: [DesignPage] = []
    public private(set) var selectedPageID: String?
    public private(set) var selectedNodeID: String?
    public private(set) var expandedNodeIDs: Set<String> = []
    public private(set) var tool: DesignTool = .move
    private var pageCount = 0
    private var nodeCount = 0

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

    /// Deletes a page; the last page is refused. Deleting the selected page selects its neighbor.
    public mutating func deletePage(_ id: String) throws(DesignTreeError) {
        guard let index = pages.firstIndex(where: { $0.id == id }) else { throw .unknownID(id) }
        guard pages.count > 1 else { throw .lastPage }
        pages.remove(at: index)
        if selectedPageID == id { selectPage(pages[Swift.min(index, pages.count - 1)].id) }
    }

    /// Selects a page by id and clears the node selection. An unknown id is ignored.
    public mutating func selectPage(_ id: String) {
        guard pages.contains(where: { $0.id == id }) else { return }
        if selectedPageID != id { selectedNodeID = nil }
        selectedPageID = id
    }

    /// Selects the page or node `id` names; a node on another page switches to that page.
    /// An unknown id is ignored.
    public mutating func selectItem(_ id: String) {
        if pages.contains(where: { $0.id == id }) { return selectPage(id) }
        guard let page = pages.first(where: { $0.nodes.node(id) != nil }) else { return }
        selectedPageID = page.id
        selectedNodeID = id
    }

    /// Adds a node of `kind` to the selected page, inside `parentID` or at the top, and selects it.
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
        if let parentID { expandedNodeIDs.insert(parentID) }
        selectedNodeID = node.id
        return node.id
    }

    /// Moves a node to the end of `parentID`'s children (nil: its page's top). Refused into a non-container or its own subtree.
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
        if let parentID { expandedNodeIDs.insert(parentID) }
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

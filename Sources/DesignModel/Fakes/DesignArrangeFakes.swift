// Fakes/DesignArrangeFakes.swift: the fixture fakes for the arrange area
// (duplicate, group and ungroup, the clipboard, stacking order, the inspector's
// style rows) and an in-memory file codec, so views, snapshots and fake-mode
// journeys build before the live types. Each keeps its protocol's undo case and
// the help law, acts anywhere in the tree and ignores locks and hidden layers.
// Stand-ins, never shipped as `.live`. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct FakeDuplicating: LayerDuplicating {
    public init() {}

    public func duplicateHelp(_ ids: [String], on page: DesignPage) -> String? { fakeSelectedHelp(ids, page) }

    /// Each copy right above its original in the same parent, moved by `offset`, unlocked.
    public func duplicate(_ ids: [String], offset: DesignPoint, on page: DesignPage,
                          mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit {
        let originals = fakeFind(ids, page)
        guard !originals.isEmpty else { throw .nothingSelected }
        var nodes = page.nodes
        var copies: [String] = []
        for original in originals {
            var copy = copySubtree(original, mint: &mint)
            copy.translate(by: offset)
            copy.isLocked = false
            let placed = copy
            nodes = fakeSiblings(page.nodes.ancestors(of: original.id)?.last, nodes) { siblings in
                let at = siblings.firstIndex { $0.id == original.id }.map { $0 + 1 } ?? siblings.count
                siblings.insert(placed, at: at)
            }
            copies.append(copy.id)
        }
        return DesignEdit(name: "Duplicate", nodes: nodes, selection: copies)
    }

    public func copySubtree(_ node: DesignNode, mint: inout DesignIDMint) -> DesignNode {
        var copy = node
        copy.children = node.children.map { copySubtree($0, mint: &mint) }
        return DesignNode(id: mint.nextNodeID(), copying: copy)
    }
}

public struct FakeGrouping: LayerGrouping {
    public init() {}

    public func groupHelp(_ ids: [String], on page: DesignPage) -> String? {
        fakeHelp { () throws(DesignRefusal) in
            var mint = DesignIDMint(taken: [], after: 0)
            return try group(ids, on: page, mint: &mint)
        }
    }

    /// The group's frame is the union; it takes the topmost member's place; nothing moves.
    public func group(_ ids: [String], on page: DesignPage, mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit {
        guard let box = fakeUnion(fakeFind(ids, page).map(\.frame)) else { throw .nothingSelected }
        let parent = try fakeSharedParent(ids, page)
        var made = DesignNode(id: mint.nextNodeID(), name: "Group", kind: .group, frame: box)
        let nodes = fakeSiblings(parent, page.nodes) { siblings in
            made.children = siblings.filter { ids.contains($0.id) }
            let top = siblings.lastIndex { ids.contains($0.id) } ?? siblings.count - 1
            siblings.insert(made, at: top + 1)
            siblings.removeAll { ids.contains($0.id) }
        }
        return DesignEdit(name: "Group", nodes: nodes, selection: [made.id])
    }

    public func ungroupHelp(_ ids: [String], on page: DesignPage) -> String? {
        fakeFind(ids, page).contains { $0.kind == .group } ? nil : DesignRefusal.notAGroup(ids.last ?? "The selection").help
    }

    public func ungroup(_ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        let groups = fakeFind(ids, page).filter { $0.kind == .group }
        guard !groups.isEmpty else { throw .notAGroup(ids.last ?? "The selection") }
        var nodes = page.nodes
        for group in groups {
            nodes = fakeSiblings(page.nodes.ancestors(of: group.id)?.last, nodes) { siblings in
                guard let at = siblings.firstIndex(where: { $0.id == group.id }) else { return }
                siblings.replaceSubrange(at...at, with: group.children)
            }
        }
        return DesignEdit(name: "Ungroup", nodes: nodes, selection: groups.flatMap { $0.children.map(\.id) })
    }
}

public struct FakeClipboard: LayerClipboard {
    /// What the fake puts on the pasteboard: the layers and the parent they came from.
    struct Payload: Codable {
        var parentID: String?
        var nodes: [DesignNode]
    }

    public init() {}

    public var pasteboardType: String { "org.creativesuite.design.layers" }

    public func copyHelp(_ ids: [String], on page: DesignPage) -> String? { fakeSelectedHelp(ids, page) }

    public func encode(_ ids: [String], on page: DesignPage) throws(DesignRefusal) -> Data {
        let nodes = fakeFind(ids, page)
        guard let first = nodes.first else { throw .nothingSelected }
        let payload = Payload(parentID: page.nodes.ancestors(of: first.id)?.last, nodes: nodes)
        do { return try JSONEncoder().encode(payload) } catch { throw .unreadable }
    }

    public func pasteHelp(_ data: Data?) -> String? {
        guard let data, Self.payload(data) != nil else { return DesignRefusal.unreadable.help }
        return nil
    }

    /// Fresh ids, offset by (10, 10); into `parentID`, else the parent the copies came from when it is
    /// on `page`, else the top level.
    public func paste(_ data: Data, into parentID: String?, on page: DesignPage,
                      mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit {
        guard let payload = Self.payload(data) else { throw .unreadable }
        let target = parentID ?? payload.parentID.flatMap { page.nodes.node($0) == nil ? nil : $0 }
        var pasted: [DesignNode] = []
        for node in payload.nodes {
            var copy = FakeDuplicating().copySubtree(node, mint: &mint)
            copy.translate(by: DesignPoint(x: 10, y: 10))
            pasted.append(copy)
        }
        let tree = fakeSiblings(target, page.nodes) { $0 += pasted }
        return DesignEdit(name: "Paste", nodes: tree, selection: pasted.map(\.id))
    }

    private static func payload(_ data: Data) -> Payload? {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data), !payload.nodes.isEmpty else { return nil }
        return payload
    }
}

public struct FakeOrdering: LayerOrdering {
    public init() {}

    public func moveHelp(_ id: String, into parentID: String?, at index: Int, on page: DesignPage) -> String? {
        fakeHelp { () throws(DesignRefusal) in try move(id, into: parentID, at: index, on: page) }
    }

    public func move(_ id: String, into parentID: String?, at index: Int,
                     on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        var nodes = page.nodes
        guard let node = nodes.remove(id) else { throw .unknownID(id) }
        if let parentID {
            guard parentID != id, node.children.node(parentID) == nil else { throw .intoItself(node.name) }
            guard let parent = nodes.node(parentID), parent.kind.holdsChildren else { throw .notAContainer(parentID) }
        }
        nodes = fakeSiblings(parentID, nodes) { $0.insert(node, at: Swift.min(Swift.max(index, 0), $0.count)) }
        guard nodes != page.nodes else { throw .unchanged }
        return DesignEdit(name: "Move Layer", nodes: nodes, selection: [id])
    }

    public func arrangeHelp(_ step: DesignArrangeStep, _ ids: [String], on page: DesignPage) -> String? {
        fakeSelectedHelp(ids, page)
    }

    /// The primary layer, within its own parent.
    public func arrange(_ step: DesignArrangeStep, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        guard let id = ids.last(where: { page.nodes.node($0) != nil }) else { throw .nothingSelected }
        let parent = page.nodes.ancestors(of: id)?.last
        let level = parent.flatMap { page.nodes.node($0)?.children } ?? page.nodes
        guard let from = level.firstIndex(where: { $0.id == id }) else { throw .unknownID(id) }
        let to = switch step {
        case .bringToFront: level.count - 1
        case .bringForward: Swift.min(from + 1, level.count - 1)
        case .sendBackward: Swift.max(from - 1, 0)
        case .sendToBack: 0
        }
        var edit = try move(id, into: parent, at: to, on: page)
        edit.name = step.title
        return edit
    }
}

public struct FakeStyling: StyleEditing {
    public init() {}

    public func styleHelp(_ property: DesignStyleProperty, _ ids: [String], on page: DesignPage) -> String? {
        fakeSelectedHelp(ids, page)
    }

    public func setFrame(_ field: DesignFrameField, to value: Double, _ ids: [String],
                         on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try fakeChange(ids, page, "Change Frame", key: "frame") { node in
            guard value.isFinite else { return }
            switch field {
            case .x: node.translate(by: DesignPoint(x: value - node.frame.x, y: 0))
            case .y: node.translate(by: DesignPoint(x: 0, y: value - node.frame.y))
            case .width: node.frame.width = Swift.max(value, 1)
            case .height: node.frame.height = Swift.max(value, 1)
            }
        }
    }

    public func setFill(_ color: DesignColor, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try fakeChange(ids, page, "Change Fill", key: "fill") { $0.fill = color }
    }

    public func setCornerRadius(_ radius: Double, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try fakeChange(ids, page, "Change Corner Radius", key: "radius") {
            $0.cornerRadius = Swift.min(Swift.max(radius, 0), Swift.min($0.frame.width, $0.frame.height) / 2)
        }
    }

    public func setOpacity(_ opacity: Double, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try fakeChange(ids, page, "Change Opacity", key: "opacity") { $0.opacity = Swift.min(Swift.max(opacity, 0), 1) }
    }

    public func setStroke(_ stroke: DesignStroke?, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try fakeChange(ids, page, "Change Stroke", key: "stroke") { $0.stroke = stroke }
    }

    public func setTextStyle(_ style: DesignTextStyle, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try fakeChange(ids, page, "Change Text Style", key: "text-style") { $0.textStyle = style }
    }
}

/// Keeps documents in memory as JSON; refuses bytes that don't decode.
public struct FakeFiling: DocumentFiling {
    public init() {}

    public func encode(_ document: DesignDocument) throws(DesignFileError) -> Data {
        do { return try JSONEncoder().encode(document.pages) } catch { throw .unreadable }
    }

    public func decode(_ data: Data) throws(DesignFileError) -> DesignDocument {
        guard let pages = try? JSONDecoder().decode([DesignPage].self, from: data) else { throw .unreadable }
        guard !pages.isEmpty else { throw .noPages }
        return DesignDocument(pages: pages)
    }
}

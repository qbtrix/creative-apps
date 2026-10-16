// DesignActions+Edit.swift: the Edit menu's clipboard (Copy, Cut, Paste), the Layers panel's
// Move Layer, and the inspector's style rows, each run through `services` on the selected page as
// one named undo step under the help law (EditContracts.swift). Paste goes into the selected frame
// when one is selected, else where the copies came from, else the top level (#415). With exactly
// one layer selected, the frame, fill and corner radius rows keep today's methods (`setNodeFrame`,
// `setFill`, `setCornerRadius`) and Cut deletes through today's `deleteSelection`, so they work on
// `.live` while its styling and transforming slots are NotBuilt. A refusal records nothing.
// Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One inspector change on every selected layer (one or several).
public enum DesignStyleChange: Hashable, Sendable {
    case frame(DesignFrameField, Double), fill(DesignColor)
    case cornerRadius(Double), opacity(Double), stroke(DesignStroke?), textStyle(DesignTextStyle)

    public var property: DesignStyleProperty {
        switch self {
        case .frame: .frame
        case .fill: .fill
        case .cornerRadius: .cornerRadius
        case .opacity: .opacity
        case .stroke: .stroke
        case .textStyle: .textStyle
        }
    }
}

extension DesignStyleProperty {
    /// Frame, fill and corner radius: with one layer selected they keep today's methods.
    var hasOneLayerMethod: Bool { self == .frame || self == .fill || self == .cornerRadius }
}

extension DesignWorkspace {
    /// The pasteboard type the bridge reads and writes.
    public var pasteboardType: String { services.clipboard.pasteboardType }

    /// Why Copy (and Cut) is off; nil when it can run.
    public func copyHelp() -> String? {
        guard let page = selectedPage, !selectedNodeIDs.isEmpty else { return DesignRefusal.nothingSelected.help }
        if editingTextID != nil { return Self.editingTextHelp }
        return services.clipboard.copyHelp(selectedNodeIDs, on: page)
    }

    /// The selected layers as pasteboard bytes; the document doesn't change.
    public func copySelection() throws(DesignRefusal) -> Data {
        guard let page = selectedPage, !selectedNodeIDs.isEmpty else { throw .nothingSelected }
        guard editingTextID == nil else { throw .unchanged }
        return try services.clipboard.encode(selectedNodeIDs, on: page)
    }

    /// Copy, then delete as one step named "Cut". One layer deletes through today's method.
    public mutating func cutSelection() throws(DesignRefusal) -> Data {
        let data = try copySelection()
        guard let page = selectedPage, let node = selectedNode else { throw .nothingSelected }
        var edit: DesignEdit
        if selectedNodeIDs.count == 1 {
            if isLockedInTree(node.id) { throw .locked(node.name) }
            var after = self
            after.deleteSelection()
            guard let nodes = after.selectedPage?.nodes, nodes != page.nodes else { throw .unchanged }
            edit = DesignEdit(name: "Cut", nodes: nodes, selection: after.selectedNodeIDs)
        } else {
            edit = try services.transforming.delete(selectedNodeIDs, on: page)
            (edit.name, edit.coalescingKey) = ("Cut", nil)
        }
        apply(edit)
        return data
    }

    /// Why Paste is off for the pasteboard's bytes (nil `data`: it holds none of our type).
    public func pasteHelp(_ data: Data?) -> String? {
        if editingTextID != nil { return Self.editingTextHelp }
        return services.clipboard.pasteHelp(data)
    }

    /// Into the selected frame, else where the copies came from, else the top level (#415).
    public mutating func paste(_ data: Data) throws(DesignRefusal) {
        guard let page = selectedPage, editingTextID == nil else { throw .unchanged }
        let frame = selectedNode.flatMap { $0.kind == .frame && !isLockedInTree($0.id) ? $0.id : nil }
        var mint = mint()
        let edit = try services.clipboard.paste(data, into: frame, on: page, mint: &mint)
        apply(edit, mint: mint)
    }

    /// Why layer `id` can't move into `parentID` at `index`; nil when it can.
    public func moveLayerHelp(_ id: String, into parentID: String?, at index: Int) -> String? {
        guard let page = selectedPage else { return DesignRefusal.unknownID(id).help }
        if editingTextID != nil { return Self.editingTextHelp }
        return services.ordering.moveHelp(id, into: parentID, at: index, on: page)
    }

    /// Moves layer `id` into `parentID` (nil: the top level) at `index`, as one "Move Layer" step.
    public mutating func moveLayer(_ id: String, into parentID: String?, at index: Int) throws(DesignRefusal) {
        guard let page = selectedPage, editingTextID == nil else { throw .unchanged }
        apply(try services.ordering.move(id, into: parentID, at: index, on: page))
    }

    /// Why the inspector's `property` row is off for the selection; nil when it can be set.
    public func styleHelp(_ property: DesignStyleProperty) -> String? {
        let ids = selectedNodeIDs
        guard let page = selectedPage, let id = ids.last else { return DesignRefusal.nothingSelected.help }
        if editingTextID != nil { return Self.editingTextHelp }
        if ids.count == 1, property.hasOneLayerMethod { return property == .cornerRadius ? cornerRadiusHelp : lockHelp(id) }
        return services.styling.styleHelp(property, ids, on: page)
    }

    /// Sets `change` on every selected layer as one step (a run of the same row is one step).
    public mutating func setStyle(_ change: DesignStyleChange) throws(DesignRefusal) {
        let ids = selectedNodeIDs
        guard let page = selectedPage, !ids.isEmpty else { throw .nothingSelected }
        guard editingTextID == nil else { throw .unchanged }
        if ids.count == 1, change.property.hasOneLayerMethod, let node = selectedNode {
            return try setOneLayerStyle(change, on: node)
        }
        let styling = services.styling
        let edit = switch change {
        case .frame(let field, let value): try styling.setFrame(field, to: value, ids, on: page)
        case .fill(let color): try styling.setFill(color, ids, on: page)
        case .cornerRadius(let radius): try styling.setCornerRadius(radius, ids, on: page)
        case .opacity(let opacity): try styling.setOpacity(opacity, ids, on: page)
        case .stroke(let stroke): try styling.setStroke(stroke, ids, on: page)
        case .textStyle(let style): try styling.setTextStyle(style, ids, on: page)
        }
        apply(edit)
    }

    /// The frame, fill or corner radius row on one layer through today's methods, which record
    /// their own coalescing step; their refusals come back as DesignRefusal.
    private mutating func setOneLayerStyle(_ change: DesignStyleChange, on node: DesignNode) throws(DesignRefusal) {
        do throws(DesignTreeError) {
            switch change {
            case .frame(let field, let value):
                let f = node.frame
                try setNodeFrame(
                    node.id, x: field == .x ? value : f.x, y: field == .y ? value : f.y,
                    width: field == .width ? value : f.width, height: field == .height ? value : f.height)
            case .fill(let color): try setFill(node.id, color)
            case .cornerRadius(let radius): try setCornerRadius(node.id, radius)
            case .opacity, .stroke, .textStyle: throw .unknownID(node.id)
            }
        } catch {
            switch error {
            case .locked: throw .locked(node.name)
            case .noCorners: throw .noCorners(node.name)
            default: throw .unknownID(node.id)
            }
        }
    }

    private static let editingTextHelp = "Finish editing the text first."
}

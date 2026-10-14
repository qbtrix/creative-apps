// FlareEdit.swift: the Edit menu (docs/blueprints/flare.md, sections 2 and 3.4). Each act is one named undo step (Cut
// is the workspace's own group: copy, then remove); Copy and Cut return the data the app puts on the pasteboard. An act
// that can't run gives its menu item's disabled reason in `editHelp` and refuses with that text.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore

/// An Edit menu item that acts on the stage.
public enum FlareEditAction: String, CaseIterable, Sendable {
    case cut, copy, paste, duplicate, delete, selectAll, deselect
}

extension FlareWorkspace {
    /// How far a paste lands right of and below what was copied, in scene points.
    public static let pasteOffset = 10.0

    /// What a locked layer says when an edit would change it.
    public static func unlockMessage(_ layerName: String) -> String { "Unlock \(layerName) to draw on it." }

    /// What Cut, Copy, Duplicate and Delete act on: the stage selection's layers, or the panel's layer outside it.
    public var editLayerIDs: [String] {
        guard let id = selectedLayerID else { return [] }
        return selectedLayerIDs.contains(id) ? selectedLayerIDs : [id]
    }

    /// Why `action` can't run, as its menu item's tooltip; nil when it can. Paste reads `pasteboard`, Flare's data.
    public func editHelp(_ action: FlareEditAction, pasteboard: Data? = nil) -> String? {
        guard let ownerLayers else { return FlareLayerError.noDocument.message }
        let targets = ownerLayers.filter { editLayerIDs.contains($0.id) }
        let locked = targets.first(where: \.isLocked).map { Self.unlockMessage($0.name) }
        let shapes = services.shapes.unavailableHelp(for: .select)
        switch action {
        case .selectAll: return everything().isEmpty ? "There is nothing to select."
            : everything() == selection ? "Everything is already selected." : nil
        case .deselect: return selection.isEmpty && selectedLayerID == nil ? "Nothing is selected." : nil
        case .paste:
            guard let pasteboard, !pasteboard.isEmpty else { return FakeShapes.nothingToPaste }
            return shapes ?? ownerLayers.first { $0.id == pasteTarget && $0.isLocked }.map { Self.unlockMessage($0.name) }
        case .copy, .duplicate: return targets.isEmpty ? "Select a layer first." : shapes
        case .cut: return targets.isEmpty ? "Select a layer first." : locked ?? shapes
        case .delete:
            guard !targets.isEmpty else { return "Select a layer first." }
            return locked ?? (tool == .directSelect && !selection.isEmpty ? shapes : nil)
        }
    }

    /// Copies the edited layers; returns the pasteboard data, or nil with the reason in `layerError`.
    public mutating func copy() -> Data? {
        if let reason = editHelp(.copy) { refuse(.refused(reason)); return nil }
        guard let owner = propertyOwner, let document else { return nil }
        let data = try? services.shapes.copy(layers: editLayerIDs, owner: owner, from: document)
        layerError = data == nil ? .refused("These layers could not be copied.") : nil
        return data
    }

    /// Copies the edited layers, then removes them, in one "Cut" step; returns the pasteboard data.
    public mutating func cut() -> Data? {
        if let reason = editHelp(.cut) { refuse(.refused(reason)); return nil }
        guard let data = copy() else { return nil }
        removeEditLayers("Cut")
        return layerError == nil ? data : nil
    }

    /// Pastes `data` above the topmost edited layer, offset by `pasteOffset`, as one "Paste" step, and selects it.
    public mutating func paste(_ data: Data?) {
        if let reason = editHelp(.paste, pasteboard: data) { return refuse(.refused(reason)) }
        guard let owner = propertyOwner, let data else { return }
        let shapes = services.shapes, above = pasteTarget
        var added: [String] = []
        step { added = try shapes.paste(data, owner: owner, aboveLayerID: above, offset: Self.pasteOffset, in: &$0) }
        if layerError == .command(.invalidDocument(FakeShapes.nothingToPaste)) { return refuse(.refused(FakeShapes.nothingToPaste)) }
        if layerError == nil { selectLayers(added) }
    }

    /// Duplicates the edited layers, each above its original, as one "Duplicate" step, and selects the copies.
    public mutating func duplicate() {
        if let reason = editHelp(.duplicate) { return refuse(.refused(reason)) }
        guard let owner = propertyOwner else { return }
        let shapes = services.shapes, layers = editLayerIDs
        var added: [String] = []
        step { added = try shapes.duplicate(layers: layers, owner: owner, in: &$0) }
        if layerError == nil { selectLayers(added) }
    }

    /// Deletes the edited layers in one "Delete" step; Direct Select deletes the selected items instead.
    public mutating func delete() {
        if let reason = editHelp(.delete) { return refuse(.refused(reason)) }
        guard tool == .directSelect, !selection.isEmpty else { return removeEditLayers("Delete") }
        let shapes = services.shapes, items = selection
        step { try shapes.delete(items, in: &$0) }
        if layerError == nil { setSelection([]) }
    }

    /// Selects every item the stage can select: visible, on an unlocked layer.
    public mutating func selectAll() {
        if let reason = editHelp(.selectAll) { return refuse(.refused(reason)) }
        setSelection(everything())
    }

    /// Clears the stage and layer selection.
    public mutating func deselect() {
        if let reason = editHelp(.deselect) { return refuse(.refused(reason)) }
        setSelection([])
    }

    /// The layer a paste lands above: the topmost edited layer, or nil for the top of the edited owner.
    private var pasteTarget: String? {
        ownerLayers?.last { editLayerIDs.contains($0.id) }?.id
    }

    /// Every selectable item of the edited owner at the playhead. In a symbol the hit tester (scene only) can't
    /// list them, so they are the symbol's own drawn items, bounded, off text and locked layers, like a marquee.
    private func everything() -> [StageAddress] {
        guard let sceneID = selectedSceneID, let document else { return [] }
        if let symbolID = editingSymbolID {
            let locked = Set(ownerLayers?.filter(\.isLocked).map(\.id) ?? [])
            let items = services.stage.drawList(document, sceneID: sceneID, frame: currentFrame, editing: symbolID).items
                .filter { !$0.isText && $0.path.bounds != nil && !locked.contains($0.address.layerID) }.map(\.address)
            return items.enumerated().filter { !items.prefix($0.offset).contains($0.element) }.map(\.element)
        }
        let all = Rect(minX: -.greatestFiniteMagnitude, minY: -.greatestFiniteMagnitude,
                       maxX: .greatestFiniteMagnitude, maxY: .greatestFiniteMagnitude)
        return services.hits.marquee(document, sceneID: sceneID, frame: currentFrame, rect: all)
    }

    /// Selects the items of `layers` on the stage, and the last of them in the panel.
    private mutating func selectLayers(_ layers: [String]) {
        setSelection(everything().filter { layers.contains($0.layerID) })
        if let last = layers.last { selectedLayerID = last }
    }

    /// Removes the edited layers, top first, in one step named `label`, and clears the selection.
    private mutating func removeEditLayers(_ label: String) {
        guard let owner = propertyOwner, let ownerLayers else { return refuse(.noDocument) }
        let targets = editLayerIDs
        let ids = ownerLayers.reversed().map(\.id).filter { targets.contains($0) }
        step(label) { engine in
            for id in ids { try engine.perform(RemoveLayer(owner: owner, layerID: id)) }
        }
        if layerError == nil { setSelection([]) }
    }
}

// FlareAnchors+Kernel.swift (pen-paths FP-1): FlareWorkspace as SuiteKernel's PathEditTarget on the one shape Direct
// Select picked; `setPath` writes it as one "Edit Path". FP-7 edits anchors; FP-6 adds the commands `runPath` runs.
import FlareCore
import SuiteKernel

extension FlareWorkspace: PathEditTarget {
    /// The one direct-selected shape item: its path and its layer's transform at the playhead; nil otherwise.
    public var pathInEdit: PathInEdit? {
        guard tool == .directSelect, selection.count == 1, let address = selection.first,
              case .shape(let index) = address.item,
              let item = stageList?.items.first(where: { $0.address == address }) else { return nil }
        return PathInEdit(id: "\(address.layerID)/\(index)", path: item.path, toDocument: item.transform)
    }

    /// The picked anchors of `pathInEdit`; cleared when the item selection changes.
    public var anchorSelection: Selection<AnchorRef> {
        get { anchorSelectionStore }
        set { anchorSelectionStore = newValue }
    }

    /// Why the points can't be edited: no one shape picked with Direct Select, or its layer is locked.
    public var pathHelp: String? {
        guard pathInEdit != nil, let layerID = selection.first?.layerID else {
            return "Select one shape with Direct Select to edit its points."
        }
        return ownerLayers?.first(where: { $0.id == layerID && $0.isLocked }).map { Self.unlockMessage($0.name) }
    }

    /// Writes `path` to the item in edit as one "Edit Path"; `drag` is the kernel's coalescing key (FP-7 uses it).
    public mutating func setPath(_ path: VectorPath, name: String, drag: String?) throws {
        guard pathInEdit != nil, let address = selection.first else { throw FlareLayerError.refused(pathHelp ?? "") }
        let shapes = services.shapes
        layerError = nil
        step { try shapes.setPath(path, of: address, in: &$0) }
        if let layerError { throw layerError }
    }

    /// Runs `intent`'s command through the catalog; an id it doesn't hold yet (before FP-6) changes nothing.
    public mutating func runPath(_ intent: PathIntent) {
        let command = intent.command
        _ = try? Self.catalog.run(command.id, params: command.params, on: &self)
    }
}

// FlareAnchors+Kernel.swift (pen-paths FP-1, FP-7): FlareWorkspace as SuiteKernel's PathEditTarget on the one shape
// Direct Select picked. Every path gesture, the anchor marquee and point drags included, runs as its shared
// `PathCommands` spec through the catalog, so the undo titles ("Move Points", "Move Handle"), the document-space
// coordinate rule and the drag token are the kernel's, as in Photo; Flare maps no coordinates of its own. `setPath`
// folds the edits under one drag token into one step. A press that picks an anchor and the drag preview stay here
// (FlareSelection.swift waits on adopt-kernel-selection).
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

    /// `pathInEdit` when its points can change (`pathHelp` is nil): what the edit overlay draws. Nil on a locked layer.
    public var editablePath: PathInEdit? { pathHelp == nil ? pathInEdit : nil }

    /// The picked anchors of `pathInEdit`; cleared when the item selection changes.
    public var anchorSelection: Selection<AnchorRef> {
        get { anchorSelectionStore }
        set { anchorSelectionStore = newValue }
    }

    /// Why path edits can't run: no document; under Direct Select, no one shape picked or its layer locked; under the
    /// other tools, a locked selected layer, which a new path can't go on (FP-6: the Pen and `path.draw` run then).
    public var pathHelp: String? {
        guard engine != nil else { return FlareLayerError.noDocument.message }
        guard tool == .directSelect else { return lockedHelp(.pen) }
        guard pathInEdit != nil, let layerID = selection.first?.layerID else {
            return "Select one shape with Direct Select to edit its points."
        }
        return ownerLayers?.first(where: { $0.id == layerID && $0.isLocked }).map { "Unlock \($0.name) to edit its points." }
    }

    /// Writes `path` to the item in edit as one step titled `name`. Edits under one `drag` token, on the same item and
    /// title, fold into one step: while the document is still the one the token's last edit left, that step is undone
    /// and the whole edit written again, so one undo goes back to before the drag. Any other change, or
    /// `endCoalescing`, starts a new step.
    public mutating func setPath(_ path: VectorPath, name: String, drag: String?) throws {
        guard let edit = pathInEdit, let address = selection.first else { throw FlareLayerError.refused(pathHelp ?? "") }
        let shapes = services.shapes, key = drag.map { "\(edit.id)-\(name)-\($0)" }
        let folds = key != nil && pathDrag?.key == key && pathDrag?.document == engine?.document
        layerError = nil
        step { engine in
            if folds { try engine.undo() }
            try engine.group(name) { try shapes.setPath(path, of: address, in: &$0) }
        }
        // A refusal the catalog passes through in the same words, as Photo's.
        if let layerError { throw CatalogError.unavailable(id: "path", why: layerError.message) }
        pathDrag = key.flatMap { key in engine.map { (key, $0.document) } }
    }

    /// Runs one Pen or point-editor gesture as its shared path command in the catalog; a refusal goes to `layerError`.
    public mutating func runPath(_ intent: PathIntent) {
        let command = intent.command
        do {
            _ = try Self.catalog.run(command.id, params: command.params, on: &self)
        } catch {
            switch error {
            case .unavailable(_, let why): refuse(.refused(why))
            default: refuse(.refused(error.description))
            }
        }
    }

    /// A Direct Select press on the path in edit: a selected anchor's handle, or an anchor, which it picks (Shift adds)
    /// unless it already is. Nil off them, so the press falls to the items.
    mutating func anchorPress(at point: Point, modifiers: DragModifiers, stageScale: Double) -> PathHit? {
        guard tool == .directSelect, let edit = pathInEdit else { return nil }
        let reach = Self.hitSlop / Self.usable(stageScale)
        switch AnchorIndex(edit.path, toDocument: edit.toDocument).hit(point, reach: reach, selected: anchorSelection) {
        case .anchor(let ref)?:
            if !anchorSelection.contains(ref) {
                anchorSelectionStore.replace((modifiers.contains(.shift) ? anchorSelection.ordered : []) + [ref])
            }
            return .anchor(ref)
        case .handle(let ref, let end)?: return .handle(ref, end)
        default: return nil
        }
    }

    /// The stage with the path in edit as `g`'s anchor or handle drag would leave it; nil when it can't change.
    func anchorPreview(_ g: StageGesture) -> StageDrawList? {
        guard let hit = g.anchor, let edit = pathInEdit, pathHelp == nil, let address = selection.first,
              var list = stageList, let at = list.items.firstIndex(where: { $0.address == address }) else { return nil }
        var preview = self
        preview.runPathGesture(hit, g)
        list.items[at].path = preview.pathInEdit?.path ?? edit.path
        return list
    }

    /// Mouse-up of a Direct Select gesture on the path in edit: an anchor or handle drag as one "Edit Path", or an
    /// anchor marquee (Shift adds). False when the gesture was on the items instead, for `endSelect`.
    mutating func endPathGesture(_ g: StageGesture) -> Bool {
        if let hit = g.anchor {
            if !g.isClick, g.start.isFinite, g.end.isFinite { runPathGesture(hit, g) }
            return true
        }
        guard g.anchorMarquee, !g.isClick, g.start.isFinite, g.end.isFinite else { return false }
        runPath(.select(anchors: nil, rect: Rect(enclosing: [g.start, g.end]), extend: g.modifiers.contains(.shift)))
        return true
    }

    private mutating func runPathGesture(_ hit: PathHit, _ g: StageGesture) {
        switch hit {
        case .handle(let ref, let end): runPath(.handle(ref, end, to: g.end, breaking: g.modifiers.contains(.option), drag: nil))
        default: runPath(.move(dx: g.end.x - g.start.x, dy: g.end.y - g.start.y, drag: nil))
        }
    }
}

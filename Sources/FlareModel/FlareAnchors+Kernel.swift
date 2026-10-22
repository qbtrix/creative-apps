// FlareAnchors+Kernel.swift (pen-paths FP-1, FP-7): FlareWorkspace as SuiteKernel's PathEditTarget on the one shape
// Direct Select picked; `setPath` writes it as one "Edit Path". Picking, moving anchors and handles, and the anchor
// marquee run here (FlareSelection.swift waits on adopt-kernel-selection); FP-6 adds the commands the catalog runs.
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

    /// Picks, moves anchors and moves a handle of the path in edit; any other intent runs through the catalog, where an
    /// id it doesn't hold yet (before FP-6) changes nothing. Moves are in document space, mapped into the path's.
    public mutating func runPath(_ intent: PathIntent) {
        guard let edit = pathInEdit else { return }
        switch intent {
        case .select(let anchors, let rect, let extend):
            var picked = (extend ? anchorSelection.ordered : []) + (anchors ?? [])
            if let rect { picked += AnchorIndex(edit.path, toDocument: edit.toDocument).inside(rect) }
            var seen = Set<AnchorRef>()
            anchorSelectionStore.replace(picked.filter { seen.insert($0).inserted })
        case .selectAll: anchorSelectionStore.replace(Self.anchorRefs(edit.path))
        case .move(let dx, let dy, let drag):
            guard !anchorSelection.set.isEmpty, editable() else { return }
            let m = edit.toDocument
            guard let back = try? Matrix(a: m.a, b: m.b, c: m.c, d: m.d, tx: 0, ty: 0).inverted() else { return }
            let local = back.apply(Point(x: dx, y: dy))
            try? setPath(AnchorEdit.moved(edit.path, anchorSelection.set, dx: local.x, dy: local.y), name: "Edit Path", drag: drag)
        case .handle(let ref, let end, let to, let breaking, let drag):
            guard editable(), let back = try? edit.toDocument.inverted() else { return }
            let path = AnchorEdit.movingHandle(edit.path, ref, end, to: back.apply(to), breaking: breaking)
            try? setPath(path, name: "Edit Path", drag: drag)
        default:
            let command = intent.command
            _ = try? Self.catalog.run(command.id, params: command.params, on: &self)
        }
    }

    /// Every anchor of `path`, in order.
    static func anchorRefs(_ path: VectorPath) -> [AnchorRef] {
        path.contours.enumerated().flatMap { c, contour in contour.anchors.indices.map { AnchorRef(contour: c, index: $0) } }
    }

    /// Whether the path in edit can change; refuses with `pathHelp` when its layer is locked.
    private mutating func editable() -> Bool {
        guard let help = pathHelp else { return true }
        refuse(.refused(help))
        return false
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

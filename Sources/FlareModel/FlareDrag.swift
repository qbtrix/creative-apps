// FlareDrag.swift: stage gestures (docs/blueprints/flare.md, section 2). A pointer move sets only `draft`, `marquee` or
// `dragPreview`; `endDrag` commits once, through the contract's one named group. A pen draft lasts until its path
// closes. A move under `clickSlop` stage points is a click (#470).
import FlareCore

/// The gesture under way: `base` is the pen draft it carries on from, `moving`
/// what a selection-tool drag moves (empty for a marquee).
struct StageGesture: Equatable, Sendable {
    var start: Point, end: Point, modifiers: DragModifiers, stageScale: Double, base: ShapeDraft?, moving: [StageAddress]

    var isClick: Bool {
        let scale = FlareWorkspace.usable(stageScale)
        return !(abs(end.x - start.x) * scale >= FlareWorkspace.clickSlop
            || abs(end.y - start.y) * scale >= FlareWorkspace.clickSlop)
    }
}

extension FlareWorkspace {
    /// How far the pointer may move and still click, and how near a click hits an item, in stage points.
    public static let clickSlop = 1.0, hitSlop = 4.0

    static func usable(_ stageScale: Double) -> Double { stageScale.isFinite && stageScale > 0 ? stageScale : 1 }

    /// Why `tool` is disabled, as its tooltip; nil when its drag works. Asks the tool's service; Ellipse draws through
    /// the workspace (FlareDrawing.swift).
    public func toolHelp(_ tool: FlareTool) -> String? {
        guard tool != .ellipse, let reason = services.shapes.unavailableHelp(for: tool) else { return nil }
        return reason.isEmpty ? tool.unavailableHelp ?? reason : reason
    }

    /// One whole gesture: `dragChanged`, then `endDrag`.
    public mutating func drag(from start: Point, to end: Point, modifiers: DragModifiers = [], stageScale: Double = 1) {
        dragChanged(from: start, to: end, modifiers: modifiers, stageScale: stageScale)
        endDrag()
    }

    /// The pointer is at `end` in a gesture from `start`, in scene points: updates the live preview. `stageScale` is
    /// the stage's fit scale (stage points per scene point), so minimums apply on screen.
    public mutating func dragChanged(from start: Point, to end: Point, modifiers: DragModifiers = [], stageScale: Double = 1) {
        if gesture?.start != start {
            gesture = StageGesture(start: start, end: end, modifiers: modifiers, stageScale: stageScale,
                                   base: gesture.map(\.base) ?? draft, moving: grabbed(at: start, stageScale: stageScale))
        }
        gesture?.end = end; gesture?.modifiers = modifiers; gesture?.stageScale = stageScale
        guard selectedScene != nil, let g = gesture else { return draft = nil }
        let shapes = services.shapes
        switch tool {
        case .ellipse:
            draft = Self.ellipse(from: start, to: end, stageScale: stageScale).map { ShapeDraft(tool: .ellipse, shape: $0) }
        case .rectangle: draft = g.isClick ? nil : shapes.draft(tool, from: start, to: end, modifiers: modifiers, previous: nil)
        case .pen: draft = shapes.draft(tool, from: start, to: end, modifiers: modifiers, previous: g.base)
        case .select, .directSelect:
            let drags = !g.isClick && start.isFinite && end.isFinite
            marquee = drags && g.moving.isEmpty ? Rect(enclosing: [start, end]) : nil
            dragPreview = drags && !g.moving.isEmpty ? movePreview(g.moving, dx: end.x - start.x, dy: end.y - start.y) : nil
        }
    }

    /// Mouse-up: commits the gesture as one undo step, or for a click or a marquee changes the selection.
    public mutating func endDrag() {
        guard let g = gesture else { return }
        let pending = draft
        cancelDrag()
        switch tool {
        case .ellipse: commitEllipse(from: g.start, to: g.end, stageScale: g.stageScale)
        case .rectangle: if let pending { commit(pending) }
        case .pen: if let pending, pending.isClosed { commit(pending) } else { draft = pending }
        case .select, .directSelect: endSelect(g)
        }
    }

    /// Escape: drops the gesture, its draft (a pen path too), marquee and preview.
    public mutating func cancelDrag() { (gesture, draft, marquee, dragPreview) = (nil, nil, nil, nil) }

    /// Adds `draft` as a new layer above the selected one and selects it.
    mutating func commit(_ draft: ShapeDraft) {
        guard let sceneID = selectedSceneID else { return refuse(.noDocument) }
        let shapes = services.shapes, above = selectedLayerID
        var added: String?
        step { added = try shapes.commit(draft, sceneID: sceneID, aboveLayerID: above, in: &$0) }
        if let added, layerError == nil { setSelection([]); selectedLayerID = added }
    }

    /// One "Move" by (`dx`, `dy`) scene points: Select writes the layers' x and y, Direct Select the items' geometry.
    mutating func commitMove(_ moving: [StageAddress], dx: Double, dy: Double) {
        guard let sceneID = selectedSceneID, let document, dx.isFinite, dy.isFinite else { return }
        let shapes = services.shapes, frame = currentFrame, layers = layerIDs(of: moving), tool = tool, autoKey = autoKey
        let box = services.hits.bounds(document, sceneID: sceneID, frame: frame, of: moving)
        step { engine in
            guard tool == .select else { return try shapes.translate(moving, dx: dx, dy: dy, in: &engine) }
            try shapes.commitBox(.move(dx: dx, dy: dy), layers: layers, sceneID: sceneID, frame: frame,
                                 box: box ?? Rect(minX: 0, minY: 0, maxX: 0, maxY: 0), autoKey: autoKey, in: &engine)
        }
        if layerError == nil { setSelection(moving) }
    }

    /// The stage at the playhead with `moving` shifted by (`dx`, `dy`).
    private func movePreview(_ moving: [StageAddress], dx: Double, dy: Double) -> StageDrawList? {
        guard let sceneID = selectedSceneID, let document else { return nil }
        var list = services.stage.drawList(document, sceneID: sceneID, frame: currentFrame, editing: editingSymbolID)
        let layers = Set(moving.map(\.layerID)), tool = tool
        for (i, item) in list.items.enumerated() where tool == .select ? layers.contains(item.address.layerID) : moving.contains(item.address) {
            list.items[i].transform = .translation(x: dx, y: dy) * item.transform
        }
        return list
    }
}

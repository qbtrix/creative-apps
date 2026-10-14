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
        case .pen:
            // The pen's tolerances are on screen: the draft carries this click's fit scale (#619).
            var base = g.base ?? ShapeDraft(tool: .pen, shape: FlareShape(points: []))
            base.stageScale = stageScale
            draft = shapes.draft(tool, from: start, to: end, modifiers: modifiers, previous: base)
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

    /// Adds `draft` as a new layer of the edited owner (the symbol edited in place, else the scene) above the
    /// selected layer, and selects it.
    mutating func commit(_ draft: ShapeDraft) {
        guard let owner = propertyOwner else { return refuse(.noDocument) }
        let shapes = services.shapes, above = selectedLayerID
        var added: String?
        step { added = try shapes.commit(draft, owner: owner, aboveLayerID: above, in: &$0) }
        if let added, layerError == nil { setSelection([]); selectedLayerID = added }
    }

    /// One "Move" by (`dx`, `dy`) scene points: Select writes the layers' x and y, Direct Select the items' geometry,
    /// each layer's items by the offset in that layer's space (`layerMoves`). Select refuses a symbol's layers.
    mutating func commitMove(_ moving: [StageAddress], dx: Double, dy: Double) {
        guard let sceneID = selectedSceneID, let document, dx.isFinite, dy.isFinite else { return }
        if selectKeysSymbol(moving) { return refuse(.refused(Self.moveInSymbolMessage)) }
        let shapes = services.shapes, frame = currentFrame, layers = layerIDs(of: moving), tool = tool, autoKey = autoKey
        let box = selectionBox(of: moving)
        let moves = tool == .select ? [] : Self.layerMoves(moving, dx: dx, dy: dy, in: document, frame: frame)
        step { engine in
            guard tool == .select else {
                return try engine.group("Move") { engine in
                    for move in moves { try shapes.translate(move.items, dx: move.dx, dy: move.dy, in: &engine) }
                }
            }
            try shapes.commitBox(.move(dx: dx, dy: dy), layers: layers, sceneID: sceneID, frame: frame,
                                 box: box ?? Rect(minX: 0, minY: 0, maxX: 0, maxY: 0), autoKey: autoKey, in: &engine)
        }
        if layerError == nil { setSelection(moving) }
    }

    /// `items` grouped by layer, each with the scene offset (`dx`, `dy`) mapped through the inverse of its layer's scale
    /// and rotation at `frame`, so the item lands where the preview drew it (#554). A layer that can't invert (scale
    /// 0, so nothing on it shows) moves nothing.
    static func layerMoves(_ items: [StageAddress], dx: Double, dy: Double, in document: Document,
                           frame: Int) -> [(items: [StageAddress], dx: Double, dy: Double)] {
        var moves: [(items: [StageAddress], dx: Double, dy: Double)] = []
        for item in items where !moves.contains(where: { $0.items.first.map { Self.sameLayer($0, item) } ?? false }) {
            guard let layer = document.layers(of: item.owner)?.first(where: { $0.id == item.layerID }) else { continue }
            let m = layer.placement(at: Double(frame)).transform.matrix
            guard let back = try? Matrix(a: m.a, b: m.b, c: m.c, d: m.d, tx: 0, ty: 0).inverted() else { continue }
            let local = back.apply(Point(x: dx, y: dy))
            moves.append((items.filter { Self.sameLayer($0, item) }, local.x, local.y))
        }
        return moves
    }

    /// Whether a Select move of `moving` would key a symbol's layers. The box commit keys scene layers only, so it
    /// would key the scene layer that shares their id instead (#674).
    private func selectKeysSymbol(_ moving: [StageAddress]) -> Bool {
        tool == .select && moving.contains { $0.owner != selectedSceneID.map(LayerOwner.scene) }
    }

    private static func sameLayer(_ a: StageAddress, _ b: StageAddress) -> Bool { a.owner == b.owner && a.layerID == b.layerID }

    /// The stage at the playhead with `moving` shifted by (`dx`, `dy`).
    private func movePreview(_ moving: [StageAddress], dx: Double, dy: Double) -> StageDrawList? {
        guard let sceneID = selectedSceneID, let document, !selectKeysSymbol(moving) else { return nil }
        var list = services.stage.drawList(document, sceneID: sceneID, frame: currentFrame, editing: editingSymbolID)
        let layers = Set(moving.map(\.layerID)), tool = tool
        for (i, item) in list.items.enumerated() where tool == .select ? layers.contains(item.address.layerID) : moving.contains(item.address) {
            list.items[i].transform = .translation(x: dx, y: dy) * item.transform
        }
        return list
    }
}

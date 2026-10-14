// FlareSelection.swift: the stage selection (docs/blueprints/flare.md, section 2). Select (V) picks layers: a click hits
// the topmost item, Shift-click adds or drops its layer. Direct Select (A) picks items. A marquee adds with Shift.
import FlareCore

extension FlareWorkspace {
    /// The layers the stage selection touches, in selection order, each once.
    public var selectedLayerIDs: [String] { layerIDs(of: selection) }

    /// The selection box at the playhead, strokes included; nil with no selection. Select frames the selected layers
    /// (every item on them), Direct Select the selected items (#565).
    public var selectionBounds: Rect? { selectionBox(of: selection) }

    /// The world bounds of what a move of `items` changes: their layers' items under Select, else `items` alone.
    func selectionBox(of items: [StageAddress]) -> Rect? {
        guard let sceneID = selectedSceneID, let document, !items.isEmpty else { return nil }
        var framed = items
        if tool == .select {
            // The hit tester's own view of the stage: the scene, or the symbol being edited (#641).
            framed = services.stage.drawList(document, sceneID: sceneID, frame: currentFrame, editing: editingSymbolID).items
                .map(\.address).filter { a in items.contains { $0.owner == a.owner && $0.layerID == a.layerID } }
        }
        return services.hits.bounds(document, sceneID: sceneID, frame: currentFrame, editing: editingSymbolID, of: framed)
    }

    func layerIDs(of items: [StageAddress]) -> [String] {
        items.map(\.layerID).enumerated().filter { !items.prefix($0.offset).map(\.layerID).contains($0.element) }.map(\.element)
    }

    /// The topmost item within `hitSlop` stage points of `point`, or nil: the edited symbol's, else the scene's.
    func hit(at point: Point, stageScale: Double) -> StageAddress? {
        guard let sceneID = selectedSceneID, let document, point.isFinite else { return nil }
        return services.hits.hit(document, sceneID: sceneID, frame: currentFrame, editing: editingSymbolID, at: point,
                                 tolerance: Self.hitSlop / Self.usable(stageScale))
    }

    /// What a selection-tool drag from `point` moves: the selection when it holds the hit item (its layer, for
    /// Select), else that item; nothing when no item is hit, so the drag draws a marquee.
    func grabbed(at point: Point, stageScale: Double) -> [StageAddress] {
        guard tool == .select || tool == .directSelect, let hit = hit(at: point, stageScale: stageScale) else { return [] }
        let held = tool == .select ? selection.contains { $0.layerID == hit.layerID } : selection.contains(hit)
        return held ? selection : [hit]
    }

    /// Mouse-up: a click selects what it hits, a drag from an item moves it, a drag from empty stage is a marquee.
    mutating func endSelect(_ g: StageGesture) {
        guard let sceneID = selectedSceneID, let document, g.start.isFinite, g.end.isFinite else { return }
        let extending = g.modifiers.contains(.shift)
        if g.isClick { return select(hit(at: g.start, stageScale: g.stageScale), extending: extending) }
        guard g.moving.isEmpty else { return commitMove(g.moving, dx: g.end.x - g.start.x, dy: g.end.y - g.start.y) }
        guard let rect = Rect(enclosing: [g.start, g.end]) else { return }
        let found = services.hits.marquee(document, sceneID: sceneID, frame: currentFrame, editing: editingSymbolID, rect: rect)
        setSelection(extending ? selection + found.filter { !selection.contains($0) } : found)
    }

    /// A click: `hit` alone, or with Shift toggled in the selection. Empty stage deselects, unless Shift is held.
    mutating func select(_ hit: StageAddress?, extending: Bool) {
        guard let hit else { return extending ? () : setSelection([]) }
        guard extending else { return setSelection([hit]) }
        let isHit: (StageAddress) -> Bool = tool == .select ? { $0.layerID == hit.layerID } : { $0 == hit }
        setSelection(selection.contains(where: isHit) ? selection.filter { !isHit($0) } : selection + [hit])
    }

    /// Sets the stage selection; the layers panel follows its last layer.
    mutating func setSelection(_ items: [StageAddress]) {
        selection = items
        selectedLayerID = items.last?.layerID
    }
}

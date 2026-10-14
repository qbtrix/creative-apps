// FlareDrag.swift: the stage gesture (blueprint section 2, "One undo step, exactly"). `dragChanged` only changes
// `shapeDraft`, `dragPreview` and the selection; `endDrag` commits once through the tool's service, which opens the
// one named group; `cancelDrag` drops it all. A pen draft carries on across clicks until it closes.
import FlareCore

struct DragGesture: Equatable, Sendable {
    /// A shape tool drawing on from the pen draft `previous`, a move of the selection, or nothing.
    enum Mode: Equatable, Sendable { case draw(previous: ShapeDraft?), move, none }
    var start: Point, end: Point, stageScale: Double, modifiers: DragModifiers, mode: Mode
}

extension FlareWorkspace {
    /// The whole gesture from `start` to `end` in scene points (a click doesn't move); `stageScale` is stage points per scene point.
    public mutating func drag(from start: Point, to end: Point, stageScale: Double = 1, modifiers: DragModifiers = []) {
        dragChanged(from: start, to: end, stageScale: stageScale, modifiers: modifiers)
        endDrag()
    }

    /// The pointer moved to `end`; a new `start` begins a new gesture. Never performs a command.
    public mutating func dragChanged(from start: Point, to end: Point, stageScale: Double = 1, modifiers: DragModifiers = []) {
        if gesture?.start != start { gesture = begin(at: start, stageScale: stageScale, modifiers: modifiers) }
        gesture?.end = end
        guard let gesture, let sceneID = selectedSceneID else { return shapeDraft = nil }
        switch gesture.mode {
        case .draw where tool == .ellipse:
            shapeDraft = Self.ellipse(from: start, to: end, stageScale: stageScale).map { ShapeDraft(tool: .ellipse, shape: $0) }
        case .draw(let previous):
            shapeDraft = services.shapes.draft(tool, from: start, to: end, modifiers: modifiers, previous: previous)
        case .move:
            // The move runs on a scratch copy of the engine; the open document never changes mid-drag.
            guard start != end, var scratch = engine, (try? commitMove(gesture, in: &scratch)) != nil
            else { return dragPreview = nil }
            dragPreview = services.stage.drawList(scratch.document, sceneID: sceneID, frame: currentFrame,
                                                  editing: editingSymbolID)
        case .none: break
        }
    }

    /// The pointer went up: commits the gesture under way as one undo step, or keeps an open pen draft.
    public mutating func endDrag() {
        guard let gesture else { return }
        switch gesture.mode {
        case .draw where tool == .ellipse:
            cancelDrag()
            commitEllipse(from: gesture.start, to: gesture.end, stageScale: gesture.stageScale)
        case .draw:
            guard let draft = shapeDraft, tool != .pen || draft.isClosed else { return self.gesture = nil }
            cancelDrag()
            guard let sceneID = selectedSceneID else { return refuse(.noDocument) }
            let shapes = services.shapes, above = selectedLayerID
            var added: String?
            step { added = try shapes.commit(draft, sceneID: sceneID, aboveLayerID: above, in: &$0) }
            if layerError == nil, let added { selectedLayerID = added }
        case .move:
            cancelDrag()
            guard gesture.start != gesture.end else { return }
            let move = self
            step { try move.commitMove(gesture, in: &$0) }
        case .none:
            cancelDrag()
        }
    }

    /// Drops the gesture, its draft (an open pen path too) and its preview; the document is untouched.
    public mutating func cancelDrag() {
        (gesture, shapeDraft, dragPreview) = (nil, nil, nil)
    }

    /// What a gesture starting at `start` does with the active tool, picking what a select click hits.
    private mutating func begin(at start: Point, stageScale: Double, modifiers: DragModifiers) -> DragGesture {
        var mode = DragGesture.Mode.none
        switch tool {
        case .pen: mode = .draw(previous: shapeDraft)
        case .rectangle, .ellipse: mode = .draw(previous: nil)
        case .select, .directSelect:
            guard let document, let sceneID = selectedSceneID else { break }
            let scale = stageScale.isFinite && stageScale > 0 ? stageScale : 1
            let hit = services.hits.hit(document, sceneID: sceneID, frame: currentFrame, at: start,
                                        tolerance: 4 / scale)  // 4 stage points
            guard let hit else {
                if !modifiers.contains(.shift) { selection = [] }
                break
            }
            pick(hit, adding: modifiers.contains(.shift))
            mode = isSelected(hit) ? .move : .none
        }
        return DragGesture(start: start, end: start, stageScale: stageScale, modifiers: modifiers, mode: mode)
    }

    /// "Move": the selected layers' x and y (Select) or the selected items' geometry (Direct Select).
    private func commitMove(_ gesture: DragGesture, in engine: inout CommandEngine) throws {
        let dx = gesture.end.x - gesture.start.x, dy = gesture.end.y - gesture.start.y
        guard dx.isFinite, dy.isFinite, let sceneID = selectedSceneID else { throw CommandError.invalidDocument("No move.") }
        if tool == .directSelect { return try services.shapes.translate(selection, dx: dx, dy: dy, in: &engine) }
        let box = selectionBounds ?? Rect(minX: 0, minY: 0, maxX: 0, maxY: 0)
        try services.shapes.commitBox(.move(dx: dx, dy: dy), layers: selectedLayerIDs, sceneID: sceneID,
                                      frame: currentFrame, box: box, autoKey: autoKey, in: &engine)
    }
}

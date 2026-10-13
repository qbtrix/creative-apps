// DesignCanvasEditing.swift: what the canvas does with the selection and the
// pointer: hit testing, handle hits, moving, nudging, resizing and deleting the
// selected node, and the pointer gesture that routes a drag to the active tool.
//
// The canvas sends every pointer move as `drag(from:to:modifiers:)` in document
// points and `endDrag()` when the pointer lifts. CanvasViewport sends the
// previous point as `from`, so only the first call's `from` counts: it is the
// gesture's start. Every later call recomputes the whole result from the
// document as it was at the start, so nothing drifts, and `endDrag` records the
// one undo step. A click is a drag that never moves.
//
//   move    a press on a handle of the selected node resizes it (Shift keeps the
//           aspect, Option works from the center; a small node shows only its
//           corners, outside it, and a press inside it moves it); otherwise it selects the node
//           under the pointer (none deselects) and a drag moves it with its
//           subtree. A click on an already selected text node edits it.
//   frame, rectangle, ellipse, text   DesignDrawing.
//   pen     nothing.
//
// A drawing tool is good for one shape: once its gesture adds a node (a Text
// click its node, whose edit then opens), the tool goes back to Move.
//
// Locked nodes never move, resize, change or delete, and neither hidden nor
// locked nodes are hit. Linux-safe.

/// A pointer gesture in progress, from its first `drag` to `endDrag`.
struct DesignGesture: Sendable, Equatable {
    enum Route: Sendable, Equatable {
        /// Move the node's subtree by the drag.
        case move(String)
        /// Resize the node by the drag from the frame it had at the start.
        case resize(String, DesignHandle, DesignRect)
        /// Draw a node of this kind (DesignDrawing).
        case draw(DesignNodeKind)
        /// Place a text node and edit it (DesignDrawing).
        case text
        case none
    }

    var route: Route
    var start: DesignPoint
    /// The document at the start; the undo step puts it back.
    var before: DesignSnapshot
    /// Whether the node under a Move press was already selected before it.
    var wasSelected: Bool
    /// Whether any call left the start.
    var moved = false
}

extension DesignWorkspace {
    /// The topmost visible, unlocked node on the selected page under `point`.
    public func hitTest(_ point: DesignPoint) -> String? {
        selectedPage?.nodes.hit(at: point)
    }

    /// The handle of the selected, unlocked, visible node nearest `point` and within
    /// `handleTolerance` (Chebyshev distance) of where it shows (DesignRect.handles, a handle
    /// being `handleTolerance` across); corners win a tie. A press inside a compact node is never
    /// a handle: its handles sit outside it, so the press moves it.
    public func handle(at point: DesignPoint) -> DesignHandle? {
        guard let node = selectedNode, !node.isLocked, !node.isHidden else { return nil }
        let frame = node.frame
        let inside = point.x > frame.x && point.x < frame.maxX && point.y > frame.y && point.y < frame.maxY
        if inside, frame.isCompact(handleSize: handleTolerance) { return nil }
        let shown = frame.handles(size: handleTolerance)
        let order = DesignHandle.allCases.filter(\.isCorner) + DesignHandle.allCases.filter { !$0.isCorner }
        let hits = order.compactMap { handle -> (handle: DesignHandle, distance: Double)? in
            guard let at = shown[handle] else { return nil }
            let distance = Swift.max((at.x - point.x).magnitude, (at.y - point.y).magnitude)
            return distance <= handleTolerance ? (handle, distance) : nil
        }
        return hits.min { $0.distance < $1.distance }?.handle
    }

    /// Moves a node and its subtree by `delta`. Refused for an unknown or locked node; a
    /// non-finite delta changes nothing.
    public mutating func move(_ id: String, by delta: DesignPoint) throws(DesignTreeError) {
        try editNode(id, named: "Move") { node in
            if delta.isFinite { node.translate(by: delta) }
        }
    }

    /// Moves the selected node by 1 point (10 with Shift). A run of nudges to one node is one
    /// step. Does nothing without an unlocked selection, or while editing text.
    public mutating func nudge(_ direction: DesignDirection, shift: Bool) {
        guard editingTextID == nil, let id = selectedNodeID else { return }
        let step = shift ? 10.0 : 1.0
        let delta = switch direction {
        case .up: DesignPoint(x: 0, y: -step)
        case .down: DesignPoint(x: 0, y: step)
        case .left: DesignPoint(x: -step, y: 0)
        case .right: DesignPoint(x: step, y: 0)
        }
        // A locked node is refused and stays put; the selection's id always exists.
        try? editNode(id, named: "Nudge", coalescing: "nudge-\(id)") { $0.translate(by: delta) }
    }

    /// Drags `handle` of a node's frame by `delta` (see DesignRect.resized). Children stay where
    /// they are. Refused for an unknown or locked node.
    public mutating func resizeNode(
        _ id: String, handle: DesignHandle, by delta: DesignPoint, shift: Bool, option: Bool
    ) throws(DesignTreeError) {
        try editNode(id, named: "Resize") {
            $0.frame = $0.frame.resized(handle, by: delta, keepAspect: shift, fromCenter: option)
        }
    }

    /// Deletes the selected node and its subtree and deselects. Does nothing without an
    /// unlocked selection, or while editing text.
    public mutating func deleteSelection() {
        guard editingTextID == nil, let node = selectedNode, !node.isLocked,
            let page = pages.firstIndex(where: { $0.id == selectedPageID })
        else { return }
        let before = snapshot
        _ = pages[page].nodes.remove(node.id)
        held.remove([node])
        selectedNodeID = nil
        record("Delete \(node.kind.defaultName)", before: before)
    }

    /// One pointer move of the active tool's gesture, from the gesture's start to `end`.
    public mutating func drag(from start: DesignPoint, to end: DesignPoint, modifiers: DesignModifiers = []) {
        guard isOpen, end.isFinite, gesture != nil || start.isFinite else { return }
        if gesture == nil { gesture = beginGesture(at: start) }
        guard var current = gesture else { return }
        if end != current.start { current.moved = true }
        let delta = DesignPoint(x: end.x - current.start.x, y: end.y - current.start.y)
        switch current.route {
        case .move(let id):
            restorePages(current.before)
            _ = pages.update(id) { $0.translate(by: delta) }
        case .resize(let id, let handle, let original):
            restorePages(current.before)
            let frame = original.resized(
                handle, by: delta, keepAspect: modifiers.contains(.shift), fromCenter: modifiers.contains(.option))
            _ = pages.update(id) { $0.frame = frame }
        case .draw(let kind):
            draw(kind, from: current, to: end, square: modifiers.contains(.shift))
        case .text:
            placeText(from: current)
        case .none:
            break
        }
        gesture = current
    }

    /// Puts back the gesture's starting pages and their held-id index together, so an edit
    /// made mid-drag can't leave `held` out of step with the pages (#443).
    private mutating func restorePages(_ before: DesignSnapshot) {
        pages = before.pages
        held.replace(with: before.heldIDs)
    }

    /// Ends the gesture: records its undo step when it changed the document, starts the
    /// inline edit of a text node the gesture placed or clicked, and puts a drawing tool that
    /// added a node back to Move.
    public mutating func endDrag() {
        guard let done = gesture else { return }
        gesture = nil
        switch done.route {
        case .move(let id):
            // A click only selects, like a click on nothing deselects: no undo step.
            if done.moved { record("Move", before: done.before) }
            if !done.moved, done.wasSelected, findNode(id)?.kind == .text { try? beginTextEdit(id) }
        case .resize:
            record("Resize", before: done.before)
        case .draw(let kind):
            record("Add \(kind.defaultName)", before: done.before)
            tool = .move
        case .text:
            if let id = selectedNodeID, findNode(id)?.kind == .text {
                (editingTextID, textDraft) = (id, "Text")
                placedText = DesignPlacedText(id: id, before: done.before)
                tool = .move
            }
        case .none:
            break
        }
    }

    /// Decides what the gesture starting at `start` does, selecting the node a Move press hits.
    private mutating func beginGesture(at start: DesignPoint) -> DesignGesture {
        commitTextEdit()
        var route = DesignGesture.Route.none
        var wasSelected = false
        switch tool {
        case .move:
            if let handle = handle(at: start), let node = selectedNode {
                route = .resize(node.id, handle, node.frame)
            } else if let id = hitTest(start) {
                wasSelected = id == selectedNodeID
                selectItem(id)
                route = .move(id)
            } else {
                deselect()
            }
        case .frame, .rectangle, .ellipse:
            if let kind = tool.nodeKind { route = .draw(kind) }
        case .text:
            route = .text
        case .pen:
            break
        }
        return DesignGesture(route: route, start: start, before: snapshot, wasSelected: wasSelected)
    }
}

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
//           subtree. A click on an already selected text node edits it. With Shift
//           a press adds the node under it to the selection or takes it out
//           (DesignSelection) and moves nothing; on empty canvas it keeps the selection.
//           A press on the background of a frame that isn't selected, or outside every
//           layer, starts a marquee at that frame's level (the top level outside): each
//           step `marquee` holds the rectangle and the selection is what
//           `services.marquee` picks; it records nothing, and a click without moving
//           selects the frame (deselects outside). With several layers selected a press
//           on one moves them all, and on a handle of their box resizes them all, through
//           `services.transforming`; Option on a selected layer duplicates it and drags
//           the copies, one "Duplicate" step whose ids are minted once at the press. Each
//           of these steps rewinds to the gesture's start, history included, so the last
//           sample alone gives the same document. With one layer selected, move and
//           resize keep the routes below whatever `services` holds.
//   frame, rectangle, ellipse, text   DesignDrawing.
//   pen     nothing.
//
// A drawing tool is good for one shape: once its gesture adds a node (a Text
// click its node, whose edit then opens), the tool goes back to Move.
//
// Locked nodes never move, resize, change or delete, and neither hidden nor
// locked nodes are hit. A lock covers the node's whole subtree (DesignLocking),
// so a layer inside a locked group is locked too (#450), and a layer inside a
// hidden group shows no handles to press (#449). Linux-safe.

/// A pointer gesture in progress, from its first `drag` to `endDrag`.
struct DesignGesture: Sendable, Equatable {
    enum Route: Sendable, Equatable {
        /// Move the node's subtree by the drag.
        case move(String)
        /// Resize the node by the drag from the frame it had at the start.
        case resize(String, DesignHandle, DesignRect)
        /// Select what `services.marquee` picks among the children of this frame (nil: the top level).
        case marquee(String?)
        /// Move these selected layers through `services.transforming`.
        case moveSeveral([String])
        /// Resize the box of these selected layers by its handle through `services.transforming`.
        case resizeSeveral([String], DesignHandle)
        /// Duplicate these layers with the ids of this mint and drag the copies.
        case optionCopy([String], DesignIDMint)
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
    /// The undo history at the start; a service step puts it back before it applies.
    var history = DesignHistory()
}

extension DesignWorkspace {
    /// The topmost visible, unlocked node on the selected page under `point`.
    public func hitTest(_ point: DesignPoint) -> String? {
        selectedPage?.nodes.hit(at: point)
    }

    /// The handle of the selected node outside any lock and any hidden group (the canvas draws no
    /// handles for a hidden subtree, #449) nearest `point` and within
    /// `handleTolerance` (Chebyshev distance) of where it shows (DesignRect.handles, a handle
    /// being `handleTolerance` across); corners win a tie. A press inside a compact node is never
    /// a handle: its handles sit outside it, so the press moves it.
    public func handle(at point: DesignPoint) -> DesignHandle? {
        guard !hasMultipleSelection, let node = selectedNode, !isLockedInTree(node.id), !isHiddenInTree(node.id)
        else { return nil }
        return handle(on: node.frame, at: point)
    }

    /// With several layers selected, the handle of their box (`selectionBounds`) under `point`, as
    /// `handle(at:)` finds one on a single layer; nil otherwise.
    func boxHandle(at point: DesignPoint) -> DesignHandle? {
        guard hasMultipleSelection, let box = selectionBounds else { return nil }
        return handle(on: box, at: point)
    }

    private func handle(on frame: DesignRect, at point: DesignPoint) -> DesignHandle? {
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
    /// step. Does nothing without an unlocked selection, with several layers selected, or while editing text.
    public mutating func nudge(_ direction: DesignDirection, shift: Bool) {
        guard editingTextID == nil, !hasMultipleSelection, let id = selectedNodeID else { return }
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

    /// Deletes the selected node and its subtree and deselects. Does nothing without a
    /// selection outside any lock, with several layers selected, or while editing text.
    public mutating func deleteSelection() {
        guard editingTextID == nil, !hasMultipleSelection, let node = selectedNode, !isLockedInTree(node.id),
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
        if gesture == nil {
            gesture = beginGesture(at: start, shift: modifiers.contains(.shift), option: modifiers.contains(.option))
        }
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
        case .marquee(let parent):
            guard current.moved, let page = selectedPage else { break }
            let rect = DesignRect(
                x: Swift.min(current.start.x, end.x), y: Swift.min(current.start.y, end.y),
                width: (end.x - current.start.x).magnitude, height: (end.y - current.start.y).magnitude)
            marquee = rect
            selectedNodeIDs = services.marquee.layers(touching: rect, in: parent, on: page)
            for id in selectedNodeIDs { expandAncestors(of: id, in: page.nodes) }
        case .moveSeveral, .resizeSeveral, .optionCopy:
            applyStep(current, delta: delta, modifiers: modifiers)
        case .draw(let kind):
            draw(kind, from: current, to: end, square: modifiers.contains(.shift))
        case .text:
            placeText(from: current)
        case .none:
            break
        }
        gesture = current
    }

    /// One step of a service route: back to the gesture's start, history included, then the
    /// edit for `delta` from the start. A refused edit leaves the start as it was.
    private mutating func applyStep(_ current: DesignGesture, delta: DesignPoint, modifiers: DesignModifiers) {
        rewind(to: current.before)
        history = current.history
        guard current.moved, let page = selectedPage else { return }
        let transforming = services.transforming
        do throws(DesignRefusal) {
            switch current.route {
            case .moveSeveral(let ids):
                apply(try transforming.move(ids, by: delta, on: page))
            case .resizeSeveral(let ids, let handle):
                apply(try transforming.resize(ids, handle: handle, by: delta, modifiers: modifiers, on: page))
            case .optionCopy(let ids, let start):
                var mint = start
                let copied = try services.duplicating.duplicate(ids, offset: DesignPoint(x: 0, y: 0), on: page, mint: &mint)
                var copies = page
                copies.nodes = copied.nodes
                let nodes: [DesignNode]
                do throws(DesignRefusal) {
                    nodes = try transforming.move(copied.selection, by: delta, on: copies).nodes
                } catch .unchanged {
                    nodes = copied.nodes
                }
                apply(DesignEdit(name: "Duplicate", nodes: nodes, selection: copied.selection,
                                 coalescingKey: DesignEdit.runKey("option-drag", ids)), mint: mint)
            default:
                break
            }
        } catch {
            return
        }
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
        marquee = nil
        defer { endEditRun() }
        switch done.route {
        case .move(let id):
            // A click only selects, like a click on nothing deselects: no undo step.
            if done.moved { record("Move", before: done.before) }
            if !done.moved, done.wasSelected, findNode(id)?.kind == .text { try? beginTextEdit(id) }
        case .resize:
            record("Resize", before: done.before)
        case .marquee(let frame):
            // A click without moving: the frame's background selects it; outside, nothing.
            if !done.moved, let frame { selectItem(frame) }
        case .moveSeveral, .resizeSeveral, .optionCopy:
            break
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
    /// With Shift a Move press on a node adds it to the selection or takes it out, and moves nothing.
    private mutating func beginGesture(at start: DesignPoint, shift: Bool, option: Bool) -> DesignGesture {
        commitTextEdit()
        endEditRun()
        var route = DesignGesture.Route.none
        var wasSelected = false
        let ids = selectedNodeIDs
        switch tool {
        case .move:
            let hit = hitTest(start)
            if let handle = handle(at: start), let node = selectedNode {
                route = .resize(node.id, handle, node.frame)
            } else if let handle = boxHandle(at: start) {
                route = .resizeSeveral(ids, handle)
            } else if let id = hit, shift {
                toggleSelection(id)
            } else if let id = hit, ids.contains(id), option, let page = selectedPage,
                services.duplicating.duplicateHelp(ids, on: page) == nil {
                route = .optionCopy(ids, mint())
            } else if let id = hit, ids.contains(id), ids.count > 1 {
                route = .moveSeveral(ids)
            } else if let id = hit, !ids.contains(id), selectedPage?.nodes.node(id)?.kind == .frame {
                route = .marquee(id)
            } else if let id = hit {
                wasSelected = id == selectedNodeID
                selectItem(id)
                route = .move(id)
            } else if !shift {
                deselect()
                route = .marquee(nil)
            }
        case .frame, .rectangle, .ellipse:
            if let kind = tool.nodeKind { route = .draw(kind) }
        case .text:
            route = .text
        case .pen:
            break
        }
        return DesignGesture(route: route, start: start, before: snapshot, wasSelected: wasSelected, history: history)
    }
}

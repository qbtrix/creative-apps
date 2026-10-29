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
//           resize keep the routes below whatever `services` holds. A move (of one layer,
//           several or their copies) and a one-layer resize land on whole points
//           (DesignWholePoints); a nudge keeps its fraction. A move first snaps its box with
//           the engine the press built (DesignSnapIndex, SN-4); a resize (one or several)
//           snaps only the edges its handle drags (Shift: the nearer line sets the scale;
//           Option: the far edge mirrors). `.noSnap` snaps nothing.
//   frame, rectangle, ellipse, shape, text   DesignDrawing; once the pointer has moved, the start and
//           the end each snap to the lines of the frame drawn into (Shift: the end's nearer
//           axis only), before whole points (SN-5). A click places the default box unsnapped.
//   pen     nothing.
//
// A drawing tool is good for one shape: once its gesture adds a node (a Text
// click its node, whose edit then opens), the tool goes back to Move.
//
// Locked nodes never move, resize, change or delete, and neither hidden nor
// locked nodes are hit. A lock covers the node's whole subtree (DesignLocking),
// so a layer inside a locked group is locked too (#450), and a layer inside a
// hidden group shows no handles to press (#449), nor moves with the arrow keys (#607).
//
// While a gesture is live (`gesture != nil`) the canvas edits do nothing, as Undo and Redo
// don't: each pointer move rewinds to the gesture's start, so an edit landing between two moves
// would be thrown away while its undo step stayed (#542).
//
// The nudge step and its run key are SuiteKernel's `Nudge`, and the marquee's box
// and the selection it leaves are its `Marquee` (adopt-kernel-selection AS-design). A press on
// a full-size frame finds its handle with the kernel's `HandleHit` (adopt-kernel-transform
// AT-d1), in the node's own unturned frame (`TransformRules.local`), so each handle hits where the
// turned node shows it. The rotate knob above the top (`BoxMath.handles`) turns one selected layer
// about its centre through `runTransform` (DT-5); the knob above several layers' box turns each about
// its own centre by the same angle (#4224), Shift snapping to the kernel's
// `BoxMath.snappedDegrees`; every sample rewinds as a service step does, so the drag is one step
// (transform DT-u). A handle of a turned or mirrored layer resizes it in its own axes, the opposite
// edge kept where it shows (#4223); an upright one resizes, snaps and rounds as before. The angle comes from libm's atan2 (Glibc/Musl/Darwin). Linux-safe.
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Darwin)
import Darwin
#endif
import SuiteKernel

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
        /// Turn the selected layer, whose box this was at the press, by the knob's sweep about its centre.
        case turn(TransformBox)
        /// Duplicate these layers with the ids of this mint and drag the copies.
        case optionCopy([String], DesignIDMint)
        /// Draw a node of this kind (DesignDrawing).
        case draw(DesignNodeKind)
        /// Draw the Shape tool's spec, one step through `addShape` (DesignDrawing).
        case shape
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
    /// The snap engine the press built (nil: no snapping), its build count, and the last step's guides.
    var snap: DesignSnapIndex?, snapBuilds = 0, guides = DesignSnapGuides.empty
}

extension DesignWorkspace {
    /// The topmost visible, unlocked node on the shown page (`shownPage`) under `point`.
    public func hitTest(_ point: DesignPoint) -> String? {
        shownPage?.nodes.hit(at: point)
    }

    /// The handle of the selected node outside any lock and any hidden group (the canvas draws no
    /// handles for a hidden subtree, #449) nearest `point` and within
    /// `handleTolerance` (Chebyshev distance) of where it shows (DesignRect.handles, a handle
    /// being `handleTolerance` across); corners win a tie. A press inside a compact node is never
    /// a handle: its handles sit outside it, so the press moves it. `point` is taken into the node's
    /// unturned frame first, so a turned node's handles, knob included, hit where they show.
    public func handle(at point: DesignPoint) -> DesignHandle? {
        guard !hasMultipleSelection, let id = selectedNodeID, let node = shownPage?.nodes.node(id),
            !isLockedInTree(node.id), !isHiddenInTree(node.id)
        else { return nil }
        let local = TransformRules.local(Point(x: point.x, y: point.y), in: node.transformBox)
        return handle(on: node.frame, at: DesignPoint(x: local.x, y: local.y))
    }

    /// With several layers selected, the handle of their box (`selectionBounds`) under `point`, as
    /// `handle(at:)` finds one on a single layer, the knob above the box included (#4224); nil otherwise.
    func boxHandle(at point: DesignPoint) -> DesignHandle? {
        guard hasMultipleSelection, let box = selectionBounds else { return nil }
        return handle(on: box, at: point)
    }

    /// A full-size frame asks the kernel's `HandleHit` (its inside is no Design handle), then the
    /// knob's square; a compact one tries its corners and knob where they show, outside it.
    private func handle(on frame: DesignRect, at point: DesignPoint) -> DesignHandle? {
        guard frame.isCompact(handleSize: handleTolerance) else {
            let hit = HandleHit.handle(at: Point(x: point.x, y: point.y), in: frame.kernelRect, tolerance: handleTolerance)
            if let handle = hit.flatMap(DesignHandle.init) { return handle }
            guard let knob = frame.handles(size: handleTolerance)[.rotate] else { return nil }
            let distance = Swift.max((knob.x - point.x).magnitude, (knob.y - point.y).magnitude)
            return distance <= handleTolerance ? .rotate : nil
        }
        let inside = point.x > frame.x && point.x < frame.maxX && point.y > frame.y && point.y < frame.maxY
        if inside { return nil }
        let shown = frame.handles(size: handleTolerance)
        let hits = DesignHandle.allCases.compactMap { handle -> (handle: DesignHandle, distance: Double)? in
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

    /// Moves the selected node by the kernel's `Nudge.delta`: 1 point, 10 with Shift. A run of
    /// nudges to one node (`Nudge.runKey`) is one step. Several selected layers move together through `run(.nudge)` (#2463). Does nothing
    /// without an unlocked selection, for a layer hidden in the tree (#607), while editing text
    /// or mid-gesture (#542).
    public mutating func nudge(_ direction: DesignDirection, shift: Bool) {
        guard gesture == nil else { return }
        if hasMultipleSelection { try? run(.nudge(direction, large: shift)); return }
        guard editingTextID == nil, let id = selectedNodeID, !isHiddenInTree(id) else { return }
        let step = Nudge.delta(direction.kernel, large: shift)
        let delta = DesignPoint(x: step.x, y: step.y)
        // A locked node is refused and stays put; the selection's id always exists.
        try? editNode(id, named: "Nudge", coalescing: Nudge.runKey("nudge", [id])) { [playhead] in $0 = $0.moved(by: delta, at: playhead) }
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

    /// Deletes the selected node and its subtree and deselects. Several selected layers go
    /// together through `run(.delete)` (#2463). Does nothing without a selection outside any
    /// lock, while editing text or mid-gesture (#542).
    public mutating func deleteSelection() {
        guard gesture == nil else { return }
        if hasMultipleSelection { try? run(.delete); return }
        guard editingTextID == nil, let node = selectedNode, !isLockedInTree(node.id),
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
            gesture = beginGesture(at: start, modifiers: modifiers)
        }
        guard var current = gesture else { return }
        if end != current.start { current.moved = true }
        let delta = DesignPoint(x: end.x - current.start.x, y: end.y - current.start.y)
        switch current.route {
        case .move(let id):
            restorePages(current.before)
            current.guides = .empty
            guard current.moved, let frame = selectedPage?.nodes.node(id)?.frame else { break }
            // Snap first, whole points second (DesignWholePoints); a keyed axis keys at the playhead (LiveKeying).
            let moveBy = frame.wholeDelta(snapMove(delta, box: frame, modifiers: modifiers, current))
            _ = pages.update(id) { [playhead] in $0 = $0.moved(by: moveBy, at: playhead) }
            current.guides = landedGuides(frame, by: moveBy, modifiers: modifiers, current)
        case .resize(let id, let handle, let original):
            restorePages(current.before)
            current.guides = .empty
            if let t = selectedPage?.nodes.node(id)?.transformBox, t.degrees != 0 || t.flipX || t.flipY {
                _ = pages.update(id) { $0.frame = Self.resized(t, handle, from: current.start, to: end, modifiers: modifiers) }
                break
            }
            let snapped = snapResize(delta, box: original, handle: handle, modifiers: modifiers, current)
            let raw = original.resized(
                handle, by: snapped, keepAspect: modifiers.contains(.shift), fromCenter: modifiers.contains(.option))
            let frame = current.moved ? raw.wholePoints : raw
            _ = pages.update(id) { $0.frame = frame }
            current.guides = landedGuides(on: frame, modifiers: modifiers, current)
        case .marquee(let parent):
            guard current.moved, let page = shownPage else { break }
            let box = Marquee.rect(enclosing: Point(x: current.start.x, y: current.start.y), Point(x: end.x, y: end.y))
            let rect = DesignRect(x: box.minX, y: box.minY, width: box.maxX - box.minX, height: box.maxY - box.minY)
            marquee = rect
            let found = services.marquee.layers(touching: rect, in: parent, on: page)
            selectedNodeIDs = Marquee.union(selectedNodeIDs, found, extending: false)
            for id in selectedNodeIDs { expandAncestors(of: id, in: page.nodes) }
        case .moveSeveral, .resizeSeveral, .optionCopy, .turn:
            applyStep(&current, delta: delta, modifiers: modifiers)
        case .draw(let kind):
            let (from, to) = snapDraw(current, to: end, modifiers: modifiers)
            draw(kind, from: from, to: to, modifiers: modifiers)
            current.guides = landedGuides(on: selectedNode?.frame, modifiers: modifiers, current)
        case .shape:
            let (from, to) = snapDraw(current, to: end, modifiers: modifiers)
            drawShape(from: from, to: to, modifiers: modifiers)
            current.guides = landedGuides(on: selectedNode?.frame, modifiers: modifiers, current)
        case .text:
            let (from, to) = snapDraw(current, to: end, modifiers: modifiers)
            placeText(from: from, to: to)
            current.guides = landedGuides(on: selectedNode?.frame, modifiers: modifiers, current)
        case .none:
            break
        }
        gesture = current
    }

    /// One step of a service route: back to the gesture's start, history included, then the
    /// edit for `delta` from the start. A refused edit leaves the start as it was.
    private mutating func applyStep(_ current: inout DesignGesture, delta: DesignPoint, modifiers: DesignModifiers) {
        rewind(to: current.before)
        history = current.history
        current.guides = .empty
        guard current.moved, let page = selectedPage else { return }
        let transforming = services.transforming
        // A move snaps the selection box, then lands its top-left on a whole point (DesignWholePoints).
        let bounds = selectionBounds
        let moveBy = bounds?.wholeDelta(snapMove(delta, box: bounds, modifiers: modifiers, current)) ?? delta
        do throws(DesignRefusal) {
            switch current.route {
            case .moveSeveral(let ids):
                apply(try transforming.move(ids, by: moveBy, on: page, at: playhead))
            case .resizeSeveral(let ids, let handle):
                let snapped = snapResize(delta, box: bounds, handle: handle, modifiers: modifiers, current)
                apply(try transforming.resize(ids, handle: handle, by: snapped, modifiers: modifiers, on: page))
            case .optionCopy(let ids, let start):
                var mint = start
                let copied = try services.duplicating.duplicate(ids, offset: DesignPoint(x: 0, y: 0), on: page, mint: &mint)
                var copies = page
                copies.nodes = copied.nodes
                let nodes: [DesignNode]
                do throws(DesignRefusal) {
                    nodes = try transforming.move(copied.selection, by: moveBy, on: copies).nodes
                } catch .unchanged {
                    nodes = copied.nodes
                }
                apply(DesignEdit(name: "Duplicate", nodes: nodes, selection: copied.selection,
                                 coalescingKey: DesignEdit.runKey("option-drag", ids)), mint: mint)
            case .turn(let box):
                // The sweep from the press to the pointer about the centre, within ±180°.
                let (c, end) = (box.box, DesignPoint(x: current.start.x + delta.x, y: current.start.y + delta.y))
                let (cx, cy) = ((c.minX + c.maxX) / 2, (c.minY + c.maxY) / 2)
                var turn = (atan2(end.y - cy, end.x - cx) - atan2(current.start.y - cy, current.start.x - cx)) * 180 / .pi
                guard turn.isFinite else { return }
                turn -= 360 * (turn / 360).rounded()
                let degrees = BoxMath.snappedDegrees(box.degrees + turn, modifiers: modifiers.editModifiers)
                if hasMultipleSelection { turnEach(by: degrees - box.degrees) } else {
                    runTransform(.rotate(by: degrees - box.degrees, drag: "knob"))
                }
            default:
                break
            }
        } catch {
            return
        }
        current.guides = landedGuides(on: selectionBounds, modifiers: modifiers, current)
    }

    /// Turns every selected layer by `degrees` about its own centre as one "Rotate" step (#4224); a layer
    /// inside another selected one goes with it. A selection `transformHelp` refuses changes nothing.
    private mutating func turnEach(by degrees: Double) {
        guard transformHelp == nil else { return }
        let before = snapshot
        for root in transformRoots { _ = pages.update(root.id) { $0.place(TransformRules.rotated(root.transformBox, by: degrees)) } }
        record("Rotate", before: before)
    }

    /// `t`'s frame with `handle` dragged from `start` to `end` in the node's own axes (#4223): the sweep
    /// taken into its unturned, unmirrored frame (`TransformRules.local`), the handle's edge moved there
    /// (Shift keeps the aspect, Option works from the centre), and the new centre put back on the page
    /// through the turn and mirrors about the old one, so the opposite edge stays where it shows. No
    /// snap and no whole points: the page's lines and grid don't run along a turned edge.
    static func resized(_ t: TransformBox, _ handle: DesignHandle, from start: DesignPoint, to end: DesignPoint,
                        modifiers: DesignModifiers) -> DesignRect {
        let (a, b) = (TransformRules.local(Point(x: start.x, y: start.y), in: t), TransformRules.local(Point(x: end.x, y: end.y), in: t))
        let local = DesignRect(t.box).resized(handle, by: DesignPoint(x: b.x - a.x, y: b.y - a.y),
                                              keepAspect: modifiers.contains(.shift), fromCenter: modifiers.contains(.option))
        // A unit box about the old centre with the node's turn and mirrors: its matrix takes an offset
        // from the centre in the node's own axes to the page.
        let c = Point(x: (t.box.minX + t.box.maxX) / 2, y: (t.box.minY + t.box.maxY) / 2)
        let unit = TransformBox(box: Rect(minX: c.x - 0.5, minY: c.y - 0.5, maxX: c.x + 0.5, maxY: c.y + 0.5),
                                degrees: t.degrees, flipX: t.flipX, flipY: t.flipY)
        let centre = TransformRules.matrix(of: unit).apply(
            Point(x: local.x + local.width / 2 - c.x + 0.5, y: local.y + local.height / 2 - c.y + 0.5))
        return DesignRect(x: centre.x - local.width / 2, y: centre.y - local.height / 2, width: local.width, height: local.height)
    }

    /// `delta` snapped so `box` moved by it lines up; as is under `.noSnap` or without an engine.
    private func snapMove(_ delta: DesignPoint, box: DesignRect?, modifiers: DesignModifiers, _ current: DesignGesture) -> DesignPoint {
        guard !modifiers.contains(.noSnap), current.moved, let box, let snap = current.snap else { return delta }
        return snap.snapped(delta, box: box, tolerance: handleTolerance)
    }

    /// The guides `box` moved by `moveBy` landed on; none under `.noSnap` or without an engine.
    private func landedGuides(_ box: DesignRect, by moveBy: DesignPoint, modifiers: DesignModifiers, _ current: DesignGesture) -> DesignSnapGuides {
        landedGuides(on: DesignRect(x: box.x + moveBy.x, y: box.y + moveBy.y, width: box.width, height: box.height),
                     modifiers: modifiers, current)
    }

    /// The guides a step's landed `box` sits on; none under `.noSnap`, before a move or without an engine.
    private func landedGuides(on box: DesignRect?, modifiers: DesignModifiers, _ current: DesignGesture) -> DesignSnapGuides {
        guard current.moved, !modifiers.contains(.noSnap), let box, let snap = current.snap else { return .empty }
        return snap.guides(on: box)
    }

    /// `delta` snapped so the edges `handle` drags of `box` line up, and no other edge. Shift: the
    /// nearer of the two lines sets the scale and the other side follows the aspect; Option keeps the
    /// far edge mirrored. As is under `.noSnap` or without an engine.
    private func snapResize(_ delta: DesignPoint, box: DesignRect?, handle: DesignHandle,
                            modifiers: DesignModifiers, _ current: DesignGesture) -> DesignPoint {
        guard current.moved, !modifiers.contains(.noSnap), let box, let snap = current.snap else { return delta }
        let (shift, grow) = (modifiers.contains(.shift), modifiers.contains(.option) ? 2.0 : 1.0)
        let raw = box.resized(handle, by: delta, keepAspect: shift, fromCenter: grow > 1)
        let (h, v) = handle.direction
        func offset(_ axis: DesignSnapLine.Axis, _ side: Int, _ low: Double, _ high: Double) -> Double? {
            side == 0 ? nil : snap.lines.offset(axis, for: [side > 0 ? high : low], tolerance: handleTolerance)
        }
        let (dx, dy) = (offset(.x, h, raw.x, raw.maxX), offset(.y, v, raw.y, raw.maxY))
        guard shift, handle.isCorner, box.width > 0, box.height > 0 else {
            return DesignPoint(x: delta.x + (dx ?? 0), y: delta.y + (dy ?? 0))
        }
        let scale: Double
        if let dx, dy.map({ abs(dx) <= abs($0) }) ?? true {
            scale = (raw.width + Double(h) * dx * grow) / box.width
        } else if let dy {
            scale = (raw.height + Double(v) * dy * grow) / box.height
        } else {
            return delta
        }
        return DesignPoint(x: box.width * (scale - 1) / (Double(h) * grow), y: box.height * (scale - 1) / (Double(v) * grow))
    }

    /// A draw's gesture with its start snapped, and its end snapped, each on both axes once the
    /// pointer has moved (Shift: only the end's nearer axis, then the square). As is under `.noSnap`.
    private func snapDraw(_ current: DesignGesture, to end: DesignPoint, modifiers: DesignModifiers) -> (DesignGesture, DesignPoint) {
        guard current.moved, !modifiers.contains(.noSnap), let snap = current.snap else { return (current, end) }
        func offsets(_ p: DesignPoint) -> (x: Double?, y: Double?) {
            (snap.lines.offset(.x, for: [p.x], tolerance: handleTolerance),
             snap.lines.offset(.y, for: [p.y], tolerance: handleTolerance))
        }
        var drawing = current
        let start = offsets(current.start)
        drawing.start = DesignPoint(x: current.start.x + (start.x ?? 0), y: current.start.y + (start.y ?? 0))
        var (ex, ey) = offsets(end)
        if modifiers.contains(.shift), let x = ex, let y = ey {
            if abs(x) <= abs(y) { ey = nil } else { ex = nil }
        }
        return (drawing, DesignPoint(x: end.x + (ex ?? 0), y: end.y + (ey ?? 0)))
    }

    /// Builds the snap engine once, at the press, for a move, a resize (one layer or several, or
    /// their copies) and a draw, whose candidates are those of the frame it draws into.
    private func buildSnap(_ current: inout DesignGesture) {
        var (moving, parent) = ([String](), String?.none)
        switch current.route {
        case .move(let id), .resize(let id, _, _): moving = [id]
        case .moveSeveral(let ids), .optionCopy(let ids, _), .resizeSeveral(let ids, _): moving = ids
        case .draw, .shape, .text: parent = shownPage?.nodes.deepestFrame(containing: current.start)
        default: return
        }
        var candidates = snapCandidates(moving: moving, drawingInto: parent)
        // A draw outside every frame lines up with the page's top level, which the kernel's
        // candidates give only for a moving layer there.
        if moving.isEmpty, parent == nil, let page = shownPage {
            let roots = page.nodes.filter { !$0.isHidden }.map { DesignSnapCandidate(id: $0.id, frame: $0.frame.snapRect) }
            candidates.insert(contentsOf: roots, at: 0)
        }
        current.snap = DesignSnapIndex(candidates)
        current.snapBuilds += 1
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
        case .moveSeveral, .resizeSeveral, .optionCopy, .turn:
            break
        case .draw(let kind):
            record("Add \(kind.defaultName)", before: done.before)
            tool = .move
        case .shape:  // drawShape recorded the step; a refused draw leaves the tool on
            if pages != done.before.pages { tool = .move }
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
    private mutating func beginGesture(at start: DesignPoint, modifiers: DesignModifiers) -> DesignGesture {
        commitTextEdit()
        endEditRun()
        let (shift, option) = (modifiers.contains(.shift), modifiers.contains(.option))
        var route = DesignGesture.Route.none
        var wasSelected = false
        let ids = selectedNodeIDs
        switch tool {
        case .move:
            // The hit lifted to its group in the entered scope (DesignGroupPick+Kernel).
            let hit = pressedLayer(at: start, modifiers: modifiers)
            if handle(at: start) == .rotate, let node = selectedNode {
                route = .turn(node.transformBox)
            } else if let handle = handle(at: start), let node = selectedNode {
                route = .resize(node.id, handle, node.frame)
            } else if boxHandle(at: start) == .rotate, let bounds = selectionBounds {
                route = .turn(TransformBox(box: bounds.kernelRect))
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
        case .eyedropper:  // one pick per click, at the press; the rest of the drag does nothing
            try? pick(at: start, toStroke: sampleToStroke != option)
        case .shape:
            route = .shape
        case .pen:
            break
        }
        var gesture = DesignGesture(route: route, start: start, before: snapshot, wasSelected: wasSelected, history: history)
        buildSnap(&gesture)
        return gesture
    }
}

extension DesignDirection {
    /// The kernel's direction, for `Nudge.delta`.
    var kernel: Direction {
        switch self {
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        }
    }
}

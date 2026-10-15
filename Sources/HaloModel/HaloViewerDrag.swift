// HaloViewerDrag.swift: dragging a layer in the viewer (#207, LK-7). A point
// in the artboard view maps to composition pixels; mouse-down hits the topmost
// drawn layer at the playhead and selects it; each move only updates
// `viewerDrag.delta`, which `viewerDrawList` shows as a preview offset; mouse-up
// records one "Move" through `services.dragging.commitMove` (keys when the
// position is animated); a cancel drops the preview. Linux-safe.

extension HaloProject {
    /// A point in the artboard view (top-left origin, `artboardWidth` by
    /// `artboardHeight` points) in composition pixels; nil with no composition
    /// or a side that isn't positive, so nothing divides by zero.
    public func compositionPoint(x: Double, y: Double, artboardWidth: Double, artboardHeight: Double) -> HaloPoint? {
        guard let comp = selectedComposition, artboardWidth > 0, artboardHeight > 0,
            comp.width > 0, comp.height > 0
        else { return nil }
        return HaloPoint(x: x * Double(comp.width) / artboardWidth, y: y * Double(comp.height) / artboardHeight)
    }

    /// Mouse-down at `point` (composition pixels): selects the topmost drawn
    /// layer under it at the playhead and starts a drag of it. Over empty
    /// space or the surround nothing changes. Never an undo step.
    public mutating func beginViewerDrag(at point: HaloPoint) {
        guard let comp = selectedComposition,
            let id = services.dragging.hit(comp, at: comp.playheadFrame, point: point)
        else { return }
        selectLayer(id)
        viewerDrag = HaloViewerDragState(layerID: id, start: point, delta: HaloPoint(x: 0, y: 0))
    }

    /// The drag is now at `point`: only the preview offset changes; nothing
    /// is recorded until `endViewerDrag`.
    public mutating func moveViewerDrag(to point: HaloPoint) {
        guard let start = viewerDrag?.start else { return }
        viewerDrag?.delta = HaloPoint(x: point.x - start.x, y: point.y - start.y)
    }

    /// Mouse-up: moves the dragged layer by the drag's delta at the playhead
    /// as one "Move" step. A zero delta (a click) adds no step.
    public mutating func endViewerDrag() {
        defer { viewerDrag = nil }
        guard let drag = viewerDrag, drag.delta.x != 0 || drag.delta.y != 0,
            let compID = selectedCompositionID
        else { return }
        let dragging = services.dragging
        edit("Move", control: "halo.viewer.artboard") { doc in
            guard let c = doc.compositions.firstIndex(where: { $0.id == compID }) else { return }
            let frame = doc.compositions[c].playheadFrame
            try dragging.commitMove(drag.layerID, by: drag.delta, at: frame, in: &doc.compositions[c])
        }
        endCoalescing()
    }

    /// Escape: drops the drag and its preview; nothing is recorded.
    public mutating func cancelViewerDrag() {
        viewerDrag = nil
    }
}

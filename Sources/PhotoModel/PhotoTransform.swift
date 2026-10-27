// PhotoTransform.swift: Free Transform's canvas drag (PV-7). While
// `transformDraft` is set, every canvas drag comes here instead of the tool:
// the press takes the handle under it (`services.transform.handle`, 6 pt at
// the zoom) and the draft as it was; each sample sets the draft to that draft
// dragged from the press to the pointer (`services.transform.dragged`, the
// kernel's HandleHit and BoxMath on the live services), so a body drag moves
// the box, a side or corner scales it and the rotate zone turns it.
// `endDrag` records the gesture as one "Transform" step. Linux-safe.
import CoreRaster

extension PhotoWorkspace {
    /// A drag on the transform's handles or body, from the press to `end`; a press off the box drags nothing.
    mutating func transformDrag(from start: Mask.Point, to end: Mask.Point, modifiers: DragModifiers, zoom: Double) {
        guard let draft = transformDraft else { return }
        var current = stroke ?? PhotoStroke(tool: tool, start: start, layerID: nil)
        if stroke == nil {
            current.transformFrom = draft
            current.transformHandle = services.transform.handle(at: start, in: draft, tolerance: 6 / max(zoom, 1e-6))
        }
        stroke = current
        guard let from = current.transformFrom, let handle = current.transformHandle else { return }
        let next = services.transform.dragged(from, handle: handle, from: current.start, to: end, modifiers: modifiers)
        guard next != transformDraft else { return }
        transformDraft = next
        touch(.all)
    }
}

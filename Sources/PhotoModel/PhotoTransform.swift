// PhotoTransform.swift: Free Transform's canvas drag (PV-7). While
// `transformDraft` is set, every canvas drag comes here instead of the tool:
// the press takes the handle under it (`services.transform.handle`, 6 pt at
// the zoom) and the draft as it was; each sample sets the draft to that draft
// dragged from the press to the pointer (`services.transform.dragged`, the
// kernel's HandleHit and BoxMath on the live services), so a body drag moves
// the box, a side or corner scales it and the rotate zone turns it.
// `endDrag` records the gesture as one "Transform" step. A Select move's drag
// comes here too, on the implied draft PhotoStroke.swift begins for it (the
// press takes `.inside`); its frames damage only where the layer was and is,
// and its release lays the offsets. Linux-safe.
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
        let damage = current.movesLayer ? moveDamage(from: transformDraft, to: next) : .all
        transformDraft = next
        touch(damage)
    }

    /// Where a Move drag's frame changes the canvas: the layer where draft `a` had it and where `b` puts it;
    /// everything when the move runs off the canvas's integer range.
    private func moveDamage(from a: TransformDraft?, to b: TransformDraft) -> PhotoDamage {
        guard let at = index(of: b.layerID), let rect = bounds(of: layers[at]) else { return .all }
        func placed(_ d: TransformDraft) -> PixelRect? {
            let (dx, dy) = (d.transform.dx.rounded(), d.transform.dy.rounded())
            guard dx.isFinite, dy.isFinite, abs(dx) < 1e7, abs(dy) < 1e7 else { return nil }
            return rect.offsetBy(Int(dx), Int(dy))
        }
        guard let from = placed(a ?? b), let to = placed(b) else { return .all }
        return .region(from.union(to))
    }
}

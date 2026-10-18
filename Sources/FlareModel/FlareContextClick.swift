// FlareContextClick.swift: what the stage's context menu acts on. A right click on an item the selection doesn't hold
// selects it first, as a click would, so Cut or Delete never acts on a selection somewhere else on the stage; a held
// item (its layer, unless Direct Select is the tool) or empty stage keeps the selection. Not an undo step.
import FlareCore

extension FlareWorkspace {
    /// The topmost stage item under `point`, in scene points; nil over empty stage.
    public func stageHit(at point: Point, stageScale: Double) -> StageAddress? { hit(at: point, stageScale: stageScale) }

    /// A right click at `point`: the hit item becomes the selection unless the selection already holds it.
    public mutating func contextClick(at point: Point, stageScale: Double) {
        guard let hit = hit(at: point, stageScale: stageScale) else { return }
        let held = tool == .directSelect ? selection.contains(hit) : selection.contains { $0.layerID == hit.layerID }
        if !held { setSelection([hit]) }
    }
}

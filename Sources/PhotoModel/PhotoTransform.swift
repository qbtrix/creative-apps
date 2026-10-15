// PhotoTransform.swift: Free Transform (PV-7 owns this file). While
// `transformDraft` is set, every canvas drag comes here instead of the tool;
// until PV-7 builds the handles it changes nothing. Linux-safe.
import CoreRaster

extension PhotoWorkspace {
    /// A drag on the transform's handles or body; a no-op until PV-7.
    mutating func transformDrag(from start: Mask.Point, to end: Mask.Point, modifiers: DragModifiers, zoom: Double) {}
}

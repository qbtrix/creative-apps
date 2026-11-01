// HaloDrawLift.swift: a viewer drag's lift (render contract rule 3). At the
// drag's start the frame's draw list is split once around the dragged layer:
// the layers under it, the layer itself and the layers over it. The viewer
// draws the three parts once and moves only the lifted part by the drag's
// delta, a compositor transform, so no step redraws a layer; mouse-up commits
// the move and the viewer draws the moved frame once. The split is exact
// only when every part blends normally over the one under it (source-over is
// associative, so grouping changes nothing), so a lifted layer or a layer
// over it with any other blend mode gets no lift and the drag keeps drawing
// the offset list per step (HaloDrawList.offsetting). Linux-safe.

/// The frame split around one layer: drawn bottom first, `below`, then
/// `lifted` moved by the drag's delta, then `above`.
public struct HaloDrawLift: Sendable, Hashable {
    public var layerID: String
    public var below: HaloDrawList
    public var lifted: HaloDrawList
    public var above: HaloDrawList
}

extension HaloDrawList {
    /// The list split around `layerID`; nil when it isn't drawn exactly once,
    /// or it or a layer over it blends other than normally.
    public func lift(_ layerID: String) -> HaloDrawLift? {
        let hits = items.indices.filter { items[$0].layerID == layerID }
        guard hits.count == 1, let i = hits.first,
            items[i...].allSatisfy({ $0.blendMode == .normal })
        else { return nil }
        func part(_ slice: ArraySlice<HaloDrawItem>) -> HaloDrawList {
            HaloDrawList(width: width, height: height, frame: frame, items: Array(slice))
        }
        return HaloDrawLift(
            layerID: layerID, below: part(items[..<i]), lifted: part(items[i...i]), above: part(items[(i + 1)...]))
    }
}

extension HaloProject {
    /// The live viewer drag's lift: the frame at the playhead without the
    /// drag's offset, split around the dragged layer; nil with no drag or
    /// when the layer can't be lifted (`HaloDrawList.lift`).
    public var viewerLift: HaloDrawLift? {
        guard let drag = viewerDrag, let comp = selectedComposition else { return nil }
        return services.drawing.drawList(comp, at: comp.playheadFrame).lift(drag.layerID)
    }
}

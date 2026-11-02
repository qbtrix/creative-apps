// HaloKeyPick+Kernel.swift (key-editing KE-3): the timeline's key picks as
// an adapter over the kernel `Selection<HaloKeyRef>` (`keySelection`). A pick
// spans layers: a plain click picks a lane's keys at a frame and selects that
// layer, Shift adds them, ⌘ takes them out once all are picked, and a press
// on the lane's bed (nil frame) clears. After each pick the kernel's `prune`
// drops keys no longer in the selected composition (#2763), keeping other
// layers'. Select All Keys picks every key of every layer, hidden ones too
// (Halo has no eye yet; a layer out of its range at the playhead is still
// picked). A key is a key of an animated track (two or more keys). A pick is
// never an edit. Linux-safe: no UI imports.
import SuiteKernel

extension HaloProject {
    /// Picks `layerID`'s keys at `frame` the way `mode` says; a nil frame
    /// clears the pick.
    public mutating func pickLaneKeys(layerID: String, frame: Int?, mode: Pick) {
        guard let frame else { return keySelection.clear() }
        if layerID != selectedLayerID, mode == .replace { selectLayer(layerID) }
        let keys = compositionKeys.filter { $0.layerID == layerID && $0.frame == frame }
        switch mode {
        case .replace: keySelection.replace(keys)
        case .extend: for key in keys { keySelection.pick(key, .extend) }
        case .toggle:
            let all = !keys.isEmpty && keys.allSatisfy { keySelection.contains($0) }
            for key in keys where keySelection.contains(key) == all { keySelection.pick(key, .toggle) }
        }
        let alive = Set(compositionKeys)
        keySelection.prune { alive.contains($0) }
    }

    /// Picks every key of the selected composition, hidden layers included.
    public mutating func selectAllKeys() {
        keySelection.selectAll(compositionKeys)
    }

    /// The frames `layerID`'s lane draws picked.
    public func pickedFrames(of layerID: String) -> Set<Int> {
        Set(pickedKeyframes.filter { $0.layerID == layerID }.map(\.frame))
    }

    /// Nil when Select All Keys can act; otherwise why not.
    public var selectAllKeysHelp: String? {
        compositionKeys.isEmpty ? "There are no keys to select." : nil
    }

    /// Every key of the selected composition's animated tracks: layers top
    /// first, then `HaloProperty.keyable` order, then by frame.
    var compositionKeys: [HaloKeyRef] {
        let layers = selectedComposition?.layers ?? []
        return layers.flatMap { layer in
            HaloProperty.keyable.flatMap { property -> [HaloKeyRef] in
                guard let track = layer.tracks[property.rawValue], track.count >= 2 else { return [] }
                return track.map(\.frame).sorted().map { HaloKeyRef(layerID: layer.id, property: property, frame: $0) }
            }
        }
    }
}

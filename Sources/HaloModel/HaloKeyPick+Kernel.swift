// HaloKeyPick+Kernel.swift (key-editing KE-1 stubs, KE-3 bodies): the
// timeline's key picks as an adapter over the kernel `Selection<HaloKeyRef>`
// (`keySelection`). On the stubs a pick forwards to today's lane pick
// (`selectLaneKeys`, narrowed to the selected layer): replace starts over,
// extend and toggle add to it, and a nil frame (a press on the lane's bed)
// clears it. Select All Keys waits on KE-3. A pick is never an edit.
// Linux-safe: no UI imports.
import SuiteKernel

extension HaloProject {
    /// Picks `layerID`'s keys at `frame` the way `mode` says; a nil frame
    /// clears the pick.
    public mutating func pickLaneKeys(layerID: String, frame: Int?, mode: Pick) {
        guard let frame else { return clearKeySelection() }
        selectLaneKeys(layerID: layerID, frame: frame, extending: mode != .replace)
    }

    /// Picks every key of the selected composition, hidden layers included (KE-3).
    public mutating func selectAllKeys() {}

    /// The frames `layerID`'s lane draws picked.
    public func pickedFrames(of layerID: String) -> Set<Int> {
        Set(pickedKeyframes.filter { $0.layerID == layerID }.map(\.frame))
    }

    /// Nil when Select All Keys can act; otherwise why not.
    public var selectAllKeysHelp: String? { "Not built yet (KE-3)." }
}

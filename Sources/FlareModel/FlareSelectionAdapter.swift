// FlareSelectionAdapter.swift: the stage selection on SuiteKernel's `Selection<StageAddress>` (adopt-kernel-selection
// AS-flare). `picks` is the kernel's ordered selection, primary last; `selection` reads it as a list. A click is the
// kernel's `.replace` pick, Shift-click its `.toggle` (under Select, a hit on a held layer prunes the whole layer), a
// marquee joins through `Marquee.union`. Every change goes through `adopt`: the layers panel follows the primary's
// layer, and a change to the picks ends the coalescing run (`endCoalescing`), so one scrub never spans two
// selections; a click the kernel reports as no change keeps it. Linux-safe.
import SuiteKernel

extension FlareWorkspace {
    /// The stage selection in selection order, each item once (the kernel's `ordered`).
    public internal(set) var selection: [StageAddress] {
        get { picks.ordered }
        set { picks.replace(newValue) }
    }

    /// A click: `hit` alone, or with Shift toggled in the selection. Empty stage deselects, unless Shift is held.
    mutating func select(_ hit: StageAddress?, extending: Bool) {
        guard let hit else { return extending ? () : setSelection([]) }
        var next = picks
        let changed: Bool
        if !extending {
            changed = next.pick(hit, .replace)
        } else if tool == .select, picks.ordered.contains(where: { $0.layerID == hit.layerID }) {
            next.prune { $0.layerID != hit.layerID }
            changed = true
        } else {
            changed = next.pick(hit, .toggle)
        }
        adopt(next, changed: changed)
    }

    /// Sets the stage selection; the layers panel follows its last layer.
    mutating func setSelection(_ items: [StageAddress]) {
        var next = picks
        next.replace(items)
        adopt(next, changed: next.ordered != picks.ordered)
    }

    /// A marquee found `found`: it replaces the selection, or with Shift (`extending`) joins after it.
    mutating func marqueeSelect(_ found: [StageAddress], extending: Bool) {
        setSelection(Marquee.union(selection, found, extending: extending))
    }

    /// Makes `next` the picks and points the layers panel at the primary's layer. A change ends the edit run.
    mutating func adopt(_ next: Selection<StageAddress>, changed: Bool) {
        picks = next
        selectedLayerID = next.primary?.layerID
        if changed { endCoalescing() }
    }
}

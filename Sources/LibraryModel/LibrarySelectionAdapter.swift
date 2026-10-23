// LibrarySelectionAdapter.swift: the grid's selection on SuiteKernel's
// `Selection<String>` (adopt-kernel-selection AS-library). `picks` is the
// kernel's ordered selection; `selection` reads it as a set. A click is the
// kernel's `pick` through the display order, an arrow its `move` in a grid of
// columns, and `select(_:)` its `replace`. A photo the selected collection
// doesn't show is refused and changes nothing. A change to the picked set ends
// the edit run (`endCoalescing`), so one drag never spans two selections; a
// refused click, or one that changes nothing, keeps it. Linux-safe.
import SuiteKernel

extension LibraryCatalog {
    /// Sets the grid selection; ids not shown in the selected collection are
    /// dropped. A change ends the edit run.
    public mutating func select(_ ids: Set<String>) {
        var next = picks
        next.replace(order.filter(ids.contains))
        adopt(next)
    }

    /// One click on photo `id`: replace, toggle, or extend from the anchor
    /// through the display order. Returns false, changing nothing, when the
    /// kernel refuses it (a photo the collection doesn't show) or it changes nothing.
    @discardableResult
    public mutating func pick(_ id: String, _ kind: Pick) -> Bool {
        // A range comes from `order`, so only the clicked id can be one not shown.
        let shown = order.contains(id)
        var next = picks
        guard next.pick(id, kind, order: order, canAdd: { $0 != id || shown }) else { return false }
        adopt(next)
        return true
    }

    /// An arrow key in a grid of `columns`: the one photo next to the primary
    /// (the kernel's `move`); at an edge it stays put. With no shown photo
    /// selected it picks the first. `columns` is clamped to 1...order.count.
    public mutating func move(_ direction: Direction, columns: Int) {
        guard let first = order.first else { return }
        var next = picks
        if let primary = next.primary, order.contains(primary) {
            next.move(direction, order: order, columns: min(max(columns, 1), order.count))
        } else {
            next.replace([first])
        }
        adopt(next)
    }

    /// Makes `next` the picks. A change to the picked set ends the edit run;
    /// the same photos in a new order keep it.
    mutating func adopt(_ next: Selection<String>) {
        let changed = next.set != selection
        picks = next
        if changed { endCoalescing() }
    }
}

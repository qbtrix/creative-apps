// DesignSelect+Kernel.swift: Design's adapter onto SuiteKernel's shared Select tool (#6012). A point hits what the
// Move tool's press hits (`hitTest`, the topmost visible unlocked layer), a box touches what Move's marquee
// touches at the top level (`services.marquee`), and the picks are `selection`, the one the Layers list shows.
// Move's Shift-click and its marquee run the same kernel rule (DesignSelection, DesignCanvasEditing), so the two
// tools share one implementation. A pick is view state, never an undo step. Linux-safe.
import SuiteKernel

extension DesignWorkspace: SelectTarget {
    public func layerHits(in rect: Rect) -> [String] {
        guard let page = selectedPage else { return [] }
        let box = DesignRect(x: rect.minX, y: rect.minY, width: rect.maxX - rect.minX, height: rect.maxY - rect.minY)
        return services.marquee.layers(touching: box, in: nil, on: page)
    }

    public var selectPicks: Selection<String> { selection }

    public mutating func setSelectPicks(_ picks: Selection<String>) {
        guard picks != selection else { return }
        adopt(picks)
        if let page = selectedPage { for id in picks.ordered { expandAncestors(of: id, in: page.nodes) } }
    }

    /// A Select press on `id`: the kernel's click (Shift toggles); a layer that can't join is refused.
    mutating func selectClick(_ id: String, extending: Bool) {
        commitTextEdit()
        setSelectPicks(SelectTool.click(selection, hit: id, extending: extending, canAdd: canAddToSelection))
    }
}

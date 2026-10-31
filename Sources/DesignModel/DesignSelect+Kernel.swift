// DesignSelect+Kernel.swift: Design's adapter onto SuiteKernel's shared Select tool (#6012). Design's one pointer
// tool on V (the `move` case) is its Select: a click selects and a drag on a selected layer moves it. A point hits
// what its press hits (`hitTest`, the topmost visible unlocked layer), a box touches what its marquee
// touches (`services.marquee`), inside the top-level frame that holds the whole box, and the picks are `selection`, the one the Layers list shows.
// Its Shift-click and its marquee run the kernel's `SelectTool.click` and `SelectTool.box` (DesignSelection,
// DesignCanvasEditing), so Design has no select logic of its own. A pick is view state, never an undo step. Linux-safe.
import SuiteKernel

extension DesignWorkspace: SelectTarget {
    public func layerHits(in rect: Rect) -> [String] {
        guard let page = selectedPage else { return [] }
        let box = DesignRect(x: rect.minX, y: rect.minY, width: rect.maxX - rect.minX, height: rect.maxY - rect.minY)
        // At the level of the top-level frame holding the whole box, as Move's marquee from that frame's background.
        let frame = page.nodes.first {
            $0.kind == .frame && $0.frame.x <= box.x && $0.frame.y <= box.y && $0.frame.maxX >= box.maxX && $0.frame.maxY >= box.maxY
        }
        return services.marquee.layers(touching: box, in: frame?.id, on: page)
    }

    public var selectPicks: Selection<String> { selection }

    public mutating func setSelectPicks(_ picks: Selection<String>) {
        guard picks != selection else { return }
        adopt(picks)
        if let page = selectedPage { for id in picks.ordered { expandAncestors(of: id, in: page.nodes) } }
    }
}

// Live/DesignSVG.swift: the SVG text of Design nodes, what File > Export writes
// for the SVG format (LiveExport.svg and DesignWorkspace.exportSVG call it).
// Design's own drawing, which no shared module has. Linux-safe: text only.

/// The SVG text of nodes inside a box. One element per visible layer in paint order; the box is
/// the viewBox and coordinates are relative to its origin.
enum DesignSVG {
    static func document(_ nodes: [DesignNode], box: DesignRect, clip: Bool) -> String {
        // DE-5 fills this per the packet's pseudocode (QD-V8).
        "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \(box.width) \(box.height)\"/>"
    }
}

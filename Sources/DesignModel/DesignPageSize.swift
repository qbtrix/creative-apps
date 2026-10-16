// DesignPageSize.swift: the page's size and what reaches past it (canvas-basics
// CB-8). setPageSize changes the selected page's width and height as one
// "Change Page Size" step, each side clamped to 1...100,000; layers keep their
// frames, so a smaller page can cut a layer. contentBounds is the union of the
// visible layers' frames (a hidden layer hides its subtree), which the canvas's
// past-the-edge overlay lays itself out over, and isPastEdge says whether one
// layer reaches outside the page's rectangle at (0, 0). Linux-safe: no UI imports.

extension DesignWorkspace {
    /// The smallest and largest a page side can be, in points.
    static let pageSideRange = 1.0...100_000.0

    /// Sets the selected page's size as one step "Change Page Size". Clamps to 1...100,000;
    /// a non-finite value or the current size changes nothing and records nothing, and an open
    /// text edit stays open. Layers stay put. With no open file nothing happens.
    public mutating func setPageSize(width: Double, height: Double) {
        guard let index = pages.firstIndex(where: { $0.id == selectedPageID }),
            width.isFinite, height.isFinite
        else { return }
        let range = Self.pageSideRange
        let newWidth = Swift.min(Swift.max(width, range.lowerBound), range.upperBound)
        let newHeight = Swift.min(Swift.max(height, range.lowerBound), range.upperBound)
        guard newWidth != pages[index].frameWidth || newHeight != pages[index].frameHeight else { return }
        commitTextEdit()
        let before = snapshot
        (pages[index].frameWidth, pages[index].frameHeight) = (newWidth, newHeight)
        record("Change Page Size", before: before)
    }
}

extension DesignPage {
    /// The union of the visible layers' frames; nil on an empty page. A hidden layer's
    /// children are skipped with it; a visible group's children count.
    public var contentBounds: DesignRect? {
        var bounds: (minX: Double, minY: Double, maxX: Double, maxY: Double)?
        func visit(_ nodes: [DesignNode]) {
            for node in nodes where !node.isHidden {
                let frame = node.frame
                if let box = bounds {
                    bounds = (
                        Swift.min(box.minX, frame.x), Swift.min(box.minY, frame.y),
                        Swift.max(box.maxX, frame.maxX), Swift.max(box.maxY, frame.maxY))
                } else {
                    bounds = (frame.x, frame.y, frame.maxX, frame.maxY)
                }
                visit(node.children)
            }
        }
        visit(nodes)
        return bounds.map { DesignRect(x: $0.minX, y: $0.minY, width: $0.maxX - $0.minX, height: $0.maxY - $0.minY) }
    }

    /// Whether a layer's frame reaches past the page's edge: the page is the rectangle at (0, 0)
    /// with the page's size.
    public func isPastEdge(_ node: DesignNode) -> Bool {
        let frame = node.frame
        return frame.x < 0 || frame.y < 0 || frame.maxX > frameWidth || frame.maxY > frameHeight
    }
}

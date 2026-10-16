// Live/LiveFraming.swift: what View > Zoom to Selection shows on the live
// services. The rect is the union of the selected layers' frames that are
// visible: a layer hidden itself, or by a frame or group around it, is left
// out, and an id not on the page is skipped. With none left the rect is nil
// and the help reads "Select a layer first.", so the help is nil exactly when
// the rect is not (the read-only half of the help law). Linux-safe.

public struct LiveFraming: ViewFraming {
    public init() {}

    public func framingHelp(_ ids: [String], on page: DesignPage) -> String? {
        rectToShow(ids, on: page) == nil ? DesignRefusal.nothingSelected.help : nil
    }

    public func rectToShow(_ ids: [String], on page: DesignPage) -> DesignRect? {
        let frames = Self.visibleFrames(of: Set(ids), in: page.nodes)
        guard let first = frames.first else { return nil }
        return frames.dropFirst().reduce(first) { box, frame in
            let (x, y) = (Swift.min(box.x, frame.x), Swift.min(box.y, frame.y))
            return DesignRect(x: x, y: y, width: Swift.max(box.maxX, frame.maxX) - x, height: Swift.max(box.maxY, frame.maxY) - y)
        }
    }

    /// The frames of the nodes in `ids` under `nodes`; a hidden node hides its whole subtree.
    private static func visibleFrames(of ids: Set<String>, in nodes: [DesignNode]) -> [DesignRect] {
        nodes.filter { !$0.isHidden }.flatMap { node in
            (ids.contains(node.id) ? [node.frame] : []) + visibleFrames(of: ids, in: node.children)
        }
    }
}

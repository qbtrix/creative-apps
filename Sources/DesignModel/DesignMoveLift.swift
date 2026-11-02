// DesignMoveLift.swift: a live move drag as the canvas draws it without repainting the page
// (render contract rule 3; Design's canvas is SwiftUI, so the lift is an offset view, not
// CanvasLiveLayer). `moveLift` is the page as it was at the press, the first and last node of
// the moved layers' run in paint order (DesignPage.painted's: depth first, hidden subtrees
// skipped), and how far the drag has moved them. The canvas draws the nodes before the run, the
// run, and the nodes after it, each from that unchanged page, and moves only the run's view.
// Nil unless a Move drag (one layer or several) has moved, and nil when the moved layers are
// not one unbroken run in paint order, which a single offset view can't draw in place.
// Linux-safe: no UI imports.

public struct DesignMoveLift: Sendable, Equatable {
    /// The selected page as it was at the press.
    public let page: DesignPage
    /// The first and last painted node of the moved run, in paint order.
    public let firstID, lastID: String
    /// How far the run has moved since the press, in page points.
    public let offset: DesignPoint
}

extension DesignWorkspace {
    public var moveLift: DesignMoveLift? {
        guard let gesture, gesture.moved else { return nil }
        let roots: [String]
        switch gesture.route {
        case .move(let id): roots = [id]
        case .moveSeveral(let ids): roots = ids
        default: return nil
        }
        guard let page = gesture.before.pages.first(where: { $0.id == selectedPageID }), let root = roots.first,
              let was = page.nodes.node(root)?.frame, let now = selectedPage?.nodes.node(root)?.frame,
              let run = Self.run(of: Set(roots), in: page.nodes)
        else { return nil }
        return DesignMoveLift(
            page: page, firstID: run.first, lastID: run.last, offset: DesignPoint(x: now.x - was.x, y: now.y - was.y))
    }

    /// The first and last painted node under `roots`, when those nodes are one unbroken run in paint order.
    static func run(of roots: Set<String>, in nodes: [DesignNode]) -> (first: String, last: String)? {
        var (first, last, broken, ended) = (String?.none, String?.none, false, false)
        func walk(_ nodes: [DesignNode], inside: Bool) {
            for node in nodes where !node.isHidden {
                let lifted = inside || roots.contains(node.id)
                if lifted {
                    if ended { broken = true }
                    if first == nil { first = node.id }
                    last = node.id
                } else if first != nil {
                    ended = true
                }
                walk(node.children, inside: lifted)
            }
        }
        walk(nodes, inside: false)
        guard !broken, let first, let last else { return nil }
        return (first, last)
    }
}

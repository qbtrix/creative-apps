// Fakes/DesignSelectFakes.swift: the fixture fakes for the select area (marquee,
// move/resize/nudge/delete, align and distribute, Zoom to Selection), so views,
// snapshots and fake-mode journeys build before the live types. Each keeps its
// protocol's undo case and the help law, and acts anywhere in the tree with the
// simplest rule: the marquee picks what it touches at the level it started in
// and never a hidden or locked layer or one inside them; the others ignore
// locks and hidden layers. Stand-ins, never shipped as `.live`. Linux-safe.

public struct FakeMarquee: MarqueeSelecting {
    public init() {}

    public func layers(touching rect: DesignRect, in parentID: String?, on page: DesignPage) -> [String] {
        let chain = parentID.map { (page.nodes.ancestors(of: $0) ?? []) + [$0] } ?? []
        let open = chain.allSatisfy { id in page.nodes.node(id).map { !$0.isHidden && !$0.isLocked } ?? false }
        guard open else { return [] }
        let level = parentID.flatMap { page.nodes.node($0)?.children } ?? page.nodes
        return level.filter { n in
            !n.isHidden && !n.isLocked && n.frame.x <= rect.maxX && rect.x <= n.frame.maxX
                && n.frame.y <= rect.maxY && rect.y <= n.frame.maxY
        }.map(\.id)
    }
}

public struct FakeTransforming: SelectionTransforming {
    public init() {}

    public func transformHelp(_ ids: [String], on page: DesignPage) -> String? { fakeSelectedHelp(ids, page) }

    public func move(_ ids: [String], by delta: DesignPoint, on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try fakeChange(ids, page, "Move", key: "move") { $0.translate(by: delta) }
    }

    /// Each layer's own frame by `handle`; children stay, as a one-layer resize leaves them today.
    public func resize(_ ids: [String], handle: DesignHandle, by delta: DesignPoint, modifiers: DesignModifiers,
                       on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try fakeChange(ids, page, "Resize", key: "resize") {
            $0.frame = $0.frame.resized(
                handle, by: delta, keepAspect: modifiers.contains(.shift), fromCenter: modifiers.contains(.option))
        }
    }

    public func nudge(_ ids: [String], _ direction: DesignDirection, large: Bool,
                      on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        let step = large ? 10.0 : 1.0
        let delta = switch direction {
        case .up: DesignPoint(x: 0, y: -step)
        case .down: DesignPoint(x: 0, y: step)
        case .left: DesignPoint(x: -step, y: 0)
        case .right: DesignPoint(x: step, y: 0)
        }
        return try fakeChange(ids, page, "Nudge", key: "nudge") { $0.translate(by: delta) }
    }

    public func delete(_ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        guard !fakeFind(ids, page).isEmpty else { throw .nothingSelected }
        var nodes = page.nodes
        for id in ids { _ = nodes.remove(id) }
        return DesignEdit(name: "Delete", nodes: nodes, selection: [])
    }
}

public struct FakeAligning: LayerAligning {
    public init() {}

    public func alignHelp(_ edge: DesignAlignEdge, _ ids: [String], on page: DesignPage) -> String? {
        fakeSelectedHelp(ids, page)
    }

    /// To the selection's bounds; one layer aligns to the page.
    public func align(_ edge: DesignAlignEdge, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        let selected = fakeFind(ids, page)
        let whole = DesignRect(x: 0, y: 0, width: page.frameWidth, height: page.frameHeight)
        guard let box = selected.count == 1 ? whole : fakeUnion(selected.map(\.frame)) else { throw .nothingSelected }
        return try fakeChange(ids, page, edge.title) { node in
            let f = node.frame
            let x: Double = switch edge {
            case .left: box.x
            case .center: box.x + (box.width - f.width) / 2
            case .right: box.maxX - f.width
            case .top, .middle, .bottom: f.x
            }
            let y: Double = switch edge {
            case .top: box.y
            case .middle: box.y + (box.height - f.height) / 2
            case .bottom: box.maxY - f.height
            case .left, .center, .right: f.y
            }
            node.translate(by: DesignPoint(x: x - f.x, y: y - f.y))
        }
    }

    public func distributeHelp(_ axis: DesignDistributeAxis, _ ids: [String], on page: DesignPage) -> String? {
        fakeFind(ids, page).count >= 3 ? nil : DesignRefusal.tooFewToDistribute.help
    }

    /// Equal gaps between the layers in position order; the outer two stay.
    public func distribute(_ axis: DesignDistributeAxis, _ ids: [String],
                           on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        let horizontal = axis == .horizontal
        let selected = fakeFind(ids, page).sorted { horizontal ? $0.frame.x < $1.frame.x : $0.frame.y < $1.frame.y }
        guard selected.count >= 3, let first = selected.first, let last = selected.last else { throw .tooFewToDistribute }
        func length(_ node: DesignNode) -> Double { horizontal ? node.frame.width : node.frame.height }
        let start = horizontal ? first.frame.maxX : first.frame.maxY
        let end = horizontal ? last.frame.x : last.frame.y
        let inner = selected.dropFirst().dropLast()
        let gap = (end - start - inner.reduce(0) { $0 + length($1) }) / Double(inner.count + 1)
        var targets: [String: Double] = [:]
        var cursor = start + gap
        for node in inner {
            targets[node.id] = cursor
            cursor += length(node) + gap
        }
        return try fakeChange(ids, page, axis.title) { node in
            guard let to = targets[node.id] else { return }
            node.translate(by: horizontal ? DesignPoint(x: to - node.frame.x, y: 0) : DesignPoint(x: 0, y: to - node.frame.y))
        }
    }
}

public struct FakeFraming: ViewFraming {
    public init() {}

    public func framingHelp(_ ids: [String], on page: DesignPage) -> String? { fakeSelectedHelp(ids, page) }

    public func rectToShow(_ ids: [String], on page: DesignPage) -> DesignRect? {
        fakeUnion(fakeFind(ids, page).map(\.frame))
    }
}

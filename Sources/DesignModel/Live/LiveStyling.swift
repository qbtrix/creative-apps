// Live/LiveStyling.swift: the inspector's style rows on the live services, the
// shipping StyleEditing (style-rows ST-1, blueprint 5.4). Every setter acts on
// the named layers anywhere in the page tree as one edit coalescing under
// `runKey(base, ids)`, so a scrub on a row is one undo step per selection.
// Refusals, in order: no named layer `.nothingSelected`; the first layer locked
// in the tree `.locked(name)`; the first hidden in the tree `.hidden(name)`;
// then the kinds a property reaches (corner radius: rectangles and frames; text
// style: text), skipping the rest of a mixed selection and refusing with
// `.noCorners` / `.notText`, named by the last selected, when none take it;
// nothing changed `.unchanged`. Clamps: opacity 0...1, stroke width 0...1000
// (nil removes it), radius 0...half the shorter side, width and height at least
// 1, text size 1...1000, weight 100...900; a non-finite value changes nothing.
// Help law: nil exactly when the write succeeds or only reports `.unchanged`;
// it depends on the selection, never on the value. A text style keeps each
// layer's own `fixedWidth` unless the style differs from that layer's only in
// it, which switches the layer's width mode (#3337; auto is stored as nil), and
// refits its box by the size's ratio in the same step (canvas-basics CB-5):
// auto width both sides, fixed width the height, rounded up, at least 1. A
// switch to auto keeps the width until the next edit measures the text.
// At a playhead X, Y and opacity are what the canvas shows: a keyed one keys there (LiveKeying.swift).
// Linux-safe.

public struct LiveStyling: StyleEditing {
    public init() {}

    public func styleHelp(_ property: DesignStyleProperty, _ ids: [String], on page: DesignPage) -> String? {
        do {
            _ = try takers(ids, on: page, Reach(property))
            return nil
        } catch {
            return error.help
        }
    }

    public func setFrame(_ field: DesignFrameField, to value: Double, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try setFrame(field, to: value, ids, on: page, at: nil)
    }

    public func setFrame(_ field: DesignFrameField, to value: Double, _ ids: [String], on page: DesignPage,
                         at playhead: Int?) throws(DesignRefusal) -> DesignEdit {
        let shown = page.shown(at: playhead)
        return try change("frame", "Change Frame", ids, on: page) { node in
            guard value.isFinite else { return }
            // This node's frame (moved already when a selected parent moved it) plus its playhead offset.
            let (seen, rest) = (shown.nodes.node(node.id)?.frame ?? node.frame, page.nodes.node(node.id)?.frame ?? node.frame)
            let frame = DesignRect(x: node.frame.x + seen.x - rest.x, y: node.frame.y + seen.y - rest.y,
                                   width: node.frame.width, height: node.frame.height)
            switch field {
            case .x, .y:
                let delta = DesignPoint(x: field == .x ? value - frame.x : 0, y: field == .y ? value - frame.y : 0)
                node = node.moved(by: delta, at: playhead)
            case .width: node.frame.width = Swift.max(value, 1)
            case .height: node.frame.height = Swift.max(value, 1)
            }
        }
    }

    public func setFill(_ color: DesignColor, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try change("fill", "Change Fill", ids, on: page) { $0.fill = color }
    }

    public func setCornerRadius(_ radius: Double, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try change("radius", "Change Corner Radius", ids, on: page, reach: .corners) { node in
            guard radius.isFinite else { return }
            node.cornerRadius = Swift.min(Swift.max(radius, 0), node.maxCornerRadius)
        }
    }

    public func setOpacity(_ opacity: Double, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try setOpacity(opacity, ids, on: page, at: nil)
    }

    public func setOpacity(_ opacity: Double, _ ids: [String], on page: DesignPage, at playhead: Int?) throws(DesignRefusal) -> DesignEdit {
        try change("opacity", "Change Opacity", ids, on: page) { node in
            guard opacity.isFinite else { return }
            node = node.writing(.opacity, Swift.min(Swift.max(opacity, 0), 1), at: playhead)
        }
    }

    public func setStroke(_ stroke: DesignStroke?, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try change("stroke", "Change Stroke", ids, on: page) { node in
            if var stroke {
                guard stroke.width.isFinite else { return }
                stroke.width = Swift.min(Swift.max(stroke.width, 0), 1000)
                node.stroke = stroke
            } else {
                node.stroke = nil
            }
        }
    }

    public func setTextStyle(_ style: DesignTextStyle, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try change("text-style", "Change Text Style", ids, on: page, reach: .text) { node in
            guard style.size.isFinite else { return }
            var clamped = style
            clamped.size = Swift.max(1, Swift.min(style.size, 1000))
            clamped.weight = Swift.min(Swift.max(style.weight, 100), 900)
            clamped.fixedWidth = Self.widthMode(style, over: node.textStyle)
            let old = node.textStyle.size
            node.textStyle = clamped
            guard old.isFinite, old > 0, clamped.size != old else { return }
            let ratio = clamped.size / old
            if clamped.fixedWidth != true { node.frame.width = Self.scaled(node.frame.width, ratio) }
            node.frame.height = Self.scaled(node.frame.height, ratio)
        }
    }

    /// The width mode `style` leaves on a layer styled `own`: `style`'s when it differs from `own`
    /// only in that mode (the inspector's Width choice, #3337), true for fixed and nil for auto;
    /// else `own`'s, so a row that sets one layer's style on several keeps each one's mode.
    private static func widthMode(_ style: DesignTextStyle, over own: DesignTextStyle) -> Bool? {
        var same = style
        same.fixedWidth = own.fixedWidth
        guard same == own else { return own.fixedWidth }
        return style.fixedWidth == true ? true : nil
    }

    /// `side` × `ratio`, rounded up to a whole point, at least 1.
    private static func scaled(_ side: Double, _ ratio: Double) -> Double {
        Swift.max(1, (side * ratio).rounded(.up))
    }

    /// Which layers a property reaches: every kind, or only those with corners or with text.
    private enum Reach {
        case every, corners, text

        init(_ property: DesignStyleProperty) {
            self = switch property {
            case .cornerRadius: .corners
            case .textStyle: .text
            default: .every
            }
        }

        func takes(_ kind: DesignNodeKind) -> Bool {
            switch self {
            case .every: true
            case .corners: kind.hasCorners
            case .text: kind == .text
            }
        }

        /// The refusal when no selected layer is of the reached kind, named by the last selected.
        func refusal(_ name: String) -> DesignRefusal { self == .text ? .notText(name) : .noCorners(name) }
    }

    /// The named layers `reach` sets, in `ids` order, after the refusals: none on the page, the first
    /// locked in the tree, the first hidden in the tree, none of the reached kind.
    private func takers(_ ids: [String], on page: DesignPage, _ reach: Reach) throws(DesignRefusal) -> [DesignNode] {
        let selected = fakeFind(ids, page)
        guard let last = selected.last else { throw .nothingSelected }
        if let node = selected.first(where: { inTree($0.id, on: page, \.isLocked) }) { throw .locked(node.name) }
        if let node = selected.first(where: { inTree($0.id, on: page, \.isHidden) }) { throw .hidden(node.name) }
        let takers = selected.filter { reach.takes($0.kind) }
        guard !takers.isEmpty else { throw reach.refusal(last.name) }
        return takers
    }

    /// Whether `id` or a layer around it has `flag` set.
    private func inTree(_ id: String, on page: DesignPage, _ flag: KeyPath<DesignNode, Bool>) -> Bool {
        ((page.nodes.ancestors(of: id) ?? []) + [id]).contains { page.nodes.node($0)?[keyPath: flag] == true }
    }

    /// `body` on each layer `reach` sets, as one edit named `name` that coalesces under `runKey(base, ids)`.
    private func change(_ base: String, _ name: String, _ ids: [String], on page: DesignPage, reach: Reach = .every,
                        _ body: (inout DesignNode) -> Void) throws(DesignRefusal) -> DesignEdit {
        var nodes = page.nodes
        for node in try takers(ids, on: page, reach) { _ = nodes.update(node.id, body) }
        guard nodes != page.nodes else { throw .unchanged }
        return DesignEdit(name: name, nodes: nodes, selection: ids, coalescingKey: DesignEdit.runKey(base, ids))
    }
}

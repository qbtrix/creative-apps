// DesignCanvasHints.swift: what the canvas shows before a click. `hover(at:)` says
// which layer a Move press at a point would pick (its frame is the hover outline),
// which pointer the canvas shows there (a handle of the selection, move, copy with
// Option, the Text tool's I-beam, or the tool's own), and the Text tool's box. The
// selection badge is the "120 × 80" text under the selection, or "X 100, Y 40" while
// a move runs. While a text edit is open the badge, its anchor and the inspector
// read the edited box as its commit will fit it to the draft's measured extent
// (`liveFrame`, #3335), and `textLegibilityHint` asks for a zoom-in when the
// typed text draws under 9 pt on screen (#3336). Nothing here writes the
// document. Linux-safe; no UI imports.
//
// A press on a handle resizes the selected layer, so over a handle the hover names
// that layer. Over a layer that is locked or hidden, or over a drawing tool's
// canvas, there is no layer to name. A live gesture shows no outline and the tool's
// pointer, so the hover never fights the gesture's own feedback.

/// The pointer the canvas shows over the canvas.
public enum DesignPointerHint: Sendable, Equatable {
    case tool                     // the active tool's own pointer (arrow, crosshair)
    case move                     // over a layer a Move press would pick and drag
    case copy                     // the same with Option held: a drag duplicates (copy-group)
    case resize(DesignHandle)     // over a handle of the selection
    case text                     // the Text tool

    /// "move", "copy", "resize-bottom-right", "text", "tool": the hover mark's accessibility value.
    public var name: String {
        switch self {
        case .tool: "tool"
        case .move: "move"
        case .copy: "copy"
        case .text: "text"
        case .resize(.rotate):
            "rotate"
        case .resize(let handle):
            "resize-" + handle.rawValue.map { $0.isUppercase ? "-" + $0.lowercased() : String($0) }.joined()
        }
    }
}

/// What a click at a point would do.
public struct DesignHover: Sendable, Equatable {
    public var nodeID: String?        // the layer a Move click picks; nil on bare canvas and for drawing tools
    public var outline: DesignRect?   // that layer's frame, or the box a Text click places
    public var pointer: DesignPointerHint

    public init(nodeID: String?, outline: DesignRect?, pointer: DesignPointerHint) {
        (self.nodeID, self.outline, self.pointer) = (nodeID, outline, pointer)
    }
}

extension DesignWorkspace {
    /// nil `point` (the pointer left the artboard), a non-finite point or a live gesture gives no
    /// outline and `.tool`. With the Text tool the answer is its box at the point; with another
    /// drawing tool, `.tool` and no outline. With Move, a handle of the selection wins, then the
    /// layer under the point (`hitTest`), and Option makes that layer's pointer `.copy`.
    public func hover(at point: DesignPoint?, modifiers: DesignModifiers) -> DesignHover {
        let idle = DesignHover(nodeID: nil, outline: nil, pointer: .tool)
        guard let point, point.isFinite, gesture == nil else { return idle }
        if tool == .text {
            let size = DesignNodeKind.text.defaultSize
            let box = DesignRect(x: point.x, y: point.y, width: size.width, height: size.height)
            return DesignHover(nodeID: nil, outline: box, pointer: .text)
        }
        guard tool == .move else { return idle }
        if let handle = handle(at: point), let node = selectedNode {
            return DesignHover(nodeID: node.id, outline: node.frame, pointer: .resize(handle))
        }
        guard let id = hitTest(point), let node = findNode(id) else { return idle }
        return DesignHover(nodeID: id, outline: node.frame, pointer: modifiers.contains(.option) ? .copy : .move)
    }

    /// "120 × 80" for the selection (several: their bounds), "X 100, Y 40" while a move gesture
    /// runs; whole points; nil with nothing selected.
    public var selectionBadge: String? { selectionBadge(draft: nil) }

    /// `selectionBadge` with an open text edit's box fitted to `extent`, the draft's measured size.
    public func selectionBadge(draft extent: DesignTextExtent?) -> String? {
        guard let bounds = liveSelectionBounds(extent) else { return nil }
        if case .move? = gesture?.route {
            return "X \(wholePoints(bounds.x)), Y \(wholePoints(bounds.y))"
        }
        return "\(wholePoints(bounds.width)) × \(wholePoints(bounds.height))"
    }

    /// `node`'s frame as the canvas shows it now: the box of the open text edit fitted to the
    /// draft's measured `extent` the way its commit fits it (#3335), else the node's own frame.
    public func liveFrame(of node: DesignNode, draft extent: DesignTextExtent?) -> DesignRect {
        node.id == editingTextID ? Self.fitted(node.frame, node.textStyle, extent) : node.frame
    }

    /// The selection's bounds with the open edit's box fitted to `extent` (the edited node is then
    /// the whole selection); `selectionBounds` otherwise.
    private func liveSelectionBounds(_ extent: DesignTextExtent?) -> DesignRect? {
        guard extent != nil, let id = editingTextID, selectedNodeIDs == [id], let node = findNode(id) else {
            return selectionBounds
        }
        return liveFrame(of: node, draft: extent)
    }

    /// The smallest on-screen size, in points, typed text reads at.
    public static let legibleTextSize = 9.0

    /// "Zoom in to read text" while a text edit is open at a `zoom` where its text draws under
    /// `legibleTextSize` on screen (#3336); nil otherwise.
    public func textLegibilityHint(zoom: Double) -> String? {
        guard let id = editingTextID, let node = findNode(id) else { return nil }
        let onScreen = node.textStyle.size * Self.textEditScale(zoom: zoom)
        return onScreen < Self.legibleTextSize ? "Zoom in to read text" : nil
    }
}

extension DesignHover {
    /// The rect the hover mark draws: the layer a click picks, or the box a Text click places; nil otherwise.
    public var mark: DesignRect? { nodeID != nil || pointer == .text ? outline : nil }

    /// The box a Text click would place at the pointer; nil for any other answer.
    public var placement: DesignRect? { nodeID == nil && pointer == .text ? outline : nil }

    /// This answer as the canvas's pointer needs it: nil when there is nothing to show, and the Text
    /// tool's box dropped, so it changes only when the pointer or the layer under it does.
    public var steady: DesignHover? {
        if nodeID == nil, outline == nil, pointer == .tool { return nil }
        guard placement != nil else { return self }
        return DesignHover(nodeID: nil, outline: nil, pointer: pointer)
    }
}

extension DesignWorkspace {
    /// Where the size badge hangs: the middle of the selection's bottom edge (page points); nil with no badge.
    public var selectionBadgeAnchor: DesignPoint? { selectionBadgeAnchor(draft: nil) }

    /// `selectionBadgeAnchor` with an open text edit's box fitted to `extent`.
    public func selectionBadgeAnchor(draft extent: DesignTextExtent?) -> DesignPoint? {
        guard let bounds = liveSelectionBounds(extent) else { return nil }
        return DesignPoint(x: bounds.x + bounds.width / 2, y: bounds.maxY)
    }
}

/// `value` rounded to whole points, clamped so the conversion can't trap; non-finite is 0.
private func wholePoints(_ value: Double) -> Int {
    guard value.isFinite else { return 0 }
    return Int(Swift.min(Swift.max(value.rounded(), -1e9), 1e9))
}

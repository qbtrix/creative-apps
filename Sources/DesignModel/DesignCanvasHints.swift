// DesignCanvasHints.swift: what the canvas shows before a click. `hover(at:)` says
// which layer a Move press at a point would pick (its frame is the hover outline),
// which pointer the canvas shows there (a handle of the selection, move, copy with
// Option, the Text tool's I-beam, or the tool's own), and the Text tool's box. The
// selection badge is the "120 × 80" text under the selection, or "X 100, Y 40" while
// a move runs. Nothing here writes the document. Linux-safe; no UI imports.
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
    public var selectionBadge: String? {
        guard let bounds = selectionBounds else { return nil }
        if case .move? = gesture?.route {
            return "X \(wholePoints(bounds.x)), Y \(wholePoints(bounds.y))"
        }
        return "\(wholePoints(bounds.width)) × \(wholePoints(bounds.height))"
    }
}

/// `value` rounded to whole points, clamped so the conversion can't trap; non-finite is 0.
private func wholePoints(_ value: Double) -> Int {
    guard value.isFinite else { return 0 }
    return Int(Swift.min(Swift.max(value.rounded(), -1e9), 1e9))
}

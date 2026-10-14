// DesignCorners.swift: corner radius, the inspector's Radius row (#532). A
// rectangle or frame has corners to round; every other kind refuses. The
// stored radius is clamped to half the shorter side when it is set, and the
// canvas draws `drawnCornerRadius`, so a layer resized smaller after rounding
// still draws a valid shape. A run of radius edits on one layer is one undo
// step, like the frame fields. Linux-safe: no UI imports.

extension DesignNodeKind {
    /// Whether a layer of this kind has corners a radius rounds.
    public var hasCorners: Bool { self == .rectangle || self == .frame }

    /// Why a layer of this kind has no Radius to set, or nil when it has corners.
    public var cornerlessHelp: String? {
        switch self {
        case .rectangle, .frame: nil
        case .ellipse: "An ellipse has no corners to round."
        case .text: "Text has no corners to round."
        case .group: "A group has no corners to round."
        case .instance: "An instance has no corners to round."
        }
    }
}

extension DesignNode {
    /// The most a radius can be: half the shorter side, never below 0.
    public var maxCornerRadius: Double {
        let half = Swift.min(frame.width, frame.height) / 2
        return half.isFinite ? Swift.max(half, 0) : 0
    }

    /// The radius the canvas draws: the stored one, kept within `maxCornerRadius`; 0 without corners.
    public var drawnCornerRadius: Double {
        guard kind.hasCorners, cornerRadius.isFinite else { return 0 }
        return Swift.min(Swift.max(cornerRadius, 0), maxCornerRadius)
    }
}

extension DesignWorkspace {
    /// Why the Radius row can't be used for the selection, or nil when it can: nothing selected,
    /// a kind with no corners, or a lock on the layer or a group around it.
    public var cornerRadiusHelp: String? {
        guard let node = selectedNode else { return "Select a rectangle or frame to round its corners." }
        return node.kind.cornerlessHelp ?? lockHelp(node.id)
    }

    /// Sets a rectangle's or frame's corner radius, clamped to 0...half its shorter side. A
    /// non-finite radius changes nothing. Refused for an unknown id, a kind with no corners and a
    /// locked layer or one inside a locked group. A run of changes to one layer is one step.
    public mutating func setCornerRadius(_ id: String, _ radius: Double) throws(DesignTreeError) {
        guard let node = findNode(id) else { throw .unknownID(id) }
        guard node.kind.hasCorners else { throw .noCorners(id) }
        guard radius.isFinite else { return }
        let clamped = Swift.min(Swift.max(radius, 0), node.maxCornerRadius)
        try editNode(id, named: "Change Corner Radius", coalescing: "radius-\(id)") { $0.cornerRadius = clamped }
    }
}

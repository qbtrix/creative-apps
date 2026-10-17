// DesignInspectorContent.swift: the words Design's inspector shows about the
// selection: the header lines for a node and for a page, whether a kind has a
// fill row to edit, the value a row shows over one or several selected layers
// (the value they all share, or nil, which the view draws as "Mixed"), the
// Opacity row's percent text, and the hint the value column shows when the
// selection can't be edited ("Unlock A to change it.", #276). Sizes are whole
// points, rounded the way DesignPage.sizeText rounds them, and a non-finite or
// huge size never traps. Linux-safe: no UI imports.

extension DesignNode {
    /// The header lines under the name: the kind ("Rectangle"), left out when
    /// the name already says it, and the size in whole points ("160 × 120 pt").
    public var inspectorDetails: [String] {
        (name == kind.defaultName ? [] : [kind.defaultName]) + ["\(wholePoints(frame.width)) × \(wholePoints(frame.height)) pt"]
    }
}

extension DesignPage {
    /// The header line under the name: "Frame 1440 × 1024 pt".
    public var inspectorDetails: [String] { ["Frame \(sizeText)"] }
}

extension DesignNodeKind {
    /// The label of the Fill section's color row, or nil when the kind has no
    /// fill to edit: a text node's fill is its text color, a group has none.
    public var fillLabel: String? {
        switch self {
        case .group: nil
        case .text: "Text Color"
        case .frame, .rectangle, .ellipse, .instance: "Fill"
        }
    }
}

extension DesignWorkspace {
    /// The inspector's value for a row over the selection: `read` of every selected layer when
    /// they all agree, or nil ("Mixed") when any differs or nothing is selected.
    public func sharedValue<T: Equatable>(_ read: (DesignNode) -> T) -> T? {
        let values = selectedNodes.map(read)
        guard let first = values.first else { return nil }
        return values.dropFirst().allSatisfy { $0 == first } ? first : nil
    }

    /// The Opacity row's text, the shared opacity as a whole percent ("50%"); nil when mixed.
    public var opacityPercentText: String? {
        sharedValue(\.opacity).map { "\(wholePercent($0))%" }
    }

    /// The hint the value column shows for `property`'s row when the selection can't be edited,
    /// or nil when it can: the first locked layer's "Unlock A to change it.", else the first
    /// hidden layer's "Show Hidden to change it." (locked or hidden itself or through a group
    /// around it, named as DesignRefusal says it), else the row's `styleHelp`.
    public func styleHint(_ property: DesignStyleProperty) -> String? {
        let nodes = selectedNodes
        if let locked = nodes.first(where: { isLockedInTree($0.id) }) { return DesignRefusal.locked(locked.name).help }
        if let hidden = nodes.first(where: { isHiddenInTree($0.id) }) { return DesignRefusal.hidden(hidden.name).help }
        return styleHelp(property)
    }
}

/// `value` rounded to a whole number of points, clamped to a billion either way; 0 for NaN or infinity.
private func wholePoints(_ value: Double) -> Int {
    value.isFinite ? Int(Swift.max(Swift.min(value, 1e9), -1e9).rounded()) : 0
}

/// `fraction` (0...1) as a whole percent, rounded (0.496 is 50), clamped to 0...100; 0 for NaN or infinity.
private func wholePercent(_ fraction: Double) -> Int {
    fraction.isFinite ? Int(Swift.max(Swift.min(fraction * 100, 100), 0).rounded()) : 0
}

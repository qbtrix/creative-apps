// DesignInspectorContent.swift: the words Design's inspector shows about the
// selection: the header lines for a node and for a page, and whether a kind
// has a fill row to edit. Sizes are whole points, rounded the way
// DesignPage.sizeText rounds them, and a non-finite or huge size never traps.
// Linux-safe: no UI imports.

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

/// `value` rounded to a whole number of points, clamped to a billion either way; 0 for NaN or infinity.
private func wholePoints(_ value: Double) -> Int {
    value.isFinite ? Int(Swift.max(Swift.min(value, 1e9), -1e9).rounded()) : 0
}

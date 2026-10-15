// HaloLayerRowHelp.swift: a layer row's tooltip. It names the kind the way
// HaloLayerKindHelp does ("Shape layer"), says what a null is for (it draws
// nothing; other layers can follow it), and tells a newcomer the row renames
// on a double-click of its name and reorders by drag. Linux-safe.

extension HaloLayerKind {
    /// The layer row's tooltip: "Shape layer. Double-click the name to rename
    /// it; drag to reorder."
    public var rowHelp: String {
        let gestures = "Double-click the name to rename it; drag to reorder."
        switch self {
        case .null: return "\(layerTitle): draws nothing; other layers can follow it. \(gestures)"
        case .solid, .shape, .text: return "\(layerTitle). \(gestures)"
        }
    }
}

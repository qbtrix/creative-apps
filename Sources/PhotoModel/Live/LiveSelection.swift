// Live/LiveSelection.swift: the live selection shapes and layer masks. PV-5
// replaces these NotBuilt stand-ins. Linux-safe.
enum LiveSelection {
    static func selection() -> any SelectionShaping { NotBuiltSelection() }
    static func masking() -> any LayerMasking { NotBuiltMasking() }
}

// HaloKeying.swift: the inspector's TRANSFORM rows for the selected layer at
// the playhead (#38). A row's value goes through `PropertyKeying.setValue`
// (a key when animated, else the static value) as one "Change <title>" step;
// a scrub's writes to one row coalesce into that step until
// `endPropertyScrub()`, and a typed value is always its own step. Typed text
// that isn't a number is refused under its row and changes nothing. Shown
// values are stored values times `displayFactor` (percent rows).
// The stopwatch, the key diamond and Set Parent are each their own step,
// named from the row's state before the toggle; a parent cycle is refused
// under the Parent picker. `parentChoices` and `blendChoices` fill the LAYER
// group's pickers. Linux-safe: no UI imports.
import CoreRaster

extension HaloProject {
    /// A TRANSFORM row's identifier, where its refusal shows.
    static func propertyRowControl(_ p: HaloProperty) -> String { "halo.inspector.row.\(p.rawValue)" }

    /// The selected layer's rows at the playhead, in `HaloProperty.allCases`
    /// order; empty with no layer selected.
    public var propertyRows: [HaloPropertyRow] {
        guard let id = selectedLayerID, let comp = selectedComposition else { return [] }
        return services.keying.rows(for: id, in: comp, at: comp.playheadFrame)
    }

    /// Sets `p` of the selected layer at the playhead to the stored `value`.
    /// Writes to the same row merge into one "Change <title>" step until
    /// `endPropertyScrub()`. Nothing with no layer selected.
    public mutating func setProperty(_ p: HaloProperty, to value: Double) {
        guard let id = selectedLayerID else { return }
        atPlayhead("Change \(p.title)", control: Self.propertyRowControl(p), coalesceKey: "\(id).\(p.rawValue)") {
            [keying = services.keying] comp, frame in
            try keying.setValue(value, for: p, of: id, at: frame, in: &comp)
        }
    }

    /// Sets `p` from what a person typed ("45°", " 50 %"), as its own step.
    /// Text that isn't a number sets `refusal` ("Rotation needs a number.")
    /// and changes nothing. Nothing with no layer selected.
    public mutating func setProperty(_ p: HaloProperty, text: String) {
        guard selectedLayerID != nil else { return }
        guard let value = p.parse(text) else {
            edit("Change \(p.title)", control: Self.propertyRowControl(p)) { _ in throw HaloEditError.notANumber(p) }
            return
        }
        endCoalescing()
        setProperty(p, to: value)
        endCoalescing()
    }

    /// Ends a row's scrub, so the next write is its own step.
    public mutating func endPropertyScrub() {
        endCoalescing()
    }

    /// The stopwatch on `p` of the selected layer at the playhead, as its own
    /// step: "Animate <title>" when the row wasn't animated, else "Stop
    /// Animating <title>". Nothing with no layer selected.
    public mutating func toggleAnimation(_ p: HaloProperty) {
        guard let id = selectedLayerID else { return }
        let state = propertyRows.first { $0.property == p }?.keyState
        let name = state == .notAnimated ? "Animate \(p.title)" : "Stop Animating \(p.title)"
        ownStep(name, control: Self.keyControl(p)) { [keying = services.keying] comp, frame in
            try keying.toggleAnimation(p, of: id, at: frame, in: &comp)
        }
    }

    /// The key diamond on `p` at the playhead, as its own step: "Remove Key"
    /// when a key is there, else "Add Key". Nothing with no layer selected.
    public mutating func toggleKey(_ p: HaloProperty) {
        guard let id = selectedLayerID else { return }
        let state = propertyRows.first { $0.property == p }?.keyState
        ownStep(state == .keyedHere ? "Remove Key" : "Add Key", control: Self.keyControl(p)) {
            [keying = services.keying] comp, frame in
            try keying.toggleKey(p, of: id, at: frame, in: &comp)
        }
    }

    /// The selected layer follows `parentID` (nil clears it), keeping its
    /// place on screen, as one "Set Parent" step. A cycle is refused under
    /// the Parent picker and changes nothing. Nothing with no layer selected.
    public mutating func setParent(_ parentID: String?) {
        guard let id = selectedLayerID else { return }
        ownStep("Set Parent", control: Self.parentControl) { [keying = services.keying] comp, frame in
            try keying.setParent(parentID, of: id, at: frame, in: &comp)
        }
    }

    /// The layers the selected one may follow, in timeline order: never
    /// itself or a layer that already follows it. The view puts None first.
    public var parentChoices: [(id: String, name: String)] {
        guard let id = selectedLayerID, let comp = selectedComposition else { return [] }
        let names = Dictionary(comp.layers.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        return services.placing.parentCandidates(for: id, in: comp).compactMap { candidate in
            guard candidate != id, let name = names[candidate] else { return nil }
            return (candidate, name)
        }
    }

    /// Every blend mode with its Blend picker title, in `allCases` order.
    public var blendChoices: [(mode: BlendMode, title: String)] {
        BlendMode.allCases.map { ($0, Self.blendTitle($0)) }
    }

    // MARK: Helpers

    /// The stopwatch's and diamond's identifier for `p`.
    static func keyControl(_ p: HaloProperty) -> String { "halo.inspector.key.\(p.rawValue)" }

    /// The Parent picker's identifier, where a cycle's refusal shows.
    static let parentControl = "halo.inspector.parent"

    /// The Blend picker's title for `mode`.
    static func blendTitle(_ mode: BlendMode) -> String {
        switch mode {
        case .normal: "Normal"
        case .multiply: "Multiply"
        case .screen: "Screen"
        case .overlay: "Overlay"
        case .darken: "Darken"
        case .lighten: "Lighten"
        case .colorDodge: "Color Dodge"
        case .colorBurn: "Color Burn"
        case .hardLight: "Hard Light"
        case .softLight: "Soft Light"
        case .difference: "Difference"
        case .exclusion: "Exclusion"
        case .hue: "Hue"
        case .saturation: "Saturation"
        case .color: "Color"
        case .luminosity: "Luminosity"
        }
    }

    /// One `edit` on the selected composition at its playhead.
    private mutating func atPlayhead(
        _ name: String, control: String, coalesceKey: String? = nil,
        _ body: (inout HaloComposition, Int) throws -> Void
    ) {
        edit(name, control: control, coalesceKey: coalesceKey) { doc in
            guard let c = doc.compositions.firstIndex(where: { $0.id == doc.selectedCompositionID }) else {
                throw HaloEditError.noComposition
            }
            let frame = doc.compositions[c].playheadFrame
            try body(&doc.compositions[c], frame)
        }
    }

    /// `atPlayhead` as its own step: it never merges with a scrub before or
    /// after it.
    private mutating func ownStep(_ name: String, control: String, _ body: (inout HaloComposition, Int) throws -> Void) {
        endCoalescing()
        atPlayhead(name, control: control, body)
        endCoalescing()
    }
}

extension HaloPropertyRow {
    /// The value as the row's bar shows it (percent for scale and opacity).
    public var shown: Double { value * property.displayFactor }
    /// The bar's range in shown units.
    public var shownRange: ClosedRange<Double> {
        (property.range.lowerBound * property.displayFactor)...(property.range.upperBound * property.displayFactor)
    }
    /// One arrow-key step in shown units.
    public var shownStep: Double { property.step * property.displayFactor }
}

extension HaloProperty {
    /// The stored value for a value the bar shows: `shown ÷ displayFactor`.
    public func stored(fromShown shown: Double) -> Double { shown / displayFactor }
}

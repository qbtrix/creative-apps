// HaloKeying.swift: the inspector's TRANSFORM rows for the selected layer at
// the playhead (#38). A row's value goes through `PropertyKeying.setValue`
// (a key when animated, else the static value) as one "Change <title>" step;
// a scrub's writes to one row coalesce into that step until
// `endPropertyScrub()`, and a typed value is always its own step. Typed text
// that isn't a number is refused under its row and changes nothing. Shown
// values are stored values times `displayFactor` (percent rows).
// Linux-safe: no UI imports.

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
        let keying = services.keying  // read before `edit`: its closure can't touch `self`
        edit("Change \(p.title)", control: Self.propertyRowControl(p), coalesceKey: "\(id).\(p.rawValue)") { doc in
            guard let c = doc.compositions.firstIndex(where: { $0.id == doc.selectedCompositionID }) else {
                throw HaloEditError.noComposition
            }
            let frame = doc.compositions[c].playheadFrame
            try keying.setValue(value, for: p, of: id, at: frame, in: &doc.compositions[c])
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

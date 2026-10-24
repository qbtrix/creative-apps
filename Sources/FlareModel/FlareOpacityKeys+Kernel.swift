// FlareOpacityKeys+Kernel.swift (brush-keys BK-12): Flare as the kernel's BrushKeyTarget. Flare has no brush tool, so
// a digit (BrushKeys' rule) is always layer opacity: `layer.set-opacity` sets every selected layer's opacity as one
// "Layer Opacity" step, by the inspector's recording rule (auto-key on keys it at the playhead). The stage and
// Object > Opacity send it as one inspector opacity edit, `opacityIntents`.
import FlareCore
import SuiteKernel

extension FlareWorkspace: BrushKeyTarget {
    /// No brush tool in Flare.
    public var activeBrush: BrushSettings? { nil }

    /// Why the selected layers' opacity can't be set: no animation or scene, or no layer selected.
    public var layerOpacityHelp: String? {
        guard document != nil, propertyOwner != nil else { return FlareLayerError.noDocument.message }
        return propertyLayerIDs.isEmpty ? "Select a layer first." : nil
    }

    public mutating func setActiveBrush(_ s: BrushSettings) throws {
        throw CatalogError.failed(id: "brush.set-opacity", message: BrushKeyCommands.noBrushHelp)
    }

    /// Sets every selected layer's opacity to `percent` (0 to 100) at the playhead: keyed there while recording or on
    /// an animated track, else the layer's one value. One undo step; throws with the reason when it can't.
    public mutating func setSelectedOpacity(_ percent: Double) throws {
        try attempt("layer.set-opacity") { w in
            guard let owner = w.propertyOwner else { return w.refuse(.noDocument) }
            let layers = w.propertyLayerIDs
            guard !layers.isEmpty else { return w.refuse(.refused("Select a layer first.")) }
            let properties = w.services.properties, frame = w.currentFrame, recording = w.autoKey
            let value = Swift.min(1, Swift.max(0, percent / 100))
            w.step("Layer Opacity") {
                try properties.setValue(value, of: "opacity", owner: owner, layerIDs: layers, frame: frame,
                                        autoKey: recording, coalesceKey: nil, in: &$0)
            }
        }
    }

    /// Object > Opacity's percents.
    public static let opacityMenuPercents: [Double] = (1...10).map { Double($0 * 10) }

    /// The inspector edit a digit or an Object > Opacity item sends: one opacity scrub at `percent`, then its end.
    public static func opacityIntents(_ percent: Double) -> [FlareIntent] {
        let value = Swift.min(1, Swift.max(0, percent / 100))
        return [.inspector(.scrub(property: "opacity", value: value, dragStart: value)), .inspector(.endScrub)]
    }
}

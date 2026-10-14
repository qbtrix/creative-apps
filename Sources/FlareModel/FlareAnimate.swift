// FlareAnimate.swift: auto-key and the inspector's animated properties (docs/blueprints/flare.md, sections 2 and 3.4).
// Auto-key is a preference (it survives opening another file). A value scrub is one coalesced "Set Keyframe" step
// however many values it sends; the stopwatch and the keyframe button are one step each. Everything goes through
// `services.properties`, which applies section 2's not-animated rule.
import FlareCore

extension FlareWorkspace {
    /// The layers the inspector edits: the stage selection's, or the panel's selected layer when nothing is on stage.
    public var propertyLayerIDs: [String] {
        selection.isEmpty ? selectedLayerID.map { [$0] } ?? [] : selectedLayerIDs
    }

    /// The scene or symbol whose layers the inspector edits; nil with no scene selected.
    var propertyOwner: LayerOwner? {
        editingSymbolID.map(LayerOwner.symbol) ?? selectedSceneID.map(LayerOwner.scene)
    }

    /// The TRANSFORM rows at the playhead; a value that differs across the layers is nil ("Mixed").
    public var animatedProperties: [AnimatedProperty] {
        guard let document, let owner = propertyOwner else { return [] }
        return services.properties.properties(document, owner: owner, layerIDs: propertyLayerIDs, frame: currentFrame)
    }

    /// Turns auto-key (record) on or off.
    public mutating func toggleAutoKey() { autoKey.toggle() }

    /// Sets `property` on the inspector's layers at the playhead, during a scrub that began at `dragStart`. Values of
    /// one scrub share one step until `endPropertyScrub()`, so the next scrub gets a step of its own even when it
    /// starts from the same value (#574).
    public mutating func setProperty(_ property: String, to value: Double, dragStart start: Double) {
        guard let owner = propertyOwner else { return refuse(.noDocument) }
        let layers = propertyLayerIDs
        guard !layers.isEmpty else { return refuse(.refused("Select a layer first.")) }
        let properties = services.properties, frame = currentFrame, autoKey = autoKey
        let key = "property-\(property)-\(layers)-\(frame)-\(start)-\(propertyScrubSerial)"
        step {
            try properties.setValue(value, of: property, owner: owner, layerIDs: layers, frame: frame,
                                    autoKey: autoKey, coalesceKey: key, in: &$0)
        }
    }

    /// Ends the current scrub: the next `setProperty` starts a new undo step.
    public mutating func endPropertyScrub() { propertyScrubSerial &+= 1 }

    /// The stopwatch: animates a not-animated property, or stops animating an animated one, on the one layer.
    public mutating func toggleAnimated(_ property: String) {
        guard let (owner, layerID) = oneLayer() else { return }
        let properties = services.properties, frame = currentFrame
        let lastFrame = max((selectedScene?.durationFrames ?? 1) - 1, 0)
        step { try properties.toggleAnimated(property, owner: owner, layerID: layerID, frame: frame, lastFrame: lastFrame, in: &$0) }
    }

    /// The keyframe button: adds or removes the key at the playhead on the one layer.
    public mutating func toggleKey(_ property: String) {
        guard let (owner, layerID) = oneLayer() else { return }
        let properties = services.properties, frame = currentFrame
        step { try properties.toggleKey(property, owner: owner, layerID: layerID, frame: frame, in: &$0) }
    }

    /// The owner and the one layer a stopwatch or key acts on; refuses and gives nil without exactly one.
    private mutating func oneLayer() -> (LayerOwner, String)? {
        guard let owner = propertyOwner else { refuse(.noDocument); return nil }
        let layers = propertyLayerIDs
        guard layers.count == 1, let id = layers.first else { refuse(.refused("Select one layer to key it.")); return nil }
        return (owner, id)
    }
}

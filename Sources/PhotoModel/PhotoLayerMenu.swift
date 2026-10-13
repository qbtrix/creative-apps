// PhotoLayerMenu.swift: when each item in Photo's Layer menu can run, and what
// the Show/Hide item says. PhotoApp's Layer menu disables, never hides, an
// item that can't run. Bring Forward and Send Backward move the selected
// layer one place up or down the stack, the keyboard's way to reorder (the
// Layers list also takes a drag); each is one "Reorder Layers" step. Select
// Layer Above and Below move the selection the same way, the keyboard's way
// to pick a layer; selecting is not an edit, so it is no undo step.
// Linux-safe.

extension PhotoWorkspace {
    /// Whether New Layer can run: it needs an open image.
    public var canAddLayer: Bool { canvas != nil }

    /// Whether Delete Layer can run: a layer is selected and it isn't the last.
    public var canDeleteSelectedLayer: Bool { canRemoveLayer && selectedLayer != nil }

    /// Whether Rename Layer… and Show/Hide Layer can run: a layer is selected.
    public var canEditSelectedLayer: Bool { selectedLayer != nil }

    /// The Show/Hide item's title, saying what it will do to the selection.
    public var visibilityCommandTitle: String {
        selectedLayer?.isVisible == false ? "Show Layer" : "Hide Layer"
    }

    /// Whether Bring Forward can run: the selected layer isn't the top one.
    public var canBringSelectedLayerForward: Bool { selectedIndex.map { $0 > 0 } ?? false }

    /// Whether Send Backward can run: the selected layer isn't the bottom one.
    public var canSendSelectedLayerBackward: Bool { selectedIndex.map { $0 < layers.count - 1 } ?? false }

    /// Moves the selected layer one place toward the top. Ignored at the top.
    public mutating func bringSelectedLayerForward() {
        guard canBringSelectedLayerForward, let at = selectedIndex else { return }
        moveLayers(fromOffsets: [at], toOffset: at - 1)
    }

    /// Moves the selected layer one place toward the bottom. Ignored at the bottom.
    public mutating func sendSelectedLayerBackward() {
        guard canSendSelectedLayerBackward, let at = selectedIndex else { return }
        // A list drag's destination: before the layer two below, once this one is out.
        moveLayers(fromOffsets: [at], toOffset: at + 2)
    }

    /// Selects the layer above the selected one. Ignored at the top.
    public mutating func selectLayerAbove() {
        guard canBringSelectedLayerForward, let at = selectedIndex else { return }
        selectedLayerID = layers[at - 1].id
    }

    /// Selects the layer below the selected one. Ignored at the bottom.
    public mutating func selectLayerBelow() {
        guard canSendSelectedLayerBackward, let at = selectedIndex else { return }
        selectedLayerID = layers[at + 1].id
    }

    private var selectedIndex: Int? { selectedLayerID.flatMap(index(of:)) }
}

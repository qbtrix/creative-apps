// PhotoLayerMenu.swift: when each item in Photo's Layer menu can run, and what
// the Show/Hide item says. PhotoApp's Layer menu disables, never hides, an
// item that can't run. Linux-safe.

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
}

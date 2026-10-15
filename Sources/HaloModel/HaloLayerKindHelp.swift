// HaloLayerKindHelp.swift: the words a layer row's tooltip and VoiceOver value
// use for its kind ("Solid layer", "Null layer"), built from the kind's title so
// the menus and the layer list name a kind the same way. Linux-safe.

extension HaloLayerKind {
    /// The kind as a layer row says it: "Solid layer", "Shape layer",
    /// "Text layer" or "Null layer".
    public var layerTitle: String { "\(title) layer" }
}

// Availability/HaloAvailability+Text.swift: whether the TEXT field, its size
// and the layer color can act now, answered from state only (#430). Each
// needs a composition. The field, size and size scrub need a selected text
// layer; the color row needs any layer `setLayerColor` can color (text,
// solid or shape, `HaloLayerKind.takesColor`). An empty string is refused by
// the edit itself, not here. Linux-safe.

extension HaloProject {
    /// The reason the text commands give while no text layer is selected.
    static let noTextLayerHelp = "Select a text layer first."
    /// The reason the color row gives while no colorable layer is selected.
    static let noColorLayerHelp = "Select a text, solid or shape layer first."

    /// Nil when `command` can act now; otherwise why not.
    func textHelp(_ command: HaloCommand) -> String? {
        guard selectedComposition != nil else { return HaloEditError.noComposition.message }
        if case .setLayerColor = command {
            return selectedLayer?.kind.takesColor == true ? nil : Self.noColorLayerHelp
        }
        guard selectedLayer?.kind == .text else { return Self.noTextLayerHelp }
        return nil
    }
}

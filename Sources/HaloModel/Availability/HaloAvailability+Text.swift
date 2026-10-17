// Availability/HaloAvailability+Text.swift: whether the TEXT field, its size
// and the layer color can act now, answered from state only (#430). Each
// needs a composition and a selected text layer; with one, every text
// command acts (an empty string is refused by the edit itself, not here).
// Linux-safe.

extension HaloProject {
    /// The reason the text commands give while no text layer is selected.
    static let noTextLayerHelp = "Select a text layer first."

    /// Nil when `command` can act now; otherwise why not.
    func textHelp(_ command: HaloCommand) -> String? {
        guard selectedComposition != nil else { return HaloEditError.noComposition.message }
        guard selectedLayer?.kind == .text else { return Self.noTextLayerHelp }
        return nil
    }
}

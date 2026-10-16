// FlareWindow+Interactions.swift: the router's interactions area
// (FlareWindow+Router.swift). A stub until F13a builds the Interactions
// editor: `performInteractions` does nothing and `interactionsHelp` says why.
import FlareModel

extension FlareWindow {
    /// Acts on an interactions intent; nothing yet.
    func performInteractions(_ intent: FlareIntent.Interactions) {}

    /// Why an interactions intent can't act now.
    func interactionsHelp(_ intent: FlareIntent.Interactions) -> String? { "Not built yet (F13a)." }
}

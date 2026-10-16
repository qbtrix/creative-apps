// FlareWindow+Library.swift: the router's library area (FlareWindow+Router.swift).
// A stub until F12a builds the Library tab's symbols and swatches:
// `performLibrary` does nothing and `libraryHelp` says why.
import FlareModel

extension FlareWindow {
    /// Acts on a library intent; nothing yet.
    func performLibrary(_ intent: FlareIntent.Library) {}

    /// Why a library intent can't act now.
    func libraryHelp(_ intent: FlareIntent.Library) -> String? { "Not built yet (F12a)." }
}

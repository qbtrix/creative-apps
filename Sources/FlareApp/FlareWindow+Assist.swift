// FlareWindow+Assist.swift: the router's assist area (FlareWindow+Router.swift).
// A stub until F16a builds the Assist popover: `performAssist` does nothing
// and `assistHelp` says why.
import FlareModel

extension FlareWindow {
    /// Acts on an assist intent; nothing yet.
    func performAssist(_ intent: FlareIntent.Assist) {}

    /// Why an assist intent can't act now.
    func assistHelp(_ intent: FlareIntent.Assist) -> String? { "Not built yet (F16a)." }
}

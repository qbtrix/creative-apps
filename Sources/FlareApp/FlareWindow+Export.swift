// FlareWindow+Export.swift: the router's export area (FlareWindow+Router.swift).
// A stub until F15a builds the Export sheet: `performExport` does nothing and
// `exportHelp` says why.
import FlareModel

extension FlareWindow {
    /// Acts on an export intent; nothing yet.
    func performExport(_ intent: FlareIntent.Export) {}

    /// Why an export intent can't act now.
    func exportHelp(_ intent: FlareIntent.Export) -> String? { "Not built yet (F15a)." }
}

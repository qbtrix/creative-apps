// FlareWindow+View.swift: the router's view area (FlareWindow+Router.swift).
// A stub until F3c builds zoom, rulers and guides: `performView` does nothing
// and `viewHelp` says why.
import FlareModel

extension FlareWindow {
    /// Acts on a view intent; nothing yet.
    func performView(_ intent: FlareIntent.View) {}

    /// Why a view intent can't act now.
    func viewHelp(_ intent: FlareIntent.View) -> String? { "Not built yet (F3c)." }
}

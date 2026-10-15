// Availability/HaloAvailability+Render.swift: whether Render Frame and the
// render sheet's commands can act now. W0 stub: none is built yet, so each
// says which issue brings it (Render Frame #451, rendering to files #429);
// `render-out` replaces this file whole when they work. Linux-safe.

extension HaloProject {
    /// Nil when `command` can act now; otherwise why not.
    func renderHelp(_ command: HaloCommand) -> String? {
        command == .renderFrame ? "Not built yet (#451)." : "Not built yet (#429)."
    }
}

// Availability/HaloAvailability+Render.swift: whether Render Frame and the
// render sheet's commands can act now (render-out RO-4, #451, #429). State
// answers first: every command needs a composition; Render… and Render are
// off while a render runs (one render at a time); Cancel and Close need an
// open sheet, Cancel is off once a started render has ended (a sheet whose
// render never started just closes), and Close waits for a running render
// to end. Then each
// command takes its service's own help: Render Frame `services.rendering`,
// the rest `services.compositionRendering`. Render Frame stays on while a
// render runs. Linux-safe.

extension HaloProject {
    /// Nil when `command` can act now; otherwise why not.
    func renderHelp(_ command: HaloCommand) -> String? {
        guard selectedComposition != nil else { return HaloEditError.noComposition.message }
        switch command {
        case .renderFrame:
            return services.rendering.unavailableHelp
        case .openRenderSheet, .startRender:
            return renderRunning ? "A render is already running." : services.compositionRendering.unavailableHelp
        case .cancelRender:
            guard let job = renderJob else { return "No render is open." }
            return job.plan == nil || job.outcome == nil ? nil : "The render has already ended."
        case .closeRenderSheet:
            guard renderJob != nil else { return "No render is open." }
            return renderRunning ? "Cancel the render first." : nil
        default:
            return nil
        }
    }
}

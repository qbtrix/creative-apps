// Availability/HaloAvailability+Render.swift: whether Render Frame and the
// render sheet's commands can act now (render-out RO-4, #451, #429; core-loop
// CL-7, #1971). It reads the kernel's `renderRun`, so each command is on
// exactly in the state its move acts in: Render Frame and Render… need a
// composition, and Render… is off while a render runs (one at a time; a
// finished or failed render lets the next open); Render needs the sheet
// editing, Cancel a running render, and Close a sheet the kernel can dismiss
// (editing, finished or failed). With the state right, Render Frame takes
// `services.rendering`'s help and Render… and Render take
// `services.compositionRendering`'s. Render Frame stays on while a render
// runs. Linux-safe.
import SuiteKernel

extension HaloProject {
    /// Nil when `command` can act now; otherwise why not.
    func renderHelp(_ command: HaloCommand) -> String? {
        let run = renderRun
        switch command {
        case .renderFrame:
            guard selectedComposition != nil else { return HaloEditError.noComposition.message }
            return services.rendering.unavailableHelp
        case .openRenderSheet:
            guard selectedComposition != nil else { return HaloEditError.noComposition.message }
            if case .running = run { return "A render is already running." }
            return services.compositionRendering.unavailableHelp
        case .startRender:
            switch run {
            case .editing:
                guard selectedComposition != nil else { return HaloEditError.noComposition.message }
                return services.compositionRendering.unavailableHelp
            case .idle: return "No render is open."
            case .running: return "A render is already running."
            case .finished, .failed: return "The render has already ended."
            }
        case .cancelRender:
            switch run {
            case .running: return nil
            case .idle: return "No render is open."
            case .editing: return "No render is running."
            case .finished, .failed: return "The render has already ended."
            }
        case .closeRenderSheet:
            switch run {
            case .editing, .finished, .failed: return nil
            case .idle: return "No render is open."
            case .running: return "Cancel the render first."
            }
        default:
            return nil
        }
    }
}

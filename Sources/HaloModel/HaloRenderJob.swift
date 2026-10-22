// HaloRenderJob.swift: the pure helpers behind File > Render… (#429): what a
// render would write, the name it takes and what a finished one wrote. The job's state and its moves
// are HaloRenderJob+Kernel.swift's, on SuiteKernel's ExportRun (core-loop
// CL-6, #1971). Linux-safe: no UI imports.
import SuiteKernel
import SuiteModel

extension HaloProject {
    /// What `settings` would write, for the sheet: "48 PNG files, 960 × 540,
    /// into a new folder "Bounce"" or "One movie, 1920 × 1080, 24 fps,
    /// "Bounce.mp4"". `existing` is what the destination folder holds. Nil with
    /// no composition or when the plan is refused.
    public func renderSummary(_ settings: HaloRenderSettings, existing: Set<String>) -> String? {
        guard let comp = selectedComposition,
            let plan = try? services.compositionRendering.plan(comp, settings: settings),
            let name = renderOutputName(settings, existing: existing)
        else { return nil }
        let size = "\(plan.width) × \(plan.height)"
        switch settings.format {
        case .pngSequence:
            let files = plan.frames.count == 1 ? "1 PNG file" : "\(plan.frames.count) PNG files"
            return "\(files), \(size), into a new folder \"\(name)\""
        case .movie:
            return "One movie, \(size), \(plan.framesPerSecond) fps, \"\(name)\""
        }
    }

    /// The name a render takes in a folder holding `existing`: a new folder
    /// for a PNG sequence ("Bounce", then "Bounce 2"), one file for a movie
    /// ("Bounce.mp4", then "Bounce 2.mp4"). Nil with no composition.
    public func renderOutputName(_ settings: HaloRenderSettings, existing: Set<String>) -> String? {
        guard let comp = selectedComposition else { return nil }
        let ext = settings.format == .movie ? "mp4" : ""
        return UniqueFileNames.name(comp.name, extension: ext, among: existing)
    }

    /// What a finished render wrote into `output` (its folder or movie
    /// file's name), for the sheet's finished line: "48 PNG files into
    /// "Bounce"" or "Bounce.mp4". Nil unless the run has finished.
    public func renderWrittenText(into output: String) -> String? {
        guard case .finished(let settings, let files) = renderRun else { return nil }
        switch settings.format {
        case .pngSequence:
            let count = files.count == 1 ? "1 PNG file" : "\(files.count) PNG files"
            return "\(count) into \"\(output)\""
        case .movie:
            return output
        }
    }
}

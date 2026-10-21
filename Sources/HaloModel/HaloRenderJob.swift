// HaloRenderJob.swift: the render job behind File > Render… (#429). Opens and
// closes the sheet, names what a render writes, starts a render from the
// services' plan, and records its progress and how it ended: the old moves
// the kernel adapter replaces (core-loop CL-6 removes them; #1971). Cancel
// and the progress and outcome text read the kernel's run in
// HaloRenderJob+Kernel.swift. The frames are rendered off the main actor by
// the app through `services.compositionRendering.run`; this file only keeps
// the state the sheet shows. A job is running once it has a plan and no
// outcome. Linux-safe: no UI imports.
import SuiteModel

extension HaloProject {
    /// Whether a render has started and not ended yet.
    var renderRunning: Bool {
        renderJob?.plan != nil && renderJob?.outcome == nil
    }

    /// Opens the Render sheet: settings only, no plan. Keeps the last settings
    /// asked for; does nothing with no composition or while a render runs.
    public mutating func openRenderSheet() {
        guard selectedComposition != nil, !renderRunning else { return }
        renderJob = HaloRenderJobState(settings: renderJob?.settings ?? HaloRenderSettings(format: .pngSequence))
    }

    /// Closes the Render sheet; refused while a render runs (Cancel first).
    public mutating func closeRenderSheet() {
        guard !renderRunning else { return }
        renderJob = nil
    }

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

    /// Starts a render of the selected composition: the plan from
    /// `services.compositionRendering` with progress 0, so the sheet reads
    /// "Frame 0 of 48" at once. Returns what the app's run needs; nil with no
    /// composition, while a render runs, or when the plan is refused (the
    /// sheet then shows the refusal as a failure with no plan).
    public mutating func startRender(_ settings: HaloRenderSettings) -> (
        plan: HaloRenderPlan, composition: HaloComposition
    )? {
        guard let comp = selectedComposition, !renderRunning else { return nil }
        let plan: HaloRenderPlan
        do {
            plan = try services.compositionRendering.plan(comp, settings: settings)
        } catch {
            let message = (error as? HaloEditError)?.message ?? "\(error)"
            renderJob = HaloRenderJobState(settings: settings, outcome: .failed(frame: 0, message: message))
            return nil
        }
        renderJob = HaloRenderJobState(settings: settings, plan: plan)
        return (plan, comp)
    }

    /// Records that `frame` frames are written. Only while running; progress
    /// never goes back and never passes the plan's frame count.
    public mutating func renderProgress(frame: Int) {
        guard renderRunning, var job = renderJob, let plan = job.plan else { return }
        job.progress = min(max(job.progress, frame), plan.frames.count)
        renderJob = job
    }

    /// How the app's run ended. A running render takes any outcome; after
    /// Cancel only the run's own cancelled count or a failure replaces the
    /// guess. A finished job never changes.
    public mutating func finishRender(_ outcome: HaloRenderOutcome) {
        guard let job = renderJob, job.plan != nil else { return }
        switch (job.outcome, outcome) {
        case (nil, _), (.cancelled, .cancelled), (.cancelled, .failed): renderJob?.outcome = outcome
        default: return
        }
    }
}

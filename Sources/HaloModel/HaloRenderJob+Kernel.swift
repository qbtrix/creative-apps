// HaloRenderJob+Kernel.swift: the adapter from Halo's render job onto
// SuiteKernel's ExportRun (core-loop CL-2 stubs, CL-6 bodies; #1971). The
// stored `renderJob: HaloRenderJobState?` keeps its shape; `renderRun` reads
// it as the kernel's run, and the sheet (CL-4) codes against these
// signatures. These are stubs: each forwards to render-out's job in
// HaloRenderJob.swift, so the sheet clicks end to end on the fakes (`keyed`:
// a 48-frame plan at 960 × 540 for half size). CL-6 replaces every body with
// a kernel transition and never changes a signature. `cancelRender()`,
// `renderProgressText` and `renderOutcomeText` keep their declarations in
// HaloRenderJob.swift (same signatures as the Contract slice) until CL-6
// moves them here while trimming that file. Linux-safe: no UI imports.
import SuiteKernel

extension HaloProject {
    /// The render job as the kernel's run: `.idle` with no job (or a
    /// cancelled one), `.editing` while the sheet is open on settings,
    /// `.running` with frames written of the plan's count, `.finished` with
    /// the plan's file names, `.failed` with the outcome in words.
    public var renderRun: ExportRun<HaloRenderSettings> {
        guard let job = renderJob else { return .idle }
        switch (job.plan, job.outcome) {
        case (nil, nil): return .editing(job.settings)
        case (let plan?, nil): return .running(job.settings, done: job.progress, total: plan.frames.count)
        case (let plan, .finished?): return .finished(job.settings, plan?.fileNames ?? [])
        case (_, .failed?): return .failed(job.settings, renderOutcomeText ?? "")
        case (_, .cancelled?): return .idle
        }
    }

    /// Opens the Render sheet on `settings` (idle → editing). False, and no
    /// change, with no composition or from any state but idle.
    @discardableResult
    public mutating func beginRender(_ settings: HaloRenderSettings) -> Bool {
        guard selectedComposition != nil, renderRun == .idle else { return false }
        renderJob = HaloRenderJobState(settings: settings)
        return true
    }

    /// Changes the sheet's settings; only while editing.
    public mutating func setRenderSettings(_ settings: HaloRenderSettings) {
        guard case .editing = renderRun else { return }
        renderJob = HaloRenderJobState(settings: settings)
    }

    /// Starts the render the sheet is editing (editing → running(0, frames))
    /// from `services.compositionRendering`'s plan. Returns what the app's run
    /// needs; nil unless editing, or when the plan is refused.
    public mutating func startRender() -> (plan: HaloRenderPlan, composition: HaloComposition)? {
        guard case .editing(let settings) = renderRun else { return nil }
        return startRender(settings)
    }

    /// Records `done` frames written; only while running. Never goes back,
    /// never passes the plan's frame count.
    public mutating func renderProgressed(done: Int) {
        renderProgress(frame: done)
    }

    /// How the app's run ended: `.finished` → finished with the file names,
    /// `.failed` → failed in words, `.cancelled` → idle.
    public mutating func endRender(_ outcome: HaloRenderOutcome) {
        finishRender(outcome)
        if case .cancelled = outcome { closeRenderSheet() }
    }

    /// Closes a finished or failed render's sheet (→ idle); a running render
    /// stays.
    public mutating func dismissRender() {
        var run = renderRun
        run.dismiss()
        if run == .idle { closeRenderSheet() }
    }
}

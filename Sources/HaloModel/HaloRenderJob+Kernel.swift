// HaloRenderJob+Kernel.swift: the adapter from Halo's render job onto
// SuiteKernel's ExportRun (core-loop CL-2 signatures, CL-6 bodies; #1971).
// The stored `renderJob: HaloRenderJobState?` keeps its shape; `renderRun`
// reads it as the kernel's run, and every transition builds that run, lets
// the kernel decide (`begin`, `start`, `progressed`, `end`, `dismiss`) and
// writes the result back. The only file that writes `renderJob`. The frames
// are rendered off the main actor by the app through
// `services.compositionRendering.run`; this file keeps the state the sheet
// shows. A cancel is never stored: it goes straight to idle. Linux-safe: no
// UI imports.
import SuiteKernel

extension HaloProject {
    /// The render job as the kernel's run: `.idle` with no job, `.editing`
    /// while the sheet is open on settings, `.running` with frames written of
    /// the plan's count, `.finished` with the plan's file names, `.failed`
    /// with the outcome in words.
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

    /// Whether a render has started and not ended yet.
    var renderRunning: Bool {
        if case .running = renderRun { return true }
        return false
    }

    /// Opens the Render sheet on `settings` (idle → editing). False, and no
    /// change, with no composition or from any state but idle.
    @discardableResult
    public mutating func beginRender(_ settings: HaloRenderSettings) -> Bool {
        guard selectedComposition != nil, renderRun == .idle else { return false }
        var opened = false
        transition { opened = $0.begin(settings) }
        return opened
    }

    /// Changes the sheet's settings; only while editing.
    public mutating func setRenderSettings(_ settings: HaloRenderSettings) {
        guard case .editing = renderRun else { return }
        transition { _ = $0.begin(settings) }
    }

    /// Starts the render the sheet is editing (editing → running(0, frames))
    /// from `services.compositionRendering`'s plan. Returns what the app's run
    /// needs; nil unless editing. A refused plan fails the run in its words.
    public mutating func startRender() -> (plan: HaloRenderPlan, composition: HaloComposition)? {
        guard case .editing(let settings) = renderRun, let comp = selectedComposition else { return nil }
        let plan: HaloRenderPlan
        do {
            plan = try services.compositionRendering.plan(comp, settings: settings)
        } catch {
            let message = (error as? HaloEditError)?.message ?? "\(error)"
            transition(ending: .failed(frame: 0, message: message)) {
                _ = $0.start(total: 0)
                $0.end(.failure(error))
            }
            return nil
        }
        transition { _ = $0.start(total: plan.frames.count) }
        renderJob?.plan = plan
        return (plan, comp)
    }

    /// Records `done` frames written; only while running. Never goes back,
    /// never passes the plan's frame count.
    public mutating func renderProgressed(done: Int) {
        transition { $0.progressed(done: done) }
    }

    /// Cancel from the sheet: editing or running → idle (the app cancels its
    /// task first).
    public mutating func cancelRender() {
        transition {
            $0.end(.failure(CancellationError()))
            $0.dismiss()
        }
    }

    /// How the app's run ended: `.finished` → finished with the file names,
    /// `.failed` → failed in words, `.cancelled` → idle. Only a running
    /// render takes it.
    public mutating func endRender(_ outcome: HaloRenderOutcome) {
        switch outcome {
        case .finished:
            let files = renderJob?.plan?.fileNames ?? []
            transition(ending: outcome) { $0.end(.success(files)) }
        case .failed(let frame, let message):
            transition(ending: outcome) { $0.end(.failure(RenderStopped(frame: frame, message: message))) }
        case .cancelled:
            transition { $0.end(.failure(CancellationError())) }
        }
    }

    /// Closes a finished or failed render's sheet (→ idle); a running render
    /// stays.
    public mutating func dismissRender() {
        transition { $0.dismiss() }
    }

    /// "Frame 12 of 48" while a render runs; nil otherwise.
    public var renderProgressText: String? {
        guard case .running(_, let done, let total) = renderRun else { return nil }
        return "Frame \(done) of \(total)"
    }

    /// How the render ended, as the sheet shows it: "Rendered 48 frames." or
    /// "Render stopped at frame 5: Disk full." (a refused plan: its words);
    /// nil until it has.
    public var renderOutcomeText: String? {
        guard let job = renderJob, let outcome = job.outcome else { return nil }
        switch outcome {
        case .finished(let n):
            return n == 1 ? "Rendered 1 frame." : "Rendered \(n) frames."
        case .failed(let frame, let message):
            let reason = message.hasSuffix(".") ? String(message.dropLast()) : message
            return job.plan == nil ? "\(reason)." : "Render stopped at frame \(frame): \(reason)."
        case .cancelled:
            return nil
        }
    }

    /// Builds the kernel's run, lets `body` move it, and stores the result.
    /// `outcome` is what a run that ends here records.
    private mutating func transition(
        ending outcome: HaloRenderOutcome? = nil, _ body: (inout ExportRun<HaloRenderSettings>) -> Void
    ) {
        var run = renderRun
        body(&run)
        switch run {
        case .idle: renderJob = nil
        case .editing(let settings): renderJob = HaloRenderJobState(settings: settings)
        case .running(_, let done, _): renderJob?.progress = done
        case .finished, .failed: if renderJob?.outcome == nil { renderJob?.outcome = outcome }
        }
    }
}

/// A run that stopped at a frame, for the kernel's failed case; the words
/// the sheet shows come from `renderOutcomeText`.
private struct RenderStopped: Error {
    let frame: Int
    let message: String
}

// FlareExport+Kernel.swift: the export sheet's run transitions over the kernel's `ExportRun`
// (docs/blueprints/flare/features/flare-export.md, Contract slice and Pseudocode). Every move delegates to the run:
// it holds the state, clamps progress and keeps a running run open (rule 20); this file only says which move each
// sheet action is and when the sheet may make it.
import FlareCore
import SuiteKernel

extension FlareWorkspace {
    /// The run's options in every state but idle.
    public var exportingOptions: ExportOptions? {
        switch exportState {
        case .idle: nil
        case .editing(let o), .running(let o, _, _), .finished(let o, _), .failed(let o, _): o
        }
    }

    /// Idle to editing on the SVG frame defaults; false (and no change) with no document or a sheet already open.
    @discardableResult
    public mutating func openExport() -> Bool {
        guard case .idle = exportState, document != nil, let o = exportOptions(.svgFrame) else { return false }
        return exportState.begin(o)
    }

    /// Editing with no problem to running at 0 of `exportFileCount`; false (and no change) otherwise.
    @discardableResult
    public mutating func startExport() -> Bool {
        guard exportProblem == nil else { return false }
        return exportState.start(total: exportFileCount)
    }

    /// Moves the running run to `fraction` of its total, rounded down; the run clamps and never goes back.
    /// Ignored unless running.
    public mutating func exportProgressed(_ fraction: Double) {
        guard case .running(_, done: _, total: let total) = exportState, !fraction.isNaN else { return }
        exportState.progressed(done: Int((min(max(fraction, 0), 1) * Double(total)).rounded(.down)))
    }

    /// Ends the running run: finished with the written names, idle after a cancel, failed with the sheet's sentence.
    public mutating func endExport(_ outcome: Result<[String], any Error>) {
        switch outcome {
        case .success(let names): exportState.end(.success(names))
        case .failure(let error as CancellationError): exportState.end(.failure(error))
        case .failure(let error): exportState.end(.failure(ExportRefusal(description: Self.exportMessage(error))))
        }
    }

    /// Failed back to editing with the same options; any other state stays.
    public mutating func retryExport() {
        guard case .failed(let o, _) = exportState else { return }
        _ = exportState.begin(o)
    }

    /// Closes an editing, finished or failed run; a running one stays until it ends.
    public mutating func dismissExport() { exportState.dismiss() }
}

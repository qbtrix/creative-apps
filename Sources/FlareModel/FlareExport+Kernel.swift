// FlareExport+Kernel.swift: the export sheet's run transitions over the kernel's `ExportRun`
// (docs/blueprints/flare/features/flare-export.md, Contract slice). FX-2 declares them: the openers report nothing
// and change nothing, and progress, end and dismiss forward to the run, whose bodies arrive with EK-22. FX-4 fills
// the bodies without changing a signature.
import FlareCore
import SuiteKernel

extension FlareWorkspace {
    /// The run's options in every state but idle. Stub (FX-4): nil.
    public var exportingOptions: ExportOptions? { nil }

    /// Idle to editing on the SVG frame defaults; false otherwise. Stub (FX-4): false, changing nothing.
    @discardableResult
    public mutating func openExport() -> Bool { false }

    /// Editing with no problem to running at 0 of `exportFileCount`; false otherwise. Stub (FX-4): false, changing nothing.
    @discardableResult
    public mutating func startExport() -> Bool { false }

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

    /// Failed back to editing with the same options. Stub (FX-4): changes nothing.
    public mutating func retryExport() {}

    /// Closes an editing, finished or failed run; a running one stays until it ends.
    public mutating func dismissExport() { exportState.dismiss() }
}

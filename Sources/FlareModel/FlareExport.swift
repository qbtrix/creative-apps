// FlareExport.swift: the export sheet's state (docs/blueprints/flare.md, sections 2 and 3.3): default options and the
// scan's warnings before Export, then one run: `beginExport`, `exportProgressed`, and `endExport` (a result finishes,
// a cancel goes back to idle, any other error fails with a sentence). `export` does all three without live progress.
import FlareCore

extension FlareWorkspace {
    /// The sheet's starting options: the selected scene, its whole range, 1x, opaque. Nil with no scene.
    public func exportOptions(_ format: ExportFormat) -> ExportOptions? {
        selectedScene.map { ExportOptions(format: format, sceneID: $0.id, frames: 0...max($0.durationFrames - 1, 0)) }
    }

    /// What this export can't write, listed before Export; empty with no document.
    public func exportWarnings(_ options: ExportOptions) -> [String] {
        document.map { services.export.warnings($0, options: options) } ?? []
    }

    /// Starts a run at 0 progress. False, changing nothing, with no document or while a run is under way.
    @discardableResult
    public mutating func beginExport() -> Bool {
        guard document != nil else { return false }
        if case .running = exportState { return false }
        exportState = .running(progress: 0)
        return true
    }

    /// Moves the running bar to `fraction`, clamped to 0...1; never backwards, and ignored when nothing runs.
    public mutating func exportProgressed(_ fraction: Double) {
        guard case .running(let done) = exportState, !fraction.isNaN else { return }
        exportState = .running(progress: max(done, min(max(fraction, 0), 1)))
    }

    /// Ends the run: finished with the result, idle after a cancel, or failed with the reason. Ignored when nothing runs.
    public mutating func endExport(_ outcome: Result<ExportResult, any Error>) {
        guard case .running = exportState else { return }
        switch outcome {
        case .success(let result): exportState = .finished(result)
        case .failure(is CancellationError): exportState = .idle
        case .failure(let error): exportState = .failed(Self.exportMessage(error))
        }
    }

    /// Closes a finished or failed run; a running one stays until it ends.
    public mutating func dismissExport() {
        if case .running = exportState { return }
        exportState = .idle
    }

    /// One whole run through `services.export`, without live progress.
    public mutating func export(_ options: ExportOptions, rasterizer: any FrameRasterizing) async {
        guard let document, beginExport() else { return }
        do {
            endExport(.success(try await services.export.export(document, options: options, rasterizer: rasterizer) { _ in }))
        } catch {
            endExport(.failure(error))
        }
    }

    /// A failed export as a sentence for the sheet's error row.
    static func exportMessage(_ error: any Error) -> String {
        switch error {
        case let e as NotBuilt: e.reason
        case CommandError.sceneNotFound: "The scene to export is gone."
        case PNGExportError.frameOutOfRange(let r): "Frames \(r.lowerBound)–\(r.upperBound) aren't all in the scene."
        case PNGExportError.invalidStep: "The frame step must be 1 or more."
        case PNGExportError.invalidScale, PNGExportError.invalidSize: "That scale makes frames too small or too large to write."
        default: "The export couldn't be written."
        }
    }
}

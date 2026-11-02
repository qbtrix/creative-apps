// LibraryExportAdapter.swift (adopt-kernel-export AX-library): the export
// sheet's run is SuiteKernel's `ExportRun<ExportOptions>` (`exportRun`), moved
// only by its own calls in LibraryExport.swift. Library has no export state of
// its own: the kernel's `finished` holds the written names, the run's full
// `ExportSummary` rides beside it in `exportSummary`, and `exportFinished`
// reads the two. A `failed` run is never a finished one: it has no summary,
// and `exportError` is its message, which the sheet shows as an error.
import SuiteKernel

extension LibraryCatalog {
    /// The finished run's summary, else one of its written names; nil before a run ends and for a failed run.
    public var exportFinished: ExportSummary? {
        guard case .finished(_, let files) = exportRun else { return nil }
        return exportSummary ?? ExportSummary(total: files.count, written: files)
    }

    /// The failed run's error in words; nil unless the run failed.
    public var exportError: String? {
        if case .failed(_, let message) = exportRun { return message }
        return nil
    }
}

extension ExportRun where Options == ExportOptions {
    /// The run's options; nil when idle.
    var options: ExportOptions? {
        switch self {
        case .idle: nil
        case .editing(let o), .running(let o, _, _), .finished(let o, _), .failed(let o, _): o
        }
    }

    /// The sheet's options while editing; nil otherwise.
    public var editingOptions: ExportOptions? { if case .editing(let o) = self { o } else { nil } }

    /// True while the run writes.
    public var isRunning: Bool { if case .running = self { true } else { false } }
}

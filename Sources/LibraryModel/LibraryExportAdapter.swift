// LibraryExportAdapter.swift (adopt-kernel-export AX-library): the export
// sheet's run is SuiteKernel's `ExportRun<ExportOptions>` (`exportRun`), moved
// only by its own calls in LibraryExport.swift. The kernel's `finished` holds
// the written names; the run's full `ExportSummary` rides beside it in
// `exportSummary`. `ExportState` is the sheet's readout of the two, the shape
// LibraryApp's sheet and snapshots switch on; it holds no state of its own.
import SuiteKernel

/// The export sheet's readout of the kernel run: closed, editing its options, writing, or done.
public enum ExportState: Hashable, Sendable {
    case idle
    case editing(ExportOptions)
    case running(done: Int, total: Int)
    case finished(ExportSummary)

    /// Reads `run`: a finished run shows `summary` (else its written names); a failed one
    /// shows its error as the one failure, at the options' folder.
    public init(_ run: ExportRun<ExportOptions>, summary: ExportSummary?) {
        switch run {
        case .idle: self = .idle
        case .editing(let options): self = .editing(options)
        case .running(_, let done, let total): self = .running(done: done, total: total)
        case .finished(_, let files): self = .finished(summary ?? ExportSummary(total: files.count, written: files))
        case .failed(let options, let message):
            self = .finished(ExportSummary(total: 0, written: [],
                                           failures: [FileFailure(path: options.folder, reason: message)]))
        }
    }
}

extension LibraryCatalog {
    /// The sheet's state, read from the kernel run. A write (tests and fixtures only) lands on
    /// the kernel run under its current options, or an empty folder's.
    public internal(set) var exportState: ExportState {
        get { ExportState(exportRun, summary: exportSummary) }
        set {
            let options = exportRun.options ?? ExportOptions(folder: "")
            switch newValue {
            case .idle: exportRun = .idle
            case .editing(let next): exportRun = .editing(next)
            case .running(let done, let total): exportRun = .running(options, done: done, total: total)
            case .finished(let summary): exportRun = .finished(options, summary.written)
            }
            if case .finished(let summary) = newValue { exportSummary = summary } else { exportSummary = nil }
        }
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
}

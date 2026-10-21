// PhotoExportRun+Kernel.swift (adopt-kernel-export AX-photo): the Export
// sheet's state on SuiteKernel's `ExportRun`, in place of the window's own
// Bool. The run holds the state and refuses the moves it doesn't allow (no
// open over a running write, no start but from the sheet); this file says
// which move each window action is. Export… opens the sheet on the last
// choices, Export starts one write on the sheet's choice, and the write's
// outcome (the file's name, a cancelled save panel, an error) ends it.
// Linux-safe.
import SuiteKernel

extension PhotoWorkspace {
    /// The Export sheet is up (the run is editing).
    public var isExportSheetOpen: Bool {
        if case .editing = exportRun { return true }
        return false
    }

    /// An export's write is under way (the run is running).
    public var isExportRunning: Bool {
        if case .running = exportRun { return true }
        return false
    }

    /// Export…: opens the sheet on the last choices; false (and no change)
    /// with no image or while a write runs.
    @discardableResult
    public mutating func openExport() -> Bool {
        guard canvas != nil else { return false }
        return exportRun.begin(exportOptions)
    }

    /// Export: from the open sheet, keeps `o` as the last choices and starts
    /// its one write; false (and no change) with no sheet open.
    @discardableResult
    public mutating func startExport(_ o: ExportOptions) -> Bool {
        guard isExportSheetOpen else { return false }
        _ = exportRun.begin(o)
        exportOptions = o
        return exportRun.start(total: 1)
    }

    /// Ends the running write: finished with the written file's name, idle
    /// after a cancel, failed with the error; ignored unless running.
    public mutating func endExport(_ outcome: Result<[String], any Error>) {
        exportRun.end(outcome)
    }

    /// Cancel: closes the sheet (or a finished or failed run); a running write stays.
    public mutating func dismissExport() { exportRun.dismiss() }
}

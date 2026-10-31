// PhotoExportRun+Kernel.swift (adopt-kernel-export AX-photo): the Export
// sheet's state on SuiteKernel's `ExportRun`, in place of the window's own
// Bool. The run holds the state and refuses the moves it doesn't allow (no
// open over a running write, no start but from the sheet); this file says
// which move each window action is. Export… opens the sheet on the last
// choices, a pick in the sheet (export-pack PX-2) changes the open sheet's
// choice, the sheet's note says the size it writes and what the format does
// with transparency, Export starts one write on it, and the write's outcome (the file's
// name, a cancelled save panel, an error) ends it.
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

    /// The open sheet's choices; nil with no sheet open.
    public var exportChoice: ExportOptions? {
        if case .editing(let o) = exportRun { return o }
        return nil
    }

    /// The open sheet's note: the size it writes, then what the format does
    /// with transparent pixels; nil with no sheet open.
    public var exportNote: String? {
        guard let choice = exportChoice, let canvas else { return nil }
        let alpha = choice.format == .png ? "PNG keeps transparent pixels." : "JPEG has no transparency: transparent pixels export white."
        return "Exports \(Self.sizeText(width: canvas.width, height: canvas.height)).\n\(alpha)"
    }

    /// A pick in the open sheet (a format chip, Quality): the sheet shows `o`,
    /// its quality held to the 0.1...1 `file.export` takes; kept as the last
    /// choices only on Export. False (and no change) with no sheet open.
    @discardableResult
    public mutating func editExport(_ o: ExportOptions) -> Bool {
        guard isExportSheetOpen else { return false }
        var picked = o
        picked.quality = picked.quality.isNaN ? exportOptions.quality : min(max(picked.quality, 0.1), 1)
        return exportRun.begin(picked)
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

// LibraryExport.swift (EX-3; EX-13 fills cancel and retry): the catalog's export
// states (targets, help, the sheet's options, preview, plan, progress, summary)
// and the runner that renders and writes a plan in order, keeping each file's
// failure. Exporting is never an undo step. Progress moves by SuiteKernel's
// `ExportRun` rule; `ExportState` itself moves onto `ExportRun` in #3091.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel

extension LibraryCatalog {
    /// The loupe's photo in the loupe, else the selected photos in `order`.
    public var exportTargets: [PhotoItem] {
        let loupe = focusedItemID.map { order.contains($0) ? [$0] : [] } ?? []
        let ids = mode == .loupe ? loupe : order.filter(selection.contains)
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { byID[$0] }
    }

    /// Why Export… can't act; nil when it can.
    public var exportHelp: String? {
        if case .running = exportState { return "An export is already running." }
        if exportTargets.isEmpty { return "Select a photo to export it." }
        return services.unavailable["exporter"]
    }

    /// Opens the sheet: `.editing(last ?? default)` with `folder`; false with no targets or while one runs.
    public mutating func beginExport(folder: String, last: ExportOptions? = nil) -> Bool {
        guard exportHelp == nil else { return false }
        var options = last ?? ExportOptions(folder: folder)
        options.folder = folder
        exportState = .editing(options)
        return true
    }

    /// Replaces the sheet's options; ignored unless editing.
    public mutating func setExportOptions(_ options: ExportOptions) {
        guard case .editing = exportState else { return }
        exportState = .editing(options)
    }

    /// The sheet's preview of the first target: "IMG_0001.jpg · 2048 × 1365",
    /// "IMG_0001.jpg + .xmp · …" with a sidecar, the template's help, or the
    /// exporter's unavailable reason; otherwise nil unless editing.
    public var exportPreview: String? {
        if let reason = services.unavailable["exporter"] { return reason }
        guard case .editing(let options) = exportState else { return nil }
        if let help = options.naming.help { return help }
        guard let first = exportTargets.first,
              let item = services.exporter.plan([first], options: options, existingNames: []).items.first
        else { return nil }
        let sidecar = options.sidecar ? " + .xmp" : ""
        return "\(item.fileName)\(sidecar) · \(item.size.width) × \(item.size.height)"
    }

    /// The plan for `exportTargets` under the editing options, `.running(0, n)`;
    /// nil unless editing with a usable template and something to export.
    public mutating func exportPlan(existingNames: Set<String>) -> ExportPlan? {
        guard case .editing(let options) = exportState, options.naming.help == nil else { return nil }
        let targets = exportTargets
        guard !targets.isEmpty else { return nil }
        let plan = services.exporter.plan(targets, options: options, existingNames: existingNames)
        guard !plan.items.isEmpty else { return nil }
        exportState = .running(done: 0, total: plan.items.count)
        return plan
    }

    /// Reports `done` photos while running: never backwards, never past the plan's total.
    public mutating func showExportProgress(done: Int, total: Int) {
        guard case .running(let old, let planned) = exportState else { return }
        var run = ExportRun<Int>.running(0, done: old, total: planned)
        run.progressed(done: done)
        if case .running(_, let now, _) = run { exportState = .running(done: now, total: planned) }
    }

    /// Ends a running export with its summary.
    public mutating func finishExport(_ summary: ExportSummary) {
        guard case .running = exportState else { return }
        exportState = .finished(summary)
    }

    /// True while running; the area then cancels its task (EX-13).
    public mutating func cancelExport() -> Bool { false }
    /// From `.finished` with failures, the plan of only `failedIDs` under `options` (EX-13).
    public mutating func retryExport(options: ExportOptions, existingNames: Set<String>) -> ExportPlan? { nil }

    /// Closes the sheet; refused while running.
    public mutating func closeExport() {
        if case .running = exportState { return }
        exportState = .idle
    }
}

/// Renders and writes a plan off the main actor, in order, one photo at a time.
public enum ExportRunner {
    /// Renders and writes each item in order; a file that fails is kept as a
    /// `FileFailure` with its photo id and the run goes on. Reports `progress`
    /// after every item. With `sidecar`, writes the photo's XMP beside it.
    public static func run(_ plan: ExportPlan, photos: [String: PhotoItem],
                           exporter: any PhotoExporting, writer: any JPEGWriting,
                           writeSidecar: @escaping @Sendable (Data, _ folder: String, _ fileName: String) async throws -> Void,
                           progress: @escaping @Sendable (Int) -> Void) async -> ExportSummary {
        let options = plan.options
        var written: [String] = [], failures: [FileFailure] = [], failedIDs: [String] = []
        func fail(_ item: ExportPlan.Item, _ error: any Error) {
            failures.append(FileFailure(path: item.fileName, reason: (error as? LibraryError)?.message ?? "\(error)"))
            failedIDs.append(item.photoID)
        }
        for (index, item) in plan.items.enumerated() {
            defer { progress(index + 1) }
            guard let photo = photos[item.photoID] else { fail(item, LibraryError.missingFile(item.photoID)); continue }
            do {
                let image = try await exporter.render(item, photo: photo)
                try await writer.write(image, quality: options.quality, folder: options.folder, fileName: item.fileName)
                if options.sidecar, let xmp = ExportSidecar.xmp(for: photo) {
                    try await writeSidecar(xmp, options.folder, ExportSidecar.fileName(for: item.fileName))
                }
            } catch { fail(item, error); continue }
            written.append(item.fileName)
        }
        return ExportSummary(total: plan.items.count, written: written, failures: failures, failedIDs: failedIDs)
    }
}

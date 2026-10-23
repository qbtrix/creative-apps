// LibraryExport.swift (EX-3, EX-13): the catalog's export states (targets,
// help, the sheet's options, preview, plan, progress, summary, cancel, retry of
// the failed photos) and the runner that renders and writes a plan in order,
// keeping each file's failure and stopping on Cancel. Exporting is never an undo step. Each move is
// one call on the kernel's `exportRun` (LibraryExportAdapter.swift); `exportState` reads it.
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
        return exportRun.begin(options)
    }

    /// Replaces the sheet's options; ignored unless editing.
    public mutating func setExportOptions(_ options: ExportOptions) {
        guard case .editing = exportRun else { return }
        _ = exportRun.begin(options)
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
        guard !plan.items.isEmpty, exportRun.start(total: plan.items.count) else { return nil }
        return plan
    }

    /// Reports `done` photos while running: never backwards, never past the plan's total.
    public mutating func showExportProgress(done: Int, total: Int) {
        exportRun.progressed(done: done)
    }

    /// Ends a running export with its summary.
    public mutating func finishExport(_ summary: ExportSummary) {
        guard case .running = exportRun else { return }
        exportSummary = summary
        exportRun.end(.success(summary.written))
    }

    /// True while running; the area then cancels its task, and the runner's
    /// summary (`cancelled`) ends the run through `finishExport`.
    public mutating func cancelExport() -> Bool {
        if case .running = exportState { return true }
        return false
    }

    /// From `.finished` with failures: the plan of only `failedIDs` under
    /// `options`, in that order, `.running(0, n)`; nil otherwise.
    public mutating func retryExport(options: ExportOptions, existingNames: Set<String>) -> ExportPlan? {
        guard case .finished(let summary) = exportState, !summary.failedIDs.isEmpty else { return nil }
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let failed = summary.failedIDs.compactMap { byID[$0] }
        let plan = services.exporter.plan(failed, options: options, existingNames: existingNames)
        guard !plan.items.isEmpty, exportRun.begin(options), exportRun.start(total: plan.items.count) else { return nil }
        return plan
    }

    /// Closes the sheet; refused while running.
    public mutating func closeExport() {
        exportRun.dismiss()
    }
}

/// Renders and writes a plan off the main actor, in order, one photo at a time.
public enum ExportRunner {
    /// Renders and writes each item in order; a file that fails is kept as a
    /// `FileFailure` with its photo id and the run goes on. Reports `progress`
    /// after every item. With `sidecar`, writes the photo's XMP beside it.
    /// Checks for Cancel before each photo and between its render and write,
    /// so nothing is written after Cancel; the summary then says `cancelled`.
    public static func run(_ plan: ExportPlan, photos: [String: PhotoItem],
                           exporter: any PhotoExporting, writer: any JPEGWriting,
                           writeSidecar: @escaping @Sendable (Data, _ folder: String, _ fileName: String) async throws -> Void,
                           progress: @escaping @Sendable (Int) -> Void) async -> ExportSummary {
        let options = plan.options
        var written: [String] = [], failures: [FileFailure] = [], failedIDs: [String] = []
        var cancelled = false
        func fail(_ item: ExportPlan.Item, _ error: any Error) {
            failures.append(FileFailure(path: item.fileName, reason: (error as? LibraryError)?.message ?? "\(error)"))
            failedIDs.append(item.photoID)
        }
        for (index, item) in plan.items.enumerated() {
            if Task.isCancelled { cancelled = true; break } // before each photo
            if let photo = photos[item.photoID] {
                do {
                    let image = try await exporter.render(item, photo: photo)
                    guard !Task.isCancelled else { cancelled = true; break } // between render and write
                    try await writer.write(image, quality: options.quality, folder: options.folder, fileName: item.fileName,
                                           metadataFrom: photo.path, dropping: item.dropping)
                    if options.sidecar, let xmp = ExportSidecar.xmp(for: photo, metadata: options.metadata) {
                        try await writeSidecar(xmp, options.folder, ExportSidecar.fileName(for: item.fileName))
                    }
                    written.append(item.fileName)
                } catch {
                    if Task.isCancelled { cancelled = true; break }
                    fail(item, error)
                }
            } else {
                fail(item, LibraryError.missingFile(item.photoID))
            }
            progress(index + 1)
        }
        return ExportSummary(total: plan.items.count, written: written, failures: failures, failedIDs: failedIDs,
                             cancelled: cancelled)
    }
}

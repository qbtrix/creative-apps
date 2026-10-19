// LibraryExport.swift (EX-1 stubs, filled by EX-3/EX-13): export methods and runner; each refuses until EX-3.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension LibraryCatalog {
    /// The loupe's photo in the loupe, else the selected photos in `order`.
    public var exportTargets: [PhotoItem] { [] }
    /// Why Export… can't act; nil when it can.
    public var exportHelp: String? { LiveExporter.unavailable }
    /// Opens the sheet: `.editing(last ?? default)` with `folder`; false with no targets or while one runs.
    public mutating func beginExport(folder: String, last: ExportOptions? = nil) -> Bool { false }
    public mutating func setExportOptions(_ options: ExportOptions) {}
    /// The sheet's preview of the first target: "IMG_0001.jpg · 2048 × 1365".
    public var exportPreview: String? { LiveExporter.unavailable }
    /// The plan for `exportTargets` under the editing options, `.running(0, n)`.
    public mutating func exportPlan(existingNames: Set<String>) -> ExportPlan? { nil }
    public mutating func showExportProgress(done: Int, total: Int) {}
    public mutating func finishExport(_ summary: ExportSummary) {}
    /// True while running; the area then cancels its task (EX-13).
    public mutating func cancelExport() -> Bool { false }
    /// From `.finished` with failures, the plan of only `failedIDs` under `options` (EX-13).
    public mutating func retryExport(options: ExportOptions, existingNames: Set<String>) -> ExportPlan? { nil }
    /// Closes the sheet; refused while running.
    public mutating func closeExport() {}
}

/// Renders and writes a plan off the main actor, in order, one photo at a time.
public enum ExportRunner {
    /// Stub: writes nothing and fails every item with the exporter's reason.
    public static func run(_ plan: ExportPlan, photos: [String: PhotoItem],
                           exporter: any PhotoExporting, writer: any JPEGWriting,
                           writeSidecar: @escaping @Sendable (Data, _ folder: String, _ fileName: String) async throws -> Void,
                           progress: @escaping @Sendable (Int) -> Void) async -> ExportSummary {
        let reason = LiveExporter.unavailable ?? ""
        return ExportSummary(total: plan.items.count, written: [],
                             failures: plan.items.map { FileFailure(path: $0.fileName, reason: reason) },
                             failedIDs: plan.items.map(\.photoID))
    }
}

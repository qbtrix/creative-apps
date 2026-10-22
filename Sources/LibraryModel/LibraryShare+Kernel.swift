// LibraryShare+Kernel.swift (share-sheet SH-1 contract, SH-3 bodies): what Share makes before the system's share
// sheet opens (packet docs/blueprints/library/features/share-sheet.md). The copies are export-pack's "For Sharing"
// preset with location off, made by Library's own exporter and writer (`ExportRunner`) into
// `<support>/Share/<run>/`, named uniquely in the grid's order, and emptied at the next launch. `file.share-prepare`
// names the same files for an agent: kernel commands run synchronously, so the command plans the copies and
// `prepareShare` writes them. No encoder lives here. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel

/// The share copies: their export options and where they live.
public enum SharePrep {
    /// The "For Sharing" preset (JPEG, quality 85, long edge 2048) with location off; the folder is set per run.
    public static let options: ExportOptions = {
        let base = ExportOptions(longEdge: 2048, quality: 85, folder: "", format: .jpeg, metadata: .noLocation)
        var options = ExportPresets.builtIns.first { $0.name == "For Sharing" }?.applied(to: base) ?? base
        options.metadata = .noLocation
        return options
    }()

    /// `<support>/Share`, where every run's folder lives.
    static func root(support: String) -> String {
        (support.hasSuffix("/") ? String(support.dropLast()) : support) + "/Share"
    }

    /// The run's folder, `<support>/Share/<run>`.
    public static func folder(support: String, run: String) -> String {
        "\(root(support: support))/\(run)"
    }

    /// Empties `<support>/Share/` on disk at launch, keeping the folder and the rest of `support`.
    public static func cleanup(support: String) throws {
        try empty(root(support: support))
    }

    /// The same cleanup through `writer`, so the copies a fake writer holds go too.
    public static func cleanup(support: String, writer: any JPEGWriting) async throws {
        try await writer.removeAll(in: root(support: support))
    }

    /// Removes everything inside `folder` on disk; a missing folder is already empty.
    static func empty(_ folder: String) throws {
        let files = FileManager.default
        guard files.fileExists(atPath: folder) else { return }
        for name in try files.contentsOfDirectory(atPath: folder) {
            try files.removeItem(atPath: folder + "/" + name)
        }
    }
}

extension JPEGWriting {
    public func removeAll(in folder: String) async throws { try SharePrep.empty(folder) }
}

extension LibraryCatalog {
    /// `file.share-prepare`'s params: the ids (left out, the photos Export would take), and the support folder
    /// and run the copies go under (left out, `.` and `share`).
    struct ShareParams: Codable, Sendable { var ids: [String]?; var support: String?; var run: String? }
    /// The files the prepare writes, in the grid's order.
    struct ShareFiles: Codable, Sendable { var files: [String] }

    /// Why Share can't run now: an export running, nothing selected, or no exporter; nil when it can.
    public var shareHelp: String? {
        if case .running = exportState { return "An export is already running." }
        if exportTargets.isEmpty { return "Select a photo to share it." }
        return services.unavailable["exporter"]
    }

    /// The plan for the share copies of `ids` (nil: `exportTargets`) in the grid's order, into the run's folder.
    func sharePlan(support: String, run: String, ids: [String]?, existingNames: Set<String>) throws -> ExportPlan {
        if let help = shareHelp { throw LibraryRefusal(help) }
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let photos = ids.map { Set($0) }.map { picked in order.filter(picked.contains).compactMap { byID[$0] } } ?? exportTargets
        guard !photos.isEmpty else { throw LibraryRefusal("None of those photos are shown.") }
        var options = SharePrep.options
        options.folder = SharePrep.folder(support: support, run: run)
        return services.exporter.plan(photos, options: options, existingNames: existingNames)
    }

    /// Writes the share copies of `ids` (nil: `exportTargets`) into `SharePrep.folder(support:run:)` through the
    /// exporter and writer Export uses, and returns their paths in the grid's order. Throws `LibraryRefusal` with
    /// `shareHelp` when Share can't run, and the first failure when a copy can't be made.
    public func prepareShare(support: String, run: String, ids: [String]? = nil) async throws -> [String] {
        let folder = SharePrep.folder(support: support, run: run)
        let existing = (try? await services.writer.existingNames(in: folder)) ?? []
        let plan = try sharePlan(support: support, run: run, ids: ids, existingNames: existing)
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let summary = await ExportRunner.run(plan, photos: byID, exporter: services.exporter, writer: services.writer,
                                             writeSidecar: { _, _, _ in }, progress: { _ in })
        if let failure = summary.failures.first { throw LibraryError.writeFailed(path: failure.path, reason: failure.reason) }
        return summary.written.map { folder + "/" + $0 }
    }

    /// `file.share-prepare`, `{ids?, support?, run?}` → `{files: [path]}`; not an undo step. It names the files
    /// `prepareShare` writes for the same run, which the window and an agent's host then await.
    static let sharePrepareSpec: CommandSpec<LibraryCatalog> =
        .typed("file.share-prepare", title: "Share", summary: "Makes share copies of the selected photos, location off.",
               kind: .file, params: ShareParams.self,
               schema: .object(["ids": .optional(.array(of: .string("A photo's id."))),
                                "support": .optional(.string("The folder Share/ goes in.")),
                                "run": .optional(.string("This run's folder name under Share/."))], required: []),
               example: .object([:]), availability: { available($0.shareHelp) }
        ) { c, p -> ShareFiles in
            let support = p.support ?? ".", run = p.run ?? "share"
            let folder = SharePrep.folder(support: support, run: run)
            let plan = try c.sharePlan(support: support, run: run, ids: p.ids, existingNames: [])
            return ShareFiles(files: plan.items.map { folder + "/" + $0.fileName })
        }
}

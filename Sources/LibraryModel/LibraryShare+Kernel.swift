// LibraryShare+Kernel.swift (share-sheet SH-1 stubs, SH-3 bodies): what Share makes before the system's share
// sheet opens (packet docs/blueprints/library/features/share-sheet.md). The copies are export-pack's "For Sharing"
// preset with location off, written into `<support>/Share/<run>/` and emptied at the next launch; the
// `file.share-prepare` spec gives an agent the same files. SH-3 runs Library's exporter for the prepare and the
// cleanup and appends the spec to the catalog; until then both throw LibraryNotBuilt, so Share reads as
// unavailable with the reason. No encoder lives here. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel

/// A part of sharing SH-3 builds; it says so instead of acting.
public struct LibraryNotBuilt: Error, Sendable, Equatable {
    public let message: String
    public init(_ message: String) { self.message = message }
}

/// The share copies: their export options and where they live.
public enum SharePrep {
    /// What Share says until SH-3 makes the copies.
    public static let notBuilt = "Sharing arrives with SH-3."

    /// The "For Sharing" preset (JPEG, quality 85, long edge 2048) with location off; the folder is set per run.
    public static let options: ExportOptions = {
        let base = ExportOptions(longEdge: 2048, quality: 85, folder: "", format: .jpeg, metadata: .noLocation)
        var options = ExportPresets.builtIns.first { $0.name == "For Sharing" }?.applied(to: base) ?? base
        options.metadata = .noLocation
        return options
    }()

    /// The run's folder, `<support>/Share/<run>`.
    public static func folder(support: String, run: String) -> String {
        let root = support.hasSuffix("/") ? String(support.dropLast()) : support
        return "\(root)/Share/\(run)"
    }

    /// Empties `<support>/Share/` at launch. Stub: throws until SH-3.
    public static func cleanup(support: String) throws {
        throw LibraryNotBuilt(notBuilt)
    }
}

extension LibraryCatalog {
    /// `file.share-prepare`'s ids; left out, the photos Export would take.
    struct ShareParams: Codable, Sendable { var ids: [String]? }
    /// The files the prepare wrote, in selection order.
    struct ShareFiles: Codable, Sendable { var files: [String] }

    /// Why Share can't run now: an export running or nothing selected, then (until SH-3) the stub's reason.
    public var shareHelp: String? {
        if case .running = exportState { return "An export is already running." }
        if exportTargets.isEmpty { return "Select a photo to share it." }
        return SharePrep.notBuilt
    }

    /// Writes the share copies of `exportTargets` into `SharePrep.folder(support:run:)` and returns their paths in
    /// selection order. Stub: throws until SH-3.
    public func prepareShare(support: String, run: String) async throws -> [String] {
        throw LibraryNotBuilt(shareHelp ?? SharePrep.notBuilt)
    }

    /// `file.share-prepare`, `{ids?}` → `{files: [path]}`; not an undo step. SH-3 appends it to `commands`.
    static let sharePrepareSpec: CommandSpec<LibraryCatalog> =
        .typed("file.share-prepare", title: "Share", summary: "Makes share copies of the selected photos, location off.",
               kind: .file, params: ShareParams.self,
               schema: .object(["ids": .optional(.array(of: .string("A photo's id.")))], required: []),
               example: .object([:]), availability: { available($0.shareHelp) }
        ) { _, _ -> ShareFiles in throw LibraryNotBuilt(SharePrep.notBuilt) }
}

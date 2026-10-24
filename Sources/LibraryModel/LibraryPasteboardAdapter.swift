// LibraryPasteboardAdapter.swift (clipboard-interop CB-12, packet docs/blueprints/suiteui/features/clipboard-interop.md,
// slice CB-library): what Edit > Copy puts on the pasteboard for the selected photo, richest first: a full-size PNG
// with its develop settings applied, then the file URL of a clean PNG copy. Both come out of export's pipeline: the
// exporter's plan and render (full size, PNG, location off) and the writer, which writes the copy with the plan's
// `dropping`. The PNG bytes are the caller's encoder's, or, without one, the bytes of the copy just written, so no
// encoder lives here. `edit.copy` names the same copy for an agent: kernel commands run synchronously, so the command
// plans it and `copy` writes it. The app hands the items to SuiteShell's PasteboardBridge. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel
import SuiteModel

/// Copy's two representations of the selected photo, made through export.
public struct LibraryPasteboardAdapter: Sendable {
    /// The developed image as PNG bytes; nil reads back the copy the writer wrote.
    let encode: (@Sendable (DisplayImage) throws -> Data)?

    public init(encode: (@Sendable (DisplayImage) throws -> Data)? = nil) { self.encode = encode }

    /// The copy's export options: full size, PNG, location off, into `folder`.
    public static func options(folder: String) -> ExportOptions {
        ExportOptions(longEdge: nil, folder: folder, format: .png, metadata: .noLocation)
    }

    /// `<support>/Clipboard`, where the one clean copy lives.
    public static func folder(support: String) -> String {
        (support.hasSuffix("/") ? String(support.dropLast()) : support) + "/Clipboard"
    }

    /// The copy's plan: the photo Export would take first (the loupe's, else the first selected).
    static func plan(_ catalog: LibraryCatalog, folder: String, existingNames: Set<String>) -> (ExportPlan.Item, PhotoItem)? {
        guard let photo = catalog.exportTargets.first else { return nil }
        let plan = catalog.services.exporter.plan([photo], options: options(folder: folder), existingNames: existingNames)
        return plan.items.first.map { ($0, photo) }
    }

    /// The selected photo as `[PNG, file URL]`; nothing when no photo is selected. Empties `folder` first, so it
    /// holds only the latest copy. Throws the render's or the write's failure.
    public func copy(_ catalog: LibraryCatalog, folder: String) async throws -> [TypedData] {
        guard catalog.copyHelp == nil else { return [] }
        let writer = catalog.services.writer
        try await writer.removeAll(in: folder)
        let existing = (try? await writer.existingNames(in: folder)) ?? []
        guard let planned = Self.plan(catalog, folder: folder, existingNames: existing) else { return [] }
        let (item, photo) = planned
        let image = try await catalog.services.exporter.render(item, photo: photo)
        let path = folder + "/" + item.fileName
        try await writer.write(image, quality: Self.options(folder: folder).quality, folder: folder,
                               fileName: item.fileName, metadataFrom: photo.path, dropping: item.dropping)
        let png = try encode?(image) ?? Self.written(path)
        return [TypedData(type: .png, data: png), TypedData(type: .fileURL, data: Data(("file://" + path).utf8))]
    }

    /// The bytes of the copy at `path`, as the writer encoded it.
    static func written(_ path: String) throws -> Data {
        guard let data = FileManager.default.contents(atPath: path) else {
            throw LibraryError.writeFailed(path: path, reason: "The copy couldn't be read back.")
        }
        return data
    }
}

extension LibraryCatalog {
    /// What `edit.copy` names: the copy's file and its pixel size.
    struct CopyFile: Codable, Sendable { var file: String; var width, height: Int }

    /// Why Copy can't run now: nothing selected, or no exporter; nil when it can.
    public var copyHelp: String? {
        if exportTargets.isEmpty { return "Select a photo to copy it." }
        return services.unavailable["exporter"]
    }

    /// `edit.copy`, `{}` → `{file, width, height}`; a query: it writes the pasteboard, never the catalog. It names
    /// the copy `LibraryPasteboardAdapter.copy` writes into `./Clipboard`, which the window then awaits.
    static let copySpec: CommandSpec<LibraryCatalog> =
        .typed("edit.copy", title: "Copy", summary: "Copies the selected photo, developed and location off, as a PNG and its file.",
               kind: .query, params: NoParams.self, schema: ParamSchema.none, example: .object([:]),
               availability: { available($0.copyHelp) }
        ) { c, _ -> CopyFile in
            let folder = LibraryPasteboardAdapter.folder(support: ".")
            if let help = c.copyHelp { throw LibraryRefusal(help) }
            guard let item = LibraryPasteboardAdapter.plan(c, folder: folder, existingNames: [])?.0 else {
                throw LibraryRefusal("Select a photo to copy it.")
            }
            return CopyFile(file: folder + "/" + item.fileName, width: item.size.width, height: item.size.height)
        }
}

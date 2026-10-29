// PhotoHeadless.swift (adopt-command-catalog AC-p2): Photo's document with no window, for the afterglow CLI, MCP and
// the real jobs. It opens Photo's own file (OpenRaster .ora), PNG and JPEG through `CoreRasterImageCodec`, saves .ora,
// exports the flattened image as PNG or JPEG on the suite's export options (export-pack PX-3), and runs `PhotoWorkspace.catalog` lifted
// onto itself. Linux-safe: no UI imports.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel

/// Photo's headless document: one `PhotoWorkspace` on the live services, or on the caller's (`open(_:name:services:)`,
/// `new(_:services:)`): PhotoModel can't reach the suite's live text, so a host that can passes it in.
public struct PhotoHeadless: HeadlessDocument {
    public static let app = "photo", openExtensions = ["ora", "png", "jpg", "jpeg"], exportFormats = ["png", "jpeg"]
    /// Why the window's file commands refuse here: the CLI opens, saves and exports instead.
    public static let fileCommandHelp = "The CLI opens, saves and exports the file."
    /// Every `PhotoWorkspace.catalog` command, run on the wrapped workspace; file commands are unavailable.
    public static let catalog: CommandCatalog<PhotoHeadless> =
        (try? CommandCatalog(app: app, PhotoWorkspace.commands.map(lifted), history: { $0.workspace.history.kernel }))
        ?? .empty(app: app)
    /// The codec every file goes through.
    public static let codec = CoreRasterImageCodec()
    /// Exports write PNG at deflate level 1: core's level-6 search took 28 of 33 s of a scale-2 8064 x 6048 export
    /// (creative-core #728). Still lossless; the file grows a little.
    static let exportCodec = CoreRasterImageCodec(pngLevel: 1)

    /// The image the commands edit.
    public private(set) var workspace: PhotoWorkspace

    /// A headless document holding `workspace`.
    public init(workspace: PhotoWorkspace) { self.workspace = workspace }

    /// The file `data`, named `name`, by its extension: a Photo document (.ora) with its layers, or a flat PNG or
    /// JPEG. Throws `ArchiveError` for a bad document, `CodecError` for an image core can't read yet.
    public static func open(_ data: Data, name: String) throws -> PhotoHeadless {
        try open(data, name: name, services: .live)
    }

    /// `open(_:name:)` on `services`.
    public static func open(_ data: Data, name: String, services: PhotoServices) throws -> PhotoHeadless {
        var workspace = PhotoWorkspace(services: services)
        switch name.split(separator: ".").last.map({ $0.lowercased() }) ?? "" {
        case "ora": try workspace.openDocument(workspace.services.archive.package(fromContainer: data), name: name, codec: codec)
        case "png", "jpg", "jpeg": try workspace.openImage(data, name: name, codec: codec)
        default: throw CatalogError.unavailable(id: "open", why: "Photo opens .ora, .png, .jpg and .jpeg files.")
        }
        return PhotoHeadless(workspace: workspace)
    }

    /// A white image `width` x `height` (1024 x 768 when absent), its one layer "Background".
    public static func new(_ options: JSONValue) throws -> PhotoHeadless {
        try new(options, services: .live)
    }

    /// `new(_:)` on `services`.
    public static func new(_ options: JSONValue, services: PhotoServices) throws -> PhotoHeadless {
        let o = try options.decode(NewOptions.self)
        var workspace = PhotoWorkspace(services: services)
        do { try workspace.newCanvas(width: o.width ?? 1024, height: o.height ?? 768) } catch {
            throw CatalogError.failed(id: "new", message: "\(error)")
        }
        return PhotoHeadless(workspace: workspace)
    }

    /// The Photo document's bytes (.ora), as the window's Save writes them.
    public func save() throws -> Data {
        try workspace.services.archive.container(workspace.documentPackage(codec: Self.codec))
    }

    /// The flattened image as "png" or "jpeg" on the suite's export options (`SuiteExportOptions(json:)`: `size`,
    /// `quality`, ...; `format` names the file, whatever the options say), through the sheet's own
    /// `exportPixels(_:)`. The older `{"longSide": n}` form still resizes a copy with `image.resize`.
    public func export(_ format: String, options: JSONValue) throws -> [ExportedFile] {
        guard let kind = ImageFormat(rawValue: format) else {
            throw CatalogError.unavailable(id: "export", why: "Photo exports png and jpeg.")
        }
        guard case .object(let keys) = options, keys["longSide"] != nil else {
            var o = try SuiteExportOptions(json: options, defaults: workspace.exportOptionsDefault())
            o.format = format
            let data = try Self.exportCodec.encode(workspace.exportPixels(o), as: kind, quality: o.quality)
            return [ExportedFile(suggestedName: workspace.fileName(for: kind), format: format, data: data)]
        }
        let o = try options.decode(ExportOptions.self)
        var copy = workspace
        if let side = o.longSide, let canvas = copy.canvas {
            let scale = Double(side) / Double(max(canvas.width, canvas.height))
            let size: JSONValue = .object(["width": .number(max((Double(canvas.width) * scale).rounded(), 1)),
                                           "height": .number(max((Double(canvas.height) * scale).rounded(), 1))])
            _ = try PhotoWorkspace.catalog.run("image.resize", params: size, on: &copy)
        }
        let data = try Self.exportCodec.encode(copy.exportPixels(as: kind), as: kind, quality: o.quality ?? 0.9)
        return [ExportedFile(suggestedName: copy.fileName(for: kind), format: format, data: data)]
    }

    /// The file's name, the canvas size, the layers (top first) and the selected layer.
    public func summary() -> JSONValue {
        let layers = workspace.layers.map { l -> JSONValue in
            .object(["id": .string(l.id), "name": .string(l.name), "visible": .bool(l.isVisible), "opacity": .number(l.opacity)])
        }
        return .object([
            "app": .string(Self.app), "name": workspace.documentName.map(JSONValue.string) ?? .null,
            "width": workspace.canvas.map { .number(Double($0.width)) } ?? .null,
            "height": workspace.canvas.map { .number(Double($0.height)) } ?? .null,
            "layers": .array(layers), "selectedLayer": workspace.selectedLayerID.map(JSONValue.string) ?? .null,
        ])
    }

    /// `spec` over the wrapped workspace: the same id, words, schema and availability, run through PhotoWorkspace's
    /// catalog. File commands are unavailable: the CLI's open, save and export do their work.
    static func lifted(_ spec: CommandSpec<PhotoWorkspace>) -> CommandSpec<PhotoHeadless> {
        let id = spec.id
        let windowOnly = spec.kind == .file
        return .typed(id, title: spec.title, summary: spec.summary, kind: spec.kind, params: JSONValue.self,
                      schema: spec.params, result: spec.result, example: spec.example,
                      availability: { windowOnly ? .unavailable(fileCommandHelp) : spec.availability($0.workspace) }) { h, json in
            try PhotoWorkspace.catalog.run(id, params: json, on: &h.workspace).result
        }
    }

    struct NewOptions: Decodable { var width, height: Int? }
    struct ExportOptions: Decodable { var longSide: Int?; var quality: Double? }
}

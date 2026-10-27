// LibraryHeadless.swift (adopt-command-catalog AC-l3): Library's document with no window, for the afterglow CLI, MCP
// and the real jobs. A `.library` file is a stored zip (core's ZipStore): `catalog.json` in the catalog file's format
// (LiveCatalogCoding) and the photos under `images/`. Opening it imports every image the catalog doesn't list yet.
// Commands are `LibraryCatalog.catalog`'s, lifted; saving writes the zip back; export writes the catalog file
// ("json") or the picks as PNGs at a long side through CoreRaster's codec, which refuses until core's PNG lands
// (qbtrix/creative-core#562). The catalog (about 1.7 KB inline) lives in a copy-on-write box, so copying the document
// is a pointer copy and fits a small thread stack (#5032). Linux-safe: no UI imports.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
import CoreRaster
import SuiteKernel

/// Library's headless document: one catalog and the images it points at.
public struct LibraryHeadless: HeadlessDocument {
    public static let app = "library", openExtensions = ["library"], exportFormats = ["png", "json"]
    /// Why the window's file commands refuse here: the CLI opens, saves and exports instead.
    public static let fileCommandHelp = "The CLI opens, saves and exports the library."
    /// Every `LibraryCatalog.catalog` command, run on the wrapped catalog; file commands are unavailable.
    public static let catalog: CommandCatalog<LibraryHeadless> =
        (try? CommandCatalog(app: app, LibraryCatalog.commands.map(lifted), history: { LibraryCatalogSteps(catalog: $0.library) }))
        ?? .empty(app: app)
    static let catalogEntry = "catalog.json", imageFolder = "images/"
    static let pngFeature = "image-codecs (qbtrix/creative-core#562)"

    /// The photos and their culling, stored in `box` and copied only when a shared box is written.
    public private(set) var library: LibraryCatalog {
        _read { yield box.value }
        set { box = CatalogBox(newValue) }
        _modify {
            if !isKnownUniquelyReferenced(&box) { box = CatalogBox(box.value) }
            yield &box.value
        }
    }
    private var box: CatalogBox
    /// Each image's bytes by its path in the file ("images/<name>.png").
    public private(set) var images: [String: Data]
    /// The file's name without its extension, for the export's names.
    public private(set) var stem: String

    init(photos: [PhotoItem], images: [String: Data], stem: String) {
        var services = LibraryServices.fake()
        services.culling = LiveCulling(); services.coding = LiveCatalogCoding(); services.isPreview = false
        box = CatalogBox(LibraryCatalog(services: services))
        self.images = images; self.stem = stem
        library.restore(photos)
    }

    /// The window's catalog as a headless document, for the live command channel (editor-menus EM-7). It keeps the
    /// window's services and holds no images: the window's photos are files on disk.
    public init(catalog: LibraryCatalog) {
        box = CatalogBox(catalog); images = [:]; stem = "Library"
    }

    /// A `.library` file: its catalog's photos, then every listed-nowhere image under `images/` as a new photo.
    public static func open(_ data: Data, name: String) throws -> LibraryHeadless {
        do {
            let entries = try ZipStore.entries(data)
            var photos = try entries[catalogEntry].map { try LiveCatalogCoding().decode($0) } ?? []
            let images = entries.filter { $0.key.hasPrefix(imageFolder) }
            let listed = Set(photos.compactMap(\.path))
            for (path, bytes) in images.sorted(by: { $0.key < $1.key }) where !listed.contains(path) {
                photos.append(try photo(bytes, path: path))
            }
            return LibraryHeadless(photos: photos, images: images, stem: fileStem(name))
        } catch let error as CatalogError { throw error } catch {
            throw CatalogError.failed(id: "open", message: "\(name) isn't a Library file: \(error)")
        }
    }

    /// An empty library.
    public static func new(_ options: JSONValue) throws -> LibraryHeadless { LibraryHeadless(photos: [], images: [:], stem: "Library") }

    /// Adds the PNG `data` as `images/<name>`, a new photo whose id and name are the name without its extension.
    public mutating func importImage(_ data: Data, name: String) throws {
        let item = try Self.photo(data, path: Self.imageFolder + name)
        guard images[Self.imageFolder + name] == nil, !library.items.contains(where: { $0.id == item.id }) else {
            throw CatalogError.failed(id: "import", message: "The library already holds \(name).")
        }
        images[Self.imageFolder + name] = data
        library.appendImported([item])
    }

    /// The `.library` zip: the catalog file first, then the images.
    public func save() throws -> Data {
        var files = images
        files[Self.catalogEntry] = try catalogFile()
        return try ZipStore.archive(files, first: Self.catalogEntry)
    }

    /// "json": the catalog file, or the shown photos with `contents` "shown". "png": each pick, developed, at
    /// `longSide` (its own size when absent).
    public func export(_ format: String, options: JSONValue) throws -> [ExportedFile] {
        switch format {
        case "json":
            let data = try Self.wantsShown(options) ? shownFile() : catalogFile()
            return [ExportedFile(suggestedName: stem + ".json", format: format, data: data)]
        case "png": break
        default: throw CatalogError.unavailable(id: "export", why: "Library exports png and json.")
        }
        let plan = exportPlan(longSide: try options.decode(ExportSize.self).longSide)
        guard !plan.items.isEmpty else { throw CatalogError.failed(id: "export.png", message: "No photo is a pick; pick one to export it.") }
        let photos = Dictionary(library.items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return try plan.items.map { item in
            guard let photo = photos[item.photoID], let data = photo.path.flatMap({ images[$0] }) else {
                throw CatalogError.failed(id: "export.png", message: "\(item.photoID) has no image in the library.")
            }
            do {
                var buffer = try LiveDevelop().render(PNG.read(data), settings: photo.develop)
                if buffer.width != item.size.width || buffer.height != item.size.height {
                    buffer = try buffer.resized(width: item.size.width, height: item.size.height, filter: .lanczos3)
                }
                return ExportedFile(suggestedName: item.fileName, format: format, data: try PNG.write(buffer))
            } catch CodecError.unsupported {
                throw CatalogError.notBuilt(id: "export.png", feature: Self.pngFeature)
            }
        }
    }

    /// The picks in the library's order, each named `<name>.png` and sized to `longSide` (never enlarged).
    func exportPlan(longSide: Int?) -> ExportPlan {
        let picks = library.order.compactMap { id in library.items.first { $0.id == id && $0.flag == .pick } }
        let exporter = LiveExporter(decoder: library.services.decoder, develop: LiveDevelop())
        return exporter.plan(picks, options: ExportOptions(longEdge: longSide, folder: "", format: .png), existingNames: [])
    }

    /// The photo count and each photo's id, name, rating, flag and label, in catalog order.
    public func summary() -> JSONValue {
        let photos = library.items.map { p -> JSONValue in
            .object(["id": .string(p.id), "name": .string(p.name), "rating": .number(Double(p.rating)),
                     "flag": .string(p.flag.rawValue), "label": p.label.map { .string($0.rawValue) } ?? .null])
        }
        return .object(["app": .string(Self.app), "photos": .array(photos)])
    }

    func catalogFile() throws -> Data {
        do { return try LiveCatalogCoding().encode(library.items) } catch {
            throw CatalogError.failed(id: "save", message: "\(error)")
        }
    }

    /// A new photo for the PNG at `path`: its size from the header, an id and name from the file name.
    static func photo(_ data: Data, path: String) throws -> PhotoItem {
        guard let size = pngSize(data) else { throw CatalogError.failed(id: "import", message: "\(path) isn't a PNG.") }
        let name = fileStem(String(path.dropFirst(imageFolder.count)))
        return PhotoItem(id: name, name: name, captureDate: Date(timeIntervalSince1970: 0),
                         color: Color3(0.5, 0.5, 0.5), path: path, pixelSize: size)
    }

    /// A PNG's width and height from its IHDR chunk (W3C PNG 11.2.2), nil for anything else.
    static func pngSize(_ data: Data) -> PixelSize? {
        let b = [UInt8](data.prefix(24))
        guard b.count == 24, b.starts(with: [137, 80, 78, 71, 13, 10, 26, 10]), b[12..<16].elementsEqual("IHDR".utf8) else { return nil }
        let width = b[16..<20].reduce(0) { $0 << 8 | Int($1) }, height = b[20..<24].reduce(0) { $0 << 8 | Int($1) }
        return width > 0 && height > 0 ? PixelSize(width: width, height: height) : nil
    }

    static func fileStem(_ name: String) -> String {
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return name }
        return String(name[..<dot])
    }

    /// `spec` over the wrapped catalog; file commands are unavailable, as the CLI does their work.
    static func lifted(_ spec: CommandSpec<LibraryCatalog>) -> CommandSpec<LibraryHeadless> {
        let id = spec.id, windowOnly = spec.kind == .file
        return .typed(id, title: spec.title, summary: spec.summary, kind: spec.kind, params: JSONValue.self, schema: spec.params,
                      result: spec.result, example: spec.example,
                      availability: { windowOnly ? .unavailable(fileCommandHelp) : spec.availability($0.library) }) { doc, json in
            try LibraryCatalog.catalog.run(id, params: json, on: &doc.library).result
        }
    }

    struct ExportSize: Decodable { var longSide: Int? }

    /// The catalog on the heap; `library`'s `_modify` copies it before writing a shared one.
    final class CatalogBox: @unchecked Sendable {
        var value: LibraryCatalog
        init(_ value: LibraryCatalog) { self.value = value }
    }
}

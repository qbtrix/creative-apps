// DesignHeadless.swift (adopt-command-catalog AC-d2): Design's document with no
// window, for the afterglow CLI, MCP and the real jobs. It is the workspace on its live services: `open` and `save`
// go through the file codec (DesignFile), every command through Design's catalog (DesignCommandCatalog), and SVG
// export writes the scope its options name (every visible top-level frame of every page by default, each page, or the
// selection) through the export plan and its SVG (DesignExport+Kernel), names unique across the file, at the options'
// `frame` (the rest pose without one); any other option is refused in words. PNG waits on a Linux PNG writer (the App
// rasterizes it today). Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel

/// Design's headless document: one workspace and the file name it was opened from.
public struct DesignHeadless: HeadlessDocument {
    /// The slice that builds this document.
    public static let adoptingSlice = "adopt-command-catalog AC-design"
    public static let app = "design", openExtensions = ["design"], exportFormats = ["svg"]
    /// Design's commands lifted onto this document: each runs through `DesignWorkspace.catalog` on the workspace.
    public static let catalog: CommandCatalog<DesignHeadless> =
        (try? CommandCatalog(app: app, DesignWorkspace.commands.map(lift), history: { $0.workspace.history.kernel })) ?? .empty(app: app)

    /// The open document and the file name it came from ("Untitled.design" for a new one).
    public private(set) var workspace: DesignWorkspace, name: String

    public init(_ workspace: DesignWorkspace, name: String = "Untitled.design") { (self.workspace, self.name) = (workspace, name) }

    /// One workspace spec as a spec on this document, with the same id, schemas, example and availability.
    static func lift(_ spec: CommandSpec<DesignWorkspace>) -> CommandSpec<DesignHeadless> {
        .typed(spec.id, title: spec.title, summary: spec.summary, kind: spec.kind, params: JSONValue.self, schema: spec.params,
               result: spec.result, example: spec.example, availability: { spec.availability($0.workspace) }
        ) { doc, params in try DesignWorkspace.catalog.run(spec.id, params: params, on: &doc.workspace).result }
    }

    /// Opens a Design file's bytes; a refused file throws `failed` with the reason the window's alert shows.
    public static func open(_ data: Data, name: String) throws -> DesignHeadless {
        var workspace = DesignWorkspace()
        do throws(DesignFileError) { try workspace.open(data, at: URL(fileURLWithPath: name)) } catch { throw CatalogError.failed(id: "file.open", message: error.reason) }
        return DesignHeadless(workspace, name: name)
    }

    /// A new file, as File > New makes it: one page holding a Desktop frame. Design's new file takes no options.
    public static func new(_ options: JSONValue) throws -> DesignHeadless {
        var workspace = DesignWorkspace()
        workspace.newFile()
        return DesignHeadless(workspace)
    }

    /// The file's bytes, as Save writes them.
    public func save() throws -> Data {
        do throws(DesignFileError) { return try workspace.fileData() } catch { throw CatalogError.failed(id: "file.save", message: error.reason) }
    }

    /// `svg` at `options.scope`: `frame` (the default) writes one file per visible top-level frame of every page,
    /// `page` one file per page, `selection` the selected page's selected layers, in page order, each named after
    /// its layer or page and unique across the file; each page as it shows at `options.frame` (left out: the rest
    /// pose). An option other than `scope` or `frame`, or a scope it doesn't name, throws `failed` in words; so does
    /// a file with nothing to export. `png` is not built on Linux yet.
    public func export(_ format: String, options: JSONValue) throws -> [ExportedFile] {
        guard format == "svg" else {
            if format == "png" { throw CatalogError.notBuilt(id: "export.png", feature: "a Linux PNG writer for Design's raster path") }
            throw CatalogError.failed(id: "export", message: "Design exports \(Self.exportFormats.joined(separator: ", ")), not \(format).")
        }
        let scope = try Self.scope(options)
        var frame: Int?
        if case .object(let fields) = options, case .number(let value)? = fields["frame"], value.isFinite { frame = Int(value) }
        var files: [ExportedFile] = [], taken = Set<String>()
        let pages = scope == .selection ? workspace.selectedPage.map { [$0] } ?? [] : workspace.pages
        for page in pages {
            var onPage = workspace
            // Selecting a page clears the layer selection, so a selection export keeps the selected page as it is.
            if scope != .selection { onPage.selectPage(page.id) }
            let items: [DesignExportItem]
            do throws(DesignRefusal) { items = try onPage.exportPlan(DesignExportOptions(format: .svg, scope: scope), existing: taken) }
            catch .nothingToExport where scope != .selection { continue }
            catch { throw CatalogError.failed(id: "export", message: error.help) }
            for item in items {
                let svg: String
                do throws(DesignRefusal) { svg = try onPage.exportSVG(item, at: frame) } catch { throw CatalogError.failed(id: "export", message: error.help) }
                files.append(ExportedFile(suggestedName: item.fileName, format: format, data: Data(svg.utf8)))
                taken.insert(item.fileName)
            }
        }
        guard !files.isEmpty else { throw CatalogError.failed(id: "export", message: DesignRefusal.nothingToExport.help) }
        return files
    }

    /// The scope `options` names (`{"scope": "page"}`), `.frame` when absent; any key but `scope` and `frame` (read apart) or bad value throws `failed`.
    static func scope(_ options: JSONValue) throws -> DesignExportScope {
        let names = DesignExportScope.allCases.map(\.rawValue).joined(separator: ", ")
        guard case .object(let keys) = options else {
            if options == .null { return .frame }
            throw CatalogError.failed(id: "export", message: "Design's export options are an object, such as {\"scope\": \"page\"}.")
        }
        if let other = keys.keys.sorted().first(where: { $0 != "scope" && $0 != "frame" }) {
            throw CatalogError.failed(id: "export", message: "Design's SVG export takes one option, scope (\(names)), not \(other).")
        }
        guard let value = keys["scope"] else { return .frame }
        guard case .string(let name) = value, let scope = DesignExportScope(rawValue: name) else {
            throw CatalogError.failed(id: "export", message: "The scope is one of \(names).")
        }
        return scope
    }

    /// The file's name, its pages with their layer counts, and the selected page and layers.
    public func summary() -> JSONValue {
        func count(_ nodes: [DesignNode]) -> Int { nodes.reduce(nodes.count) { $0 + count($1.children) } }
        let pages = workspace.pages.map { JSONValue.object(["id": .string($0.id), "name": .string($0.name), "layers": .number(Double(count($0.nodes)))]) }
        return .object(["app": .string(Self.app), "name": .string(name), "pages": .array(pages),
                        "selectedPage": workspace.selectedPageID.map(JSONValue.string) ?? .null,
                        "selection": .array(workspace.selectedNodeIDs.map(JSONValue.string))])
    }
}

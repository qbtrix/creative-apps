// DesignHeadless.swift (adopt-command-catalog AC-d2): Design's document with no
// window, for the afterglow CLI, MCP and the real jobs. It is the workspace on its live services: `open` and `save`
// go through the file codec (DesignFile), every command through Design's catalog (DesignCommandCatalog), and SVG
// export writes every visible top-level frame of every page through the export plan and its SVG (DesignExport+Kernel),
// names unique across the file. PNG waits on a Linux PNG writer (the App rasterizes it today). Linux-safe.
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

    /// `svg`: one file per visible top-level frame of every page, in page order, each named after its frame and unique
    /// across the file. A file with no frame to export throws `failed`; `png` is not built on Linux yet. `options` are the
    /// suite's (`SuiteExportOptions(json:)`); SVG writes each frame at its own size, so any size but 1x is refused.
    public func export(_ format: String, options: JSONValue) throws -> [ExportedFile] {
        guard format == "svg" else {
            if format == "png" { throw CatalogError.notBuilt(id: "export.png", feature: "a Linux PNG writer for Design's raster path") }
            throw CatalogError.failed(id: "export", message: "Design exports \(Self.exportFormats.joined(separator: ", ")), not \(format).")
        }
        let asked = try SuiteExportOptions(json: options, defaults: SuiteExportOptions(format: format))
        guard asked.size == .scale(1) else {
            throw ExportOptionRefusal.invalid("SVG writes each frame at its own size, so it takes no size. Leave size out.")
        }
        var files: [ExportedFile] = [], taken = Set<String>()
        for page in workspace.pages {
            var onPage = workspace
            onPage.selectPage(page.id)
            let items: [DesignExportItem]
            do throws(DesignRefusal) { items = try onPage.exportPlan(DesignExportOptions(format: .svg, scope: .frame), existing: taken) }
            catch .nothingToExport { continue }
            catch { throw CatalogError.failed(id: "export", message: error.help) }
            for item in items {
                let svg: String
                do throws(DesignRefusal) { svg = try onPage.exportSVG(item) } catch { throw CatalogError.failed(id: "export", message: error.help) }
                files.append(ExportedFile(suggestedName: item.fileName, format: format, data: Data(svg.utf8)))
                taken.insert(item.fileName)
            }
        }
        guard !files.isEmpty else { throw CatalogError.failed(id: "export", message: DesignRefusal.nothingToExport.help) }
        return files
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

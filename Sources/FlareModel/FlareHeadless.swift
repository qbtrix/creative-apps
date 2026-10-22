// FlareHeadless.swift (adopt-command-catalog AC-f3): Flare's document with no window, for the afterglow CLI, MCP and
// the real jobs. It opens and saves Flare's own file (.flare) through FlareFormat, makes a one-scene document, runs
// `FlareWorkspace.catalog` lifted onto itself, and exports a scene as SVG frames or Lottie through FlareCore's
// exporters, on a copy without text as the window's export does. PNG frames need a rasterizer only macOS has, so
// they are refused here. Linux-safe: no UI imports.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
import SuiteKernel

/// Flare's headless document: one `FlareWorkspace` on the built services.
public struct FlareHeadless: HeadlessDocument {
    public static let app = "flare", openExtensions = ["flare"], exportFormats = ["svg", "lottie"]
    /// Why the window's file commands refuse here: the CLI opens, saves and exports instead.
    public static let fileCommandHelp = "The CLI opens, saves and exports the file."
    /// Why PNG frames refuse here.
    public static let pngHelp = "PNG frames need the window's rasterizer on macOS; export svg or lottie here."
    /// Every `FlareWorkspace.catalog` command, run on the wrapped workspace; file commands are unavailable.
    public static let catalog: CommandCatalog<FlareHeadless> =
        (try? CommandCatalog(app: app, FlareWorkspace.commands.map(lifted), history: { FlareCoreHistory($0.workspace) }))
        ?? .empty(app: app)

    /// The animation the commands edit.
    public private(set) var workspace: FlareWorkspace

    /// A headless document holding `workspace`.
    public init(workspace: FlareWorkspace) { self.workspace = workspace }

    /// The Flare file `data`, named `name`; its title is the name without ".flare".
    public static func open(_ data: Data, name: String) throws -> FlareHeadless {
        guard name.lowercased().hasSuffix(".flare") else {
            throw CatalogError.unavailable(id: "open", why: "Flare opens .flare files.")
        }
        var workspace = FlareWorkspace(services: .built)
        do { try workspace.open(data, named: name) } catch { throw CatalogError.failed(id: "open", message: error.message) }
        return FlareHeadless(workspace: workspace)
    }

    /// One scene "scene-1": the Web preset (550 x 400, 24 fps, 48 frames) with any of `width`, `height`, `fps` and
    /// `durationFrames` given instead.
    public static func new(_ options: JSONValue) throws -> FlareHeadless {
        let o = try options.decode(NewOptions.self)
        var spec = NewDocumentSpec(preset: .web)
        spec.setSize(width: o.width ?? spec.width, height: o.height ?? spec.height)
        (spec.fps, spec.durationFrames) = (o.fps.map(FrameRate.init(whole:)) ?? spec.fps, o.durationFrames ?? spec.durationFrames)
        if let problem = spec.problem { throw CatalogError.failed(id: "new", message: problem) }
        var workspace = FlareWorkspace(services: .built)
        workspace.newDocument(spec)
        return FlareHeadless(workspace: workspace)
    }

    /// The .flare file's bytes, as the window's Save writes them.
    public func save() throws -> Data {
        guard let document = workspace.document else { throw CatalogError.failed(id: "save", message: "No animation is open.") }
        do { return try FlareFormat.encode(document) } catch { throw CatalogError.failed(id: "save", message: "\(error)") }
    }

    /// `scene` (the selected one when absent) as "svg", one file per frame in `frames` (the current frame when
    /// absent), or as one "lottie" file. "png" is refused: it needs the macOS rasterizer.
    public func export(_ format: String, options: JSONValue) throws -> [ExportedFile] {
        if format == "png" { throw CatalogError.unavailable(id: "export", why: Self.pngHelp) }
        guard Self.exportFormats.contains(format) else { throw CatalogError.unavailable(id: "export", why: "Flare exports svg and lottie.") }
        let o = options == .null ? ExportOptions() : try options.decode(ExportOptions.self)
        guard let document = workspace.document else { throw CatalogError.failed(id: "export", message: "No animation is open.") }
        let clean = ExportScan.withoutText(document), id = o.scene ?? workspace.selectedSceneID
        guard let scene = clean.scenes.first(where: { $0.id == id }) else {
            throw CatalogError.failed(id: "export", message: "No scene called \(id ?? "nothing").")
        }
        do {
            guard format == "svg" else {
                return [ExportedFile(suggestedName: "\(scene.id).json", format: format,
                                     data: try LottieExporter.export(scene: scene, symbols: clean.symbols))]
            }
            return try (o.frames ?? [workspace.currentFrame]).map { frame in
                guard (0..<scene.durationFrames).contains(frame) else {
                    throw CatalogError.failed(id: "export", message: "Frame \(frame) is outside 0 to \(scene.durationFrames - 1).")
                }
                let svg = try SVGExporter.export(scene: scene, frame: Double(frame), symbols: clean.symbols)
                return ExportedFile(suggestedName: "\(scene.id)-\(frame).svg", format: format, data: Data(svg.utf8))
            }
        } catch let error as CatalogError { throw error } catch {
            throw CatalogError.failed(id: "export", message: "\(error)")
        }
    }

    /// The file's name, each scene's size, rate, length and layer count, the selected scene and the current frame.
    public func summary() -> JSONValue {
        let scenes = workspace.scenes.map { s -> JSONValue in
            .object(["id": .string(s.id), "name": .string(s.name), "width": .number(s.width), "height": .number(s.height),
                     "fps": .number(Double(s.fps)), "frames": .number(Double(s.durationFrames)), "layers": .number(Double(s.layers.count))])
        }
        return .object([
            "app": .string(Self.app), "name": workspace.fileName.map(JSONValue.string) ?? .null, "scenes": .array(scenes),
            "selectedScene": workspace.selectedSceneID.map(JSONValue.string) ?? .null,
            "currentFrame": .number(Double(workspace.currentFrame)),
        ])
    }

    /// `spec` over the wrapped workspace: the same id, words, schema and availability, run through FlareWorkspace's
    /// catalog. File commands are unavailable: the CLI's open, save and export do their work.
    static func lifted(_ spec: CommandSpec<FlareWorkspace>) -> CommandSpec<FlareHeadless> {
        let id = spec.id, windowOnly = spec.kind == .file
        return .typed(id, title: spec.title, summary: spec.summary, kind: spec.kind, params: JSONValue.self,
                      schema: spec.params, result: spec.result, example: spec.example,
                      availability: { windowOnly ? .unavailable(fileCommandHelp) : spec.availability($0.workspace) }) { h, json in
            try FlareWorkspace.catalog.run(id, params: json, on: &h.workspace).result
        }
    }

    struct NewOptions: Decodable { var width, height: Double?; var fps, durationFrames: Int? }
    struct ExportOptions: Decodable { var scene: String?; var frames: [Int]? }
}

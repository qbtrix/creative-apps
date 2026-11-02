// FlareHeadless.swift (adopt-command-catalog AC-f3): Flare's document with no window, for the afterglow CLI, MCP and
// the real jobs. It opens and saves Flare's own file (.flare) through FlareFormat, opens a Lottie .json untitled, makes a one-scene document from file.new's params, runs
// `FlareWorkspace.catalog` lifted onto itself, and exports a scene as SVG frames (text included) or Lottie through
// FlareCore's exporters, or as PNG frames drawn by FlareRaster (masks, mattes and symbol animation included) through
// the `pngEncoder` the host hands in. Lottie and PNG can't hold text, so a scene with text refuses them unless
// `dropText` asks to export the rest: never a silent drop. Options failing `exportSchema` are malformed params,
// so the CLI exits 65 with the issues. Linux-safe: no UI imports.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
import SuiteKernel
import SuiteModel

/// Flare's headless document: one `FlareWorkspace` on the built services.
public struct FlareHeadless: HeadlessDocument {
    public static let app = "flare", openExtensions = ["flare", "json"], exportFormats = ["svg", "lottie", "png"]
    /// Why the window's file commands refuse here: the CLI opens, saves and exports instead.
    public static let fileCommandHelp = "The CLI opens, saves and exports the file."
    /// Why PNG frames refuse when no encoder was handed in.
    public static let pngHelp = "PNG frames need a PNG encoder; this host has none, so export svg or lottie here."
    /// Every `FlareWorkspace.catalog` command, run on the wrapped workspace; file commands are unavailable.
    public static let catalog: CommandCatalog<FlareHeadless> =
        (try? CommandCatalog(app: app, FlareWorkspace.commands.map(lifted), history: { FlareCoreHistory($0.workspace) }))
        ?? .empty(app: app)

    /// The animation the commands edit.
    public private(set) var workspace: FlareWorkspace

    /// Turns a drawn frame into PNG bytes; nil refuses "png". The CLI hands in CoreRaster's encoder.
    public var pngEncoder: (@Sendable (MediaFrame) throws -> Data)?

    /// A headless document holding `workspace`.
    public init(workspace: FlareWorkspace, pngEncoder: (@Sendable (MediaFrame) throws -> Data)? = nil) {
        self.workspace = workspace; self.pngEncoder = pngEncoder
    }

    /// The Flare file `data`, named `name`; its title is the name without ".flare". A Lottie `.json` opens through
    /// FlareLottieOpen as an untitled document, so a save writes a .flare, never the JSON.
    public static func open(_ data: Data, name: String) throws -> FlareHeadless {
        let lower = name.lowercased()
        var workspace = FlareWorkspace(services: .built)
        if FlareLottieOpen.fileExtensions.contains(where: { lower.hasSuffix(".\($0)") }) {
            do { _ = try workspace.openLottie(data, named: name) } catch { throw CatalogError.failed(id: "open", message: error.message) }
            return FlareHeadless(workspace: workspace)
        }
        guard lower.hasSuffix(".flare") else {
            throw CatalogError.unavailable(id: "open", why: "Flare opens .flare files and Lottie .json files.")
        }
        do { try workspace.open(data, named: name) } catch { throw CatalogError.failed(id: "open", message: error.message) }
        return FlareHeadless(workspace: workspace)
    }

    /// One scene "scene-1" from `file.new`'s params: the named `preset` (the Web preset, 550 x 400, 24 fps, 48
    /// frames, with none), then any `width`, `height`, `fps`, `durationFrames` and `background` given. An unknown
    /// preset or a bad background is refused, as the window's New refuses it.
    public static func new(_ options: JSONValue) throws -> FlareHeadless {
        let o = options == .null ? FlareWorkspace.NewParams() : try options.decode(FlareWorkspace.NewParams.self)
        let spec = try FlareWorkspace.newSpec(o, base: .web, id: "new")
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
    /// absent), as "png" frames the same way (`scale`, `transparent`), or as one "lottie" file. Lottie and PNG
    /// refuse text unless `dropText` is true; "png" refuses without a `pngEncoder`.
    public func export(_ format: String, options: JSONValue) throws -> [ExportedFile] {
        guard Self.exportFormats.contains(format) else { throw CatalogError.unavailable(id: "export", why: "Flare exports svg, lottie and png.") }
        if format == "png", pngEncoder == nil { throw CatalogError.unavailable(id: "export", why: Self.pngHelp) }
        if options != .null {
            let issues = Self.exportSchema.validate(options)
            guard issues.isEmpty else { throw CatalogError.malformedParams(id: "export", issues) }
        }
        let o = options == .null ? ExportOptions() : try options.decode(ExportOptions.self)
        guard let document = workspace.document else { throw CatalogError.failed(id: "export", message: "No animation is open.") }
        let id = o.scene ?? workspace.selectedSceneID
        guard let scene = document.scenes.first(where: { $0.id == id }) else {
            throw CatalogError.failed(id: "export", message: "No scene called \(id ?? "nothing").")
        }
        let texts = format == "svg" ? 0 : ExportScan.textLayers(in: document, sceneID: scene.id)
        if texts > 0, o.dropText != true { throw CatalogError.failed(id: "export", message: Self.textHelp(format, texts)) }
        do {
            if format == "png", let pngEncoder {
                let raster = FlareRaster(encode: pngEncoder), stage = LiveStage()
                return try frames(o, scene).map { frame in
                    let list = stage.drawList(document, sceneID: scene.id, frame: frame, editing: nil)
                    let data = try raster.png(list, scale: o.scale ?? 1, transparent: o.transparent ?? false)
                    return ExportedFile(suggestedName: "\(scene.id)-\(frame).png", format: format, data: data)
                }
            }
            guard format == "svg" else {
                let clean = ExportScan.withoutText(document)
                let lottieScene = clean.scenes.first { $0.id == scene.id } ?? scene
                return [ExportedFile(suggestedName: "\(scene.id).json", format: format,
                                     data: try LottieExporter.export(scene: lottieScene, symbols: clean.symbols))]
            }
            return try frames(o, scene).map { frame in
                let svg = try SVGExporter.export(scene: scene, frame: Double(frame), symbols: document.symbols)
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

    /// Why a Lottie or PNG export with text refuses: neither can hold it yet, and a silent drop loses work.
    static func textHelp(_ format: String, _ layers: Int) -> String {
        let what = format == "png" ? "PNG frames can't draw" : "Lottie can't hold"
        return "\(what) text yet (\(layers) layer\(layers == 1 ? "" : "s")): export svg, or pass \"dropText\": true to export the rest."
    }

    /// `frames` (the current frame when absent), each checked against the scene's length.
    private func frames(_ o: ExportOptions, _ scene: FlareScene) throws -> [Int] {
        let asked = o.frames ?? [workspace.currentFrame]
        if let frame = asked.first(where: { !(0..<scene.durationFrames).contains($0) }) {
            throw CatalogError.failed(id: "export", message: "Frame \(frame) is outside 0 to \(scene.durationFrames - 1).")
        }
        return asked
    }

    struct ExportOptions: Decodable {
        var scene: String?; var frames: [Int]?; var dropText: Bool?; var scale: Double?; var transparent: Bool?
    }
    /// `ExportOptions`' keys, all optional; any other key or a wrong type fails it, so the CLI exits 65 with the
    /// issues (docs/cli.md) and writes nothing.
    static let exportSchema = ParamSchema.object([
        "scene": .optional(.string("The scene id; the selected scene when absent.")),
        "frames": .optional(.array(of: .integer(minimum: 0))),
        "dropText": .optional(.boolean),
        "scale": .optional(.number("PNG frames' scale of the scene's size.")),
        "transparent": .optional(.boolean),
    ], required: [])
}

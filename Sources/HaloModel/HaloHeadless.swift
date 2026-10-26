// HaloHeadless.swift (adopt-command-catalog AC-h2): Halo's document with no window, for the afterglow CLI, MCP and
// the real jobs. It opens and saves .halo files, runs `HaloProject.catalog` lifted onto itself, and renders one frame
// of the selected composition for a PNG export; movies stay on macOS through shell-media. Linux-safe: no UI imports,
// so `.live` has no text rasterizer: a host that can reach Core Text passes its services to `open`/`new(services:)`.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import SuiteKernel

/// Halo's headless document: one `HaloProject` on the live services, or on the caller's (`open(_:name:services:)`,
/// `new(_:services:)`): HaloModel can't reach Core Text, so a host that can passes its text rasterizer in.
public struct HaloHeadless: HeadlessDocument {
    public static let app = "halo", openExtensions = ["halo"], exportFormats = ["png"]
    /// Why the window's file and render commands refuse here: the CLI opens, saves and exports instead.
    public static let fileCommandHelp = "The CLI opens, saves and exports the file; movies render on macOS."
    /// Every `HaloProject.catalog` command, run on the wrapped project; file commands are unavailable.
    public static let catalog: CommandCatalog<HaloHeadless> =
        (try? CommandCatalog(app: app, HaloProject.commandSpecs.map(lifted), history: { HaloCatalogSteps(project: $0.workspace) }))
        ?? .empty(app: app)

    /// The project the commands edit.
    public private(set) var workspace: HaloProject

    /// A headless document holding `workspace`.
    public init(workspace: HaloProject) { self.workspace = workspace }

    /// The .halo file `data`, named `name`; throws `HaloFileError` for a file Halo can't read.
    public static func open(_ data: Data, name: String) throws -> HaloHeadless {
        try open(data, name: name, services: .live)
    }

    /// `open(_:name:)` on `services`.
    public static func open(_ data: Data, name: String, services: HaloServices) throws -> HaloHeadless {
        var project = HaloProject(services: services)
        let state = try project.services.files.decode(data)
        project.beginOpen(name: name, path: name)
        project.finishOpen(.success(state))
        return HaloHeadless(workspace: project)
    }

    /// A project with one composition: `name`, `width`, `height`, `fps` and `seconds`, each optional.
    public static func new(_ options: JSONValue) throws -> HaloHeadless {
        try new(options, services: .live)
    }

    /// `new(_:)` on `services`.
    public static func new(_ options: JSONValue, services: HaloServices) throws -> HaloHeadless {
        let o = try options.decode(NewOptions.self)
        var project = HaloProject(services: services)
        let settings = o.settings(over: project.suggestedSettings)
        guard project.newComposition(settings) else {
            throw CatalogError.failed(id: "new", message: settings.problems.joined(separator: " "))
        }
        return HaloHeadless(workspace: HaloProject(services: services, document: project.document))
    }

    /// The .halo file's bytes, as the window's Save writes them.
    public func save() throws -> Data { try workspace.fileData() }

    /// "png": one frame of the selected composition (`renderFrame`'s options) as `<composition>-<frame>.png`.
    public func export(_ format: String, options: JSONValue) throws -> [ExportedFile] {
        guard format == "png" else {
            throw CatalogError.unavailable(id: "export", why: "Halo exports png here; movies render on macOS.")
        }
        let rendered = try renderFrame(options)
        let name = "\(workspace.selectedComposition?.name ?? "frame")-\(rendered.frame).png"
        return [ExportedFile(suggestedName: name, format: format, data: try Self.png(rendered))]
    }

    /// `frame` as a PNG: CoreRaster's `PNG.write` bytes, 8-bit sRGB RGBA with straight alpha. The CLI's export and
    /// the render's PNG sequence both write it, so a file and the viewer agree.
    public static func png(_ frame: HaloRenderedFrame) throws -> Data {
        try PNG.write(frame.pixels, bitsPerChannel: 8)
    }

    /// The selected composition at `frame` (the playhead when absent) at 1/`scale` size (1 when absent), drawn as
    /// the viewer draws it. Throws `unavailable` with no composition, `failed` for a size CoreRaster refuses.
    public func renderFrame(_ options: JSONValue) throws -> HaloRenderedFrame {
        let o = try options.decode(RenderOptions.self)
        guard let comp = workspace.selectedComposition else {
            throw CatalogError.unavailable(id: "export", why: "Select a composition to render.")
        }
        let frame = min(max(o.frame ?? comp.playheadFrame, 0), max(comp.durationFrames - 1, 0))
        guard let rendered = comp.renderFrame(at: frame, scale: o.scale ?? 1, text: workspace.services.text) else {
            throw CatalogError.failed(id: "export", message: "Frame \(frame) can't be rendered at that scale.")
        }
        return rendered
    }

    /// The file's name, its compositions, the selection and the playhead.
    public func summary() -> JSONValue {
        let comps = workspace.compositions.map { c -> JSONValue in
            .object(["id": .string(c.id), "name": .string(c.name), "width": .number(Double(c.width)),
                     "height": .number(Double(c.height)), "fps": .number(Double(c.framesPerSecond)),
                     "frames": .number(Double(c.durationFrames)), "layers": .number(Double(c.layers.count))])
        }
        return .object([
            "app": .string(Self.app), "name": workspace.file.name.map(JSONValue.string) ?? .null, "compositions": .array(comps),
            "selectedComposition": workspace.selectedCompositionID.map(JSONValue.string) ?? .null,
            "selectedLayer": workspace.selectedLayerID.map(JSONValue.string) ?? .null,
            "playhead": workspace.selectedComposition.map { .number(Double($0.playheadFrame)) } ?? .null,
        ])
    }

    /// `spec` over the wrapped project: the same id, words, schema and availability, run through HaloProject's catalog.
    /// File commands and render.start are unavailable: the CLI's open, save and export do their work.
    static func lifted(_ spec: CommandSpec<HaloProject>) -> CommandSpec<HaloHeadless> {
        let id = spec.id
        let windowOnly = spec.kind == .file
        return .typed(id, title: spec.title, summary: spec.summary, kind: spec.kind, params: JSONValue.self,
                      schema: spec.params, result: spec.result, example: spec.example,
                      availability: { windowOnly ? .unavailable(fileCommandHelp) : spec.availability($0.workspace) }) { h, json in
            try HaloProject.catalog.run(id, params: json, on: &h.workspace).result
        }
    }

    /// `new`'s options and New Composition's sheet values; each one given replaces the suggested setting.
    struct NewOptions: Decodable, Sendable {
        var name: String?; var width, height, fps: Int?; var seconds: Double?
        func settings(over base: CompositionSettings) -> CompositionSettings {
            CompositionSettings(name: name ?? base.name, width: width ?? base.width, height: height ?? base.height,
                                framesPerSecond: fps ?? base.framesPerSecond, durationSeconds: seconds ?? base.durationSeconds)
        }
    }
    struct RenderOptions: Decodable { var frame, scale: Int? }
}

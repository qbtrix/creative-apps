// FlarePasteboardAdapter.swift (clipboard-interop CB-8): what Flare's Copy, Cut and Paste put on and take from the
// suite pasteboard, through SuiteModel's coder. Copy offers Flare's own layers (Edit > Copy's bytes), the SVG frame
// at the playhead and a PNG of the scene at the playhead at 1x, cropped to the selection, richest first. Paste takes
// the coder's best item for Flare: own layers paste as Edit > Paste does; an SVG or an image goes to the kernel's
// `place.image` (svg-place's place path), which places vectors and refuses pixels in its own words. The app's bridge
// carries the `TypedData` to and from the system pasteboard. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
import SuiteKernel
import SuiteModel

public struct FlarePasteboardAdapter: Sendable {
    /// What draws the PNG: the window's `StageRasterizer` on macOS, a fake in previews and tests.
    public var rasterizer: any FrameRasterizing
    let coder = SuitePasteboardCoding()

    public init(rasterizer: any FrameRasterizing) { self.rasterizer = rasterizer }

    /// Edit > Copy as the pasteboard's representations, richest first; empty with the reason in `layerError`.
    public func copy(_ workspace: inout FlareWorkspace) -> [TypedData] {
        let pictures = self.pictures(workspace)
        guard let own = workspace.copy() else { return [] }
        return representations(own, pictures)
    }

    /// Edit > Cut: the same representations, drawn before the layers go; empty when nothing was cut.
    public func cut(_ workspace: inout FlareWorkspace) -> [TypedData] {
        let pictures = self.pictures(workspace)
        guard let own = workspace.cut() else { return [] }
        return representations(own, pictures)
    }

    /// Edit > Paste of what the pasteboard offers: the coder's best item for Flare, or its refusal.
    public func paste(_ offered: [TypedData], into workspace: inout FlareWorkspace) {
        if let refusal = coder.pasteRefusal(for: offered, in: .flare) { return workspace.refuse(.refused(refusal.message)) }
        guard let item = coder.bestItem(from: offered, for: .flare) else { return }
        paste(item, into: &workspace)
    }

    /// Pastes one item: own layers as Edit > Paste, vector art and pictures through `place.image`.
    public func paste(_ item: SuiteClipItem, into workspace: inout FlareWorkspace) {
        switch item {
        case .appLayers(let type, let data) where type == .flareLayers: workspace.paste(data)
        case .vector(let svg, let name): place(name: name + ".svg", data: Data(svg.utf8), into: &workspace)
        case .image(let png, _, _): place(name: "Pasted image.png", data: png, into: &workspace)
        case .envelope(let envelope) where envelope.svg != nil:
            place(name: envelope.name + ".svg", data: Data((envelope.svg ?? "").utf8), into: &workspace)
        default: workspace.refuse(.refused(SuiteError.cannotPaste(app: .flare, kind: item.kindName).message))
        }
    }

    /// Why Paste can't run on `offered`, as Edit > Paste's tooltip; nil when it can.
    public func pasteHelp(_ offered: [TypedData], in workspace: FlareWorkspace) -> String? {
        if let refusal = coder.pasteRefusal(for: offered, in: .flare) { return refusal.message }
        switch coder.bestItem(from: offered, for: .flare) {
        case .appLayers(_, let data)?: return workspace.editHelp(.paste, pasteboard: data)
        default: return Self.placeCatalog.availability("place.image", on: workspace).why
        }
    }

    /// The SVG frame and the PNG at the playhead, drawn before a cut removes what they show.
    func pictures(_ workspace: FlareWorkspace) -> (svg: Data?, png: Data?) {
        guard workspace.editHelp(.copy) == nil, let document = workspace.document,
              let sceneID = workspace.selectedSceneID else { return (nil, nil) }
        let frame = workspace.currentFrame
        let clean = ExportScan.withoutText(document)
        let svg = clean.scenes.first { $0.id == sceneID }.flatMap { scene in
            (try? SVGExporter.export(scene: scene, frame: Double(frame), symbols: clean.symbols)).map { Data($0.utf8) }
        }
        let services = workspace.services, editing = workspace.editingSymbolID
        var list = services.stage.drawList(document, sceneID: sceneID, frame: frame, editing: editing)
        let picked = workspace.selection.isEmpty
            ? list.items.map(\.address).filter { workspace.editLayerIDs.contains($0.layerID) } : workspace.selection
        if let box = services.hits.bounds(document, sceneID: sceneID, frame: frame, editing: editing, of: picked),
           box.maxX > box.minX, box.maxY > box.minY {
            list = Self.cropped(list, to: box)
        }
        return (svg, try? rasterizer.png(list, scale: 1, transparent: true))
    }

    /// `list` moved so `box`'s corner is its origin, and sized to `box`.
    static func cropped(_ list: StageDrawList, to box: Rect) -> StageDrawList {
        var out = list
        let shift = Matrix.translation(x: -box.minX, y: -box.minY)
        out.items = list.items.map { item in var moved = item; moved.transform = shift * item.transform; return moved }
        out.width = box.maxX - box.minX
        out.height = box.maxY - box.minY
        return out
    }

    /// Own layers, then the SVG, then the PNG, as the coder writes each.
    func representations(_ own: Data, _ pictures: (svg: Data?, png: Data?)) -> [TypedData] {
        var items: [SuiteClipItem] = [.appLayers(.flareLayers, own)]
        if let svg = pictures.svg { items.append(.vector(svg: String(decoding: svg, as: UTF8.self), name: "Flare frame")) }
        if let png = pictures.png { items.append(.image(png: png, pixelWidth: 0, pixelHeight: 0)) }
        return items.flatMap(coder.representations(of:))
    }

    /// Runs `place.image` centred in the scene; a refusal goes to `layerError` in the place path's words.
    func place(name: String, data: Data, into workspace: inout FlareWorkspace) {
        let command = PlaceIntent.place(name: name, data: data, at: nil).command
        workspace.layerError = nil
        do throws(CatalogError) {
            _ = try Self.placeCatalog.run(command.id, params: command.params, on: &workspace)
        } catch {
            switch error {
            case .unavailable(_, let why): workspace.refuse(.refused(why))
            case .failed(_, let message): workspace.refuse(.refused(message))
            default: workspace.refuse(.refused(error.description))
            }
        }
    }

    /// The catalog `place.image` runs through until svg-place PF-6 registers the place specs in Flare's own.
    static let placeCatalog = (try? CommandCatalog<FlareWorkspace>(app: "flare", PlaceCommands.specs(FlareWorkspace.self),
                                                                    history: FlareCoreHistory.init)) ?? .empty(app: "flare")
}

/// Copy As and Paste as Image on the workspace, for the catalog and the CLI: no window, so no rasterizer, and PNG
/// refuses in FlareHeadless's words. The window's Edit menu copies through the adapter with the stage's rasterizer.
extension FlareWorkspace: CopyAsTarget {
    public var copyAsHelp: String? { editHelp(.copy) }

    public var pasteAsImageHelp: String? { FlarePasteboardAdapter.placeCatalog.availability("place.image", on: self).why }

    public func copyAs(_ format: CopyAsFormat) throws -> CopiedBytes {
        var workspace = self
        switch format {
        case .png: throw CatalogError.unavailable(id: "edit.copy-as", why: FlareHeadless.pngHelp)
        case .svg:
            let headless = FlarePasteboardAdapter(rasterizer: FakeRasterizer())
            guard let svg = headless.pictures(workspace).svg else { throw Self.copyAsRefusal(workspace.editHelp(.copy)) }
            return CopiedBytes(type: SuiteTypeID.svg.rawValue, data: svg)
        case .own:
            guard let own = workspace.copy() else { throw Self.copyAsRefusal(workspace.layerError?.message) }
            return CopiedBytes(type: SuiteTypeID.flareLayers.rawValue, data: own)
        }
    }

    public mutating func pasteAsImage(name: String, data: Data) throws {
        FlarePasteboardAdapter(rasterizer: FakeRasterizer()).place(name: name, data: data, into: &self)
        if let error = layerError { throw CatalogError.failed(id: "edit.paste-as-image", message: error.message) }
    }

    static func copyAsRefusal(_ why: String?) -> CatalogError {
        .unavailable(id: "edit.copy-as", why: why ?? "These layers could not be copied.")
    }
}

// HaloPasteboardAdapter.swift (clipboard-interop CB-10): Halo's side of the suite's pasteboard. Copy Frame draws
// the selected composition at the playhead at its full size (never the viewer's preview size) and writes it as PNG
// through core's 8-bit `PNG.write`, as HaloHeadless does; Paste takes the coder's best item for Halo, an image (PNG
// or JPEG) or an SVG, and adds it as a placed-image solid (HaloPlace+Kernel's `insertPlaced`) fitted and centred in
// the composition, its in point at the playhead, one undo step named "Paste". The app's PasteboardBridge carries the
// bytes; the catalog's `edit.copy-frame` and `edit.paste` run here too. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import SuiteKernel
import SuiteModel

/// Copy Frame and Paste for a Halo project, through the suite's pasteboard coder.
public struct HaloPasteboardAdapter: Sendable {
    let coder = SuitePasteboardCoding()

    public init() {}

    /// Why nothing can be copied: no composition is selected.
    static let noFrame = "Make or open a composition to copy its frame."
    /// Why a frame couldn't be drawn: a size the renderer refuses.
    static let cantDraw = "This frame can't be drawn at the composition's size."
    /// The undo step a paste makes: "Undo Paste".
    static let stepName = "Paste"

    /// The viewer's frame at the playhead as one PNG, at the composition's size; throws with no composition.
    public func copyFrame(_ project: HaloProject) throws -> [TypedData] {
        [TypedData(type: .png, data: try framePNG(project))]
    }

    /// The selected composition at its playhead drawn at 1x, as PNG bytes.
    func framePNG(_ project: HaloProject) throws -> Data {
        guard let comp = project.selectedComposition else {
            throw CatalogError.unavailable(id: "edit.copy-frame", why: Self.noFrame)
        }
        guard let frame = comp.renderFrame(at: comp.playheadFrame, scale: 1, text: project.services.text) else {
            throw CatalogError.failed(id: "edit.copy-frame", message: Self.cantDraw)
        }
        return try PNG.write(frame.pixels, bitsPerChannel: 8)
    }

    /// Nil when Paste can act on `offered`; else why not, in the coder's words ("Halo can't paste text yet.").
    public func pasteRefusal(for offered: [TypedData]) -> SuiteError? {
        if let refusal = coder.pasteRefusal(for: offered, in: .halo) { return refusal }
        guard let item = coder.bestItem(from: offered, for: .halo) else { return .nothingToPaste }
        return Self.placeable(item) ? nil : .cannotPaste(app: .halo, kind: item.kindName)
    }

    /// Pastes the best of `offered` into `project`; throws the refusal, changing nothing.
    public func paste(_ offered: [TypedData], into project: inout HaloProject) throws {
        if let refusal = pasteRefusal(for: offered) { throw CatalogError.unavailable(id: "edit.paste", why: refusal.message) }
        guard let item = coder.bestItem(from: offered, for: .halo) else { return }
        try paste(item, into: &project)
    }

    /// Adds `item` (an image or an SVG) as one placed-image layer at the playhead, selected, one step.
    public func paste(_ item: SuiteClipItem, into project: inout HaloProject) throws {
        switch item {
        case .image(let data, let width, let height):
            let size = width > 0 && height > 0 ? Size(width: Double(width), height: Double(height)) : nil
            try paste(data: data, name: "Pasted Image", natural: size, into: &project)
        case .vector(let svg, let name):
            try paste(data: Data(svg.utf8), name: name, natural: nil, into: &project)
        default:
            throw CatalogError.unavailable(id: "edit.paste", why: SuiteError.cannotPaste(app: .halo, kind: item.kindName).message)
        }
    }

    /// Places `data` (PNG, JPEG or SVG) fitted and centred in the composition, its in point at the playhead.
    /// `natural` is the picture's pixel size when the pasteboard gave it; else it is read from the bytes.
    public func paste(data: Data, name: String, natural: Size?, into project: inout HaloProject) throws {
        if let help = project.placeHelp { throw CatalogError.unavailable(id: "edit.paste", why: help) }
        guard data.count <= PlaceRules.maxBytes else { throw CatalogError.unavailable(id: "edit.paste", why: PlaceRules.sizeHelp) }
        guard let format = PlaceRules.format(of: data) else {
            throw CatalogError.unavailable(id: "edit.paste", why: PlaceRules.formatHelp)
        }
        let size = try natural ?? (format == .svg ? PlaceRules.vector(data, name: name).size : project.rasterSize(data, format: format))
        let asset = PlacedAsset(id: PlaceRules.assetID(of: data), name: name, format: format, natural: size, data: data)
        let box = PlaceRules.fitted(natural: size, in: project.placeCanvas, at: nil)
        let playhead = project.selectedComposition?.playheadFrame ?? 0
        let id = try project.insertPlaced(asset, PlacedImage(assetID: asset.id, box: box), name: Self.stepName)
        // The step just recorded keeps the state before the paste, so moving the new layer's in point here stays
        // inside that one step: undo removes the layer, redo brings it back at the playhead.
        for c in project.document.compositions.indices {
            for l in project.document.compositions[c].layers.indices where project.document.compositions[c].layers[l].id == id {
                project.document.compositions[c].layers[l].inFrame = playhead
            }
        }
    }

    /// Whether Halo places `item`: an image or an SVG.
    static func placeable(_ item: SuiteClipItem) -> Bool {
        switch item {
        case .image, .vector: true
        default: false
        }
    }
}

extension HaloProject {
    /// Edit > Paste: the best of `offered` placed at the playhead as one step; throws the refusal, changing nothing.
    public mutating func paste(_ offered: [TypedData]) throws { try HaloPasteboardAdapter().paste(offered, into: &self) }
}

extension HaloProject: CopyFrameTarget {
    /// Why Copy Frame can't run: no composition; nil when one is selected.
    public var copyFrameHelp: String? { selectedComposition == nil ? HaloPasteboardAdapter.noFrame : nil }

    /// The viewer's frame at the playhead as PNG, at the composition's size.
    public func copyFrame() throws -> Data { try HaloPasteboardAdapter().framePNG(self) }

    /// `edit.paste`: an image or SVG file's bytes, base64, placed as a layer at the playhead, one undo step.
    struct PasteParams: Codable, Sendable { var name, base64: String }
    /// `edit.paste`'s example: a 1 x 1 PNG.
    static let examplePNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="

    static let pasteSpecs: [CommandSpec<HaloProject>] = [
        .typed("edit.paste", title: "Paste", summary: "Pastes a PNG, JPEG or SVG as a placed image layer starting at the playhead.",
               kind: .edit, params: PasteParams.self,
               schema: .object(["name": .string("The file name, \"screenshot.png\".", maxLength: 255),
                                "base64": .string("The file's bytes, base64: PNG, JPEG or SVG.")], required: ["name", "base64"]),
               example: .object(["name": .string("pasted.png"), "base64": .string(Self.examplePNG)]),
               availability: { $0.placeHelp.map(Availability.unavailable) ?? .available }) { project, p -> JSONValue in
            guard let data = Data(base64Encoded: p.base64) else {
                throw CatalogError.failed(id: "edit.paste", message: "\(p.name) isn't base64.")
            }
            try HaloPasteboardAdapter().paste(data: data, name: p.name, natural: nil, into: &project)
            return .object([:])
        },
    ]
}

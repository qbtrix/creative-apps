// FlarePlace+Kernel.swift (svg-place PF-5): Flare's workspace is a kernel `PlacedImageTarget`, so the place
// commands in `PlaceCommands` bring an SVG into the edited scene the way the other apps place pictures. Flare draws
// no pixels, so it takes SVG only and `rasterSize` refuses. A place reads the SVG with FlareCore's `SVGImport`: each
// top-level group becomes a layer named after it, every shape mapped by one fit matrix (the kernel's
// `PlaceRules.fitted` box), all added by one `PlaceLayers` command, so one undo step and one document check (2,000
// `AddLayer`s each scanned every layer, qbtrix/creative-core#828). Flare keeps no picture after, so
// `placedSelection` is nil and the picture edits refuse. `placeSpecs` are the kernel's five place specs as Flare's
// catalog registers them: the format refusal in Flare's words, the picture edits unavailable. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
import SuiteKernel

extension FlareWorkspace: PlacedImageTarget {
    /// Why the picture edits (read, replace, reset size, move inside) can't run: a place leaves only layers.
    public static let placedBecomesLayers = "Flare places SVG art as layers you edit."

    /// The kernel's five place specs, run through `kernelPlace`, with every command but `place.image` unavailable
    /// and the kernel's format refusal said in Flare's words (`placeFormatHelp`).
    static var placeSpecs: [CommandSpec<FlareWorkspace>] {
        PlaceCommands.specs(FlareWorkspace.self).map { spec in
            let id = spec.id, places = id == "place.image"
            return .typed(id, title: spec.title, summary: places ? placeMenuSummary : spec.summary, kind: spec.kind,
                          params: JSONValue.self, schema: spec.params, result: spec.result, example: spec.example,
                          availability: { places ? spec.availability($0) : .unavailable(placedBecomesLayers) }) { w, json in
                do throws(CatalogError) { return try kernelPlace.run(id, params: json, on: &w).result } catch {
                    guard case .unavailable(_, let why) = error, why == PlaceRules.formatHelp(for: [.svg]) else { throw error }
                    throw CatalogError.unavailable(id: id, why: placeFormatHelp)
                }
            }
        }
    }

    /// The kernel's place specs as they are: what `placeSpecs` runs.
    static let kernelPlace = (try? CommandCatalog<FlareWorkspace>(
        app: "flare", PlaceCommands.specs(FlareWorkspace.self), history: FlareCoreHistory.init)) ?? .empty(app: "flare")

    /// Why nothing can be placed now: no animation or scene open; nil when one is.
    public var placeHelp: String? {
        document == nil || selectedScene == nil ? FlareLayerError.noDocument.message : nil
    }

    /// What a placed drawing fits inside: the edited scene's frame, or an empty rect with none open.
    public var placeCanvas: Rect {
        guard let scene = selectedScene else { return Rect(minX: 0, minY: 0, maxX: 0, maxY: 0) }
        return Rect(minX: 0, minY: 0, maxX: scene.width, maxY: scene.height)
    }

    /// Flare has no box a picture fills, so a fill always refuses.
    public var placeFillBox: Rect? { nil }

    /// SVG only: Flare draws vectors, not pixels.
    public var placeFormats: Set<PlacedFormat> { [.svg] }

    /// A placed SVG becomes plain layers, so no layer is ever a placed picture.
    public var placedSelection: (id: String, image: PlacedImage, asset: PlacedAsset)? { nil }

    /// Flare reads no raster files, so every format refuses.
    public func rasterSize(_ data: Data, format: PlacedFormat) throws -> Size {
        throw CatalogError.unavailable(id: "place.image", why: Self.placeFormatHelp)
    }

    /// Adds the SVG's top-level groups as layers above the selected layer (on top without one), each shape fitted
    /// into `image.box` by one matrix, as one undo step named `name`; selects and returns the first new layer.
    /// A file that doesn't read, or reads to nothing, adds nothing and records no step.
    public mutating func insertPlaced(_ asset: PlacedAsset, _ image: PlacedImage, name: String) throws -> String {
        if let help = placeHelp { throw CatalogError.unavailable(id: "place.image", why: help) }
        guard asset.format == .svg else { throw CatalogError.unavailable(id: "place.image", why: Self.placeFormatHelp) }
        guard let owner = propertyOwner, let ownerLayers else {
            throw CatalogError.unavailable(id: "place.image", why: FlareLayerError.noDocument.message)
        }
        let imported: (scene: FlareScene, report: FlareCore.ImportReport)
        do { imported = try SVGImport.scene(from: asset.data, name: asset.name) } catch {
            throw CatalogError.failed(id: "place.image", message: Self.readerReason(error))
        }
        guard !imported.scene.layers.isEmpty else {
            throw CatalogError.failed(id: "place.image", message: "The SVG has nothing Flare can draw.")
        }
        let fit = Self.fitMatrix(width: imported.scene.width, height: imported.scene.height, into: image.box)
        var taken = takenLayerNames
        // The search resumes past the last id it took, so a 2,000-path SVG names its layers in one pass.
        var n = 1
        let placed = imported.scene.layers.map { svgLayer -> Layer in
            var layer = Self.fitted(svgLayer, by: fit)
            while taken.contains("layer-\(n)") { n += 1 }
            layer.id = "layer-\(n)"
            taken.insert(layer.id)
            return layer
        }
        let below = ownerLayers.firstIndex { $0.id == selectedLayerID }
        layerError = nil
        applyGroup(name, selection: .layer(placed.first?.id)) { engine in
            try engine.perform(PlaceLayers(owner: owner, layers: placed, index: below.map { $0 + 1 }))
        }
        if let layerError { throw CatalogError.failed(id: "place.image", message: layerError.message) }
        placeReport = Self.placeSentence(asset.name, layers: placed.count, skipped: imported.report.skipped)
        return placed.first?.id ?? ""
    }

    /// Flare keeps no placed picture to edit, so this always refuses.
    public mutating func setPlaced(_ image: PlacedImage, asset: PlacedAsset?, name: String, drag: String?) throws {
        throw CatalogError.unavailable(id: "place", why: Self.placedBecomesLayers)
    }

    /// "Placed logo.svg: 2 layers." plus " Skipped filter (3)." when the reader skipped anything.
    static func placeSentence(_ file: String, layers: Int, skipped: [String]) -> String {
        let count = layers == 1 ? "1 layer" : "\(layers) layers"
        let skips = skipped.isEmpty ? "" : " Skipped \(skipped.joined(separator: ", "))."
        return "Placed \(file): \(count).\(skips)"
    }

    /// The reader's reason a file didn't import, as a sentence.
    static func readerReason(_ error: any Error) -> String {
        switch error as? ImportError {
        case .damaged(let why)?: "This SVG is damaged: \(why)."
        case .tooLarge(let why)?: "This SVG is too large: \(why)."
        case .unsupported(let why)?: "Flare can't read this SVG: \(why)."
        default: "This file isn't an SVG Flare can read."
        }
    }

    /// The matrix taking a `width` x `height` drawing onto `box`; a drawing with no area only moves.
    static func fitMatrix(width: Double, height: Double, into box: Rect) -> Matrix {
        guard width > 0, height > 0 else { return .translation(x: box.minX, y: box.minY) }
        return .translation(x: box.minX, y: box.minY) * .scale(x: box.width / width, y: box.height / height)
    }

    /// `layer` with every shape, text and mask mapped by `m`; lengths (strokes, dashes, type, feathers, radii)
    /// scale by its uniform scale.
    static func fitted(_ layer: Layer, by m: Matrix) -> Layer {
        let k = abs(m.determinant).squareRoot()
        var out = layer
        out.shapes = layer.shapes.map { shape in
            var s = shape
            s.points = shape.points.map(m.apply)
            s.path = shape.path?.transformed(by: m)
            s.fill = fitted(shape.fill, by: m, scale: k)
            s.stroke = shape.stroke.map { stroke in
                var st = stroke
                st.width *= k
                st.dash = stroke.dash.map { $0 * k }
                st.dashPhase *= k
                return st
            }
            return s
        }
        out.texts = layer.texts.map { text in
            var t = text
            t.position = m.apply(text.position)
            t.fontSize *= k
            t.fill = fitted(text.fill, by: m, scale: k)
            if var on = text.onPath { on.path = on.path.transformed(by: m); t.onPath = on }
            return t
        }
        out.masks = layer.masks.map { mask in
            var mk = mask
            mk.path = mask.path.transformed(by: m)
            mk.feather *= k
            return mk
        }
        return out
    }

    /// `fill` with a gradient's points mapped by `m` and its radius scaled by `k`.
    static func fitted(_ fill: Fill, by m: Matrix, scale k: Double) -> Fill {
        switch fill {
        case .solid: fill
        case .linear(let stops, let start, let end): .linear(stops: stops, start: m.apply(start), end: m.apply(end))
        case .radial(let stops, let center, let radius): .radial(stops: stops, center: m.apply(center), radius: radius * k)
        }
    }
}

/// Inserts `layers` into `owner`'s list at `index` (nil appends) as one command; undo puts back the list it replaced.
/// One command, so the engine checks the document once, not once per layer.
struct PlaceLayers: Command {
    static let id = "flare.place.layers"
    var label: String { "Add Layers" }
    let owner: LayerOwner
    let layers: [Layer]
    let index: Int?
    /// The owner's layers before `execute`, for `undo`; nil until it ran.
    private var replaced: [Layer]?
    private enum CodingKeys: String, CodingKey { case owner, layers, index }

    init(owner: LayerOwner, layers: [Layer], index: Int?) {
        self.owner = owner; self.layers = layers; self.index = index
    }

    mutating func execute(_ document: inout Document) throws {
        let old = try Self.list(owner, in: document)
        var ids = Set(old.map(\.id))
        for layer in layers where !ids.insert(layer.id).inserted { throw CommandError.duplicateID(layer.id) }
        var next = old
        next.insert(contentsOf: layers, at: min(max(index ?? old.count, 0), old.count))
        try Self.set(next, owner, in: &document)
        replaced = old
    }

    func undo(_ document: inout Document) throws {
        guard let replaced else { throw CommandError.notExecuted }
        try Self.set(replaced, owner, in: &document)
    }

    static func list(_ owner: LayerOwner, in document: Document) throws -> [Layer] {
        switch owner {
        case .scene(let id):
            guard let scene = document.scenes.first(where: { $0.id == id }) else { throw ModelError.sceneNotFound(id) }
            return scene.layers
        case .symbol(let id):
            guard let symbol = document.symbols.first(where: { $0.id == id }) else { throw ModelError.symbolNotFound(id) }
            return symbol.layers
        }
    }

    static func set(_ layers: [Layer], _ owner: LayerOwner, in document: inout Document) throws {
        switch owner {
        case .scene(let id):
            guard let i = document.scenes.firstIndex(where: { $0.id == id }) else { throw ModelError.sceneNotFound(id) }
            document.scenes[i].layers = layers
        case .symbol(let id):
            guard let i = document.symbols.firstIndex(where: { $0.id == id }) else { throw ModelError.symbolNotFound(id) }
            document.symbols[i].layers = layers
        }
    }
}

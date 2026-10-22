// FlarePlace+Kernel.swift (svg-place PF-1 conformance, PF-5 bodies): Flare's workspace is a kernel
// `PlacedImageTarget`, so the place commands in `PlaceCommands` bring an SVG into the edited scene the way the
// other apps place pictures. Flare draws no pixels, so it takes SVG only and `rasterSize` refuses. A place reads
// the SVG with FlareCore's `SVGImport`: each top-level group becomes a layer named after it, every shape mapped
// by one fit matrix (the kernel's `PlaceRules.fitted` box), all added in one apply group, so one undo step. Flare
// keeps no picture after, so `placedSelection` is nil and the picture edits refuse. `placeSpecs` are the kernel's
// place specs with the format refusal in Flare's words. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
import SuiteKernel

extension FlareWorkspace: PlacedImageTarget {
    /// Why a PNG or JPEG isn't placed, and why the picture edits (replace, reset size, move inside, fill) can't run.
    public static let placeFormatHelp = "Flare places SVG files.", placedBecomesLayers = "Flare places SVG art as layers you edit."

    /// The kernel's five place specs, run through their own catalog, with the kernel's format refusal said as
    /// Flare's (`placeFormatHelp`) and every command but `place.image` unavailable: a place leaves only layers.
    public static var placeSpecs: [CommandSpec<FlareWorkspace>] {
        PlaceCommands.specs(FlareWorkspace.self).map { spec in
            let id = spec.id, places = id == "place.image"
            return .typed(id, title: spec.title, summary: spec.summary, kind: spec.kind, params: JSONValue.self,
                          schema: spec.params, result: spec.result, example: spec.example,
                          availability: { places ? spec.availability($0) : .unavailable(placedBecomesLayers) }) { w, json in
                guard let kernel = kernelPlace else { throw CatalogError.notBuilt(id: id, feature: "svg-place PF-5") }
                do throws(CatalogError) { return try kernel.run(id, params: json, on: &w).result } catch {
                    throw placeRefusal(error)
                }
            }
        }
    }

    /// The kernel's place specs as they are: what `placeSpecs` runs.
    static let kernelPlace = try? CommandCatalog<FlareWorkspace>(
        app: "flare", PlaceCommands.specs(FlareWorkspace.self), history: FlareCoreHistory.init)

    /// `error` in Flare's words: the kernel's refusal of a file that isn't SVG names the one format Flare takes.
    static func placeRefusal(_ error: CatalogError) -> CatalogError {
        guard case .unavailable(let id, let why) = error, why == PlaceRules.formatHelp else { return error }
        return .unavailable(id: id, why: placeFormatHelp)
    }

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
        let imported: (scene: FlareScene, report: ImportReport)
        do { imported = try SVGImport.scene(from: asset.data, name: asset.name) } catch {
            throw CatalogError.failed(id: "place.image", message: Self.readerReason(error))
        }
        guard !imported.scene.layers.isEmpty else {
            throw CatalogError.failed(id: "place.image", message: "The SVG has nothing Flare can draw.")
        }
        let fit = Self.fitMatrix(width: imported.scene.width, height: imported.scene.height, into: image.box)
        var taken = takenLayerNames
        let placed = imported.scene.layers.map { svgLayer -> Layer in
            var layer = Self.fitted(svgLayer, by: fit)
            var n = 1
            while taken.contains("layer-\(n)") { n += 1 }
            layer.id = "layer-\(n)"
            taken.insert(layer.id)
            return layer
        }
        let below = ownerLayers.firstIndex { $0.id == selectedLayerID }
        applyGroup(name, selection: .layer(placed.first?.id)) { engine in
            for (k, layer) in placed.enumerated() {
                try engine.perform(AddLayer(owner: owner, layer: layer, index: below.map { $0 + 1 + k }))
            }
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

    /// The matrix taking a `width` × `height` drawing onto `box`; a drawing with no area only moves.
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

// HaloPlace+Kernel.swift: Halo's project as the kernel's PlacedImageTarget (placed-images PH-1 stubs,
// PH-6 bodies): a solid keeps a PNG, JPEG or SVG picture in its own box; other kinds take none, so
// `placeFillBox` is nil there. A place adds a solid above the selection; a fill, replace, reset or focus
// changes the selected solid. Each is one step through `edit`, and a focus drag's token is its coalesce key.
// Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteImaging
import SuiteKernel

extension HaloProject: PlacedImageTarget {
    /// Why nothing can be placed: no composition; why the selected layer can't hold a picture.
    static let noPlaceComposition = "Make or open a composition to place into.",
        cantReadImage = "Can't read this image.",
        noPlaceLayer = "Select a solid layer first.",
        textTakesNoPicture = "A text layer can't hold a picture.",
        nullTakesNoPicture = "A null layer has nothing to fill.",
        shapeTakesNoPicture = "Only a solid layer can hold a picture."

    /// Why nothing can be placed now: no composition; nil when one is selected.
    public var placeHelp: String? { selectedComposition == nil ? Self.noPlaceComposition : nil }

    /// Why the selected layer can't take a picture: no composition, no layer, or not a solid; nil on a solid.
    var placeFillHelp: String? {
        if let placeHelp { return placeHelp }
        switch selectedLayer?.kind {
        case .solid: return nil
        case .text: return Self.textTakesNoPicture
        case .null: return Self.nullTakesNoPicture
        case .shape: return Self.shapeTakesNoPicture
        case nil: return Self.noPlaceLayer
        }
    }

    /// What a new picture fits inside: the composition's frame, or an empty rect with none.
    public var placeCanvas: Rect {
        guard let comp = selectedComposition else { return Rect(minX: 0, minY: 0, maxX: 0, maxY: 0) }
        return Rect(minX: 0, minY: 0, maxX: Double(comp.width), maxY: Double(comp.height))
    }

    /// The selected solid's box, which a fill covers; nil for any other kind.
    public var placeFillBox: Rect? {
        guard let comp = selectedComposition, let layer = selectedLayer, layer.kind == .solid else { return nil }
        return layer.fillBox(in: comp)
    }

    /// Every format the kernel places: PNG and JPEG raster, SVG through its PlacedVector.
    public var placeFormats: Set<PlacedFormat> { Set(PlacedFormat.allCases) }

    /// The selected solid's picture in its box, with its focus; nil when it shows none.
    public var placedSelection: (id: String, image: PlacedImage, asset: PlacedAsset)? {
        guard let box = placeFillBox, let layer = selectedLayer, let asset = layer.placedAsset else { return nil }
        return (layer.id, PlacedImage(assetID: asset.id, box: box, focus: layer.placedFocus), asset)
    }

    /// A PNG's or JPEG's pixel size from its header; the kernel sizes SVG itself.
    public func rasterSize(_ data: Data, format: PlacedFormat) throws -> Size {
        guard format != .svg else { throw CatalogError.unavailable(id: "place.image", why: PlaceRules.formatHelp) }
        guard let size = SuiteImaging.rasterSize(of: data) else { throw CatalogError.unavailable(id: "place.image", why: Self.cantReadImage) }
        return size
    }

    /// Adds a solid showing `asset` in `image.box` on top of the selected layer (else on top of all), spanning the
    /// composition, named after the file without its extension, and selects it: one step named `name`. The
    /// picture draws in place of the solid's colour, so the solid is clear around it.
    public mutating func insertPlaced(_ asset: PlacedAsset, _ image: PlacedImage, name: String) throws -> String {
        if let placeHelp { throw CatalogError.unavailable(id: "place.image", why: placeHelp) }
        var id = ""
        let added = edit(name, control: "halo.place") { doc in
            guard let c = doc.compositions.firstIndex(where: { $0.id == doc.selectedCompositionID }) else {
                throw HaloEditError.noComposition
            }
            let comp = doc.compositions[c]
            var layer = HaloLayer(
                id: doc.takeLayerID(in: comp.id), name: Self.placedLayerName(asset.name), kind: .solid, inFrame: 0,
                outFrame: comp.durationFrames, color: HaloLayerKind.solid.defaultColor, rect: image.box.layerRect)
            layer.placedAsset = asset
            layer.placedFocus = image.focus
            doc.compositions[c].layers.insert(layer, at: comp.layers.firstIndex { $0.id == doc.selectedLayerID } ?? 0)
            doc.selectedLayerID = layer.id
            id = layer.id
        }
        if !added { throw CatalogError.failed(id: "place.image", message: refusal?.message ?? Self.noPlaceComposition) }
        return id
    }

    /// Puts `image` (and `asset`, when given) into the selected solid: its box, picture and focus, one step named
    /// `name`; steps under one `drag` token fold into one. A text, null or shape layer refuses, changing nothing.
    public mutating func setPlaced(_ image: PlacedImage, asset: PlacedAsset?, name: String, drag: String?) throws {
        if let help = placeFillHelp { throw CatalogError.unavailable(id: "place", why: help) }
        let box = placeFillBox
        let key = drag.flatMap { drag in selectedLayerID.map { CoalesceKey.key("place", on: [$0], drag: drag) } }
        let set = edit(name, control: "halo.place", coalesceKey: key) { doc in
            let (c, l) = try doc.selectedLayerIndices()
            if image.box != box { doc.compositions[c].layers[l].rect = image.box.layerRect }
            if let asset { doc.compositions[c].layers[l].placedAsset = asset }
            doc.compositions[c].layers[l].placedFocus = image.focus
        }
        if !set { throw CatalogError.failed(id: "place", message: refusal?.message ?? Self.noPlaceLayer) }
    }

    /// "logo.png" places as "logo"; a name with nothing before its extension places as "Placed Image".
    static func placedLayerName(_ file: String) -> String {
        let stem = file.lastIndex(of: ".").map { String(file[..<$0]) } ?? file
        return stem.isEmpty ? "Placed Image" : stem
    }
}

extension Rect {
    /// This box as a solid's rect in composition pixels.
    var layerRect: HaloLayerRect { HaloLayerRect(x: minX, y: minY, width: width, height: height) }
}

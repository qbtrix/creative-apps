// Placed.swift (placed-images PL-1): the values every app's picture is made of. A document embeds each
// file's bytes once as a `PlacedAsset`; a layer that has a box shows one through a `PlacedImage`; an SVG is
// drawn from its `PlacedVector`. No app declares its own picture model (contract rule 20).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore

/// A width and a height: pixels for a raster asset, user units for an SVG.
public struct Size: Codable, Hashable, Sendable {
    public var width, height: Double
    public init(width: Double, height: Double) { (self.width, self.height) = (width, height) }
}

/// The file kinds Place takes.
public enum PlacedFormat: String, Codable, CaseIterable, Sendable { case png, jpeg, svg }

/// The bytes one document embeds once, however many layers show them. `id` is `PlaceRules.assetID(of: data)`;
/// `natural` is pixels for PNG and JPEG, user units for SVG.
public struct PlacedAsset: Codable, Hashable, Sendable, Identifiable {
    public var id, name: String; public var format: PlacedFormat; public var natural: Size; public var data: Data
    public init(id: String, name: String, format: PlacedFormat, natural: Size, data: Data) {
        (self.id, self.name, self.format, self.natural, self.data) = (id, name, format, natural, data)
    }
}

/// What an app's layer with a picture stores. `box` is in the app's space; `focus` (unit, 0.5 centre) is
/// the point of the asset the cover crop keeps in view.
public struct PlacedImage: Codable, Hashable, Sendable {
    public var assetID: String; public var box: Rect; public var focus: Point
    public init(assetID: String, box: Rect, focus: Point = Point(x: 0.5, y: 0.5)) {
        (self.assetID, self.box, self.focus) = (assetID, box, focus)
    }
}

/// A document's assets: `adding` keeps one copy per id; `pruned(keeping:)` drops what no layer shows (on save).
public struct PlacedAssets: Codable, Hashable, Sendable {
    public private(set) var byID: [String: PlacedAsset]
    public init(_ assets: [PlacedAsset] = []) { byID = Dictionary(assets.map { ($0.id, $0) }) { first, _ in first } }
    /// These assets with `asset`; one already held under its id stays as it is.
    public func adding(_ asset: PlacedAsset) -> PlacedAssets { PlacedAssets(Array(byID.values) + [asset]) }
    /// Only the assets whose ids are in `ids`.
    public func pruned(keeping ids: Set<String>) -> PlacedAssets { PlacedAssets(byID.values.filter { ids.contains($0.id) }) }
}

/// An SVG flattened for drawing: its size, one item per painted shape in paint order (in the asset's units),
/// and what the import skipped (SVGImport's report).
public struct PlacedVector: Hashable, Sendable {
    /// Closed polygons filled even-odd; a nil fill, or a nil stroke colour or width 0, paints nothing.
    public struct Item: Hashable, Sendable {
        public var contours: [[Point]]; public var fill: Fill?; public var strokeColor: FillColor?
        public var strokeWidth, opacity: Double
        public init(contours: [[Point]], fill: Fill?, strokeColor: FillColor? = nil, strokeWidth: Double = 0, opacity: Double = 1) {
            (self.contours, self.fill, self.strokeColor, self.strokeWidth, self.opacity) = (contours, fill, strokeColor, strokeWidth, opacity)
        }
    }
    public var size: Size; public var items: [Item]; public var skipped: [String]
    public init(size: Size, items: [Item] = [], skipped: [String] = []) { (self.size, self.items, self.skipped) = (size, items, skipped) }
}

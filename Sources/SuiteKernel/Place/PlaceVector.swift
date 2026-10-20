// PlaceVector.swift (placed-images PL-1 stub, PL-6 body): an SVG flattened once into paint every vector draw
// takes, through FlareCore's `SVGImport` and `RenderList`, each path flattened at 0.25 asset units.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension PlaceRules {
    /// The SVG in `data` as polygons with their paint, in paint order; throws the import's reason.
    public static func vector(_ data: Data, name: String) throws -> PlacedVector { PlacedVector(size: Size(width: 0, height: 0)) }
}

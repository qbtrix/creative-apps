// PlaceVector.swift (placed-images PL-1 stub, PL-6 body): an SVG flattened once into paint every vector draw
// takes, through FlareCore's `SVGImport` and `RenderList`, each path flattened at 0.25 asset units;
// `svgScene` is the parse itself, kept for the last file read, so a place's size read and the target's own layers
// (Flare's `insertPlaced`) share one parse.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
import Synchronization

extension PlaceRules {
    /// How far a flattened polygon may stray from its curve, in asset units.
    static let flattenTolerance = 0.25

    /// The SVG's natural size (its viewBox, else width and height) from one parse, with no render list or
    /// flattening: what a place reads before the target makes its own layers or paint.
    public static func vectorSize(_ data: Data, name: String) throws -> Size {
        let (scene, _) = try svgScene(data, name: name)
        return Size(width: scene.width, height: scene.height)
    }

    // ponytail: one entry, the file a place is reading right now; a keyed cache if two places ever interleave.
    private static let lastScene = Mutex<(data: Data, name: String, scene: Scene, report: ImportReport)?>(nil)

    /// `SVGImport.scene(from:name:)`, parsed once for the last file it read: the size read before a place and the
    /// target's layers after it get the same scene from one parse. A file that throws is never kept.
    public static func svgScene(_ data: Data, name: String) throws -> (Scene, ImportReport) {
        if let hit = lastScene.withLock({ $0.flatMap { $0.name == name && $0.data == data ? ($0.scene, $0.report) : nil } }) {
            return hit
        }
        let (scene, report) = try SVGImport.scene(from: data, name: name)
        lastScene.withLock { $0 = (data, name, scene, report) }
        return (scene, report)
    }

    /// The SVG in `data` as polygons with their paint, in paint order; throws the import's reason.
    public static func vector(_ data: Data, name: String) throws -> PlacedVector {
        let (scene, report) = try SVGImport.scene(from: data, name: name)
        let list = scene.renderList(at: 0, symbols: [])
        var items: [PlacedVector.Item] = []
        var texts = 0
        for item in list.items {
            if item.isText { texts += 1; continue }
            let contours = try item.outline.transformed(by: item.matrix).flattened(tolerance: flattenTolerance)
                .filter { $0.count > 1 }
            guard !contours.isEmpty else { continue }
            let stroke = item.stroke.flatMap { $0.width > 0 && $0.color.a > 0 ? $0 : nil }
            items.append(PlacedVector.Item(contours: contours, fill: paint(item.fill, item.matrix),
                                           strokeColor: stroke?.color, strokeWidth: (stroke?.width ?? 0) * scale(item.matrix),
                                           opacity: item.opacity))
        }
        let masked = scene.layers.filter { !$0.masks.isEmpty }.count
        let skipped = report.skipped + (texts > 0 ? ["text (\(texts))"] : []) + (masked > 0 ? ["clip-path (\(masked))"] : [])
        return PlacedVector(size: Size(width: scene.width, height: scene.height), items: items, skipped: skipped)
    }

    /// `fill` in asset units: a gradient's points mapped by `m`; a clear solid (SVG `none`) paints nothing.
    static func paint(_ fill: Fill?, _ m: Matrix) -> Fill? {
        switch fill {
        case .solid(let color)?: color.a > 0 ? .solid(color) : nil
        case .linear(let stops, let start, let end)?: .linear(stops: stops, start: m.apply(start), end: m.apply(end))
        case .radial(let stops, let center, let radius)?: .radial(stops: stops, center: m.apply(center), radius: radius * scale(m))
        case nil: nil
        }
    }

    /// The uniform scale `m` applies to lengths (the square root of its area scale).
    static func scale(_ m: Matrix) -> Double { abs(m.determinant).squareRoot() }
}

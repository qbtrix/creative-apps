// Marquee.swift (EK-10): the one marquee rule every app shares: the rect two
// drag corners enclose, and how the items it finds join the selection.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The drag-to-select rectangle and its union rule.
public enum Marquee {
    /// The rect with `a` and `b` as opposite corners, in either order.
    public static func rect(enclosing a: Point, _ b: Point) -> Rect {
        Rect(minX: min(a.x, b.x), minY: min(a.y, b.y), maxX: max(a.x, b.x), maxY: max(a.y, b.y))
    }

    /// The selection after a marquee finds `found`: without Shift the found
    /// items replace `selection`; with it (`extending`) they join after it.
    /// Either way each id appears once, first occurrence kept.
    public static func union<ID: Hashable>(_ selection: [ID], _ found: [ID], extending: Bool) -> [ID] {
        var seen = Set<ID>()
        var result: [ID] = []
        for id in extending ? selection + found : found where seen.insert(id).inserted {
            result.append(id)
        }
        return result
    }
}

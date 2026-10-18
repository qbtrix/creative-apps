// HandleHit.swift (EK-3 shape, EK-20 body): which box handle is under the
// pointer. Document y grows downwards.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Handle hit testing for a selection box.
public enum HandleHit {
    /// The resize handle within `tolerance` (document points, Chebyshev) of `p` on `rect`,
    /// the nearest one, corners winning ties; `.inside` inside the box on no handle; nil outside.
    public static func handle(at p: Point, in rect: Rect, tolerance: Double) -> EditorHandle? {
        var best: (handle: EditorHandle, distance: Double)?
        for handle in order {
            guard let c = centre(of: handle, on: rect, knobGap: 0) else { continue }
            let distance = max(abs(p.x - c.x), abs(p.y - c.y))
            guard distance <= tolerance else { continue }
            if best.map({ distance < $0.distance }) ?? true { best = (handle, distance) }
        }
        if let best { return best.handle }
        let inside = (rect.minX...max(rect.minX, rect.maxX)).contains(p.x)
            && (rect.minY...max(rect.minY, rect.maxY)).contains(p.y)
        return inside ? .inside : nil
    }

    /// The document tolerance for a `screen`-point one at `zoom` (screen / zoom); `screen`
    /// for a zoom that is not a positive finite number.
    public static func tolerance(screen: Double, zoom: Double) -> Double {
        guard zoom > 0, zoom.isFinite else { return screen }
        return screen / zoom
    }

    /// The handles in the order a hit tries them: the corners first, so a corner wins a tie.
    static let order: [EditorHandle] = [.topLeft, .topRight, .bottomRight, .bottomLeft, .top, .right, .bottom, .left]

    /// Where `handle` shows on `rect`: a corner, an edge's middle, or for `.rotate` the top
    /// middle raised by `knobGap`; nil for `.inside`.
    static func centre(of handle: EditorHandle, on rect: Rect, knobGap: Double) -> Point? {
        let (midX, midY) = ((rect.minX + rect.maxX) / 2, (rect.minY + rect.maxY) / 2)
        switch handle {
        case .topLeft: return Point(x: rect.minX, y: rect.minY)
        case .top: return Point(x: midX, y: rect.minY)
        case .topRight: return Point(x: rect.maxX, y: rect.minY)
        case .right: return Point(x: rect.maxX, y: midY)
        case .bottomRight: return Point(x: rect.maxX, y: rect.maxY)
        case .bottom: return Point(x: midX, y: rect.maxY)
        case .bottomLeft: return Point(x: rect.minX, y: rect.maxY)
        case .left: return Point(x: rect.minX, y: midY)
        case .rotate: return Point(x: midX, y: rect.minY - knobGap)
        case .inside: return nil
        }
    }
}

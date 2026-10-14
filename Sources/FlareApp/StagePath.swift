// StagePath.swift: FlareCore paths and colors to CoreGraphics for the stage (docs/blueprints/flare/features/
// mac-platform.md, MP-4). Each FlareCore cubic becomes exactly one `addCurve`, each quad one `addQuadCurve`, each line
// one `addLine`; moves and closes are kept, so curves reach the screen as curves, never flattened. Every point goes
// through the given Matrix first. An element with a non-finite coordinate (after the transform) is skipped, never
// drawn and never a crash; a drawing element that then has no current point starts its subpath at its end point.
// Colors become `CGColor(srgbRed:green:blue:alpha:)`. No SwiftUI: the stage view calls these when it draws.
#if canImport(CoreGraphics)
import CoreGraphics
import FlareCore
import FlareModel

enum StagePath {
    /// `path` with every point mapped by `transform`, as a CGPath with one CG element per FlareCore element.
    static func cgPath(_ path: FlarePath, transform: Matrix) -> CGPath {
        let result = CGMutablePath()
        var hasCurrentPoint = false

        func point(_ p: FlareCore.Point) -> CGPoint? {
            let mapped = transform.apply(p)
            guard mapped.x.isFinite, mapped.y.isFinite else { return nil }
            return CGPoint(x: mapped.x, y: mapped.y)
        }

        /// Draws with `draw` when there is a current point; otherwise starts a subpath at `end`.
        func segment(to end: CGPoint, _ draw: () -> Void) {
            if hasCurrentPoint {
                draw()
            } else {
                result.move(to: end)
                hasCurrentPoint = true
            }
        }

        for element in path.elements {
            switch element {
            case .move(let to):
                guard let to = point(to) else { continue }
                result.move(to: to)
                hasCurrentPoint = true
            case .line(let to):
                guard let to = point(to) else { continue }
                segment(to: to) { result.addLine(to: to) }
            case .quad(let control, let to):
                guard let control = point(control), let to = point(to) else { continue }
                segment(to: to) { result.addQuadCurve(to: to, control: control) }
            case .cubic(let control1, let control2, let to):
                guard let control1 = point(control1), let control2 = point(control2), let to = point(to) else {
                    continue
                }
                segment(to: to) { result.addCurve(to: to, control1: control1, control2: control2) }
            case .close:
                guard hasCurrentPoint else { continue }
                result.closeSubpath()
            }
        }
        return result
    }

    /// `color`'s channels as an sRGB CGColor.
    static func cgColor(_ color: FlareColor) -> CGColor {
        CGColor(srgbRed: color.r, green: color.g, blue: color.b, alpha: color.a)
    }
}
#endif

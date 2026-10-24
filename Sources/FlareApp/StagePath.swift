// StagePath.swift: the stage's names for FlareCore paths and colors in CoreGraphics (docs/blueprints/flare/features/
// mac-platform.md, MP-4). Both forward to SuiteShell's VectorRasterizer, so the stage, its overlays and the PNG export
// draw one conversion: one CG element per FlareCore element, curves kept, an element with a non-finite point after
// the matrix skipped, and colors as `CGColor(srgbRed:green:blue:alpha:)`. No SwiftUI.
#if canImport(CoreGraphics)
import CoreGraphics
import FlareCore
import FlareModel
import SuiteShell

enum StagePath {
    /// `path` with every point mapped by `transform`, one CG element per FlareCore element (VectorRasterizer's).
    static func cgPath(_ path: FlarePath, transform: Matrix) -> CGPath {
        VectorRasterizer.cgPath(path, transform: transform)
    }

    /// `color`'s channels as an sRGB CGColor.
    static func cgColor(_ color: FlareColor) -> CGColor { VectorRasterizer.cgColor(color) }
}
#endif

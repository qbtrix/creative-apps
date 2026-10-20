// ShapeRules.swift (shape-tools SH-1 stubs, SH-5 bodies): a spec's path in a box, the box a drag draws, and why a spec can't be drawn.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore

/// Why a shape wasn't drawn: a spec its help refuses, or a rule not built yet.
public enum ShapeRefusal: Error, Hashable, Sendable, CustomStringConvertible {
    case invalid(String), notBuilt
    public var description: String { if case .invalid(let help) = self { help } else { "Shape tools are not built yet (shape-tools)." } }
}

public enum ShapeRules {
    /// The counts a polygon's sides and a star's points take, and the ratios a star's inner radius takes.
    public static let counts = 3...64, ratios = 0.1...1.0
    /// What a stub throws until SH-5 builds it.
    public static let notBuilt = ShapeRefusal.notBuilt

    /// The spec's path in `box` (document space). Throws `GeometryError` from PathBuilders, or `invalid(help)`.
    public static func path(_ spec: ShapeSpec, in box: Rect) throws -> Path { throw notBuilt }

    /// The box and line ends a drag draws (Shift squares it or snaps a line to 45°, Option grows it from the centre); nil if empty.
    public static func dragged(_ kind: ShapeKind, from: Point, to: Point, modifiers: EditModifiers) -> (box: Rect, spec: ShapeSpec)? { nil }

    /// Why `spec` can't be drawn ("A polygon needs 3 to 64 sides."), nil when it can.
    public static func help(_ spec: ShapeSpec) -> String? { nil }
}

// ShapeCommands.swift (shape-tools SH-1 specs with ids, schemas and
// availability, runs throwing `ShapeRules.notBuilt`; SH-6 bodies): the shape
// target an app adopts, the option changes the tool's panel sends, and the two
// commands, shape.draw (an edit, one undo step) and tool.shape (view state).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore

/// A document the shape tool draws on.
public protocol ShapeTarget: Sendable {
    /// Why nothing can be drawn now ("Open a document first."), nil when shapes can be drawn.
    var shapeHelp: String? { get }
    /// The shape tool's current options.
    var shapeTool: ShapeSpec { get }
    /// View state: picks the tool with these options.
    mutating func pickShapeTool(_ spec: ShapeSpec)
    /// Adds one shape layer from `spec` in `box`, selected, as one undo step named `name`; returns its id.
    mutating func addShape(_ spec: ShapeSpec, in box: Rect, name: String) throws -> String
}

/// One change the tool's options panel asks for.
public enum ShapeIntent: Hashable, Sendable {
    case kind(ShapeKind), sides(Int), points(Int), innerRatio(Double), cornerRadius(Double), head(Double)
    /// The options after the intent. Stub: the options unchanged until SH-6.
    public func applied(to spec: ShapeSpec) -> ShapeSpec { spec }
    /// tool.shape with the new options. Stub: no params until SH-6.
    public var command: (id: String, params: JSONValue) { ("tool.shape", .object([:])) }
}

/// The shape commands every adopter registers.
public enum ShapeCommands {
    /// shape.draw's params: the kind, the box, and any option or line end that differs from the defaults.
    struct Draw: Decodable, Sendable {
        var kind: ShapeKind, x: Double, y: Double, w: Double, h: Double
        var sides: Int?, points: Int?, innerRatio: Double?, cornerRadius: Double?, head: Double?
        var x1: Double?, y1: Double?, x2: Double?, y2: Double?
    }
    /// tool.shape's params: the kind and any option that differs from the defaults.
    struct Tool: Decodable, Sendable {
        var kind: ShapeKind
        var sides: Int?, points: Int?, innerRatio: Double?, cornerRadius: Double?, head: Double?
    }
    /// What shape.draw returns: the new layer's id.
    struct Drawn: Encodable { var id: String }

    /// The options both commands take.
    static let options: [String: ParamSchema] = [
        "kind": .string("The shape.", oneOf: ShapeKind.allCases.map(\.rawValue)),
        "sides": .optional(.integer("A polygon's sides.")), "points": .optional(.integer("A star's points.")),
        "innerRatio": .optional(.number("A star's inner radius over its outer one.")),
        "cornerRadius": .optional(.number("A rectangle's corner radius, points.")),
        "head": .optional(.number("An arrow's head length, points.")),
    ]
    /// shape.draw's params: the options, the box and the line's ends in unit space.
    static let drawSchema = ParamSchema.object(options.merging([
        "x": .number(), "y": .number(), "w": .number(minimum: 0), "h": .number(minimum: 0),
        "x1": .optional(.number()), "y1": .optional(.number()), "x2": .optional(.number()), "y2": .optional(.number()),
    ]) { old, _ in old }, required: ["kind", "x", "y", "w", "h"])

    /// shape.draw and tool.shape on `target`, both unavailable while it has `shapeHelp`.
    public static func specs<T: ShapeTarget>(_ target: T.Type) -> [CommandSpec<T>] {
        let open: @Sendable (T) -> Availability = { $0.shapeHelp.map(Availability.unavailable) ?? .available }
        return [
            .typed("shape.draw", title: "Draw Shape", summary: "Draws one shape of the given kind and options in a box, as one undo step.",
                   kind: .edit, params: Draw.self, schema: drawSchema, result: .object(["id": .string()], required: ["id"]),
                   example: .object(["kind": .string("star"), "x": .number(0), "y": .number(0), "w": .number(100), "h": .number(100)]),
                   availability: open) { (_: inout T, _: Draw) throws -> Drawn in throw ShapeRules.notBuilt },
            .typed("tool.shape", title: "Shape Tool", summary: "Picks the shape tool with the given kind and options.",
                   kind: .view, params: Tool.self, schema: .object(options, required: ["kind"]),
                   example: .object(["kind": .string("star"), "points": .number(5)]),
                   availability: open) { (_: inout T, _: Tool) throws -> JSONValue in throw ShapeRules.notBuilt },
        ]
    }
}

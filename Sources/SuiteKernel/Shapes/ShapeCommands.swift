// ShapeCommands.swift (shape-tools SH-1 specs whose runs throw `ShapeRules.notBuilt`, SH-6 bodies):
// the target an app adopts, the panel's option changes, and shape.draw and tool.shape.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore

/// A document the shape tool draws on: why it can't now ("Open a document first."), the tool's options,
/// picking them (view state), and adding one selected shape layer as one undo step named `name`.
public protocol ShapeTarget: Sendable {
    var shapeHelp: String? { get }
    var shapeTool: ShapeSpec { get }
    mutating func pickShapeTool(_ spec: ShapeSpec)
    mutating func addShape(_ spec: ShapeSpec, in box: Rect, name: String) throws -> String
}

/// One change the tool's options panel asks for.
public enum ShapeIntent: Hashable, Sendable {
    case kind(ShapeKind), sides(Int), points(Int), innerRatio(Double), cornerRadius(Double), head(Double)
    /// The options after the intent, and tool.shape with them. Stubs until SH-6: unchanged, no params.
    public func applied(to spec: ShapeSpec) -> ShapeSpec { spec }
    public var command: (id: String, params: JSONValue) { ("tool.shape", .object([:])) }
}

public enum ShapeCommands {
    /// tool.shape's params, and with the box and line ends (unit space) shape.draw's.
    struct Tool: Decodable, Sendable {
        var kind: ShapeKind, sides: Int?, points: Int?, innerRatio: Double?, cornerRadius: Double?, head: Double?
    }
    struct Draw: Decodable, Sendable {
        var kind: ShapeKind, x: Double, y: Double, w: Double, h: Double
        var sides: Int?, points: Int?, innerRatio: Double?, cornerRadius: Double?, head: Double?
        var x1: Double?, y1: Double?, x2: Double?, y2: Double?
    }
    struct Drawn: Encodable { var id: String }

    static let options: [String: ParamSchema] = [
        "kind": .string("The shape.", oneOf: ShapeKind.allCases.map(\.rawValue)),
        "sides": .optional(.integer("A polygon's sides.")), "points": .optional(.integer("A star's points.")),
        "innerRatio": .optional(.number("A star's inner radius over its outer one.")),
        "cornerRadius": .optional(.number("A rectangle's corner radius, points.")),
        "head": .optional(.number("An arrow's head length, points.")),
    ]
    static let drawSchema = ParamSchema.object(options.merging([
        "x": .number(), "y": .number(), "w": .number(minimum: 0), "h": .number(minimum: 0),
        "x1": .optional(.number()), "y1": .optional(.number()), "x2": .optional(.number()), "y2": .optional(.number()),
    ]) { old, _ in old }, required: ["kind", "x", "y", "w", "h"])

    /// shape.draw (an edit, one undo step) and tool.shape (view state), both unavailable while `shapeHelp` is set.
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

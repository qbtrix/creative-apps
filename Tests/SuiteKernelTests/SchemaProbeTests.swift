// SchemaProbeTests.swift (command-catalog CC-3, CJ1): SchemaProbe reads a params schema from a `Decodable`
// type's init: structs, optionals, arrays, nested types, the depth cap, a throwing enum init kept partial,
// and the `CommandSchemaProviding` override. CC-5 turned them on.
import Testing
import SuiteKernel

/// CJ1's params: two numbers, an optional string and a nested size.
private struct AddRectParams: Decodable { var x: Double; var y: Double; var name: String?; var size: RectSize }
private struct RectSize: Decodable { var w: Double; var h: Double }
private struct Flags: Decodable { var on: Bool; var count: Int; var label: String; var scale: Double }
private struct Loose: Decodable { var count: Int?; var on: Bool?; var size: RectSize?; var scale: Double }
private struct Vertex: Decodable { var x: Double; var y: Double }
private struct Polyline: Decodable { var points: [Vertex]; var tags: [String]; var widths: [Int]? }
/// A type that holds itself: only the depth cap stops the probe.
private final class Link: Decodable { let id: Int; let next: Link? }
/// An enum whose init throws on the probe's "" placeholder.
private enum Blend: String, Decodable { case normal, multiply }
private struct Fill: Decodable { var opacity: Double; var blend: Blend; var after: Bool }
/// The same kind of enum, with its cases written by hand.
private enum Align: String, Decodable, CommandSchemaProviding {
    case left, right
    static let paramSchema = ParamSchema.string("Text alignment.", oneOf: ["left", "right"])
}
private struct TextLabel: Decodable { var text: String; var align: Align; var size: Double }
/// A whole params type whose bounds the probe can't see.
private struct Zoom: Decodable, CommandSchemaProviding {
    var scale: Double
    static let paramSchema = ParamSchema.object(["scale": .number("Zoom factor.", minimum: 0.01, maximum: 64)], required: ["scale"])
}

@Suite struct SchemaProbeTests {
    /// `json` with every `required` list sorted, as JSON Schema reads `required` as a set.
    static func normalized(_ json: JSONValue) -> JSONValue {
        switch json {
        case .array(let items): return .array(items.map(normalized))
        case .object(let fields):
            var out = fields.mapValues(normalized)
            if case .array(let keys)? = fields["required"] {
                let names = keys.compactMap { (key: JSONValue) -> String? in
                    guard case .string(let name) = key else { return nil }
                    return name
                }
                out["required"] = .array(names.sorted().map(JSONValue.string))
            }
            return .object(out)
        default: return json
        }
    }
    /// Records an issue unless the probe of `type` writes the same schema as `expected`.
    static func expectProbe<T: Decodable>(_ type: T.Type, maxDepth: Int = 8, equals expected: ParamSchema,
                                          sourceLocation: SourceLocation = #_sourceLocation) {
        let probed = SchemaProbe.schema(of: type, maxDepth: maxDepth)
        #expect(normalized(probed.json) == normalized(expected.json), sourceLocation: sourceLocation)
    }
    static let size = ParamSchema.object(["w": .number(), "h": .number()], required: ["w", "h"])

    /// CJ1: the probe of `AddRectParams` equals the hand-written schema (mutation `.nestedObject`).
    @Test func addRectParamsEqualsHandWritten() {
        Self.expectProbe(AddRectParams.self, equals: .object([
            "x": .number(), "y": .number(), "name": .optional(.string()), "size": Self.size,
        ], required: ["x", "y", "name", "size"]))
    }

    /// Each scalar maps to its JSON type: Bool boolean, Int integer, String string, Double number.
    @Test func structScalarsMapToTheirTypes() {
        Self.expectProbe(Flags.self, equals: .object([
            "on": .boolean, "count": .integer(), "label": .string(), "scale": .number(),
        ], required: ["on", "count", "label", "scale"]))
    }

    /// A key read with `decodeIfPresent` is left out of `required`, nested types included (mutation `.optionalNotRequired`).
    @Test func optionalsAreNotRequired() {
        Self.expectProbe(Loose.self, equals: .object([
            "count": .optional(.integer()), "on": .optional(.boolean), "size": .optional(Self.size), "scale": .number(),
        ], required: ["scale"]))
    }

    /// An array is an array of its element's schema, an object element included.
    @Test func arraysCarryTheirItemSchema() {
        Self.expectProbe(Polyline.self, equals: .object([
            "points": .array(of: .object(["x": .number(), "y": .number()], required: ["x", "y"])),
            "tags": .array(of: .string()), "widths": .optional(.array(of: .integer())),
        ], required: ["points", "tags"]))
        Self.expectProbe([Vertex].self, equals: .array(of: .object(["x": .number(), "y": .number()], required: ["x", "y"])))
    }

    /// A type that holds itself stops: `maxDepth` typed object levels, then an open `{}` (mutation `.depthCap`).
    @Test func depthCap() {
        for maxDepth in [2, 8] {
            var json = SchemaProbe.schema(of: Link.self, maxDepth: maxDepth).json, levels = 0
            while case .object(let fields) = json, fields["type"] == .string("object"), levels <= maxDepth {
                levels += 1
                guard case .object(let properties)? = fields["properties"], let next = properties["next"] else { break }
                #expect(properties["id"] == .object(["type": .string("integer")]))
                json = next
            }
            #expect(levels == maxDepth, "maxDepth \(maxDepth) gave \(levels) object levels")
            guard case .object(let last) = json else { Issue.record("the cut level is \(json), not an object"); continue }
            #expect(last["type"] == nil && last["properties"] == nil, "the cut level is \(json), not an open {}")
        }
    }

    /// An init that throws on a placeholder keeps the keys read before it and marks the throwing key
    /// a string with no cases: the known limit.
    @Test func throwingEnumInitKeptPartial() {
        Self.expectProbe(Fill.self, equals: .object(["opacity": .number(), "blend": .string()], required: ["opacity", "blend"]))
        Self.expectProbe(Blend.self, equals: .string())
    }

    /// `CommandSchemaProviding` wins, for a nested key (so the keys after it are read) and for the whole type.
    @Test func overrideWins() {
        Self.expectProbe(TextLabel.self, equals: .object([
            "text": .string(), "align": Align.paramSchema, "size": .number(),
        ], required: ["text", "align", "size"]))
        #expect(SchemaProbe.schema(of: Zoom.self) == Zoom.paramSchema)
    }
}

// SampleCommands.swift (eyedropper EY-1 spec with its id, schema and availability, run throwing
// `SampleRules.notBuilt`; EY-6 body): `color.sample`, the query every app registers with one line,
// `+ SampleCommands.specs(<X>Workspace.self)`, so an agent reads a colour the way the eyedropper does.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A document an eyedropper can read colours from.
public protocol SampleTarget: Sendable {
    /// Why nothing can be sampled now ("Open an image first."); nil when it can.
    var sampleHelp: String? { get }
    /// The colour a person sees at `point` (document space): the composite for pixel apps, the topmost
    /// visible painted layer for vector apps; nil on empty canvas or outside the document.
    func sampledColor(at point: Point, size: SampleSize) -> FillColor?
}

public enum SampleCommands {
    /// `color.sample`'s params: the point in document space and the square's size (the point alone when absent).
    struct Params: Codable, Sendable { var x, y: Double; var size: SampleSize? }

    static let channel = ParamSchema.integer("0 to 255.", minimum: 0, maximum: 255)
    static let color = ParamSchema.object(
        ["hex": .string("#RRGGBB."), "r": channel, "g": channel, "b": channel, "a": channel],
        required: ["hex", "r", "g", "b", "a"])

    /// `color.sample`, a query: the colour at a point, or null on empty canvas.
    public static func specs<T: SampleTarget>(_ target: T.Type) -> [CommandSpec<T>] {
        [
            .typed("color.sample", title: "Sample Color",
                   summary: "Reads the colour a person sees at a point, the mean of a 1, 3 or 5 pixel square; null on empty canvas.",
                   kind: .query, params: Params.self,
                   schema: .object(["x": .number("Document x."), "y": .number("Document y."),
                                    "size": .optional(.integer("The square's side: 1, 3 or 5.", minimum: 1, maximum: 5))],
                                   required: ["x", "y", "size"]),
                   result: .object(["color": nullable(color)], required: ["color"]),
                   example: .object(["x": .number(0), "y": .number(0)]),
                   availability: { $0.sampleHelp.map(Availability.unavailable) ?? .available }) { _, _ in try stub() },
        ]
    }

    /// `schema` that also takes null: its type as `[<type>, "null"]`.
    static func nullable(_ schema: ParamSchema) -> ParamSchema {
        guard case .object(var fields) = schema.json, let type = fields["type"] else { return schema }
        var copy = schema
        fields["type"] = .array([type, .string("null")])
        copy.json = .object(fields)
        return copy
    }

    static func stub() throws -> JSONValue { throw SampleRules.notBuilt }
}

// TransformCommands.swift (transform-tools TT-1 shape, TT-6 body): the six transform.* commands any app
// with a TransformTarget registers, and the intents a view sends them as. Ids, titles, schemas and
// availability are the contract; each run throws `notBuilt` until TT-6 applies one TransformRules rule.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// What an app gives the transform commands: the selection's box, why it can't transform or flip,
/// and the one edit that records a named undo step (a drag's steps fold under its token).
public protocol TransformTarget: Sendable {
    /// The selection as one box; nil when nothing is selected.
    var transformSelection: TransformBox? { get }
    /// Why the selection can't be transformed, in the app's words; nil when it can.
    var transformHelp: String? { get }
    /// Why the selection can't be mirrored, after `transformHelp`; nil when it can.
    var flipHelp: String? { get }
    /// Sets the selection's box as one undo step named `name`; steps under one `drag` token are one step.
    mutating func setTransform(_ t: TransformBox, name: String, drag: String?) throws
}

extension TransformTarget {
    /// Every selection that can transform can be mirrored unless the app says otherwise.
    public var flipHelp: String? { nil }
}

/// One transform a view asks for; `command` is the catalog id and params that run it.
public enum TransformIntent: Hashable, Sendable {
    case set(TransformBox, drag: String?), rotate(by: Double, drag: String?)
    case scale(sx: Double, sy: Double, anchor: BoxAnchor, drag: String?), flip(FlipDirection), reset

    /// The command id and its JSON params.
    public var command: (id: String, params: JSONValue) {
        let token: [String: JSONValue] = drag.map { ["drag": .string($0)] } ?? [:]
        switch self {
        case let .set(t, _):
            let b = t.box
            return ("transform.set", .object(["x": .number(b.minX), "y": .number(b.minY), "w": .number(b.width),
                                              "h": .number(b.height), "degrees": .number(t.degrees)].merging(token) { a, _ in a }))
        case let .rotate(by, _): return ("transform.rotate", .object(["degrees": .number(by)].merging(token) { a, _ in a }))
        case let .scale(sx, sy, anchor, _):
            return ("transform.scale", .object(["sx": .number(sx), "sy": .number(sy), "anchor": .string(anchor.rawValue)]
                .merging(token) { a, _ in a }))
        case let .flip(direction): return ("transform.flip", .object(["axis": .string(direction.rawValue)]))
        case .reset: return ("transform.reset", .object([:]))
        }
    }

    private var drag: String? {
        switch self {
        case let .set(_, d), let .rotate(_, d), let .scale(_, _, _, d): d
        case .flip, .reset: nil
        }
    }
}

/// The transform.* specs for a TransformTarget, and their params.
public enum TransformCommands {
    /// `transform.set`: any of the box's x, y, w, h and turn.
    public struct SetParams: Codable, Sendable { public var x, y, w, h, degrees: Double?; public var drag: String? }
    /// `transform.rotate`: turn by `degrees` more (relative).
    public struct RotateParams: Codable, Sendable { public var degrees: Double; public var drag: String? }
    /// `transform.scale`: scale by `sx` and `sy` about `anchor` (the centre when nil).
    public struct ScaleParams: Codable, Sendable { public var sx, sy: Double; public var anchor: BoxAnchor?; public var drag: String? }
    /// `transform.flip`: mirror across `axis`.
    public struct FlipParams: Codable, Sendable { public var axis: FlipDirection }
    /// `transform.read` and `transform.reset` take nothing.
    public struct NoParams: Codable, Sendable {}
    /// `transform.read`'s result.
    public struct Reading: Codable, Sendable { public var x, y, w, h, degrees: Double; public var flipX, flipY: Bool }

    static let dragSchema = ParamSchema.optional(.string("A drag's token; steps under one token are one undo step.", maxLength: 64))
    static let readingSchema = ParamSchema.object(
        ["x": .number("Left of the unturned box."), "y": .number("Top of the unturned box."), "w": .number("Width."),
         "h": .number("Height."), "degrees": .number("Clockwise turn in degrees."), "flipX": .boolean, "flipY": .boolean],
        required: ["x", "y", "w", "h", "degrees", "flipX", "flipY"])

    /// The six specs, in the packet's order.
    public static func specs<T: TransformTarget>(_ target: T.Type) -> [CommandSpec<T>] {
        let can: @Sendable (T) -> Availability = { $0.transformHelp.map(Availability.unavailable) ?? .available }
        let canFlip: @Sendable (T) -> Availability = { t in
            (t.transformHelp ?? t.flipHelp).map(Availability.unavailable) ?? .available
        }
        let number = { (desc: String) in ParamSchema.optional(.number(desc)) }
        return [
            .typed("transform.read", title: "Transform", summary: "Reads the selection's box, turn and mirrors.", kind: .query,
                   params: NoParams.self, schema: .none, result: readingSchema, example: .object([:]),
                   availability: can) { (_: inout T, _: NoParams) throws -> Reading in try notBuilt("transform.read") },
            .typed("transform.set", title: "Transform", summary: "Sets any of the selection's x, y, width, height and turn.",
                   kind: .edit, params: SetParams.self,
                   schema: .object(["x": number("Left, document points."), "y": number("Top, document points."),
                                    "w": number("Width, at least 1."), "h": number("Height, at least 1."),
                                    "degrees": number("Clockwise turn in degrees."), "drag": dragSchema],
                                   required: ["x", "y", "w", "h", "degrees", "drag"]),
                   result: readingSchema, example: .object(["w": .number(240)]),
                   availability: can) { (_: inout T, _: SetParams) throws -> Reading in try notBuilt("transform.set") },
            .typed("transform.rotate", title: "Rotate", summary: "Turns the selection clockwise by degrees about its centre.",
                   kind: .edit, params: RotateParams.self,
                   schema: .object(["degrees": .number("Degrees to turn by, clockwise."), "drag": dragSchema], required: ["degrees", "drag"]),
                   result: readingSchema, example: .object(["degrees": .number(15)]),
                   availability: can) { (_: inout T, _: RotateParams) throws -> Reading in try notBuilt("transform.rotate") },
            .typed("transform.scale", title: "Scale", summary: "Scales the selection about an anchor, the centre by default.",
                   kind: .edit, params: ScaleParams.self,
                   schema: .object(["sx": .number("Horizontal factor, above 0."), "sy": .number("Vertical factor, above 0."),
                                    "anchor": .optional(.string("The point that stays.", oneOf: BoxAnchor.allCases.map(\.rawValue))),
                                    "drag": dragSchema], required: ["sx", "sy", "anchor", "drag"]),
                   result: readingSchema, example: .object(["sx": .number(2), "sy": .number(2)]),
                   availability: can) { (_: inout T, _: ScaleParams) throws -> Reading in try notBuilt("transform.scale") },
            .typed("transform.flip", title: "Flip", summary: "Mirrors the selection about its centre: Flip Horizontal or Flip Vertical.",
                   kind: .edit, params: FlipParams.self,
                   schema: .object(["axis": .string("Which way to mirror.", oneOf: FlipDirection.allCases.map(\.rawValue))], required: ["axis"]),
                   result: readingSchema, example: .object(["axis": .string("horizontal")]),
                   availability: canFlip) { (_: inout T, _: FlipParams) throws -> Reading in try notBuilt("transform.flip") },
            .typed("transform.reset", title: "Reset Rotation", summary: "Turns the selection back to 0 and clears its mirrors.",
                   kind: .edit, params: NoParams.self, schema: .none, result: readingSchema, example: .object([:]),
                   availability: can) { (_: inout T, _: NoParams) throws -> Reading in try notBuilt("transform.reset") },
        ]
    }

    /// A stub run's refusal until TT-6 builds the commands.
    static func notBuilt<R>(_ id: String) throws -> R { throw CatalogError.notBuilt(id: id, feature: "transform-tools") }
}

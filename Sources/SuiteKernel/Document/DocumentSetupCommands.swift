// DocumentSetupCommands.swift (document-setup DS-1 shape and stubs, DS-4 bodies): document.read-settings and
// document.set-settings, which any app with a DocumentSetupTarget registers, and the setup schema each app's
// file.new (Halo: composition.new) takes. Ids, titles, schemas and examples are the contract.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// What an app gives the document commands: its setup now, its limits, and the one write that applies a
/// new setup, placing old content by `anchor`, as one undo step.
public protocol DocumentSetupTarget: AnyObject {
    /// The document's setup now.
    var documentSetup: DocumentSetup { get }
    /// What the app allows.
    var documentLimits: DocumentLimits { get }
    /// Applies `setup` as one undo step; a size change keeps old content at `anchor`.
    func apply(_ setup: DocumentSetup, anchor: BoxAnchor) throws
}

/// The two document specs, their params, the setup schema, and the runner an app's catalog forwards to.
public enum DocumentSetupCommands {
    /// `document.read-settings` takes nothing.
    public struct NoParams: Codable, Sendable {}
    /// `document.set-settings`: any of the setup's fields, and where old content stays (centre when left out).
    public struct SetParams: Codable, Sendable {
        public var width, height: Double?; public var unit: LengthUnit?; public var resolution: Double?
        public var background: DocumentBackground?; public var frameRate: FrameRate?; public var duration: Double?
        public var anchor: BoxAnchor?
    }

    static let rateSchema = ParamSchema.object(["num": .integer("Frames per den seconds.", minimum: 1),
                                                "den": .integer("Seconds the frames take; 1001 for 29.97.", minimum: 1)],
                                               required: ["num", "den"], description: "Frame rate as a fraction, timed apps only.")
    static let setupProperties: [String: ParamSchema] = [
        "width": .number("Width, in unit."),
        "height": .number("Height, in unit."),
        "unit": .optional(.string("px, pt, in, cm or mm; px when left out.", oneOf: LengthUnit.allCases.map(\.rawValue))),
        "resolution": .optional(.number("Pixels per inch; 72 when left out.")),
        "background": .optional(.string("white, transparent or #RRGGBB; white when left out.", maxLength: 11)),
        "frameRate": .optional(rateSchema),
        "duration": .optional(.number("Length in seconds, timed apps only.")),
    ]

    /// What file.new and composition.new take: a size in a unit at a resolution, a background, a rate and a duration.
    public static let setupSchema = ParamSchema.object(setupProperties, required: setupProperties.keys.sorted())

    static let setSchema: ParamSchema = {
        var properties = setupProperties.mapValues(ParamSchema.optional)
        properties["anchor"] = .optional(.string("Where old content stays when the size changes; center when left out.",
                                                 oneOf: BoxAnchor.allCases.map(\.rawValue)))
        return .object(properties, required: properties.keys.sorted())
    }()

    static let readingSchema: ParamSchema = {
        var properties = setupProperties
        properties["pixelWidth"] = .integer("Width in pixels.")
        properties["pixelHeight"] = .integer("Height in pixels.")
        properties["offsetX"] = .optional(.number("How far a set moved old content right, in pixels."))
        properties["offsetY"] = .optional(.number("How far a set moved old content down, in pixels."))
        return .object(properties, required: properties.keys.sorted())
    }()

    /// The two specs: read the setup, and set any of it with an anchor.
    public static let specs: [CommandSpec<any DocumentSetupTarget>] = [
        .typed("document.read-settings", title: "Read Document Settings",
               summary: "Answers the document's size, unit, resolution, pixel size, background and, for timed apps, rate and duration.",
               kind: .query, params: NoParams.self, schema: ParamSchema.none, result: readingSchema,
               example: .object([:])) { (t: inout any DocumentSetupTarget, _: NoParams) throws -> JSONValue in
            try read(t)
        },
        .typed("document.set-settings", title: "Document Settings",
               summary: "Changes the document's size, resolution, background, rate or duration; a size change keeps old content at anchor.",
               kind: .edit, params: SetParams.self, schema: setSchema, result: readingSchema,
               example: .object(["width": .number(1920), "height": .number(1200), "anchor": .string("bottom")])) {
            (t: inout any DocumentSetupTarget, p: SetParams) throws -> JSONValue in
            try set(t, p)
        },
    ]

    /// Runs `id` with JSON `params` on `target`, as an app's catalog forwards it; answers the setup as read.
    @discardableResult
    public static func run(_ id: String, _ params: JSONValue, on target: any DocumentSetupTarget) throws -> JSONValue {
        guard let spec = specs.first(where: { $0.id == id }) else { throw CatalogError.unknownCommand(id) }
        let issues = spec.params.validate(params)
        guard issues.isEmpty else { throw CatalogError.malformedParams(id: id, issues) }
        var t = target
        return try spec.run(&t, params)
    }

    /// Where old content's top-left lands, in pixels, when `old` becomes `new` about `anchor`.
    public static func offset(from old: DocumentSetup, to new: DocumentSetup, anchor: BoxAnchor) -> Point {
        let (before, after) = (old.pixelSize, new.pixelSize)
        return TransformRules.anchoredOrigin(old: (Double(before.width), Double(before.height)),
                                             new: (Double(after.width), Double(after.height)), anchor)
    }

    static func read(_ t: any DocumentSetupTarget) throws -> JSONValue { try reading(t.documentSetup, offset: nil) }

    /// The setup as JSON with its pixel size and, after a set, how far old content moved.
    static func reading(_ setup: DocumentSetup, offset: Point?) throws -> JSONValue {
        guard case .object(var fields) = try JSONValue(encoding: setup) else { return .object([:]) }
        let pixels = setup.pixelSize
        (fields["pixelWidth"], fields["pixelHeight"]) = (.number(Double(pixels.width)), .number(Double(pixels.height)))
        if let offset { (fields["offsetX"], fields["offsetY"]) = (.number(offset.x), .number(offset.y)) }
        return .object(fields)
    }

    /// The setup `p` asks for: each field given replaces the old one; a rate change keeps the seconds.
    static func merged(_ old: DocumentSetup, _ p: SetParams) -> DocumentSetup {
        var next = old
        (next.width, next.height) = (p.width ?? old.width, p.height ?? old.height)
        (next.unit, next.resolution) = (p.unit ?? old.unit, p.resolution ?? old.resolution)
        (next.background, next.frameRate) = (p.background ?? old.background, p.frameRate ?? old.frameRate)
        next.durationSeconds = p.duration ?? old.durationSeconds
        return next
    }

    static func set(_ t: any DocumentSetupTarget, _ p: SetParams) throws -> JSONValue {
        let old = t.documentSetup, next = merged(old, p), anchor = p.anchor ?? .center
        let problems = next.problems(t.documentLimits)
        guard problems.isEmpty else {
            throw CatalogError.failed(id: "document.set-settings", message: problems.map(\.text).joined(separator: " "))
        }
        try t.apply(next, anchor: anchor)
        return try reading(next, offset: offset(from: old, to: next, anchor: anchor))
    }
}

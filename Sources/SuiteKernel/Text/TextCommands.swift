// TextCommands.swift (text-style TS-1 specs with real ids, schemas and availability, runs throwing
// `TextStyleRules.notBuilt`; TS-6 bodies): the seven text commands every app registers with one line,
// `+ TextCommands.specs(<X>Workspace.self)`, and the text inspector's gestures as those commands.

/// A document the text commands run on: it reads the selected text layer's style and sets it back as one undo step.
public protocol TextStyleTarget: Sendable {
    /// The primary selected text layer's style; nil when no text layer is selected.
    var textStyle: TextStyle? { get }
    /// Why the text commands can't run now, in the app's words; nil when they can.
    var textHelp: String? { get }
    /// The faces `family` has, each a weight and whether it is italic; empty for a family the app doesn't know.
    func faces(of family: String) -> [(weight: Int, italic: Bool)]
    /// Sets every selected text layer's style; one undo step named `name`, steps under one `drag` token fold into one.
    mutating func setTextStyle(_ s: TextStyle, name: String, drag: String?) throws
}

/// One gesture of the text inspector; the app runs its `command` through its catalog.
public enum TextIntent: Hashable, Sendable {
    case font(family: String, weight: Int?, italic: Bool?), size(Double, drag: String?)
    case alignment(TextStyle.Alignment), lineHeight(Double, drag: String?), tracking(Double, drag: String?)

    /// The inspector's gesture as the command it is: its id and params.
    public var command: (id: String, params: JSONValue) {
        switch self {
        case .font(let family, let weight, let italic):
            ("text.set-font", .object(["family": .string(family), "weight": weight.map { .number(Double($0)) },
                                       "italic": italic.map(JSONValue.bool)].compactMapValues { $0 }))
        case .size(let size, let drag): ("text.set-size", Self.params(["size": .number(size)], drag))
        case .alignment(let alignment): ("text.set-alignment", .object(["alignment": .string(alignment.rawValue)]))
        case .lineHeight(let value, let drag): ("text.set-line-height", Self.params(["value": .number(value)], drag))
        case .tracking(let value, let drag): ("text.set-tracking", Self.params(["value": .number(value)], drag))
        }
    }
    /// `fields` as an object, with `drag` when there is one.
    private static func params(_ fields: [String: JSONValue], _ drag: String?) -> JSONValue {
        .object(fields.merging(drag.map { ["drag": .string($0)] } ?? [:]) { old, _ in old })
    }
}

public enum TextCommands {
    // Each command's params, named for it (`text.read` takes none).
    struct Empty: Codable, Sendable {}
    struct FontParams: Codable, Sendable { var family: String; var weight: Int?; var italic: Bool? }
    struct SizeParams: Codable, Sendable { var size: Double; var drag: String? }
    struct ItalicParams: Codable, Sendable { var on: Bool }
    struct AlignmentParams: Codable, Sendable { var alignment: TextStyle.Alignment }
    struct ValueParams: Codable, Sendable { var value: Double; var drag: String? }

    /// Why the text commands can't run with no text layer, and why italic can't on a family without one.
    static let selectHelp = "Select a text layer first.", italicHelp = "This family has no italic."

    static let drag = ParamSchema.optional(.string("A drag's token; edits under one token are one undo step.", maxLength: 64))
    static let alignments = ["leading", "center", "trailing", "justified"]
    static func number(_ field: TextStyleField, _ what: String) -> ParamSchema {
        .number(what, minimum: TextStyleRules.range(field).lowerBound, maximum: TextStyleRules.range(field).upperBound)
    }
    static let font: [String: ParamSchema] = [
        "family": .string("The font family's name.", maxLength: 128),
        "weight": .optional(.integer("100 thin to 900 black.", minimum: 100, maximum: 900)),
        "italic": .optional(.boolean),
    ]
    static let style = ParamSchema.object([
        "family": .string("The font family's name."), "weight": .integer("100 thin to 900 black."), "italic": .boolean,
        "size": .number("Points."), "rgba": .array(of: .integer("0 to 255.", minimum: 0, maximum: 255), minItems: 4, maxItems: 4),
        "paragraph": .object([
            "alignment": .string(nil, oneOf: alignments), "lineHeight": .number("A multiple of ascent + descent."),
            "tracking": .number("Thousandths of an em."), "paragraphSpacing": .number("Points."),
            "boxWidth": .optional(.number("Points; text wraps and justifies in it.")),
        ], required: ["alignment", "lineHeight", "tracking", "paragraphSpacing", "boxWidth"]),
    ], required: ["family", "weight", "italic", "size", "rgba", "paragraph"])

    /// The seven text commands on `target`, in menu order: `text.read` a query, the rest edits of one undo step each.
    public static func specs<T: TextStyleTarget>(_ target: T.Type) -> [CommandSpec<T>] {
        [
            .typed("text.read", title: "Read Text Style", summary: "Reads the selected text layer's style: face, size, colour and paragraph.",
                   kind: .query, params: Empty.self, schema: .none, result: style,
                   example: .object([:]), availability: { ready($0) }) { _, _ in try stub() },
            .typed("text.set-font", title: "Font", summary: "Sets the font family, keeping the face or taking the nearest one it has.",
                   kind: .edit, params: FontParams.self, schema: .object(font, required: ["family", "weight", "italic"]),
                   example: .object(["family": .string("System"), "weight": .number(700)]), availability: { ready($0) }) { _, _ in try stub() },
            .typed("text.set-size", title: "Text Size", summary: "Sets the size in points, 1 to 1600; sizes under one drag token are one undo step.",
                   kind: .edit, params: SizeParams.self, schema: .object(["size": number(.size, "Points."), "drag": drag], required: ["size", "drag"]),
                   example: .object(["size": .number(36)]), availability: { ready($0) }) { _, _ in try stub() },
            .typed("text.set-italic", title: "Italic", summary: "Turns italic on or off in the current family.",
                   kind: .edit, params: ItalicParams.self, schema: .object(["on": .boolean], required: ["on"]),
                   example: .object(["on": .bool(true)]), availability: { italic($0) }) { _, _ in try stub() },
            .typed("text.set-alignment", title: "Alignment", summary: "Aligns the paragraph leading, center, trailing or justified.",
                   kind: .edit, params: AlignmentParams.self,
                   schema: .object(["alignment": .string("The paragraph's alignment.", oneOf: alignments)], required: ["alignment"]),
                   example: .object(["alignment": .string("center")]), availability: { ready($0) }) { _, _ in try stub() },
            .typed("text.set-line-height", title: "Line Height", summary: "Sets line height, 0.5 to 4 times ascent + descent; one drag is one undo step.",
                   kind: .edit, params: ValueParams.self,
                   schema: .object(["value": number(.lineHeight, "A multiple of ascent + descent."), "drag": drag], required: ["value", "drag"]),
                   example: .object(["value": .number(1.5)]), availability: { ready($0) }) { _, _ in try stub() },
            .typed("text.set-tracking", title: "Letter Spacing", summary: "Sets letter spacing, -100 to 500 thousandths of an em; one drag is one undo step.",
                   kind: .edit, params: ValueParams.self,
                   schema: .object(["value": number(.tracking, "Thousandths of an em."), "drag": drag], required: ["value", "drag"]),
                   example: .object(["value": .number(50)]), availability: { ready($0) }) { _, _ in try stub() },
        ]
    }

    /// Available when the target has a text style to edit; else its `textHelp`.
    static func ready<T: TextStyleTarget>(_ target: T) -> Availability {
        if let why = target.textHelp { return .unavailable(why) }
        return target.textStyle == nil ? .unavailable(selectHelp) : .available
    }
    /// `ready`, and the current family has an italic face.
    static func italic<T: TextStyleTarget>(_ target: T) -> Availability {
        guard ready(target) == .available, let style = target.textStyle else { return ready(target) }
        return target.faces(of: style.family).contains { $0.italic } ? .available : .unavailable(italicHelp)
    }
    /// Every run until TS-6: refuses with `TextStyleRules.notBuilt`.
    static func stub() throws -> JSONValue { throw TextStyleRules.notBuilt }
}

// ParamSchema.swift (command-catalog CC-1: builders real; CC-4 bodies): the JSON Schema 2020-12 subset commands use.
/// A JSON Schema object for a command's params or result. Objects are closed
/// (`additionalProperties: false`); `optional` keeps a property out of `required`.
public struct ParamSchema: Hashable, Sendable {
    /// The JSON Schema object.
    public var json: JSONValue
    /// True when the parent object leaves this property out of its `required` list.
    var isOptional = false
    /// A closed object of `properties`; `required` keeps only the keys whose schema isn't `optional`.
    public static func object(_ properties: [String: ParamSchema], required: [String], description: String? = nil) -> ParamSchema {
        let kept = required.filter { properties[$0]?.isOptional != true }
        return make("object", description, ["properties": .object(properties.mapValues(\.json)),
                                            "required": .array(kept.map(JSONValue.string)), "additionalProperties": .bool(false)])
    }
    /// A string, limited to `cases` (the `enum` keyword) and to `maxLength` characters when given.
    public static func string(_ description: String? = nil, oneOf cases: [String]? = nil, maxLength: Int? = nil) -> ParamSchema {
        make("string", description, ["enum": cases.map { .array($0.map(JSONValue.string)) }, "maxLength": whole(maxLength)])
    }
    /// A number within `minimum`...`maximum`, both inclusive, when given.
    public static func number(_ description: String? = nil, minimum: Double? = nil, maximum: Double? = nil) -> ParamSchema {
        make("number", description, ["minimum": minimum.map(JSONValue.number), "maximum": maximum.map(JSONValue.number)])
    }
    /// A whole number within `minimum`...`maximum`, both inclusive, when given.
    public static func integer(_ description: String? = nil, minimum: Int? = nil, maximum: Int? = nil) -> ParamSchema {
        make("integer", description, ["minimum": whole(minimum), "maximum": whole(maximum)])
    }
    /// `true` or `false`.
    public static let boolean = make("boolean", nil, [:])
    /// An array whose every item matches `item`, with `minItems`...`maxItems` items when given.
    public static func array(of item: ParamSchema, minItems: Int? = nil, maxItems: Int? = nil) -> ParamSchema {
        make("array", nil, ["items": item.json, "minItems": whole(minItems), "maxItems": whole(maxItems)])
    }
    /// `s` as a property its parent object doesn't require.
    public static func optional(_ s: ParamSchema) -> ParamSchema { var copy = s; copy.isOptional = true; return copy }
    /// No params: `{"type":"object","additionalProperties":false}`.
    public static let none = ParamSchema(json: .object(["type": .string("object"), "additionalProperties": .bool(false)]))
    /// The issues `value` has against this schema, each with its JSON pointer; empty = valid.
    /// CC-1 stub: reports nothing until command-catalog CC-4 fills it.
    public func validate(_ value: JSONValue) -> [SchemaIssue] { [] }
    /// The schema as a standalone document, with `"$schema"` naming JSON Schema 2020-12.
    public func document() -> JSONValue {
        guard case .object(var fields) = json else { return json }
        fields["$schema"] = .string("https://json-schema.org/draft/2020-12/schema")
        return .object(fields)
    }
    /// A schema of `type` with its description and the given keywords, nil ones left out.
    private static func make(_ type: String, _ description: String?, _ keywords: [String: JSONValue?]) -> ParamSchema {
        var fields = keywords.compactMapValues { $0 }
        fields["type"] = .string(type)
        if let description { fields["description"] = .string(description) }
        return ParamSchema(json: .object(fields))
    }
    /// `value` as a JSON number, nil when it is nil.
    private static func whole(_ value: Int?) -> JSONValue? { value.map { .number(Double($0)) } }
}

/// One way a value fails a schema: where (a JSON pointer such as `/size/w`) and why ("expected number").
public struct SchemaIssue: Hashable, Sendable, Codable {
    /// The JSON pointer to the failing value ("" for the root), and what was expected, in words.
    public var path: String; public var message: String
    public init(path: String, message: String) { (self.path, self.message) = (path, message) }
}

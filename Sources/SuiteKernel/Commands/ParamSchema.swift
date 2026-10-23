// ParamSchema.swift (command-catalog CC-1: builders real; CC-4: validate): the JSON Schema 2020-12 subset commands use.
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
    /// Checks `type`, `properties`/`required`/`additionalProperties`, `items`/`minItems`/`maxItems`,
    /// `enum`/`maxLength` and inclusive `minimum`/`maximum`; a value of the wrong type gets only "expected <type>".
    public func validate(_ value: JSONValue) -> [SchemaIssue] { Self.issues(json, value, at: "") }
    /// The schema as a standalone document, with `"$schema"` naming JSON Schema 2020-12.
    public func document() -> JSONValue {
        guard case .object(var fields) = json else { return json }
        fields["$schema"] = .string("https://json-schema.org/draft/2020-12/schema")
        return .object(fields)
    }
    /// The issues `value` has against the schema object `schema`, at the JSON pointer `path`.
    private static func issues(_ schema: JSONValue, _ value: JSONValue, at path: String) -> [SchemaIssue] {
        let keywords = fields(schema)
        if case .string(let type)? = keywords["type"], !matches(type, value) {
            return [SchemaIssue(path: path, message: "expected \(type)")]
        }
        switch value {
        case .object(let members): return objectIssues(keywords, members, at: path)
        case .array(let items): return arrayIssues(keywords, items, at: path)
        case .string(let text): return stringIssues(keywords, text, at: path)
        case .number(let x): return numberIssues(keywords, x, at: path)
        case .null, .bool: return []
        }
    }
    /// True when `value` is a JSON Schema `type`; an integer is a finite number with no fraction.
    private static func matches(_ type: String, _ value: JSONValue) -> Bool {
        switch (type, value) {
        case ("object", .object), ("array", .array), ("string", .string), ("boolean", .bool), ("null", .null): return true
        case ("number", .number(let x)): return x.isFinite
        case ("integer", .number(let x)): return x.isFinite && x.rounded() == x
        default: return false
        }
    }
    /// A missing required key, an extra key on a closed object, and each property's own issues.
    private static func objectIssues(_ keywords: [String: JSONValue], _ members: [String: JSONValue], at path: String) -> [SchemaIssue] {
        let properties = fields(keywords["properties"])
        var found: [SchemaIssue] = []
        if case .array(let required)? = keywords["required"] {
            for case .string(let key) in required where members[key] == nil {
                found.append(SchemaIssue(path: child(path, key), message: "missing required key"))
            }
        }
        let closed = keywords["additionalProperties"] == .bool(false)
        for (key, member) in members.sorted(by: { $0.key < $1.key }) {
            if let property = properties[key] {
                found += issues(property, member, at: child(path, key))
            } else if closed {
                found.append(SchemaIssue(path: child(path, key), message: "unexpected key"))
            }
        }
        return found
    }
    /// The item count against `minItems`/`maxItems`, then each item against `items` at its index.
    private static func arrayIssues(_ keywords: [String: JSONValue], _ items: [JSONValue], at path: String) -> [SchemaIssue] {
        var found: [SchemaIssue] = []
        if let least = number(keywords["minItems"]), Double(items.count) < least {
            found.append(SchemaIssue(path: path, message: "expected at least \(words(least)) items"))
        }
        if let most = number(keywords["maxItems"]), Double(items.count) > most {
            found.append(SchemaIssue(path: path, message: "expected at most \(words(most)) items"))
        }
        if let item = keywords["items"] {
            for (index, element) in items.enumerated() { found += issues(item, element, at: child(path, String(index))) }
        }
        return found
    }
    /// A case outside `enum`, or more than `maxLength` characters (code points, as JSON Schema counts them).
    private static func stringIssues(_ keywords: [String: JSONValue], _ text: String, at path: String) -> [SchemaIssue] {
        var found: [SchemaIssue] = []
        if case .array(let cases)? = keywords["enum"], !cases.contains(.string(text)) {
            let names = cases.compactMap { name -> String? in if case .string(let n) = name { return n }; return nil }
            found.append(SchemaIssue(path: path, message: "expected one of \(names.joined(separator: ", "))"))
        }
        if let longest = number(keywords["maxLength"]), Double(text.unicodeScalars.count) > longest {
            found.append(SchemaIssue(path: path, message: "expected at most \(words(longest)) characters"))
        }
        return found
    }
    /// A number below `minimum` or above `maximum`; both bounds are inclusive.
    private static func numberIssues(_ keywords: [String: JSONValue], _ x: Double, at path: String) -> [SchemaIssue] {
        var found: [SchemaIssue] = []
        if let minimum = number(keywords["minimum"]), x < minimum {
            found.append(SchemaIssue(path: path, message: "expected at least \(words(minimum))"))
        }
        if let maximum = number(keywords["maximum"]), x > maximum {
            found.append(SchemaIssue(path: path, message: "expected at most \(words(maximum))"))
        }
        return found
    }
    /// `path` extended by one token, escaped as RFC 6901 asks (`~` as `~0`, `/` as `~1`).
    private static func child(_ path: String, _ token: String) -> String {
        var escaped = ""
        for character in token {
            switch character {
            case "~": escaped += "~0"
            case "/": escaped += "~1"
            default: escaped.append(character)
            }
        }
        return path + "/" + escaped
    }
    /// The members of `value` when it is an object, else none.
    private static func fields(_ value: JSONValue?) -> [String: JSONValue] {
        if case .object(let members)? = value { return members }
        return [:]
    }
    /// The number `value` holds, nil when it isn't one.
    private static func number(_ value: JSONValue?) -> Double? {
        if case .number(let x)? = value { return x }
        return nil
    }
    /// `x` in words: a whole number without a fraction ("8", not "8.0").
    private static func words(_ x: Double) -> String {
        x.rounded() == x && abs(x) < 1e15 ? String(Int(x)) : String(x)
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

// ParamSchemaTests.swift (command-catalog CC-3, CJ1): each ParamSchema builder writes the JSON Schema 2020-12
// keywords the packet names, and `validate` gives one issue per fault at its JSON pointer. The builder and
// `document()` checks run since CC-1 made them real; the validate checks since CC-4 filled `validate`.
import Testing
import SuiteKernel

@Suite struct ParamSchemaTests {
    /// A rect's params: two numbers, three optional keys with a length, cases and bounds, and a nested size.
    static let rect = ParamSchema.object([
        "x": .number(), "y": .number(),
        "name": .optional(.string(maxLength: 8)),
        "blend": .optional(.string(oneOf: ["normal", "multiply"])),
        "opacity": .optional(.number(minimum: 0, maximum: 1)),
        "size": .object(["w": .number(minimum: 0), "h": .number(minimum: 0)], required: ["w", "h"]),
    ], required: ["x", "y", "name", "blend", "opacity", "size"])
    /// A path's params: one to three points, each a closed object with an integer `x` in 0...100.
    static let path = ParamSchema.object(["points": .array(of: .object(["x": .integer(minimum: 0, maximum: 100)], required: ["x"]),
                                                           minItems: 1, maxItems: 3)], required: ["points"])
    static let valid: [String: JSONValue] = ["x": .number(1), "y": .number(2), "size": .object(["w": .number(3), "h": .number(4)])]

    /// The rect's issues for `valid` with `change` applied.
    func rectIssues(_ change: (inout [String: JSONValue]) -> Void) -> [SchemaIssue] {
        var value = Self.valid
        change(&value)
        return Self.rect.validate(.object(value))
    }
    /// The paths of `issues`, sorted, as the order of issues isn't part of the contract.
    func paths(_ issues: [SchemaIssue]) -> [String] { issues.map(\.path).sorted() }

    // MARK: builders (real since CC-1)

    @Test func stringWritesTypeDescriptionEnumAndMaxLength() {
        #expect(ParamSchema.string().json == .object(["type": .string("string")]))
        #expect(ParamSchema.string("Blend mode.", oneOf: ["normal", "multiply"], maxLength: 8).json == .object([
            "type": .string("string"), "description": .string("Blend mode."),
            "enum": .array([.string("normal"), .string("multiply")]), "maxLength": .number(8)]))
    }

    @Test func numberAndIntegerWriteInclusiveBounds() {
        #expect(ParamSchema.number().json == .object(["type": .string("number")]))
        #expect(ParamSchema.number("Opacity.", minimum: 0, maximum: 1).json == .object([
            "type": .string("number"), "description": .string("Opacity."), "minimum": .number(0), "maximum": .number(1)]))
        #expect(ParamSchema.integer(minimum: -2, maximum: 9).json == .object([
            "type": .string("integer"), "minimum": .number(-2), "maximum": .number(9)]))
        #expect(ParamSchema.integer("Count.").json == .object(["type": .string("integer"), "description": .string("Count.")]))
    }

    @Test func booleanArrayAndNoneWriteTheirKeywords() {
        #expect(ParamSchema.boolean.json == .object(["type": .string("boolean")]))
        #expect(ParamSchema.array(of: .boolean).json == .object(["type": .string("array"), "items": .object(["type": .string("boolean")])]))
        #expect(ParamSchema.array(of: .integer(), minItems: 1, maxItems: 3).json == .object([
            "type": .string("array"), "items": .object(["type": .string("integer")]), "minItems": .number(1), "maxItems": .number(3)]))
        #expect(ParamSchema.none.json == .object(["type": .string("object"), "additionalProperties": .bool(false)]))
    }

    /// A nested object is closed at every level, and `required` keeps the given order minus the optional keys.
    @Test func nestedObjectIsClosedAndDropsOptionalKeys() throws {
        guard case .object(let fields) = Self.rect.json, case .object(let properties)? = fields["properties"] else {
            Issue.record("rect is not an object with properties: \(Self.rect.json)"); return
        }
        #expect(fields["type"] == .string("object") && fields["additionalProperties"] == .bool(false))
        #expect(fields["required"] == .array([.string("x"), .string("y"), .string("size")]))
        #expect(properties["opacity"] == .object(["type": .string("number"), "minimum": .number(0), "maximum": .number(1)]))
        #expect(properties["size"] == .object([
            "type": .string("object"), "additionalProperties": .bool(false), "required": .array([.string("w"), .string("h")]),
            "properties": .object(["w": .object(["type": .string("number"), "minimum": .number(0)]),
                                   "h": .object(["type": .string("number"), "minimum": .number(0)])])]))
    }

    /// `document()` adds `$schema` naming 2020-12 and keeps every other keyword.
    @Test func documentCarriesSchema2020() {
        #expect(ParamSchema.number(minimum: 1).document() == .object([
            "$schema": .string("https://json-schema.org/draft/2020-12/schema"), "type": .string("number"), "minimum": .number(1)]))
    }

    // MARK: validate (CC-4)

    /// A value with every required key, inclusive bounds at their edges and every optional key passes
    /// (mutation `.minimumInclusive`).
    @Test func validValuePasses() {
        #expect(rectIssues { _ in }.isEmpty)
        #expect(rectIssues { $0["name"] = .string("Rect 1"); $0["blend"] = .string("multiply"); $0["opacity"] = .number(0) }.isEmpty)
        #expect(rectIssues { $0["opacity"] = .number(1); $0["size"] = .object(["w": .number(0), "h": .number(0)]) }.isEmpty)
        #expect(Self.path.validate(.object(["points": .array([.object(["x": .number(0)]), .object(["x": .number(100)])])])).isEmpty)
        #expect(ParamSchema.none.validate(.object([:])).isEmpty && ParamSchema.boolean.validate(.bool(false)).isEmpty)
    }

    /// CJ1: a string where a number goes names `/x` and "expected number"; each other type says what it expected.
    @Test func wrongTypeNamesPathAndExpectedType() {
        #expect(ParamSchema.object(["x": .number()], required: ["x"]).validate(.object(["x": .string("1")]))
                == [SchemaIssue(path: "/x", message: "expected number")])
        #expect(rectIssues { $0["y"] = .null } == [SchemaIssue(path: "/y", message: "expected number")])
        #expect(rectIssues { $0["name"] = .number(3) } == [SchemaIssue(path: "/name", message: "expected string")])
        #expect(rectIssues { $0["size"] = .array([]) } == [SchemaIssue(path: "/size", message: "expected object")])
        #expect(Self.rect.validate(.string("rect")) == [SchemaIssue(path: "", message: "expected object")])
        #expect(ParamSchema.boolean.validate(.number(1)) == [SchemaIssue(path: "", message: "expected boolean")])
        #expect(ParamSchema.integer().validate(.number(1.5)) == [SchemaIssue(path: "", message: "expected integer")])
        #expect(ParamSchema.integer().validate(.number(2)).isEmpty)
        #expect(Self.path.validate(.object(["points": .object([:])])) == [SchemaIssue(path: "/points", message: "expected array")])
    }

    /// A missing required key gives one issue at that key's pointer; a missing optional key gives none.
    @Test func missingRequiredKeyNamesIt() {
        #expect(paths(rectIssues { $0["x"] = nil }) == ["/x"])
        #expect(paths(rectIssues { $0["size"] = nil }) == ["/size"])
        #expect(paths(rectIssues { $0["size"] = .object(["w": .number(1)]) }) == ["/size/h"])
        #expect(rectIssues { $0["name"] = nil; $0["opacity"] = nil }.isEmpty)
    }

    /// A string outside `oneOf` or over `maxLength` gives one issue at its pointer.
    @Test func enumAndLengthAreChecked() {
        #expect(paths(rectIssues { $0["blend"] = .string("screen") }) == ["/blend"])
        #expect(paths(rectIssues { $0["blend"] = .string("") }) == ["/blend"])
        #expect(paths(rectIssues { $0["name"] = .string("Rectangle 1") }) == ["/name"])
        #expect(rectIssues { $0["name"] = .string("12345678") }.isEmpty)
    }

    /// A number below `minimum` or above `maximum` gives one issue at its pointer (mutation `.minimumInclusive`).
    @Test func boundsAreInclusive() {
        #expect(paths(rectIssues { $0["opacity"] = .number(1.5) }) == ["/opacity"])
        #expect(paths(rectIssues { $0["opacity"] = .number(-0.01) }) == ["/opacity"])
        #expect(paths(rectIssues { $0["size"] = .object(["w": .number(-1), "h": .number(0)]) }) == ["/size/w"])
        #expect(paths(ParamSchema.integer(minimum: -2, maximum: 9).validate(.number(10))) == [""])
        #expect(ParamSchema.integer(minimum: -2, maximum: 9).validate(.number(-2)).isEmpty)
    }

    /// An extra key gives one issue at its pointer, at the root, nested, and on `.none` (mutation `.closedObject`).
    @Test func extraKeysAreRefused() {
        #expect(paths(rectIssues { $0["z"] = .number(0) }) == ["/z"])
        #expect(paths(rectIssues { $0["size"] = .object(["w": .number(1), "h": .number(1), "d": .number(1)]) }) == ["/size/d"])
        #expect(paths(ParamSchema.none.validate(.object(["a": .number(1)]))) == ["/a"])
    }

    /// Each array item is checked at its index, and the item count against `minItems`/`maxItems`.
    @Test func arrayItemsAndCountsAreChecked() {
        let point = { (x: JSONValue) in JSONValue.object(["x": x]) }
        #expect(Self.path.validate(.object(["points": .array([point(.number(1)), point(.string("2"))])]))
                == [SchemaIssue(path: "/points/1/x", message: "expected integer")])
        #expect(paths(Self.path.validate(.object(["points": .array([point(.number(1)), point(.number(101))])]))) == ["/points/1/x"])
        #expect(paths(Self.path.validate(.object(["points": .array([point(.number(1)), .object([:])])]))) == ["/points/1/x"])
        #expect(paths(Self.path.validate(.object(["points": .array(Array(repeating: point(.number(1)), count: 4))]))) == ["/points"])
        #expect(paths(Self.path.validate(.object(["points": .array([])]))) == ["/points"])
    }

    /// Nested issues keep every parent in their pointer, and each fault is its own issue (mutation `.nestedPath`).
    @Test func nestedPathsKeepTheirParents() {
        #expect(rectIssues { $0["size"] = .object(["w": .string("1"), "h": .number(1)]) }
                == [SchemaIssue(path: "/size/w", message: "expected number")])
        #expect(paths(rectIssues { $0["size"] = .object(["w": .string("1")]) }) == ["/size/h", "/size/w"])
        #expect(paths(rectIssues { $0["x"] = .string("1"); $0["z"] = .null; $0["blend"] = .string("screen") }) == ["/blend", "/x", "/z"])
        let deep = ParamSchema.object(["a": .object(["b": .object(["c": .boolean], required: ["c"])], required: ["b"])], required: ["a"])
        #expect(deep.validate(.object(["a": .object(["b": .object(["c": .number(0)])])]))
                == [SchemaIssue(path: "/a/b/c", message: "expected boolean")])
    }
}

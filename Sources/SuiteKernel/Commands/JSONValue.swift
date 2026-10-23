// JSONValue.swift (command-catalog CC-1, real): any JSON value, the currency of params, results and examples.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
/// One JSON value. Numbers are `Double`, as JSON has one number type.
public enum JSONValue: Hashable, Sendable, Codable {
    case null, bool(Bool), number(Double), string(String), array([JSONValue]), object([String: JSONValue])
    /// Reads one JSON value (an object, an array or a bare scalar) from `json`.
    public init(json: Data) throws { self = try JSONDecoder().decode(JSONValue.self, from: json) }
    /// The value as JSON text, object keys sorted when `sorted` so equal values write equal bytes.
    public func json(sorted: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        if sorted { encoder.outputFormatting = [.sortedKeys] }
        return try encoder.encode(self)
    }
    /// The JSON value `value` encodes to.
    public init<T: Encodable>(encoding value: T) throws { self = try JSONValue(json: JSONEncoder().encode(value)) }
    /// Decodes a `T` from this value, as if it were read from its JSON text.
    public func decode<T: Decodable>(_ type: T.Type) throws -> T { try JSONDecoder().decode(type, from: json()) }
    /// Reads null, then a bool, a number, a string, an array and an object, in that order.
    public init(from decoder: any Decoder) throws {
        let box = try decoder.singleValueContainer()
        if box.decodeNil() { self = .null }
        else if let value = try? box.decode(Bool.self) { self = .bool(value) }
        else if let value = try? box.decode(Double.self) { self = .number(value) }
        else if let value = try? box.decode(String.self) { self = .string(value) }
        else if let value = try? box.decode([JSONValue].self) { self = .array(value) }
        else { self = .object(try box.decode([String: JSONValue].self)) }
    }
    /// Writes the value as the matching JSON value.
    public func encode(to encoder: any Encoder) throws {
        var box = encoder.singleValueContainer()
        switch self {
        case .null: try box.encodeNil()
        case .bool(let value): try box.encode(value)
        case .number(let value): try box.encode(value)
        case .string(let value): try box.encode(value)
        case .array(let value): try box.encode(value)
        case .object(let value): try box.encode(value)
        }
    }
}

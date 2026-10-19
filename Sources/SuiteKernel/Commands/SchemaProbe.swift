// SchemaProbe.swift (command-catalog CC-1 contract, CC-5 body): a params schema read from a `Decodable` type
// by running its `init(from:)` once on a recording decoder that answers every request with a placeholder.

/// Derives a `ParamSchema` from a `Decodable` type.
public enum SchemaProbe {
    /// The schema `T`'s `init(from:)` asks for, read by running it on a recording decoder.
    /// `decodeIfPresent` keys stay out of `required`; nested types recurse up to `maxDepth` typed levels,
    /// then read as an open `{}`. An init that throws on a placeholder keeps the keys read before it.
    public static func schema<T: Decodable>(of type: T.Type, maxDepth: Int = 8) -> ParamSchema {
        let root = ProbeNode(depth: 1, maxDepth: maxDepth)
        _ = try? root.value(type)
        return root.schema()
    }
}

/// Overrides the probe where it can't see enough (an enum's cases, a range).
public protocol CommandSchemaProviding {
    /// The hand-written schema the probe returns for this type.
    static var paramSchema: ParamSchema { get }
}

/// Thrown where the probe stops on purpose: past the depth cap.
private struct ProbeStop: Error {}

/// What the probe recorded for one value: a fixed schema, an object's keys, an array's element, or another node.
private final class ProbeNode {
    enum Kind { case unread, fixed(ParamSchema), keyed, unkeyed, wraps(ProbeNode) }
    let depth: Int, maxDepth: Int
    var kind = Kind.unread
    var keys: [String] = []
    var fields: [String: (node: ProbeNode, optional: Bool)] = [:]
    var element: ProbeNode?

    init(depth: Int, maxDepth: Int) { (self.depth, self.maxDepth) = (depth, maxDepth) }

    /// A placeholder `T`, recording its schema here: an override, a scalar, or `T`'s own init run on this node.
    func value<T: Decodable>(_ type: T.Type) throws -> T {
        if let provider = type as? any CommandSchemaProviding.Type {
            kind = .fixed(provider.paramSchema)
            return try Self.sample(provider.paramSchema.json).decode(type)
        }
        if let (schema, placeholder) = Self.scalar(type) { kind = .fixed(schema); return placeholder }
        guard depth <= maxDepth else {
            kind = .fixed(ParamSchema(json: .object(["description": .string("Not probed past depth \(maxDepth).")])))
            throw ProbeStop()
        }
        return try T(from: ProbeDecoder(node: self))
    }

    /// The node for object key `name`, one level down; the first read of a key decides whether it is optional.
    func field(_ name: String, optional: Bool) -> ProbeNode {
        if let known = fields[name] { return known.node }
        let child = ProbeNode(depth: depth + 1, maxDepth: maxDepth)
        keys.append(name)
        fields[name] = (child, optional)
        return child
    }

    /// The array element's node, one level down.
    func item() -> ProbeNode {
        let child = element ?? ProbeNode(depth: depth + 1, maxDepth: maxDepth)
        element = child
        return child
    }

    /// The schema recorded so far.
    func schema() -> ParamSchema {
        switch kind {
        case .unread: return .none
        case .fixed(let schema): return schema
        case .wraps(let inner): return inner.schema()
        case .unkeyed: return .array(of: element?.schema() ?? ParamSchema(json: .object([:])))
        case .keyed:
            let properties = fields.mapValues { field in Self.mark(field.node.schema(), optional: field.optional) }
            return .object(properties, required: keys)
        }
    }

    private static func mark(_ schema: ParamSchema, optional: Bool) -> ParamSchema { optional ? .optional(schema) : schema }

    /// The schema and placeholder of a JSON scalar type, nil for any other type.
    private static func scalar<T>(_ type: T.Type) -> (ParamSchema, T)? {
        switch type {
        case is Bool.Type: return (false as? T).map { (.boolean, $0) }
        case is String.Type: return ("" as? T).map { (.string(), $0) }
        case is Double.Type: return (Double(0) as? T).map { (.number(), $0) }
        case is Float.Type: return (Float(0) as? T).map { (.number(), $0) }
        default:
            guard let integer = type as? any FixedWidthInteger.Type, let zero = integer.zero as? T else { return nil }
            return (.integer(), zero)
        }
    }

    /// A value that `json` accepts: the first enum case, the lower bound, or the type's empty value.
    private static func sample(_ json: JSONValue) -> JSONValue {
        guard case .object(let schema) = json else { return .null }
        if case .array(let cases)? = schema["enum"], let first = cases.first { return first }
        switch schema["type"] {
        case .string("object")?:
            guard case .object(let properties)? = schema["properties"] else { return .object([:]) }
            return .object(properties.mapValues(sample))
        case .string("array")?: return .array([])
        case .string("string")?: return .string("")
        case .string("boolean")?: return .bool(false)
        default: return schema["minimum"] ?? schema["maximum"] ?? .number(0)
        }
    }
}

/// The recording decoder: each container it hands out writes into `node`.
private struct ProbeDecoder: Decoder {
    let node: ProbeNode
    var codingPath: [any CodingKey] { [] }
    var userInfo: [CodingUserInfoKey: Any] { [:] }
    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedDecodingContainer<Key> {
        node.kind = .keyed
        return KeyedDecodingContainer(ProbeKeyed<Key>(node: node))
    }
    func unkeyedContainer() -> any UnkeyedDecodingContainer { node.kind = .unkeyed; return ProbeUnkeyed(node: node) }
    func singleValueContainer() -> any SingleValueDecodingContainer { ProbeSingle(node: node) }
}

/// An object: every key is present and not null; `decode` records it required, `decodeIfPresent` optional.
private struct ProbeKeyed<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let node: ProbeNode
    var codingPath: [any CodingKey] { [] }
    var allKeys: [Key] { [] }
    func contains(_ key: Key) -> Bool { true }
    func decodeNil(forKey key: Key) -> Bool { false }
    func need<T: Decodable>(_ type: T.Type, _ key: Key) throws -> T { try node.field(key.stringValue, optional: false).value(type) }
    func maybe<T: Decodable>(_ type: T.Type, _ key: Key) -> T? { try? node.field(key.stringValue, optional: true).value(type) }
    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T { try need(type, key) }
    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool { try need(type, key) }
    func decode(_ type: String.Type, forKey key: Key) throws -> String { try need(type, key) }
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double { try need(type, key) }
    func decode(_ type: Float.Type, forKey key: Key) throws -> Float { try need(type, key) }
    func decode(_ type: Int.Type, forKey key: Key) throws -> Int { try need(type, key) }
    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 { try need(type, key) }
    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 { try need(type, key) }
    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 { try need(type, key) }
    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 { try need(type, key) }
    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt { try need(type, key) }
    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 { try need(type, key) }
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { try need(type, key) }
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { try need(type, key) }
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { try need(type, key) }
    func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: Key) -> T? { maybe(type, key) }
    func decodeIfPresent(_ type: Bool.Type, forKey key: Key) -> Bool? { maybe(type, key) }
    func decodeIfPresent(_ type: String.Type, forKey key: Key) -> String? { maybe(type, key) }
    func decodeIfPresent(_ type: Double.Type, forKey key: Key) -> Double? { maybe(type, key) }
    func decodeIfPresent(_ type: Float.Type, forKey key: Key) -> Float? { maybe(type, key) }
    func decodeIfPresent(_ type: Int.Type, forKey key: Key) -> Int? { maybe(type, key) }
    func decodeIfPresent(_ type: Int8.Type, forKey key: Key) -> Int8? { maybe(type, key) }
    func decodeIfPresent(_ type: Int16.Type, forKey key: Key) -> Int16? { maybe(type, key) }
    func decodeIfPresent(_ type: Int32.Type, forKey key: Key) -> Int32? { maybe(type, key) }
    func decodeIfPresent(_ type: Int64.Type, forKey key: Key) -> Int64? { maybe(type, key) }
    func decodeIfPresent(_ type: UInt.Type, forKey key: Key) -> UInt? { maybe(type, key) }
    func decodeIfPresent(_ type: UInt8.Type, forKey key: Key) -> UInt8? { maybe(type, key) }
    func decodeIfPresent(_ type: UInt16.Type, forKey key: Key) -> UInt16? { maybe(type, key) }
    func decodeIfPresent(_ type: UInt32.Type, forKey key: Key) -> UInt32? { maybe(type, key) }
    func decodeIfPresent(_ type: UInt64.Type, forKey key: Key) -> UInt64? { maybe(type, key) }
    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) -> KeyedDecodingContainer<NestedKey> {
        ProbeDecoder(node: node.field(key.stringValue, optional: false)).container(keyedBy: type)
    }
    func nestedUnkeyedContainer(forKey key: Key) -> any UnkeyedDecodingContainer {
        ProbeDecoder(node: node.field(key.stringValue, optional: false)).unkeyedContainer()
    }
    func superDecoder() -> any Decoder { ProbeDecoder(node: node) }
    func superDecoder(forKey key: Key) -> any Decoder { ProbeDecoder(node: node.field(key.stringValue, optional: false)) }
}

/// An array of exactly one element, which records the element's schema.
private struct ProbeUnkeyed: UnkeyedDecodingContainer {
    let node: ProbeNode
    var codingPath: [any CodingKey] { [] }
    var count: Int? { 1 }
    var currentIndex = 0
    var isAtEnd: Bool { currentIndex > 0 }
    init(node: ProbeNode) { self.node = node }
    mutating func decodeNil() -> Bool { false }
    mutating func next<T: Decodable>(_ type: T.Type) throws -> T { currentIndex += 1; return try node.item().value(type) }
    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T { try next(type) }
    mutating func decode(_ type: Bool.Type) throws -> Bool { try next(type) }
    mutating func decode(_ type: String.Type) throws -> String { try next(type) }
    mutating func decode(_ type: Double.Type) throws -> Double { try next(type) }
    mutating func decode(_ type: Float.Type) throws -> Float { try next(type) }
    mutating func decode(_ type: Int.Type) throws -> Int { try next(type) }
    mutating func decode(_ type: Int8.Type) throws -> Int8 { try next(type) }
    mutating func decode(_ type: Int16.Type) throws -> Int16 { try next(type) }
    mutating func decode(_ type: Int32.Type) throws -> Int32 { try next(type) }
    mutating func decode(_ type: Int64.Type) throws -> Int64 { try next(type) }
    mutating func decode(_ type: UInt.Type) throws -> UInt { try next(type) }
    mutating func decode(_ type: UInt8.Type) throws -> UInt8 { try next(type) }
    mutating func decode(_ type: UInt16.Type) throws -> UInt16 { try next(type) }
    mutating func decode(_ type: UInt32.Type) throws -> UInt32 { try next(type) }
    mutating func decode(_ type: UInt64.Type) throws -> UInt64 { try next(type) }
    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) -> KeyedDecodingContainer<NestedKey> {
        currentIndex += 1
        return ProbeDecoder(node: node.item()).container(keyedBy: type)
    }
    mutating func nestedUnkeyedContainer() -> any UnkeyedDecodingContainer {
        currentIndex += 1
        return ProbeDecoder(node: node.item()).unkeyedContainer()
    }
    mutating func superDecoder() -> any Decoder { currentIndex += 1; return ProbeDecoder(node: node.item()) }
}

/// One value, never null, read through a node one level down so a self-wrapping type still meets the cap.
private struct ProbeSingle: SingleValueDecodingContainer {
    let node: ProbeNode
    var codingPath: [any CodingKey] { [] }
    func decodeNil() -> Bool { false }
    func read<T: Decodable>(_ type: T.Type) throws -> T {
        let inner = ProbeNode(depth: node.depth + 1, maxDepth: node.maxDepth)
        node.kind = .wraps(inner)
        return try inner.value(type)
    }
    func decode<T: Decodable>(_ type: T.Type) throws -> T { try read(type) }
    func decode(_ type: Bool.Type) throws -> Bool { try read(type) }
    func decode(_ type: String.Type) throws -> String { try read(type) }
    func decode(_ type: Double.Type) throws -> Double { try read(type) }
    func decode(_ type: Float.Type) throws -> Float { try read(type) }
    func decode(_ type: Int.Type) throws -> Int { try read(type) }
    func decode(_ type: Int8.Type) throws -> Int8 { try read(type) }
    func decode(_ type: Int16.Type) throws -> Int16 { try read(type) }
    func decode(_ type: Int32.Type) throws -> Int32 { try read(type) }
    func decode(_ type: Int64.Type) throws -> Int64 { try read(type) }
    func decode(_ type: UInt.Type) throws -> UInt { try read(type) }
    func decode(_ type: UInt8.Type) throws -> UInt8 { try read(type) }
    func decode(_ type: UInt16.Type) throws -> UInt16 { try read(type) }
    func decode(_ type: UInt32.Type) throws -> UInt32 { try read(type) }
    func decode(_ type: UInt64.Type) throws -> UInt64 { try read(type) }
}

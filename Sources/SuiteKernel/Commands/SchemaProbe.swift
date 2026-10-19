// SchemaProbe.swift (command-catalog CC-1 stub, CC-5 body): a params schema read from a `Decodable` type.

/// Derives a `ParamSchema` from a `Decodable` type.
public enum SchemaProbe {
    /// The schema `T`'s `init(from:)` asks for, read by running it on a recording decoder.
    /// CC-1 stub: a `CommandSchemaProviding` type's own schema, else `.none`, until command-catalog CC-5.
    public static func schema<T: Decodable>(of type: T.Type, maxDepth: Int = 8) -> ParamSchema {
        (type as? any CommandSchemaProviding.Type)?.paramSchema ?? .none
    }
}

/// Overrides the probe where it can't see enough (an enum's cases, a range).
public protocol CommandSchemaProviding {
    /// The hand-written schema the probe returns for this type.
    static var paramSchema: ParamSchema { get }
}

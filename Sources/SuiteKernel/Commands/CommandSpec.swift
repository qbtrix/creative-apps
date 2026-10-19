// CommandSpec.swift (command-catalog CC-1 stub, CC-7 body): one command an app registers.
/// What a command touches: `query` reads only; `view` changes view state (zoom, selection, playhead), not undoable;
/// `edit` changes the document, exactly one undo step; `file` reads or writes files outside it (import, export).
public enum CommandKind: String, Hashable, Sendable, Codable { case query, view, edit, file }

/// Whether a command can run now, and if not, why not in the app's words.
public enum Availability: Hashable, Sendable {
    case available, unavailable(String)
    /// The why-not, nil when the command can run.
    public var why: String? { if case .unavailable(let why) = self { why } else { nil } }
}

/// One command on a `Target` document: what menus, the CLI, MCP and tests run.
public struct CommandSpec<Target>: Sendable {
    /// "layer.add": lowercase, dots and hyphens, at most 64, stable; a retired id is never reused.
    public let id: String
    /// "Add Layer": the menu title and the undo step's name.
    public let title: String
    /// One or two sentences for a person and a model.
    public let summary: String
    /// What the command touches.
    public let kind: CommandKind
    /// True for an edit: a run records exactly one undo step.
    public var undoable: Bool { kind == .edit }
    /// The params and result schemas.
    public let params: ParamSchema, result: ParamSchema
    /// Params that run on the app's fixture document.
    public let example: JSONValue
    /// Whether the command can run on a target, and why not.
    public let availability: @Sendable (Target) -> Availability
    /// Runs on a target with JSON params, returning the JSON result.
    let run: @Sendable (inout Target, JSONValue) throws -> JSONValue
    /// A spec whose params decode as `P` and whose result encodes `R`; `schema` overrides the probe of `P`.
    /// Params that validate but don't decode as `P` throw `malformedParams` before `run` is called.
    public static func typed<P: Decodable & Sendable, R: Encodable>(
        _ id: String, title: String, summary: String, kind: CommandKind,
        params: P.Type, schema: ParamSchema? = nil, result: ParamSchema = .none, example: JSONValue,
        availability: @escaping @Sendable (Target) -> Availability = { _ in .available },
        run: @escaping @Sendable (inout Target, P) throws -> R) -> CommandSpec {
        CommandSpec(id: id, title: title, summary: summary, kind: kind, params: schema ?? SchemaProbe.schema(of: P.self),
                    result: result, example: example, availability: availability) { target, json in
            let decoded: P
            do { decoded = try json.decode(P.self) } catch { throw CatalogError.malformedParams(id: id, [issue(error)]) }
            return try JSONValue(encoding: try run(&target, decoded))
        }
    }
    /// A decoding error as one schema issue: the JSON pointer it names and what it says.
    static func issue(_ error: any Error) -> SchemaIssue {
        let context: DecodingError.Context?, last: (any CodingKey)?
        switch error as? DecodingError {
        case .typeMismatch(_, let c)?, .valueNotFound(_, let c)?, .dataCorrupted(let c)?: (context, last) = (c, nil)
        case .keyNotFound(let key, let c)?: (context, last) = (c, key)
        default: (context, last) = (nil, nil)
        }
        let keys = (context?.codingPath ?? []) + (last.map { [$0] } ?? [])
        let path = keys.map { "/" + ($0.intValue.map(String.init) ?? $0.stringValue) }.joined()
        return SchemaIssue(path: path, message: context?.debugDescription ?? String(describing: error))
    }
}

/// What `describe`, `list-commands` and MCP publish for one command.
public struct CommandDescription: Codable, Hashable, Sendable {
    /// The app ("photo"), the command's id, title and summary, its kind and whether it is an edit.
    public var app, id, title, summary: String; public var kind: CommandKind; public var undoable: Bool
    /// The params and result schemas, and the example params.
    public var params, result, example: JSONValue
    public init(app: String, id: String, title: String, summary: String, kind: CommandKind, undoable: Bool,
                params: JSONValue, result: JSONValue, example: JSONValue) {
        (self.app, self.id, self.title, self.summary, self.kind, self.undoable) = (app, id, title, summary, kind, undoable)
        (self.params, self.result, self.example) = (params, result, example)
    }
}

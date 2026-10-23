// MCPTools.swift (afterglow-mcp MC-1 contract, MC-6 body): the tools
// `tools/list` publishes. Session tools come first (each app's `open` and
// `new`, then `afterglow.save`, `afterglow.export` and `afterglow.close`),
// then every app's commands in catalog id order as `<app>.<id>` with input
// `{doc, params}`: the command's params schema nested under `params`. The
// annotations come from the command's kind; `route` maps a name back.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One tool as `tools/list` describes it.
public struct MCPTool: Codable, Hashable, Sendable {
    public var name, title, description: String
    public var inputSchema: JSONValue; public var outputSchema: JSONValue?; public var annotations: JSONValue

    public init(name: String, title: String, description: String, inputSchema: JSONValue, outputSchema: JSONValue? = nil,
                annotations: JSONValue = .object([:])) {
        (self.name, self.title, self.description, self.inputSchema) = (name, title, description, inputSchema)
        (self.outputSchema, self.annotations) = (outputSchema, annotations)
    }
}

/// What a tool name runs: a session tool, or one command of one app.
public enum MCPRoute: Hashable, Sendable {
    case open(app: String), new(app: String), save, export, close, command(app: String, id: String)
}

/// The tool list and the name to route mapping.
public enum MCPTools {
    /// The prefix of the session tools that work on any app's document.
    public static let suite = "afterglow"

    /// Every tool for `apps`: session tools first, then every app's commands by id. The same on every call.
    public static func list(_ apps: [HeadlessApp]) -> [MCPTool] {
        let opening = apps.flatMap { app in [open(app.name), new(app.name)] }
        let commands = apps.flatMap { app in app.describeAll().sorted { $0.id < $1.id }.map(tool) }
        return opening + [save, export, close] + commands
    }

    /// The tool name of `command` in `app`: "photo.layer.add".
    public static func name(app: String, command: String) -> String { "\(app).\(command)" }

    /// What the tool `name` runs among `apps`, or nil for an unknown tool (JSON-RPC -32602).
    public static func route(_ name: String, in apps: [HeadlessApp]) -> MCPRoute? {
        switch name {
        case "\(suite).save": return .save
        case "\(suite).export": return .export
        case "\(suite).close": return .close
        default: break
        }
        guard let dot = name.firstIndex(of: "."), let app = Apps.named(String(name[..<dot]), in: apps) else { return nil }
        let rest = String(name[name.index(after: dot)...])
        if rest == "open" { return .open(app: app.name) }
        if rest == "new" { return .new(app: app.name) }
        return app.describeAll().contains { $0.id == rest } ? .command(app: app.name, id: rest) : nil
    }

    /// `<app>.<id>`: the command's title and summary, input `{doc, params}`, output `{result, undoStep?}`.
    static func tool(_ command: CommandDescription) -> MCPTool {
        let undo = command.kind == .edit ? " Undoable: one step named '\(command.title)'." : ""
        var output: [String: JSONValue] = ["result": command.result]
        if command.kind == .edit { output["undoStep"] = string("the undo step the edit recorded") }
        return MCPTool(name: name(app: command.app, command: command.id), title: command.title, description: command.summary + undo,
                       inputSchema: object(["doc": docSchema, "params": command.params], required: ["doc"]),
                       outputSchema: object(output, required: []), annotations: annotations(command))
    }

    /// Hints from the command's kind: a query only reads; a view or an edit (undoable) changes the document but destroys
    /// nothing; a file command is destructive only when it can overwrite (`force`).
    static func annotations(_ command: CommandDescription) -> JSONValue {
        var hints: [String: JSONValue] = ["readOnlyHint": .bool(command.kind == .query), "openWorldHint": .bool(false)]
        switch command.kind {
        case .query: break
        case .view, .edit: hints["destructiveHint"] = .bool(false)
        case .file:
            if case .object(let properties)? = field(command.params, "properties") { hints["destructiveHint"] = .bool(properties["force"] != nil) }
            else { hints["destructiveHint"] = .bool(false) }
        }
        return .object(hints)
    }

    static func open(_ app: String) -> MCPTool {
        session("\(app).open", "Open \(app) Document",
                "Opens a \(app) file inside the allowed roots and returns its document handle; "
                    + "handles expire after 1 hour idle; at most 16 open.",
                input: object(["path": string("the file to open, inside an allowed root")], required: ["path"]), output: opened)
    }

    static func new(_ app: String) -> MCPTool {
        session("\(app).new", "New \(app) Document", "Creates a new \(app) document and returns its handle.",
                input: object(["options": .object(["type": .string("object"), "description": .string("the app's new-document options")])],
                              required: []), output: opened)
    }

    static let save = session("\(suite).save", "Save Document",
                              "Saves a document in its app's native format, to its own path or `path`; an existing file needs `force`.",
                              input: object(["doc": docSchema, "path": string("where to save, inside an allowed root"), "force": flag],
                                            required: ["doc"]),
                              output: object(["path": string("the file written")], required: []), destructive: true)
    static let export = session("\(suite).export", "Export Document",
                                "Exports a document in `format` to `path`; an existing file needs `force`.",
                                input: object(["doc": docSchema, "format": string("one of the app's export formats"),
                                               "path": string("where to write, inside an allowed root"),
                                               "options": .object(["type": .string("object")]), "force": flag],
                                              required: ["doc", "format", "path"]),
                                output: object(["path": string("the file written")], required: []), destructive: true)
    static let close = session("\(suite).close", "Close Document", "Closes a document handle without saving.",
                               input: object(["doc": docSchema], required: ["doc"]), output: object([:], required: []))

    static func session(_ name: String, _ title: String, _ description: String, input: JSONValue, output: JSONValue,
                        destructive: Bool = false) -> MCPTool {
        MCPTool(name: name, title: title, description: description, inputSchema: input, outputSchema: output,
                annotations: .object(["readOnlyHint": .bool(false), "destructiveHint": .bool(destructive), "openWorldHint": .bool(false)]))
    }

    static let docSchema = string("the document handle from open or new")
    static let flag = JSONValue.object(["type": .string("boolean"), "description": .string("overwrite an existing file")])
    static let opened = object(["doc": docSchema, "summary": .object(["type": .string("object")])], required: ["doc", "summary"])

    static func string(_ description: String) -> JSONValue { .object(["type": .string("string"), "description": .string(description)]) }
    static func object(_ properties: [String: JSONValue], required: [String]) -> JSONValue {
        .object(["type": .string("object"), "properties": .object(properties), "required": .array(required.map(JSONValue.string))])
    }
    static func field(_ value: JSONValue, _ key: String) -> JSONValue? { if case .object(let body) = value { body[key] } else { nil } }
}

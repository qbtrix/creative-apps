// MCPTools.swift (afterglow-mcp MC-1 contract, MC-6 body): the tools
// `tools/list` publishes, session tools first, then `<app>.<command id>`
// with input `{doc, params}`. `name` is real; `list` and `route` are stubs.
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
    /// Every tool for `apps`: session tools first, then every app's commands by id.
    /// Stub: no tools until MC-6.
    public static func list(_ apps: [HeadlessApp]) -> [MCPTool] { [] }

    /// The tool name of `command` in `app`: "photo.layer.add".
    public static func name(app: String, command: String) -> String { "\(app).\(command)" }

    /// What the tool `name` runs among `apps`, or nil for an unknown tool (JSON-RPC -32602).
    /// Stub: nil until MC-6.
    public static func route(_ name: String, in apps: [HeadlessApp]) -> MCPRoute? { nil }
}

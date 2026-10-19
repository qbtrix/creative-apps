// MCPSessions.swift (afterglow-mcp MC-1 contract, MC-8 body): the documents
// an MCP client has open, by expiring handle, read and written only under
// the roots. Stub: every call is a tool error naming MC-8.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// What one `tools/call` returns: `structuredContent`, the text content, and whether it is a tool error.
public struct MCPToolResult: Hashable, Sendable {
    public var structured: JSONValue; public var text: String; public var isError: Bool
    public init(structured: JSONValue, text: String, isError: Bool) { (self.structured, self.text, self.isError) = (structured, text, isError) }

    /// A tool error the model can act on: `text` says why and what to do.
    public static func error(_ text: String) -> MCPToolResult { MCPToolResult(structured: .object(["error": .string(text)]), text: text, isError: true) }
}

/// The open documents, by opaque handle.
public struct MCPSessions: Sendable {
    /// The server's apps, roots and limits.
    public let options: MCPOptions
    let io: any CLIIO

    public init(_ options: MCPOptions, io: any CLIIO) { (self.options, self.io) = (options, io) }

    /// Runs `route` with the call's `arguments` at `now` (seconds), expiring idle handles first.
    /// Stub: a tool error naming MC-8.
    public mutating func call(_ route: MCPRoute, _ arguments: JSONValue, now: Double) -> MCPToolResult {
        .error("tools/call is not built yet (afterglow-mcp MC-8)")
    }
}

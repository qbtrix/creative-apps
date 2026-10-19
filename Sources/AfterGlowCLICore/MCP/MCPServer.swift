// MCPServer.swift (afterglow-cli CL-2 stub; afterglow-mcp MC-1 contract, MC-4
// body): `afterglow mcp`, every app's command catalog as MCP tools over
// stdio. Until MC-4, `serve` exits 69 and `handle` errors naming MC-4.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// What one `afterglow mcp` run serves: its apps, the folders it may read and write, and its limits.
public struct MCPOptions: Sendable {
    /// The apps whose catalogs become tools, the allowed roots, and whether `--live` bridges running apps (macOS).
    public var apps: [HeadlessApp]; public var roots: [String]; public var live: Bool
    /// The most documents open at once, how long an idle handle lives, and the call rate limit.
    public var maxOpen = 16; public var idleSeconds = 3600.0; public var maxCallsPerSecond = 50

    public init(apps: [HeadlessApp], roots: [String], live: Bool = false) { (self.apps, self.roots, self.live) = (apps, roots, live) }
}

/// The MCP server behind `afterglow mcp`: one JSON-RPC line in, at most one line out.
public final class MCPServer: Sendable {
    /// The packet that builds the server.
    public static let slice = "afterglow-mcp"

    /// What this server serves, where it reads and writes, and its time source in seconds.
    public let options: MCPOptions
    let io: any CLIIO
    let clock: @Sendable () -> Double

    public init(_ options: MCPOptions, io: any CLIIO, clock: @escaping @Sendable () -> Double) { (self.options, self.io, self.clock) = (options, io, clock) }

    /// Answers one message: the reply line without its newline, or nil for a notification.
    /// Stub: replies to every line (id null) with `RPCError.notBuilt` naming MC-4 and `data.supportedVersions`.
    public func handle(_ line: Data) -> Data? {
        var error = RPCError.notBuilt("MCPServer.handle", task: "MC-4")
        error.data = .object(["supportedVersions": .array(MCPVersions.supported.map(JSONValue.string))])
        return JSONRPC.reply(nil, error: error)
    }

    /// Serves `apps` over MCP with `arguments` (what follows `afterglow mcp`). Returns the exit code.
    /// Stub: exits 69 (`notBuilt`) with "afterglow-mcp is not built yet".
    public static func serve(_ arguments: [String], apps: [HeadlessApp], io: any CLIIO) -> Int32 {
        CLI.notBuilt("\(slice) is not built yet", io: io)
    }
}

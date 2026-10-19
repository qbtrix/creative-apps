// MCPServer.swift (afterglow-cli CL-2 stub; the afterglow-mcp packet fills
// it): `afterglow mcp`, which serves every app's command catalog as MCP
// tools over stdio. Until that packet lands it exits 69.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The MCP server behind `afterglow mcp`.
public enum MCPServer {
    /// The packet that builds the server.
    public static let slice = "afterglow-mcp"

    /// Serves `apps` over MCP with `arguments` (what follows `afterglow mcp`). Returns the exit code.
    /// Stub: exits 69 (`notBuilt`) with "afterglow-mcp is not built yet".
    public static func serve(_ arguments: [String], apps: [HeadlessApp], io: any CLIIO) -> Int32 {
        CLI.notBuilt("\(slice) is not built yet", io: io)
    }
}

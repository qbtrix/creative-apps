// MCPVersions.swift (afterglow-mcp MC-1, real): the Model Context Protocol
// revisions `afterglow mcp` speaks, pinned from the published specification,
// https://modelcontextprotocol.io/specification/versioning (checked
// 2026-10-19; current revision https://modelcontextprotocol.io/specification/2026-07-28).
// 2026-07-28 is sessionless (`_meta` per request, `server/discover`); the
// handshake era sends `initialize` first. stdio: one JSON-RPC 2.0 line each.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The protocol revisions the server answers, and how it picks one for a request.
public enum MCPVersions {
    /// The newest revision, used when a request names none.
    public static let current = "2026-07-28"
    /// Every revision the server answers, newest first.
    public static let supported = ["2026-07-28", "2025-11-25", "2025-06-18"]
    /// The `_meta` key a sessionless request carries its revision under.
    public static let metaKey = "io.modelcontextprotocol/protocolVersion"
    /// The revisions that start with `initialize` (the handshake era).
    public static let handshakeEra: Set<String> = ["2025-11-25", "2025-06-18"]

    /// The revision to answer `requested` in: `current` when none is named, the same revision when the
    /// server supports it, and nil when it doesn't (the caller replies with the unsupported-version error).
    public static func negotiate(_ requested: String?) -> String? {
        guard let requested else { return current }
        return supported.contains(requested) ? requested : nil
    }
}

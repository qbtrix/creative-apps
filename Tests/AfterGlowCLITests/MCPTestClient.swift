// MCPTestClient.swift (afterglow-mcp MC-2, test support): an in-process MCP
// client over `MCPServer.handle` (or any line transport) that speaks both
// protocol eras. Sessionless (2026-07-28): every request carries its version
// under `_meta`. Handshake (2025-11-25, 2025-06-18): `initialize` first, then
// `notifications/initialized`, then plain requests. Each request must get
// exactly one well-formed reply echoing its id, and a notification none; the
// client throws otherwise, so a server that answers twice or not at all fails.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import AfterGlowCLICore

struct MCPTestClient {
    /// The protocol era and the revision the client speaks in it.
    enum Era: Hashable, Sendable {
        case sessionless(String), handshake(String)
        var version: String { switch self { case .sessionless(let version), .handshake(let version): version } }
    }

    /// Why an exchange broke the protocol; each names the method sent.
    enum Failure: Error, Hashable {
        case noReply(String), extraReplies(String, count: Int), repliedToNotification(String)
        case notAnEnvelope(String), idMismatch(String, sent: JSONValue, got: JSONValue), notInitialized(String)
    }

    /// One reply envelope: its id and exactly one of `result` or `error`.
    struct Reply: Hashable {
        var id: JSONValue; var result: JSONValue?; var error: [String: JSONValue]?
        var errorCode: Double? { if case .number(let code)? = error?["code"] { code } else { nil } }
        var errorMessage: String? { if case .string(let text)? = error?["message"] { text } else { nil } }
    }

    let era: Era
    private let transport: (Data) -> Data?
    /// Every message sent, in order, as JSON.
    private(set) var sent: [JSONValue] = []
    /// Whether the handshake finished (always true in the sessionless era).
    private(set) var initialized: Bool
    private var nextID = 1

    /// A client over `transport`: one line in (no newline), the reply lines out or nil.
    init(era: Era, transport: @escaping (Data) -> Data?) {
        (self.era, self.transport) = (era, transport)
        if case .sessionless = era { initialized = true } else { initialized = false }
    }

    /// A client over `server.handle`, in process.
    init(_ server: MCPServer, era: Era) { self.init(era: era, transport: server.handle) }

    /// Handshake era: sends `initialize`; on a result, sends `notifications/initialized` and is ready.
    mutating func initialize(client: String = "afterglow-tests") throws -> Reply {
        let reply = try request("initialize", params: [
            "protocolVersion": .string(era.version), "capabilities": .object([:]),
            "clientInfo": .object(["name": .string(client), "version": .string("1")]),
        ])
        if reply.result != nil {
            initialized = true
            try notify("notifications/initialized")
        }
        return reply
    }

    /// Sends `server/discover`.
    mutating func discover() throws -> Reply { try request("server/discover") }

    /// Sends one request and returns its only reply, or throws how the exchange broke the protocol.
    mutating func request(_ method: String, params: [String: JSONValue] = [:]) throws -> Reply {
        guard initialized || method == "initialize" else { throw Failure.notInitialized(method) }
        let id = JSONValue.number(Double(nextID))
        nextID += 1
        let lines = try exchange(method, id: id, params: params)
        guard let line = lines.first else { throw Failure.noReply(method) }
        guard lines.count == 1 else { throw Failure.extraReplies(method, count: lines.count) }
        guard case .object(let body)? = try? JSONValue(json: line), body["jsonrpc"] == .string("2.0"),
              let got = body["id"], (body["result"] == nil) != (body["error"] == nil) else { throw Failure.notAnEnvelope(method) }
        var error: [String: JSONValue]?
        if let value = body["error"] {
            guard case .object(let object) = value else { throw Failure.notAnEnvelope(method) }
            error = object
        }
        // A null id is allowed only on an error: JSON-RPC's answer when the request's id couldn't be read.
        guard got == id || (got == .null && error != nil) else { throw Failure.idMismatch(method, sent: id, got: got) }
        return Reply(id: got, result: body["result"], error: error)
    }

    /// Sends one notification, which must get no reply.
    mutating func notify(_ method: String, params: [String: JSONValue] = [:]) throws {
        guard try exchange(method, id: nil, params: params).isEmpty else { throw Failure.repliedToNotification(method) }
    }

    /// Frames the message for the era, sends it, and splits what came back into its non-empty lines.
    private mutating func exchange(_ method: String, id: JSONValue?, params: [String: JSONValue]) throws -> [Data] {
        var params = params
        if case .sessionless(let version) = era {
            var meta: [String: JSONValue] = [:]
            if case .object(let given)? = params["_meta"] { meta = given }
            meta[MCPVersions.metaKey] = .string(version)
            params["_meta"] = .object(meta)
        }
        var envelope: [String: JSONValue] = ["jsonrpc": .string("2.0"), "method": .string(method), "params": .object(params)]
        if let id { envelope["id"] = id }
        sent.append(.object(envelope))
        guard let out = transport(try JSONValue.object(envelope).json()) else { return [] }
        return out.split(separator: UInt8(ascii: "\n")).map { Data($0) }.filter { !$0.allSatisfy { $0 == UInt8(ascii: "\r") } }
    }
}

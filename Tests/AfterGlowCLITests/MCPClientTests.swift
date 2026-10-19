// MCPClientTests.swift: MJ0's client checks (afterglow-mcp MC-2). The test
// client frames each era right, gets exactly one reply per request (two or
// none fail), checks the envelope echoes the id, and reaches the real
// server in process (MC-4).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import AfterGlowCLICore
import Testing

struct MCPClientTests {
    typealias Client = MCPTestClient
    static let eras: [Client.Era] = [.sessionless(MCPVersions.current), .handshake("2025-06-18")]
    static func server() -> MCPServer { MCPServer(MCPOptions(apps: [Apps.fake], roots: ["/tmp/mcp"]), io: FakeIO(), clock: { 0 }) }

    /// A well-behaved server: echoes each request's id with `{method}`, and stays silent on notifications.
    static func echo(_ line: Data) -> Data? {
        guard case .object(let body)? = try? JSONValue(json: line), let id = body["id"] else { return nil }
        return try? JSONValue.object(["jsonrpc": .string("2.0"), "id": id, "result": .object(["method": body["method"] ?? .null])]).json()
    }

    /// The era's first request: `initialize` in the handshake era, `server/discover` otherwise.
    static func first(_ client: inout Client) throws -> Client.Reply {
        if case .handshake = client.era { return try client.initialize() }
        return try client.discover()
    }

    static func method(of request: JSONValue?) -> JSONValue? { if case .object(let body)? = request { body["method"] } else { nil } }
    static func params(of request: JSONValue?) -> [String: JSONValue] {
        if case .object(let body)? = request, case .object(let params)? = body["params"] { params } else { [:] }
    }

    @Test func discoverReachesTheServerAndGetsTheSupportedVersions() throws {
        var client = Client(Self.server(), era: .sessionless(MCPVersions.current))
        let reply = try client.discover()
        #expect(reply.id == .number(1) && reply.error == nil)
        guard case .object(let result)? = reply.result else { Issue.record("no result: \(reply)"); return }
        #expect(result["supportedVersions"] == .array(MCPVersions.supported.map(JSONValue.string)))
    }

    @Test func handshakeWithAnUnsupportedVersionStopsAfterTheRefusedInitialize() throws {
        var client = Client(Self.server(), era: .handshake("2024-11-05"))
        let reply = try client.initialize()
        #expect(reply.errorCode == -32602 && !client.initialized && client.sent.count == 1)
        #expect(reply.error?["data"] == .object(["supportedVersions": .array(MCPVersions.supported.map(JSONValue.string)),
                                                 "requested": .string("2024-11-05")]))
        #expect(throws: Client.Failure.notInitialized("tools/list")) { try client.request("tools/list") }
    }

    @Test func sessionlessEraPutsTheVersionInEveryRequestsMeta() throws {
        var client = Client(era: .sessionless("2026-07-28"), transport: Self.echo)
        #expect(try client.discover().result == .object(["method": .string("server/discover")]))
        let reply = try client.request("tools/list", params: ["_meta": .object(["progressToken": .number(9)])])
        #expect(reply.id == .number(2))
        #expect(client.sent.map { Self.method(of: $0) } == [.string("server/discover"), .string("tools/list")])
        #expect(Self.params(of: client.sent.last)["_meta"]
                == .object([MCPVersions.metaKey: .string("2026-07-28"), "progressToken": .number(9)]))
        try client.notify("notifications/cancelled")
        #expect(client.sent.count == 3 && Self.params(of: client.sent.last)["_meta"] != nil)
    }

    @Test func handshakeEraSendsInitializeFirstThenInitialized() throws {
        var client = Client(era: .handshake("2025-06-18"), transport: Self.echo)
        #expect(throws: Client.Failure.notInitialized("tools/list")) { try client.request("tools/list") }
        #expect(client.sent.isEmpty)
        #expect(try client.initialize().id == .number(1) && client.initialized)
        #expect(try client.request("tools/list").id == .number(2))
        #expect(client.sent.map { Self.method(of: $0) }
                == [.string("initialize"), .string("notifications/initialized"), .string("tools/list")])
        let initialize = Self.params(of: client.sent.first)
        #expect(initialize["protocolVersion"] == .string("2025-06-18") && initialize["_meta"] == nil)
        #expect(client.sent.allSatisfy { Self.params(of: $0)["_meta"] == nil })
    }

    @Test(arguments: eras) func twoRepliesToOneRequestFail(era: Client.Era) {
        var client = Client(era: era, transport: { line in Self.echo(line).map { $0 + Data("\n".utf8) + $0 } })
        let method = era == .sessionless(MCPVersions.current) ? "server/discover" : "initialize"
        #expect(throws: Client.Failure.extraReplies(method, count: 2)) { try Self.first(&client) }
    }

    @Test(arguments: eras) func noReplyToARequestFails(era: Client.Era) {
        for silent in [{ (_: Data) in nil }, { (_: Data) in Data("\n".utf8) }] as [(Data) -> Data?] {
            var client = Client(era: era, transport: silent)
            let method = era == .sessionless(MCPVersions.current) ? "server/discover" : "initialize"
            #expect(throws: Client.Failure.noReply(method)) { try Self.first(&client) }
        }
    }

    @Test(arguments: eras) func theReplyMustEchoTheRequestsID(era: Client.Era) throws {
        var good = Client(era: era, transport: Self.echo)
        #expect(try Self.first(&good).id == .number(1))
        for wrong in [JSONValue.number(2), .string("1"), .null] {
            let replace = { (line: Data) -> Data? in
                guard case .object(var body)? = Self.echo(line).flatMap({ try? JSONValue(json: $0) }) else { return nil }
                body["id"] = wrong
                return try? JSONValue.object(body).json()
            }
            var client = Client(era: era, transport: replace)
            let method = era == .sessionless(MCPVersions.current) ? "server/discover" : "initialize"
            #expect(throws: Client.Failure.idMismatch(method, sent: .number(1), got: wrong)) { try Self.first(&client) }
        }
    }

    @Test func aReplyThatIsNotAnEnvelopeFails() {
        let bodies = ["hello", #"{"id":1,"result":{}}"#, #"{"jsonrpc":"2.0","id":1}"#,
                      #"{"jsonrpc":"2.0","id":1,"result":{},"error":{"code":1}}"#, #"{"jsonrpc":"2.0","id":1,"error":"x"}"#]
        for body in bodies {
            var client = Client(era: .sessionless(MCPVersions.current), transport: { _ in Data(body.utf8) })
            #expect(throws: Client.Failure.notAnEnvelope("server/discover")) { try client.discover() }
        }
    }

    @Test func aReplyToANotificationFails() {
        var client = Client(era: .sessionless(MCPVersions.current), transport: { _ in Data(#"{"jsonrpc":"2.0","id":null,"result":{}}"#.utf8) })
        #expect(throws: Client.Failure.repliedToNotification("notifications/cancelled")) { try client.notify("notifications/cancelled") }
    }

    @Test(arguments: eras)
    func theRealServerAnswersEachEraOnceWithItsID(era: Client.Era) throws {
        var client = Client(Self.server(), era: era)
        let reply = try Self.first(&client)
        #expect(reply.id == .number(1) && reply.error == nil)
        #expect(try client.request("tools/list").id == .number(2))
    }
}

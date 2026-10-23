// MCPShapeTests.swift: MJ0's shape checks (afterglow-mcp MC-1). Every
// contract type exists; the versions are pinned newest first and
// `negotiate` refuses an unknown one; the built parts answer (MC-4 built
// the server, MCPProtocolTests covers it; MC-6 the tools, MCPToolsTests;
// MC-8 the calls, MCPCallTests); the fake approval flow.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import AfterGlowCLICore
import SuiteModel
import Testing

struct MCPShapeTests {
    static let options = MCPOptions(apps: [Apps.fake], roots: ["/tmp/mcp"])

    @Test func versionsArePinnedNewestFirst() {
        #expect(MCPVersions.current == "2026-07-28")
        #expect(MCPVersions.supported == ["2026-07-28", "2025-11-25", "2025-06-18"])
        #expect(MCPVersions.supported == MCPVersions.supported.sorted(by: >))
        #expect(MCPVersions.handshakeEra == ["2025-11-25", "2025-06-18"])
        #expect(MCPVersions.metaKey == "io.modelcontextprotocol/protocolVersion")
        for version in MCPVersions.supported { #expect(MCPVersions.negotiate(version) == version) }
        #expect(MCPVersions.negotiate(nil) == MCPVersions.current)
    }

    @Test(arguments: ["2024-01-01", "2024-11-05", "2025-03-26", "2027-01-01", "", "latest"])
    func negotiateRefusesAnUnknownVersion(requested: String) {
        #expect(MCPVersions.negotiate(requested) == nil)
    }

    @Test func idsAndRepliesAreJSONRPC() throws {
        for id in [RPCID.number(7), .string("a-1")] {
            #expect(try JSONDecoder().decode(RPCID.self, from: JSONEncoder().encode(id)) == id)
        }
        #expect(RPCRequest(id: nil, method: "notifications/cancelled").params == nil)
        #expect(JSONRPC.maxLineBytes == 16 << 20)
        let ok = try JSONValue(json: JSONRPC.reply(.number(1), result: .object(["a": .bool(true)])))
        #expect(ok == .object(["jsonrpc": .string("2.0"), "id": .number(1), "result": .object(["a": .bool(true)])]))
        let failed = try JSONValue(json: JSONRPC.reply(nil, error: RPCError(code: RPCError.parseError, message: "Parse error")))
        #expect(failed == .object(["jsonrpc": .string("2.0"), "id": .null,
                                   "error": .object(["code": .number(-32700), "message": .string("Parse error")])]))
    }

    @Test func serverOptionsHaveThePacketsLimits() {
        let server = MCPServer(Self.options, io: FakeIO(), clock: { 0 })
        #expect(server.options.maxOpen == 16 && server.options.idleSeconds == 3600 && server.options.maxCallsPerSecond == 50)
        #expect(!server.options.live && server.options.roots == ["/tmp/mcp"])
    }

    @Test func toolsRouteBackAndSessionsCall() {
        #expect(MCPTools.name(app: "photo", command: "layer.add") == "photo.layer.add")
        #expect(!MCPTools.list([Apps.fake]).isEmpty)
        #expect(MCPTools.route("fake.rect.add", in: [Apps.fake]) == .command(app: "fake", id: "rect.add"))
        #expect(Set<MCPRoute>([.open(app: "f"), .new(app: "f"), .save, .export, .close, .command(app: "f", id: "a")]).count == 6)
        #expect(MCPTool(name: "fake.rect.list", title: "List", description: "d", inputSchema: .null).annotations == .object([:]))
        var sessions = MCPSessions(Self.options, io: FakeIO())
        let text = "there is no file at /tmp/mcp/a.fake"
        #expect(sessions.call(.open(app: "fake"), .object(["path": .string("a.fake")]), now: 0)
                    == MCPToolResult(structured: .object(["error": .string(text)]), text: text, isError: true))
    }

    @Test func aFileCommandAsksAndTheFakeFlowConnectsAllowOnceUntilStop() {
        var grants = AIAccessGrants()
        grants.record(.alwaysForClient, client: "c", app: "photo")
        #expect(grants.allows(client: "c", app: "photo", kind: CommandKind.file.rawValue) == nil)
        grants.revoke(client: "c", app: nil)
        #expect(grants.entries.isEmpty)
        var access = FakeAIAccess(app: "photo")
        access.request(client: FakeAIAccess.demoClient)
        #expect(access.pending == AIAccessRequest(client: "Test Client", app: "photo") && access.connectedClient == nil)
        access.decide(.allowOnce)
        #expect(access.pending == nil && access.connectedClient == "Test Client")
        access.stop()
        access.request(client: FakeAIAccess.demoClient)
        #expect(access.connectedClient == nil && access.pending?.client == "Test Client")
        access.decide(.deny)
        #expect(access.pending == nil && access.connectedClient == nil)
        #expect(access.grants.entries == [AIAccessEntry(client: "Test Client", app: "photo", decision: .deny)])
    }
}

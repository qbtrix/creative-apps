// MCPProtocolTests.swift: MJ1's protocol checks (afterglow-mcp MC-3, written
// first; MC-4 builds `JSONRPC.parse` and `MCPServer.handle` and turns them
// on). One JSON-RPC message per line: bad JSON is -32700, JSON that isn't a
// request (or a line over the cap) is -32600, an unknown method -32601, a
// notification gets nothing. `server/discover` and per-request `_meta`
// (2026-07-28) and `initialize` (handshake era) are each answered once in
// the negotiated version; an unknown version gets the error listing the
// supported ones. `handle` never prints: stdout carries only its replies.
// `serve` reads its arguments strictly and answers stdin line by line.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import AfterGlowCLICore
import Testing

struct MCPProtocolTests {
    typealias Client = MCPTestClient
    static let root = "/tmp/mcp"
    static let supported = JSONValue.array(MCPVersions.supported.map(JSONValue.string))

    static func server(_ io: FakeIO = FakeIO()) -> MCPServer { MCPServer(MCPOptions(apps: [Apps.fake], roots: [root]), io: io, clock: { 0 }) }

    /// The reply `server` writes for the raw line `text`, as an envelope's fields; nil when it wrote none.
    static func send(_ server: MCPServer, _ text: String) throws -> [String: JSONValue]? {
        try send(server, Data(text.utf8))
    }
    static func send(_ server: MCPServer, _ line: Data) throws -> [String: JSONValue]? {
        guard let out = server.handle(line) else { return nil }
        #expect(!out.contains(UInt8(ascii: "\n")), "a reply is one line, without its newline")
        guard case .object(let body) = try JSONValue(json: out) else { Issue.record("not an object"); return [:] }
        #expect(body["jsonrpc"] == .string("2.0") && (body["result"] == nil) != (body["error"] == nil))
        return body
    }
    static func field(_ value: JSONValue?, _ key: String) -> JSONValue? { if case .object(let o)? = value { o[key] } else { nil } }
    static func code(_ body: [String: JSONValue]?) -> JSONValue? { field(body?["error"], "code") }
    /// The code `JSONRPC.parse` refuses `line` with; nil when it reads a request.
    static func parseCode(_ line: String) -> Int? { if case .failure(let error) = JSONRPC.parse(Data(line.utf8)) { error.code } else { nil } }

    @Test
    func parseReadsRequestsAndNotifications() throws {
        let request = try JSONRPC.parse(Data(#"{"jsonrpc":"2.0","id":"a-1","method":"tools/list","params":{"x":1}}"#.utf8)).get()
        #expect(request == RPCRequest(id: .string("a-1"), method: "tools/list", params: .object(["x": .number(1)])))
        let note = try JSONRPC.parse(Data(#"{"jsonrpc":"2.0","method":"notifications/initialized"}"#.utf8)).get()
        #expect(note.id == nil && note.method == "notifications/initialized" && note.params == nil)
        #expect(try JSONRPC.parse(Data(#"{"jsonrpc":"2.0","id":7,"method":"server/discover"}"#.utf8)).get().id == .number(7))
    }

    @Test
    func discoverAnswersTheVersionsCapabilitiesAndServerInfo() throws {
        let body = try #require(try Self.send(Self.server(), #"{"jsonrpc":"2.0","id":1,"method":"server/discover"}"#))
        #expect(body["id"] == .number(1))
        #expect(Self.field(body["result"], "supportedVersions") == Self.supported)
        #expect(Self.field(Self.field(body["result"], "capabilities"), "tools") == .object(["listChanged": .bool(false)]))
        #expect(Self.field(Self.field(body["result"], "serverInfo"), "name") == .string("afterglow"))
        var client = Client(Self.server(), era: .sessionless(MCPVersions.current))
        #expect(Self.field(try client.discover().result, "supportedVersions") == Self.supported)
    }

    @Test(arguments: ["2025-11-25", "2025-06-18"])
    func initializeIsAnsweredInTheRequestedVersion(version: String) throws {
        var client = Client(Self.server(), era: .handshake(version))
        let reply = try client.initialize()
        #expect(reply.error == nil && client.initialized)
        #expect(Self.field(reply.result, "protocolVersion") == .string(version))
        #expect(Self.field(Self.field(reply.result, "capabilities"), "tools") != nil)
        #expect(Self.field(Self.field(reply.result, "serverInfo"), "name") == .string("afterglow"))
        let list = try client.request("tools/list")
        #expect(list.id == .number(2) && list.error == nil)
    }

    @Test(arguments: MCPVersions.supported)
    func eachSupportedVersionIsAnsweredOnceWithItsID(version: String) throws {
        let era: Client.Era = MCPVersions.handshakeEra.contains(version) ? .handshake(version) : .sessionless(version)
        var client = Client(Self.server(), era: era)
        let first = MCPVersions.handshakeEra.contains(version) ? try client.initialize() : try client.discover()
        #expect(first.id == .number(1) && first.error == nil)
        #expect(try client.request("tools/list").error == nil)
        try client.notify("notifications/cancelled", params: ["requestId": .number(2)])
    }

    @Test(arguments: [
        #"{"jsonrpc":"2.0","id":1,"method":"server/discover","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"2024-01-01"}}}"#,
        #"{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"2025-03-26"}}}"#,
        #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-01-01","capabilities":{}}}"#,
    ])
    func unsupportedVersionListed(line: String) throws {
        let body = try #require(try Self.send(Self.server(), line))
        #expect(body["id"] == .number(1) && body["result"] == nil)
        #expect(Self.code(body) == .number(Double(RPCError.invalidParams)))
        #expect(Self.field(Self.field(body["error"], "data"), "supportedVersions") == Self.supported)
    }

    @Test(arguments: ["{bad json", "[", #"{"jsonrpc":"2.0","id":1,"method":"#, "\u{1}", "nul"])
    func parseErrorIs32700(line: String) throws {
        let body = try #require(try Self.send(Self.server(), line))
        #expect(body["id"] == .null && Self.code(body) == .number(-32700))
        #expect(Self.parseCode(line) == -32700)
    }

    @Test
    func invalidUTF8IsAParseError() throws {
        let body = try #require(try Self.send(Self.server(), Data([0x7B, 0xFF, 0xFE, 0x7D])))
        #expect(body["id"] == .null && Self.code(body) == .number(-32700))
    }

    @Test(arguments: [
        "42", "[]", #"[{"jsonrpc":"2.0","id":1,"method":"server/discover"}]"#, #"{"id":1,"method":"server/discover"}"#,
        #"{"jsonrpc":"1.0","id":1,"method":"server/discover"}"#, #"{"jsonrpc":"2.0","id":1}"#,
        #"{"jsonrpc":"2.0","id":1,"method":7}"#, #"{"jsonrpc":"2.0","id":true,"method":"server/discover"}"#,
        #"{"jsonrpc":"2.0","id":1,"method":"server/discover","params":"x"}"#,
    ])
    func invalidRequestIs32600(line: String) throws {
        let body = try #require(try Self.send(Self.server(), line))
        #expect(body["id"] == .null && Self.code(body) == .number(-32600))
        #expect(Self.parseCode(line) == -32600)
    }

    @Test
    func aLineOverTheCapIsAnInvalidRequestAndOneAtTheCapIsRead() throws {
        let request = Data(#"{"jsonrpc":"2.0","id":1,"method":"server/discover"}"#.utf8)
        let atCap = request + Data(repeating: UInt8(ascii: " "), count: JSONRPC.maxLineBytes - request.count)
        #expect(atCap.count == JSONRPC.maxLineBytes)
        let read = try #require(try Self.send(Self.server(), atCap))
        #expect(read["id"] == .number(1) && read["error"] == nil)
        let over = try #require(try Self.send(Self.server(), atCap + Data(" ".utf8)))
        #expect(over["id"] == .null && Self.code(over) == .number(-32600))
    }

    @Test(arguments: ["resources/list", "prompts/get", "nope"])
    func methodNotFoundIs32601(method: String) throws {
        let line = #"{"jsonrpc":"2.0","id":4,"method":"\#(method)"}"#
        let body = try #require(try Self.send(Self.server(), line))
        #expect(body["id"] == .number(4) && Self.code(body) == .number(-32601))
    }

    @Test(arguments: [
        #"{"jsonrpc":"2.0","method":"notifications/initialized"}"#,
        #"{"jsonrpc":"2.0","method":"notifications/cancelled","params":{"requestId":3,"reason":"user"}}"#,
        #"{"jsonrpc":"2.0","method":"notifications/unknown"}"#, #"{"jsonrpc":"2.0","method":"tools/list"}"#,
        #"{"jsonrpc":"2.0","method":"server/discover","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"2024-01-01"}}}"#,
        #"{"jsonrpc":"2.0","method":"tools/call","params":{"name":"nope.tool","arguments":{}}}"#,
    ])
    func notificationsUnanswered(line: String) throws {
        let io = FakeIO()
        #expect(Self.server(io).handle(Data(line.utf8)) == nil)
        #expect(io.stdout.isEmpty && io.files.isEmpty)
    }

    @Test
    func handleNeverPrintsSoStdoutCarriesOnlyReplies() throws {
        let io = FakeIO()
        let server = Self.server(io)
        let lines = ["{bad json", "[]", #"{"jsonrpc":"2.0","id":1,"method":"server/discover"}"#,
                     #"{"jsonrpc":"2.0","id":2,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{}}}"#,
                     #"{"jsonrpc":"2.0","method":"notifications/initialized"}"#, #"{"jsonrpc":"2.0","id":3,"method":"tools/list"}"#,
                     #"{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"nope.tool","arguments":{}}}"#,
                     #"{"jsonrpc":"2.0","id":5,"method":"nope"}"#]
        let replies = try lines.map { try Self.send(server, $0) }
        #expect(replies.map { $0 == nil } == [false, false, false, false, true, false, false, false])
        #expect(io.stdout.isEmpty)
    }

    /// A seeded generator so a failing fuzz case comes back on every run (xorshift64*).
    struct Seeded: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state ^= state >> 12; state ^= state << 25; state ^= state >> 27
            return state &* 2_685_821_657_736_338_717
        }
    }

    static let fuzzSeeds = [
        #"{"jsonrpc":"2.0","id":1,"method":"server/discover","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28"}}}"#,
        #"{"jsonrpc":"2.0","id":"i","method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{}}}"#,
        #"{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{"cursor":null}}"#,
        #"{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"afterglow.save","arguments":{"doc":"x","path":"/etc/a.fake","force":true}}}"#,
        #"{"jsonrpc":"2.0","method":"notifications/cancelled","params":{"requestId":3}}"#,
    ]

    @Test(arguments: fuzzSeeds.indices)
    func fuzzedRequestsNeverCrash(kind: Int) throws {
        let io = FakeIO()
        let server = Self.server(io)
        var random = Seeded(state: 0x9E37_79B9_7F4A_7C15 &+ UInt64(kind))
        let alphabet = Array(#"{}[]",:0123456789-.eE truefalsnul\"#.utf8) + [0x00, 0xFF]
        for _ in 0..<1000 {
            var bytes = Array(Self.fuzzSeeds[kind].utf8)
            for _ in 0..<Int.random(in: 1...4, using: &random) {
                let at = Int.random(in: 0..<bytes.count, using: &random)
                switch Int.random(in: 0..<3, using: &random) {
                case 0: bytes[at] = alphabet.randomElement(using: &random) ?? 0
                case 1: if bytes.count > 1 { bytes.remove(at: at) }
                default: bytes.insert(alphabet.randomElement(using: &random) ?? 0, at: at)
                }
            }
            if let out = server.handle(Data(bytes)) {
                guard case .object(let body) = try JSONValue(json: out) else { Issue.record("not an envelope"); continue }
                #expect((body["result"] == nil) != (body["error"] == nil))
            }
        }
        #expect(io.stdout.isEmpty)
        #expect(io.files.keys.allSatisfy { $0.hasPrefix(Self.root + "/") })
    }

    static let serveArguments = ["--app", "fake", "--root", root]

    @Test func serveAnswersEachRequestLineAndExitsWhenStdinEnds() throws {
        let lines = [#"{"jsonrpc":"2.0","id":1,"method":"server/discover"}"#, "", #"{"jsonrpc":"2.0","method":"notifications/initialized"}"#,
                     "{bad json", #"{"jsonrpc":"2.0","id":2,"method":"ping"}"#]
        let io = FakeIO(stdin: lines.map { Data($0.utf8) })
        #expect(MCPServer.serve(Self.serveArguments, apps: [Apps.fake], io: io) == 0)
        let replies = try io.stdout.map { try JSONValue(json: Data($0.utf8)) }
        #expect(replies.map { Self.field($0, "id") } == [.number(1), .null, .number(2)])
        #expect(Self.field(Self.field(replies.first, "result"), "supportedVersions") == Self.supported)
        #expect(Self.field(replies.last, "result") == .object([:]) && io.stderr.isEmpty)
    }

    @Test(arguments: [[], ["--app", "fake"], ["--root"], ["--app", "nope", "--root", root], ["--app", "fake", "--app", "fake", "--root", root],
                      ["--root", root, "--bogus"], ["--root", root, "extra"], ["--root", root, "--live", "--live"], ["--root", ""]])
    func serveRefusesBadArgumentsAsUsage(arguments: [String]) {
        let io = FakeIO(stdin: [Data(#"{"jsonrpc":"2.0","id":1,"method":"ping"}"#.utf8)])
        #expect(MCPServer.serve(arguments, apps: [Apps.fake], io: io) == 64)
        #expect(io.stderr.count == 1 && io.readLine() != nil, "a refused run reads no request")
    }

    @Test func serveLiveRunsOnlyOnMacOSAndAnAppFilterNarrowsTheApps() {
        let io = FakeIO()
        #if !os(macOS)
        #expect(MCPServer.serve(Self.serveArguments + ["--live"], apps: [Apps.fake], io: io) == 69)
        #expect(io.stderr == ["afterglow mcp --live runs only on macOS, where the apps listen"])
        #endif
        #expect(CLI.run(["mcp", "--root", Self.root], io: FakeIO()) == 0)
        #expect(CLI.run(["mcp", "--app", "fake", "--root", Self.root], io: FakeIO()) == 0)
    }

    /// `--live` alone needs no `--root` (#6028): it parses with no roots, and a file tool then refuses saying why.
    @Test func liveAloneNeedsNoRoot() throws {
        let options = try MCPServer.parse(["--live"], apps: [Apps.fake])
        #expect(options.live && options.roots.isEmpty)
        #expect(throws: Refusal.self) { try MCPServer.parse(["--app", "fake"], apps: [Apps.fake]) }
        var sessions = MCPSessions(options, io: FakeIO())
        let opened = sessions.call(.open(app: "fake"), .object(["path": .string("/tmp/mcp/a.fake")]), now: 0)
        #expect(opened.isError && opened.text.contains("start afterglow mcp with --root <dir> to use files"), "\(opened.text)")
    }

    @Test func theRateWindowAdmitsTheLimitPerSecondAndRecordsNoRefusal() {
        var window = RateWindow()
        #expect([0, 0.5].map { window.admit(at: $0, limit: 2) } == [true, true])
        #expect(!window.admit(at: 0.999, limit: 2) && window.times == [0, 0.5])
        #expect(window.admit(at: 1, limit: 2) && window.times == [0.5, 1])
        var closed = RateWindow()
        #expect(!window.admit(at: 1.2, limit: 2) && !closed.admit(at: 0, limit: 0) && closed.times.isEmpty)
    }

    @Test func anUnknownToolAndArgumentsThatAreNotAnObjectAreInvalidParams() throws {
        let unknown = try Self.send(Self.server(), #"{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"nope.tool"}}"#)
        #expect(Self.code(unknown) == .number(-32602) && Self.field(unknown?["error"], "message") == .string("Unknown tool: nope.tool"))
        let bare = try Self.send(Self.server(), #"{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"x","arguments":[]}}"#)
        #expect(Self.code(bare) == .number(-32602))
        let nameless = try Self.send(Self.server(), #"{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{}}"#)
        #expect(Self.code(nameless) == .number(-32602))
    }
}

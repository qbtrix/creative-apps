// LiveBridgeTests.swift (afterglow-mcp MC-11): `afterglow mcp --live` over a
// socket-pair fake app. The fake poses as Photo: it answers LiveWire on its
// end of a socket pair with the fake canvas catalog and a grant switch. The
// bridge lists its tools as `live.photo.<id>`, forwards a call and returns
// the app's answer, turns a missing grant into the approval tool error with
// the document untouched, and skips a dead socket.
import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
@testable import AfterGlowCLICore
import SuiteKernel
import Synchronization
import Testing

/// A running app on one end of a socket pair: LiveWire over the fake canvas, granted or not.
final class FakeLiveApp: Sendable {
    struct State: Sendable { var doc = FakeCanvasDocument.fixture; var granted: Bool; var clients: [String] = [] }
    let state: Mutex<State>
    init(granted: Bool) { state = Mutex(State(granted: granted)) }

    /// A link to this app: a socket pair whose far end a thread serves until the link closes it.
    func link() -> any LiveLink {
        var fds: [Int32] = [-1, -1]
        guard socketpair(AF_UNIX, Glue.stream, 0, &fds) == 0 else { return UnixSocketLink(path: "/nonexistent/pair.sock") }
        let far = fds[1]
        Thread { [self] in
            var buffer: [UInt8] = []
            while let line = try? UnixSocketLink.line(far, &buffer) {
                guard (try? UnixSocketLink.post(far, Array(self.answer(line)) + [UInt8(ascii: "\n")])) != nil else { break }
            }
            close(far)
        }.start()
        return UnixSocketLink(connected: fds[0])
    }

    /// The app's side of LiveWire: describe as Photo, run on the document only with a grant.
    func answer(_ line: Data) -> Data {
        guard case .object(let request)? = try? JSONValue(json: line), case .string(let method)? = request["method"],
              case .object(let params)? = request["params"], case .string(let client)? = params["client"] else { return Data("{}".utf8) }
        let reply = { (body: [String: JSONValue]) in JSONRPC.encode(body.merging(["jsonrpc": .string("2.0"), "id": request["id"] ?? .null]) { a, _ in a }) }
        return state.withLock { state in
            state.clients.append(client)
            if method == LiveWire.describe {
                let commands = FakeCanvasDocument.catalog.describeAll().map { var command = $0; command.app = "photo"; return command }
                return reply(["result": .object(["app": .string("photo"), "title": .string("Photo"),
                                                 "commands": (try? JSONValue(encoding: commands)) ?? .null])])
            }
            guard state.granted else {
                return reply(["error": .object(["code": .number(Double(LiveWire.needsGrant)), "message": .string("approve \(client)")])])
            }
            guard case .string(let id)? = params["id"] else { return reply(["error": .object(["code": .number(-32602), "message": .string("no id")])]) }
            do {
                let outcome = try FakeCanvasDocument.catalog.run(id, params: params["params"] ?? .object([:]), on: &state.doc)
                var result: [String: JSONValue] = ["result": outcome.result]
                if let step = outcome.undoStep { result["undoStep"] = .string(step) }
                return reply(["result": .object(result)])
            } catch {
                return reply(["error": .object(["code": .number(-32000), "message": .string(Refusal(error).message)])])
            }
        }
    }
}

struct LiveBridgeTests {
    static let liveNames = FakeCanvasDocument.catalog.describeAll().map { "live.photo." + $0.id }.sorted()
    static let add: JSONValue = .object(["params": .object(["x": .number(0), "y": .number(0), "w": .number(10), "h": .number(10)])])

    @Test func toolsAreListedFromTheFakeAppsCatalog() {
        let app = FakeLiveApp(granted: true)
        let tools = LiveBridge { [app.link()] }.tools(client: "tests")
        #expect(tools.map(\.name) == Self.liveNames && tools.map(\.name).contains("live.photo.rect.add"))
        #expect(tools.first?.description.hasPrefix("In the open Photo window: ") == true)
        #expect(app.state.withLock { $0.clients } == ["tests"])
    }

    @Test func aCallIsForwardedAndAnswered() {
        let app = FakeLiveApp(granted: true)
        let link = app.link()
        let result = LiveBridge { [link] }.call("live.photo.rect.add", Self.add, client: "tests")
        #expect(result?.isError == false)
        guard case .object(let fields)? = result?.structured else { Issue.record("no structured result"); return }
        #expect(fields["undoStep"] == .string("Add Rectangle"))
        #expect(app.state.withLock { $0.doc.rects.count } == 3)
        let refused = LiveBridge { [link] }.call("live.photo.rect.select", .object(["params": .object(["id": .number(9)])]), client: "tests")
        #expect(refused == .error("There is no rect 9."))
    }

    @Test func aRefusedGrantIsAToolErrorAndRunsNothing() {
        let app = FakeLiveApp(granted: false)
        let result = LiveBridge { [app.link()] }.call("live.photo.rect.add", Self.add, client: "tests")
        #expect(result?.isError == true)
        #expect(result?.text.hasPrefix("Photo asked you to approve this client") == true)
        #expect(app.state.withLock { $0.doc.rects } == FakeCanvasDocument.fixture.rects)
    }

    @Test func aDeadSocketIsSkipped() throws {
        let dir = try #require(mkdtemp(strdup("/tmp/lbXXXXXX")).map { String(cString: $0) })
        defer { try? FileManager.default.removeItem(atPath: dir) }
        // A socket file nothing listens on any more (its app quit without removing it), and a file that isn't a socket.
        let stale = Glue.socket(AF_UNIX, Glue.stream, 0)
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: Array((dir + "/design-1.sock").utf8)) }
        let bound = withUnsafePointer(to: &address) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(stale, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) } }
        close(stale)
        #expect(bound == 0)
        #expect(FileManager.default.createFile(atPath: dir + "/flare-2.sock", contents: Data("x".utf8)))
        #expect(FileManager.default.createFile(atPath: dir + "/notes.txt", contents: Data()))
        let found = LiveBridge.sockets(in: dir)
        #expect(found.compactMap { ($0 as? UnixSocketLink)?.path } == [dir + "/design-1.sock", dir + "/flare-2.sock"])
        #expect(LiveBridge.sockets(in: dir + "/missing").isEmpty)
        let app = FakeLiveApp(granted: true)
        let bridge = LiveBridge { found + [app.link()] }
        #expect(bridge.tools(client: "tests").map(\.name) == Self.liveNames)
        #expect(bridge.call("live.design.rect.add", Self.add, client: "tests")?.text.hasPrefix("Design is not running") == true)
        #expect(bridge.call("live.photo.nope", Self.add, client: "tests") == nil && bridge.call("photo.rect.add", Self.add, client: "t") == nil)
    }

    @Test func theLinkFramesOneLineEachWayOverASocketPair() throws {
        var fds: [Int32] = [-1, -1]
        #expect(socketpair(AF_UNIX, Glue.stream, 0, &fds) == 0)
        let link = UnixSocketLink(connected: fds[0])
        try UnixSocketLink.post(fds[1], Array("{\"a\":1}\n{\"b\":2}\n".utf8))
        #expect(try link.exchange(Data("ping".utf8)) == Data("{\"a\":1}".utf8))
        #expect(try link.exchange(Data("again".utf8)) == Data("{\"b\":2}".utf8), "a second line waits in the buffer")
        var sent: [UInt8] = []
        #expect(try UnixSocketLink.line(fds[1], &sent) == Data("ping".utf8))
        close(fds[1])
        #expect(throws: LiveLinkError.self) { try link.exchange(Data("gone".utf8)) }
        #expect(throws: LiveLinkError.self) { try link.exchange(Data("still gone".utf8)) }
    }

    @Test func theServerListsAndCallsLiveToolsForItsClient() throws {
        let app = FakeLiveApp(granted: true)
        let link = app.link()
        let server = MCPServer(MCPOptions(apps: [Apps.fake], roots: ["/tmp/mcp"]), io: FakeIO(), live: LiveBridge { [link] }) { 0 }
        var client = MCPTestClient(server, era: .handshake("2025-11-25"))
        _ = try client.initialize(client: "Sketchpad")
        guard case .object(let list)? = try client.request("tools/list").result, case .array(let tools)? = list["tools"] else {
            Issue.record("no tool list"); return
        }
        let names = tools.compactMap { tool -> String? in if case .object(let t) = tool, case .string(let n)? = t["name"] { n } else { nil } }
        #expect(names.contains("fake.rect.add") && names.contains("live.photo.rect.add"))
        let call = try client.request("tools/call", params: ["name": .string("live.photo.rect.add"), "arguments": Self.add])
        guard case .object(let body)? = call.result else { Issue.record("no call result"); return }
        #expect(body["isError"] == .bool(false))
        #expect(app.state.withLock { $0.clients.allSatisfy { $0 == "Sketchpad" } && $0.doc.rects.count == 3 })
        #expect(try client.request("tools/call", params: ["name": .string("live.photo.nope")]).errorCode == -32602)
        let headless = MCPServer(MCPOptions(apps: [Apps.fake], roots: ["/tmp/mcp"]), io: FakeIO()) { 0 }
        var plain = MCPTestClient(headless, era: .sessionless("2026-07-28"))
        #expect(try plain.request("tools/call", params: ["name": .string("live.photo.rect.add")]).errorCode == -32602)
    }
}

// MCPCallTests.swift: MJ3's call checks (afterglow-mcp MC-7, written first;
// MC-8 built `MCPSessions.call` behind `tools/call` and turned them on).
// `<app>.open` reads a file under the allowed roots into an expiring handle;
// `<app>.<id> {doc, params}` runs one command through the catalog; why-nots,
// schema issues, refused paths and dead handles are tool errors
// (`isError: true`) the model can act on, never protocol errors; an unknown
// tool is JSON-RPC -32602. Paths are checked after resolving `..` and
// symlinks; at most `maxOpen` handles; a handle idle for `idleSeconds`
// expires; save and export never replace a file without `force`; over
// `maxCallsPerSecond` a call runs nothing and says to slow down.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import AfterGlowCLICore
import Synchronization
import Testing

struct MCPCallTests {
    static let root = "/tmp/mcp", file = root + "/a.fake"
    /// `a.fake`: "Rect 1" locked, "Rect 2" free.
    static let locked = (try? FakeCanvasDocument(rects: [FakeRect(id: 1, name: "Rect 1", x: 0, y: 0, w: 10, h: 10, locked: true),
                                                         FakeRect(id: 2, name: "Rect 2", x: 20, y: 0, w: 10, h: 10)]).save()) ?? Data()
    static let expired = "this document handle expired; open it again"
    static let addParams = JSONValue.object(["x": .number(1), "y": .number(2), "w": .number(3), "h": .number(4)])
    static let noParams = JSONValue.object([:])

    static func options(_ roots: [String] = [root], maxOpen: Int = 16, idle: Double = 3600) -> MCPOptions {
        var options = MCPOptions(apps: [Apps.fake], roots: roots)
        (options.maxOpen, options.idleSeconds) = (maxOpen, idle)
        return options
    }
    static func io() -> FakeIO { FakeIO(files: [file: locked]) }
    static func field(_ value: JSONValue?, _ key: String) -> JSONValue? { if case .object(let o)? = value { o[key] } else { nil } }
    static func path(_ path: String) -> JSONValue { .object(["path": .string(path)]) }

    /// Opens `path` and returns its handle, recording an issue when the open fails.
    static func open(_ sessions: inout MCPSessions, _ path: String = file, now: Double = 0) throws -> JSONValue {
        let result = sessions.call(.open(app: "fake"), Self.path(path), now: now)
        #expect(!result.isError, "\(result.text)")
        return try #require(field(result.structured, "doc"))
    }
    static func run(_ sessions: inout MCPSessions, _ doc: JSONValue, _ id: String, _ params: JSONValue = noParams,
                    now: Double = 0) -> MCPToolResult {
        sessions.call(.command(app: "fake", id: id), .object(["doc": doc, "params": params]), now: now)
    }
    /// The number of rects `rect.list` reports on `doc`, nil when it fails.
    static func count(_ sessions: inout MCPSessions, _ doc: JSONValue, now: Double = 0) -> Int? {
        if case .array(let rects)? = field(run(&sessions, doc, "rect.list", now: now).structured, "result") { rects.count } else { nil }
    }
    /// The first text content of a `tools/call` reply's result.
    static func text(_ result: JSONValue?) -> String {
        guard case .array(let content)? = field(result, "content"), case .string(let text)? = field(content.first, "text") else { return "" }
        return text
    }

    @Test
    func openReturnsAHandleAndTheSummaryAndCommandsRunOnIt() throws {
        var sessions = MCPSessions(Self.options(), io: Self.io())
        let opened = sessions.call(.open(app: "fake"), Self.path(Self.file), now: 0)
        #expect(!opened.isError && Self.field(opened.structured, "summary") == .object(["rects": .number(2), "selected": .null]))
        let doc = try #require(Self.field(opened.structured, "doc"))
        guard case .string(let handle) = doc else { Issue.record("the handle is a string"); return }
        #expect(UUID(uuidString: handle) != nil)
        let added = Self.run(&sessions, doc, "rect.add", Self.addParams)
        #expect(!added.isError && Self.field(added.structured, "undoStep") == .string("Add Rectangle"))
        let afterAdd = Self.count(&sessions, doc)
        let undo = Self.run(&sessions, doc, "edit.undo")
        let afterUndo = Self.count(&sessions, doc)
        #expect(afterAdd == 3 && !undo.isError && afterUndo == 2)
        let made = sessions.call(.new(app: "fake"), Self.noParams, now: 0)
        let fresh = try #require(Self.field(made.structured, "doc"))
        let freshCount = Self.count(&sessions, fresh)
        #expect(!made.isError && fresh != doc && freshCount == 0)
    }

    @Test
    func whyNotIsToolError() throws {
        var sessions = MCPSessions(Self.options(), io: Self.io())
        let doc = try Self.open(&sessions)
        let offset = JSONValue.object(["dx": .number(1), "dy": .number(0)])
        let unselected = Self.run(&sessions, doc, "rect.move", offset)
        #expect(unselected.isError && unselected.text.contains("Select a rectangle first."))
        let select = Self.run(&sessions, doc, "rect.select", .object(["id": .number(1)]))
        let moved = Self.run(&sessions, doc, "rect.move", offset)
        #expect(!select.isError && moved.isError && moved.text.contains("Unlock Rect 1 first."))
        let undo = Self.run(&sessions, doc, "edit.undo")
        #expect(undo.isError && undo.text.contains("There is nothing to undo."))
    }

    @Test
    func schemaIssuesAreToolErrorsNamingEachPath() throws {
        var sessions = MCPSessions(Self.options(), io: Self.io())
        let doc = try Self.open(&sessions)
        let bad = Self.run(&sessions, doc, "rect.add", .object(["x": .string("a"), "y": .number(0), "w": .number(0), "h": .number(1)]))
        #expect(bad.isError && bad.text.contains("/x: expected number") && bad.text.contains("/w:"))
        let notObject = Self.run(&sessions, doc, "rect.add", .string("x"))
        let rects = Self.count(&sessions, doc)
        let noDoc = sessions.call(.command(app: "fake", id: "rect.list"), .object(["params": Self.noParams]), now: 0)
        #expect(notObject.isError && rects == 2 && noDoc.isError)
    }

    @Test
    func throughTheServerAnUnknownToolIsInvalidParamsAndAWhyNotIsAResult() throws {
        let server = MCPServer(Self.options(), io: Self.io(), clock: { 0 })
        var client = MCPTestClient(server, era: .sessionless(MCPVersions.current))
        let unknown = try client.request("tools/call", params: ["name": .string("fake.nope"), "arguments": Self.noParams])
        #expect(unknown.errorCode == -32602 && unknown.errorMessage?.contains("Unknown tool: fake.nope") == true)
        let opened = try client.request("tools/call", params: ["name": .string("fake.open"), "arguments": Self.path(Self.file)])
        let doc = try #require(Self.field(Self.field(opened.result, "structuredContent"), "doc"))
        let undo = try client.request("tools/call", params: ["name": .string("fake.edit.undo"),
                                                             "arguments": .object(["doc": doc, "params": Self.noParams])])
        #expect(undo.error == nil && Self.field(undo.result, "isError") == .bool(true))
        guard case .array(let content)? = Self.field(undo.result, "content") else { Issue.record("no content"); return }
        #expect(Self.field(content.first, "type") == .string("text") && Self.text(undo.result).contains("nothing to undo"))
    }

    @Test(arguments: ["/etc/passwd", "/tmp/mcp/../etc/passwd", "/tmp/mcp-evil/a.fake", "/tmp", "relative/../../x.fake"])
    func pathsOutsideTheRootsAreRefused(path: String) {
        var files = ["/tmp/mcp-evil/a.fake": Self.locked]
        files[path] = Self.locked
        var sessions = MCPSessions(Self.options(), io: FakeIO(files: files))
        let result = sessions.call(.open(app: "fake"), Self.path(path), now: 0)
        #expect(result.isError && result.text.contains("outside the allowed roots"))
    }

    /// A temp root holding `a.fake`, a folder outside it holding `secret.fake`, and links from inside to both.
    static func liveTree() throws -> (base: String, root: String, outside: String) {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("afterglow-mcp-\(UUID().uuidString)").path
        let (root, outside) = (base + "/root", base + "/outside")
        for dir in [root, outside] { try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true) }
        _ = FileManager.default.createFile(atPath: root + "/a.fake", contents: locked)
        _ = FileManager.default.createFile(atPath: outside + "/secret.fake", contents: locked)
        try FileManager.default.createSymbolicLink(atPath: root + "/escape.fake", withDestinationPath: outside + "/secret.fake")
        try FileManager.default.createSymbolicLink(atPath: root + "/sub", withDestinationPath: outside)
        try FileManager.default.createSymbolicLink(atPath: root + "/inside.fake", withDestinationPath: root + "/a.fake")
        return (base, root, outside)
    }

    @Test
    func symlinkEscapeRefused() throws {
        let tree = try Self.liveTree()
        defer { try? FileManager.default.removeItem(atPath: tree.base) }
        var sessions = MCPSessions(Self.options([tree.root]), io: LiveIO())
        for path in [tree.root + "/escape.fake", tree.root + "/sub/secret.fake"] {
            let result = sessions.call(.open(app: "fake"), Self.path(path), now: 0)
            #expect(result.isError && result.text.contains("outside the allowed roots"), "\(path)")
        }
        _ = try Self.open(&sessions, tree.root + "/inside.fake")
        let doc = try Self.open(&sessions, tree.root + "/a.fake")
        let out = sessions.call(.save, .object(["doc": doc, "path": .string(tree.root + "/sub/written.fake")]), now: 0)
        #expect(out.isError && !FileManager.default.fileExists(atPath: tree.outside + "/written.fake"))
    }

    @Test
    func theOpenCapRefusesOneMoreUntilAHandleCloses() throws {
        var sessions = MCPSessions(Self.options(maxOpen: 2), io: Self.io())
        let first = try Self.open(&sessions)
        _ = try Self.open(&sessions)
        let third = sessions.call(.open(app: "fake"), Self.path(Self.file), now: 0)
        let made = sessions.call(.new(app: "fake"), Self.noParams, now: 0)
        let close = sessions.call(.close, .object(["doc": first]), now: 0)
        #expect(third.isError && made.isError && !close.isError)
        let closed = Self.run(&sessions, first, "rect.list")
        #expect(closed.isError && closed.text.contains(Self.expired))
        _ = try Self.open(&sessions)
    }

    @Test
    func idleExpiryInclusive() throws {
        var sessions = MCPSessions(Self.options(idle: 10), io: Self.io())
        let doc = try Self.open(&sessions, now: 0)
        let early = Self.run(&sessions, doc, "rect.list", now: 9.5)
        let renewed = Self.run(&sessions, doc, "rect.list", now: 19)
        #expect(!early.isError && !renewed.isError, "each call restarts the idle time")
        let late = Self.run(&sessions, doc, "rect.list", now: 29)
        #expect(late.isError && late.text.contains(Self.expired))
        let other = try Self.open(&sessions, now: 100)
        _ = try Self.open(&sessions, now: 105)
        let gone = sessions.call(.close, .object(["doc": other]), now: 110)
        #expect(gone.isError && gone.text.contains(Self.expired))
        let unknown = Self.run(&sessions, .string("not-a-handle"), "rect.list", now: 110)
        #expect(unknown.isError && unknown.text.contains(Self.expired))
    }

    @Test
    func saveAndExportRefuseToOverwriteWithoutForce() throws {
        let io = Self.io()
        var sessions = MCPSessions(Self.options(), io: io)
        let doc = try Self.open(&sessions)
        #expect(!Self.run(&sessions, doc, "rect.add", Self.addParams).isError)
        func save(_ path: String, _ force: Bool?) -> MCPToolResult {
            var args: [String: JSONValue] = ["doc": doc, "path": .string(path)]
            if let force { args["force"] = .bool(force) }
            return sessions.call(.save, .object(args), now: 0)
        }
        #expect(save(Self.file, nil).isError && save(Self.file, false).isError && io.files[Self.file] == Self.locked)
        #expect(!save(Self.root + "/b.fake", nil).isError && io.files[Self.root + "/b.fake"] != nil)
        #expect(!save(Self.file, true).isError && io.files[Self.file] != Self.locked)
        #expect(save("/tmp/elsewhere.fake", true).isError && io.files["/tmp/elsewhere.fake"] == nil)
        func export(_ path: String, _ force: Bool, format: String = "json") -> MCPToolResult {
            sessions.call(.export, .object(["doc": doc, "format": .string(format), "path": .string(path), "force": .bool(force)]), now: 0)
        }
        let out = Self.root + "/out.json"
        #expect(!export(out, false).isError)
        let kept = io.files[out]
        let undo = Self.run(&sessions, doc, "edit.undo")
        #expect(kept != nil && !undo.isError)
        #expect(export(out, false).isError && io.files[out] == kept)
        #expect(!export(out, true).isError && io.files[out] != kept)
        #expect(export("/etc/out.json", true).isError && io.files["/etc/out.json"] == nil)
        #expect(export(Self.root + "/out.gif", false, format: "gif").isError && io.files[Self.root + "/out.gif"] == nil)
    }

    /// A clock the test moves.
    final class MovingClock: Sendable {
        private let now = Mutex(0.0)
        var read: @Sendable () -> Double { { [self] in now.withLock { $0 } } }
        func set(_ value: Double) { now.withLock { $0 = value } }
    }

    @Test
    func rateLimited() throws {
        var options = Self.options()
        options.maxCallsPerSecond = 3
        let clock = MovingClock()
        var client = MCPTestClient(MCPServer(options, io: Self.io(), clock: clock.read), era: .sessionless(MCPVersions.current))
        func call(_ name: String, _ args: [String: JSONValue]) throws -> JSONValue? {
            try client.request("tools/call", params: ["name": .string(name), "arguments": .object(args)]).result
        }
        let made = try call("fake.new", [:])
        let doc = try #require(Self.field(Self.field(made, "structuredContent"), "doc"))
        for _ in 0..<2 {
            let added = try call("fake.rect.add", ["doc": doc, "params": Self.addParams])
            #expect(Self.field(added, "isError") == .bool(false))
        }
        let slowed = try call("fake.rect.add", ["doc": doc, "params": Self.addParams])
        #expect(Self.field(slowed, "isError") == .bool(true) && Self.text(slowed).contains("slow down: at most 3 calls a second"))
        clock.set(1.5)
        let list = try call("fake.rect.list", ["doc": doc, "params": Self.noParams])
        guard case .array(let rects)? = Self.field(Self.field(list, "structuredContent"), "result") else { Issue.record("no rects"); return }
        #expect(rects.count == 2, "the refused call ran nothing")
    }

    /// Timing (quality row "call overhead"): p95 of the routing overhead, on the perf list (`Tests/perf-suites.txt`).
    @Test
    func callOverhead() throws {
        var sessions = MCPSessions(Self.options(), io: Self.io())
        let doc = try Self.open(&sessions)
        var document = FakeCanvasDocument()
        let clock = ContinuousClock()
        var overhead: [Duration] = []
        for _ in 0..<200 {
            let direct = clock.measure { _ = try? FakeCanvasDocument.catalog.run("rect.add", params: Self.addParams, on: &document) }
            let routed = clock.measure { _ = Self.run(&sessions, doc, "rect.add", Self.addParams) }
            overhead.append(routed - direct)
        }
        let sorted = overhead.sorted()
        let p95 = sorted.indices.contains(sorted.count * 95 / 100) ? sorted[sorted.count * 95 / 100] : .zero
        #expect(p95 <= .milliseconds(1))
    }
}

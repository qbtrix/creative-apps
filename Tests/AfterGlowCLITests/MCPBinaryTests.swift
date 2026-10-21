// MCPBinaryTests.swift: MJ5 (afterglow-mcp MC-14). The built binary, spawned
// as `afterglow mcp --app fake --root <tmp>`, runs MJ1 to MJ3 over real pipes
// in each protocol era: discover or initialize, an unsupported version, bad
// JSON, a notification, `tools/list`, then open, add, a why-not, a path
// outside the roots, save, close and a dead handle. Every stdout line must be
// one reply envelope (MCPTestClient checks each), nothing is left over when
// stdin closes, the binary exits 0, and its replies equal `MCPServer.handle`'s
// on LiveIO in a twin folder, with the folder and document handles masked.
// Reads are bounded and the binary is killed past the deadline, so a hung
// server fails rather than hangs. The binary is found as CLIBinaryTests finds it.
import AfterGlowCLICore
import Foundation
import Synchronization
import Testing

struct MCPBinaryTests {
    /// One line transport: the in-process server or the spawned binary. Records every reply line it returns.
    final class Wire: Sendable {
        let replies = Mutex<[String]>([])
        let send: @Sendable (Data, Bool) -> Data?
        init(_ send: @escaping @Sendable (Data, Bool) -> Data?) { self.send = send }

        /// Sends `line`; when `answered`, returns its one reply line (recorded), else nil.
        func call(_ line: Data, answered: Bool) -> Data? {
            let reply = send(line, answered)
            if let reply { replies.withLock { $0.append(String(decoding: reply, as: UTF8.self)) } }
            return reply
        }
        func client(_ era: MCPTestClient.Era) -> MCPTestClient {
            MCPTestClient(era: era) { [self] line in
                let answered = (try? JSONValue(json: line)).map { MCPCallTests.field($0, "id") != nil } ?? true
                return call(line, answered: answered)
            }
        }
    }

    /// The spawned binary: stdout is drained on a background queue; a reply is awaited up to `timeout`.
    final class Spawned: Sendable {
        let process: Process, input: Pipe, errors: Pipe
        let buffer = Mutex<(bytes: Data, ended: Bool)>((Data(), false))
        static let timeout = 20.0

        init(root: String) throws {
            (process, input, errors) = (Process(), Pipe(), Pipe())
            let output = Pipe()
            process.executableURL = try #require(CLIBinaryTests.binary)
            process.arguments = ["mcp", "--app", "fake", "--root", root]
            process.currentDirectoryURL = URL(fileURLWithPath: root)
            (process.standardInput, process.standardOutput, process.standardError) = (input, output, errors)
            try process.run()
            let reading = output.fileHandleForReading
            DispatchQueue.global().async { [self] in
                while true {
                    let chunk = reading.availableData
                    if chunk.isEmpty { break }
                    self.buffer.withLock { $0.bytes.append(chunk) }
                }
                self.buffer.withLock { $0.ended = true }
            }
        }

        /// The next complete stdout line, waiting at most `timeout`; nil on timeout or end of output.
        func nextLine(timeout: Double = Spawned.timeout) -> Data? {
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                let line: Data?? = buffer.withLock { state in
                    if let cut = state.bytes.firstIndex(of: UInt8(ascii: "\n")) {
                        let line = Data(state.bytes[state.bytes.startIndex..<cut])
                        state.bytes = Data(state.bytes[(cut + 1)...])
                        return .some(line)
                    }
                    return state.ended ? .some(nil) : nil
                }
                if let line { return line }
                Thread.sleep(forTimeInterval: 0.005)
            }
            return nil
        }

        func wire() -> Wire {
            Wire { [self] line, answered in
                try? input.fileHandleForWriting.write(contentsOf: line + Data("\n".utf8))
                return answered ? nextLine() : nil
            }
        }

        /// Closes stdin and waits for the exit; returns its code, what stdout still held, and stderr. Kills a hung binary.
        func finish() -> (code: Int32?, leftover: String, stderr: String) {
            try? input.fileHandleForWriting.close()
            let deadline = Date().addingTimeInterval(Self.timeout)
            while process.isRunning, Date() < deadline { Thread.sleep(forTimeInterval: 0.01) }
            guard !process.isRunning else { process.terminate(); return (nil, "", "") }
            let ended = Date().addingTimeInterval(Self.timeout)
            while !buffer.withLock({ $0.ended }), Date() < ended { Thread.sleep(forTimeInterval: 0.01) }
            let leftover = buffer.withLock { String(decoding: $0.bytes, as: UTF8.self) }
            let stderr = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            return (process.terminationStatus, leftover, stderr)
        }
    }

    static let eras: [MCPTestClient.Era] = [.sessionless(MCPVersions.current), .handshake("2025-11-25"), .handshake("2025-06-18")]
    static let field = MCPCallTests.field
    static let handshakeTools = ["fake.open", "fake.new", "afterglow.save", "afterglow.export", "afterglow.close"]

    /// A fresh temp folder holding MJ3's `a.fake` (Rect 1 locked), its path.
    static func folder() throws -> String {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("afterglow-mcp-bin-\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
        try MCPCallTests.locked.write(to: URL(fileURLWithPath: root + "/a.fake"))
        return root
    }

    /// MJ1 to MJ3 over `wire` in `era`, with files under `root`; checks each step.
    static func session(_ wire: Wire, era: MCPTestClient.Era, root: String) throws {
        var client = wire.client(era)
        if case .handshake(let version) = era {
            let hello = try client.initialize()
            #expect(field(hello.result, "protocolVersion") == .string(version))
        }
        let discover = try client.discover()
        #expect(field(discover.result, "supportedVersions") == .array(MCPVersions.supported.map(JSONValue.string)))
        #expect(field(field(discover.result, "serverInfo"), "name") == .string("afterglow"))
        let old = #"{"jsonrpc":"2.0","id":"old","method":"tools/list","params":{"_meta":{"\#(MCPVersions.metaKey)":"2024-01-01"}}}"#
        let refused = try JSONValue(json: try #require(wire.call(Data(old.utf8), answered: true)))
        #expect(field(field(refused, "error"), "code") == .number(-32602))
        let bad = try JSONValue(json: try #require(wire.call(Data("{bad json".utf8), answered: true)))
        #expect(field(field(bad, "error"), "code") == .number(-32700) && field(bad, "id") == .null)
        try client.notify("notifications/cancelled", params: ["requestId": .number(1)])

        let listed = try client.request("tools/list")
        guard case .array(let tools)? = field(listed.result, "tools") else { Issue.record("no tools"); return }
        let names = tools.compactMap { if case .string(let name)? = field($0, "name") { name } else { nil } }
        #expect(Array(names.prefix(5)) == handshakeTools && names.count == tools.count)
        let list = tools.first { field($0, "name") == .string("fake.rect.list") }
        #expect(field(field(list, "annotations"), "readOnlyHint") == .bool(true))
        let add = tools.first { field($0, "name") == .string("fake.rect.add") }
        #expect(field(field(field(add, "inputSchema"), "properties"), "params") != nil)

        func call(_ name: String, _ arguments: [String: JSONValue]) throws -> JSONValue? {
            try client.request("tools/call", params: ["name": .string(name), "arguments": .object(arguments)]).result
        }
        func failed(_ result: JSONValue?, saying text: String) -> Bool {
            field(result, "isError") == .bool(true) && MCPCallTests.text(result).contains(text)
        }
        let opened = try call("fake.open", ["path": .string(root + "/a.fake")])
        let doc = try #require(field(field(opened, "structuredContent"), "doc"))
        #expect(field(field(opened, "structuredContent"), "summary") == .object(["rects": .number(2), "selected": .null]))
        let added = try call("fake.rect.add", ["doc": doc, "params": MCPCallTests.addParams])
        #expect(field(field(added, "structuredContent"), "undoStep") == .string("Add Rectangle"))
        _ = try call("fake.rect.select", ["doc": doc, "params": .object(["id": .number(1)])])
        let moved = try call("fake.rect.move", ["doc": doc, "params": .object(["dx": .number(1), "dy": .number(0)])])
        #expect(failed(moved, saying: "Unlock Rect 1 first."))
        #expect(failed(try call("fake.open", ["path": .string("/etc/passwd")]), saying: "outside the allowed roots"))
        let saved = try call("afterglow.save", ["doc": doc, "path": .string(root + "/b.fake")])
        #expect(field(saved, "isError") == .bool(false) && FileManager.default.fileExists(atPath: root + "/b.fake"))
        #expect(field(try call("afterglow.close", ["doc": doc]), "isError") == .bool(false))
        #expect(failed(try call("fake.rect.list", ["doc": doc, "params": .object([:])]), saying: MCPCallTests.expired))
    }

    /// `lines` with `root` and every document handle (a UUID) masked, so two runs compare.
    static func masked(_ lines: [String], root: String) -> [String] {
        lines.map {
            $0.replacingOccurrences(of: root, with: "<root>")
                .replacing(/[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}/, with: "<doc>")
        }
    }

    /// MJ5: the binary runs MJ1 to MJ3 in `era`, prints only replies, exits 0 on stdin's end, and agrees with `handle`.
    @Test(.enabled(if: CLIBinaryTests.built, "afterglow not found beside the test bundle"), arguments: eras)
    func mj5BinaryServesTheJourneyOverPipes(era: MCPTestClient.Era) throws {
        let (binaryRoot, twinRoot) = (try Self.folder(), try Self.folder())
        defer { for root in [binaryRoot, twinRoot] { try? FileManager.default.removeItem(atPath: root) } }
        let spawned = try Spawned(root: binaryRoot)
        let binary = spawned.wire()
        let ran = Result { try Self.session(binary, era: era, root: binaryRoot) }
        let end = spawned.finish()
        try ran.get()
        #expect(end.code == 0, "the binary did not exit 0 on stdin's end (nil: killed after \(Spawned.timeout) s)")
        #expect(end.leftover.isEmpty, "stdout carried lines no request asked for: \(end.leftover)")
        #expect(end.stderr.isEmpty, "\(end.stderr)")

        let server = MCPServer(MCPOptions(apps: [Apps.fake], roots: [twinRoot]), io: LiveIO(), clock: { 0 })
        let twin = Wire { line, _ in server.handle(line) }
        try Self.session(twin, era: era, root: twinRoot)
        let fromBinary = Self.masked(binary.replies.withLock { $0 }, root: binaryRoot)
        let fromHandle = Self.masked(twin.replies.withLock { $0 }, root: twinRoot)
        #expect(fromBinary.count == fromHandle.count)
        for (got, wanted) in zip(fromBinary, fromHandle) { #expect(got == wanted, "the binary and handle disagree") }
    }
}

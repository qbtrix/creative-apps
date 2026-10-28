// LiveCommandChannel.swift (afterglow-mcp MC-10): a running app's end of LiveWire (AfterGlowCLICore's
// LiveBridge.swift): newline-delimited JSON-RPC 2.0 over ~/Library/Application Support/AfterGlow/live/<app>-<pid>.sock
// (folder 0700, socket 0600, dead sockets removed at start), served to peers of this user only. `live/describe`
// answers `{app, title, commands}`; `live/run {client, id, params}` needs a grant (else -32010; `ask` shows the sheet
// while the bridge waits up to 120 s), runs the command through the catalog on the main actor and answers
// `{result, undoStep}`. Each run leaves one AIAccessAuditLine in ~/Library/Logs/AfterGlow/ai-access.log.
import Darwin
import Foundation
import Observation
import SuiteKernel
import SuiteModel
import Synchronization
import SwiftUI

/// Why the channel couldn't listen.
public struct LiveChannelError: Error, CustomStringConvertible, Sendable { public let description: String }

/// One app window's live command socket, started by `.suiteApp(_:host:live:)`.
@MainActor @Observable
public final class LiveCommandChannel {
    /// The client that ran the last granted command on a connection still open; what the chip shows.
    public private(set) var connectedClient: String?

    /// The app's name on the wire ("photo") and in the sheet ("Photo"), and its catalog.
    let app: String, title: String, commands: [CommandDescription]
    /// Runs a command on the window's document and hands the new one to the app; nil with no document open.
    let perform: @MainActor (String, JSONValue) -> Result<CommandOutcome, CatalogError>?
    let ask: @MainActor (AIAccessRequest) async -> AIAccessDecision
    let grants: any PreferencesStoring
    @ObservationIgnored var wire: Wire?
    @ObservationIgnored var path: String?
    /// Per open connection: the client it last ran for, and the client allowed once on it.
    @ObservationIgnored var drivers: [Int: String] = [:]
    @ObservationIgnored var allowedOnce: [Int: String] = [:]

    /// A channel for the window titled `app` whose document is `document()`; `apply` takes the document after a
    /// command changed it, and `ask` shows the approval sheet and returns the user's answer.
    public init<D: HeadlessDocument>(app: String, document: @escaping @MainActor () -> D?, apply: @escaping @MainActor (D) -> Void,
                                     ask: @escaping @MainActor (AIAccessRequest) async -> AIAccessDecision) {
        (self.app, title, commands, self.ask) = (D.app, app, D.catalog.describeAll(), ask)
        perform = { id, params in
            guard var doc = document() else { return nil }
            do throws(CatalogError) { let outcome = try D.catalog.run(id, params: params, on: &doc); apply(doc); return .success(outcome) }
            catch { return .failure(error) }
        }
        let support = SuiteLocations.processSupportFolder
        grants = StorePreferences(store: FileStore(folder: support))
    }

    /// Listens at `<app>-<pid>.sock`; does nothing when already listening.
    public func start() throws {
        guard wire == nil else { return }
        let dir = NSHomeDirectory() + "/Library/Application Support/AfterGlow/live"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        guard chmod(dir, 0o700) == 0 else { throw LiveChannelError(description: "can't make \(dir) private: errno \(errno)") }
        Self.removeStale(app: app, in: dir)
        let path = dir + "/\(app)-\(getpid()).sock", wire = try Wire(listener: Self.listen(at: path))
        (self.wire, self.path) = (wire, path)
        Thread.detachNewThread { [self] in while let fd = wire.next() { Self.admit(fd, wire: wire, channel: self) } }
    }

    /// Stops listening, closes every connection and removes the socket.
    public func stop() {
        wire?.stop()
        if let path { unlink(path) }
        (wire, path, drivers, allowedOnce) = (nil, nil, [:], [:])
        connectedClient = nil
    }

    /// One request line in, one reply line out (without its newline).
    func answer(_ line: [UInt8], connection: Int) async -> [UInt8] {
        guard let parsed = try? JSONValue(json: Data(line)) else { return Self.failure(.null, -32700, "the line isn't JSON") }
        guard case .object(let request) = parsed, case .string(let method)? = request["method"] else {
            return Self.failure(.null, -32600, "send one JSON-RPC request per line")
        }
        let id = request["id"] ?? .null
        let params: [String: JSONValue] = if case .object(let given)? = request["params"] { given } else { [:] }
        let client: String = if case .string(let name)? = params["client"], !name.isEmpty { String(name.prefix(128)) } else { "MCP client" }
        switch method {
        case "live/describe":
            let list = (try? JSONValue(encoding: commands)) ?? .array([])
            return Self.success(id, .object(["app": .string(app), "title": .string(title), "commands": list]))
        case "live/run":
            guard case .string(let command)? = params["id"], let kind = commands.first(where: { $0.id == command })?.kind else {
                return Self.failure(id, -32602, "\(title) has no such command")
            }
            return await run(command, kind, params["params"] ?? .object([:]), client: client, connection: connection, id: id)
        default:
            return Self.failure(id, -32601, "no method \(method)")
        }
    }

    /// Runs `command` for `client` once it holds a grant, asking the user first when it doesn't.
    func run(_ command: String, _ kind: CommandKind, _ params: JSONValue, client: String, connection: Int, id: JSONValue) async -> [UInt8] {
        let audit = { (outcome: String) in Self.audit(AIAccessAuditLine(client: client, app: self.app, id: command, time: Date(), outcome: outcome)) }
        let stored = (try? await AIAccessGrants.load(from: grants)) ?? AIAccessGrants()
        switch stored.verdict(client: client, app: app, kind: kind.rawValue, allowedOnce: allowedOnce[connection] == client) {
        case .run: break
        case .refuse:
            audit("refused")
            return Self.failure(id, -32010, "\(title) refuses \(client)")
        case .ask:
            let asked = ContinuousClock.now
            let decision = await ask(AIAccessRequest(client: client, app: app, command: command))
            if decision != .allowOnce, var latest = try? await AIAccessGrants.load(from: grants) {
                latest.record(decision, client: client, app: app)
                try? await latest.save(to: grants)
            }
            let waited = ContinuousClock.now - asked
            guard AIAccessGrants.answeredInTime(decision: decision, waited: waited) else {
                audit("refused")
                return Self.failure(id, -32010, "\(title) has no answer for \(client) yet")
            }
            // Only an allow once in time holds the connection; a late one (AIAccessCenter.ask with no sheet) doesn't.
            if AIAccessGrants.holdsConnection(decision: decision, kind: kind.rawValue, waited: waited) { allowedOnce[connection] = client }
        }
        (drivers[connection], connectedClient) = (client, client)
        let (outcome, reply): (String, [UInt8]) = switch perform(command, params) {
        case .success(let done)?: ("ran", Self.success(id, .object(["result": done.result, "undoStep": done.undoStep.map(JSONValue.string) ?? .null])))
        case .failure(let error)?: ("failed", Self.failure(id, -32000, error.description))
        case nil: ("failed", Self.failure(id, -32000, "\(title) has no document open; open one, then call again"))
        }
        audit(outcome)
        return reply
    }

    /// A connection closed: its allow once ends and the chip shows the client of another open one, if any.
    func closed(_ connection: Int) {
        (drivers[connection], allowedOnce[connection]) = (nil, nil)
        connectedClient = drivers.max { $0.key < $1.key }?.value
    }

    nonisolated static func success(_ id: JSONValue, _ result: JSONValue) -> [UInt8] { encode(["id": id, "result": result]) }
    nonisolated static func failure(_ id: JSONValue, _ code: Int, _ message: String) -> [UInt8] {
        encode(["id": id, "error": .object(["code": .number(Double(code)), "message": .string(message)])])
    }
    nonisolated static func encode(_ body: [String: JSONValue]) -> [UInt8] {
        Array((try? JSONValue.object(body.merging(["jsonrpc": .string("2.0")]) { $1 }).json()) ?? Data("{}".utf8))
    }

    /// Appends one line to the AI access log (folder 0700, file 0600); a failed write loses only that line.
    nonisolated static func audit(_ line: AIAccessAuditLine) {
        let path = AIAccessAuditLine.path(home: NSHomeDirectory())
        let dir = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let fd = open(path, O_WRONLY | O_APPEND | O_CREAT | O_CLOEXEC, 0o600)
        guard fd >= 0 else { return }
        defer { close(fd) }
        _ = Array(line.text.utf8).withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
    }

    /// Removes `<app>-<pid>.sock` files in `dir` whose process is gone, and this process's own.
    nonisolated static func removeStale(app: String, in dir: String) {
        for name in (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? [] where name.hasPrefix(app + "-") && name.hasSuffix(".sock") {
            let pid = Int32(name.dropFirst(app.count + 1).dropLast(5)) ?? 0
            if pid > 0, pid != getpid(), kill(pid, 0) == 0 || errno == EPERM { continue }
            unlink(dir + "/" + name)
        }
    }

    /// A listening socket at `path`, 0600 before it listens.
    nonisolated static func listen(at path: String) throws -> Int32 {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        let bytes = Array(path.utf8)
        guard bytes.count < MemoryLayout.size(ofValue: address.sun_path) else { throw LiveChannelError(description: "the socket path is too long: \(path)") }
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
        let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw LiveChannelError(description: "no socket: errno \(errno)") }
        _ = fcntl(fd, F_SETFD, FD_CLOEXEC)
        let size = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bound = withUnsafePointer(to: &address) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(fd, $0, size) } }
        guard bound == 0, chmod(path, 0o600) == 0, Darwin.listen(fd, 8) == 0 else {
            let code = errno
            Darwin.close(fd)
            unlink(path)
            throw LiveChannelError(description: "can't listen at \(path): errno \(code)")
        }
        return fd
    }

    /// Serves `fd` on its own thread when its peer runs as this user; otherwise closes it.
    nonisolated static func admit(_ fd: Int32, wire: Wire, channel: LiveCommandChannel) {
        var uid: uid_t = 0, gid: gid_t = 0, one: Int32 = 1
        guard getpeereid(fd, &uid, &gid) == 0, uid == geteuid(), let connection = wire.adopt(fd) else { Darwin.close(fd); return }
        _ = setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))
        Thread.detachNewThread {
            var buffer: [UInt8] = []
            while let line = Self.line(fd, &buffer) {
                let reply = Reply()
                Task { @MainActor in reply.set(await channel.answer(line, connection: connection)) }
                guard Self.post(fd, reply.wait() + [UInt8(ascii: "\n")]) else { break }
            }
            wire.drop(connection)
            Task { @MainActor in channel.closed(connection) }
        }
    }

    /// The next line on `fd`, without its newline; nil when the peer closed, the read failed, or a line passed 16 MiB.
    nonisolated static func line(_ fd: Int32, _ buffer: inout [UInt8]) -> [UInt8]? {
        var chunk = [UInt8](repeating: 0, count: 64 << 10)
        while buffer.count <= 16 << 20 {
            if let end = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                defer { buffer.removeSubrange(...end) }
                return Array(buffer[..<end])
            }
            let count = chunk.withUnsafeMutableBytes { recv(fd, $0.baseAddress, $0.count, 0) }
            if count > 0 { buffer += chunk[..<count] } else if count == 0 || errno != EINTR { return nil }
        }
        return nil
    }

    /// Writes all of `bytes` to `fd`; false when the peer is gone.
    nonisolated static func post(_ fd: Int32, _ bytes: [UInt8]) -> Bool {
        var sent = 0
        while sent < bytes.count {
            let count = bytes.withUnsafeBytes { send(fd, $0.baseAddress.map { $0 + sent }, bytes.count - sent, 0) }
            if count > 0 { sent += count } else if count == 0 || errno != EINTR { return false }
        }
        return true
    }
}

/// The listening socket and the open connections, shared by the accept thread, the connection threads and `stop`.
final class Wire: Sendable {
    struct State { var listener: Int32; var open: [Int: Int32] = [:]; var last = 0 }
    let state: Mutex<State>, stopped = Atomic<Bool>(false)
    init(listener: Int32) { state = Mutex(State(listener: listener)) }

    /// The next accepted connection; nil once stopped, after closing the listener.
    func next() -> Int32? {
        let listener = state.withLock { $0.listener }
        while !stopped.load(ordering: .acquiring) {
            var ready = pollfd(fd: listener, events: Int16(POLLIN), revents: 0)
            guard poll(&ready, 1, 500) > 0 else { continue }
            let fd = accept(listener, nil, nil)
            if fd >= 0 { return fd } else if errno == EBADF { break }
        }
        close(listener)
        return nil
    }

    /// Registers `fd` as an open connection (at most 8); nil when stopped or full.
    func adopt(_ fd: Int32) -> Int? {
        state.withLock { (state: inout State) -> Int? in
            guard !stopped.load(ordering: .acquiring), state.open.count < 8 else { return nil }
            state.last += 1
            state.open[state.last] = fd
            return state.last
        }
    }

    func drop(_ connection: Int) { if let fd = state.withLock({ $0.open.removeValue(forKey: connection) }) { close(fd) } }

    /// Ends the accept loop and wakes every connection's read, so each thread closes its socket.
    func stop() {
        stopped.store(true, ordering: .releasing)
        state.withLock { for fd in $0.open.values { _ = shutdown(fd, SHUT_RDWR) } }
    }
}

/// One reply handed from the main actor to a connection's thread.
final class Reply: Sendable {
    let done = DispatchSemaphore(value: 0), value = Mutex<[UInt8]>([])
    func set(_ bytes: [UInt8]) { value.withLock { $0 = bytes }; done.signal() }
    func wait() -> [UInt8] { done.wait(); return value.withLock { $0 } }
}

extension View {
    /// Makes this window the one `front`'s live channel reaches whenever it becomes the active window, and lets
    /// go when it closes; `read` is its document now and `write` lands a command's result in it.
    public func suiteLiveWindow<Document>(_ front: LiveFront<Document>, read: @escaping @MainActor () -> Document?,
                                          write: @escaping @MainActor (Document) -> Void) -> some View {
        modifier(LiveWindowRegistration(front: front, read: read, write: write))
    }
}

/// Registers its window with a LiveFront on appear and whenever it becomes active; releases it on close.
struct LiveWindowRegistration<Document>: ViewModifier {
    let front: LiveFront<Document>
    let read: @MainActor () -> Document?
    let write: @MainActor (Document) -> Void
    @State private var id = UUID()
    @Environment(\.appearsActive) private var appearsActive

    func body(content: Content) -> some View {
        content
            .onChange(of: appearsActive, initial: true) { _, active in
                if active { front.register(id, read: read, write: write) }
            }
            .onDisappear { front.release(id) }
    }
}

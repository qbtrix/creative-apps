// LiveBridge.swift (afterglow-mcp MC-11): `afterglow mcp --live`, the
// running apps' documents as `live.<app>.<id>` tools. Each running app
// listens on a same-user Unix socket (MC-10's LiveCommandChannel, macOS):
// `~/Library/Application Support/AfterGlow/live/<app>-<pid>.sock`. The wire is
// LiveWire: newline-delimited JSON-RPC 2.0, `live/describe` for the app and
// its catalog, `live/run` for one command on the window's document. The
// bridge lists every app that answers (a dead socket is skipped, never
// fatal), forwards a call to the app that serves it, and turns the app's
// refusals into tool errors: no grant for this client is "<App> asked you to
// approve this client", a why-not is the app's own words. The wire is plain
// POSIX and is tested on Linux over a socket pair; only `serve --live`
// waits on macOS, where the apps run.
import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Darwin)
import Darwin
#endif
import Synchronization

/// The wire between `afterglow mcp --live` and a running app: one JSON-RPC 2.0 message per line.
public enum LiveWire {
    /// `live/describe {client}` → `{app, title, commands: [CommandDescription]}`;
    /// `live/run {client, id, params}` → `{result, undoStep?}`.
    public static let describe = "live/describe", run = "live/run"
    /// The error code an app answers `live/run` with while the client has no grant (asked, denied or revoked).
    public static let needsGrant = -32010
    /// The prefix of every live tool name: `live.photo.layer.add`.
    public static let prefix = "live"
    /// The folder the running apps' sockets are in, under the user's home.
    public static func directory(home: String) -> String { home + "/Library/Application Support/AfterGlow/live" }
}

/// One running app's end of the wire: one request line out, its reply line back.
public protocol LiveLink: Sendable {
    /// Sends `request` (no newline) and returns the reply line (no newline); throws when the app is gone or silent.
    func exchange(_ request: Data) throws -> Data
}

/// The running apps behind `live.<app>.<id>` tools.
public struct LiveBridge: Sendable {
    /// The client name the apps' approval sheets show when the client gave none.
    public static let unnamedClient = "MCP client"

    let find: @Sendable () -> [any LiveLink]

    /// A bridge over the links `find` returns, asked again on every list and call (apps come and go).
    public init(find: @escaping @Sendable () -> [any LiveLink]) { self.find = find }

    /// The bridge to this user's running apps: their sockets under Application Support. Nil off macOS.
    public static func local() -> LiveBridge? {
        #if os(macOS)
        let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        return LiveBridge { sockets(in: LiveWire.directory(home: home)) }
        #else
        return nil
        #endif
    }

    /// A link to each `*.sock` in `dir`, by name; none when the folder is missing.
    public static func sockets(in dir: String) -> [any LiveLink] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []
        return names.filter { $0.hasSuffix(".sock") }.sorted().map { UnixSocketLink(path: dir + "/" + $0) }
    }

    /// One running app as it described itself.
    struct Peer { let link: any LiveLink; let app, title: String; let commands: [CommandDescription] }

    /// Every app that answers `live/describe`, by name; a link that fails or answers nonsense is skipped.
    func peers(client: String) -> [Peer] {
        var peers: [String: Peer] = [:]
        for link in find() {
            guard case .success(.object(let body)) = Self.ask(link, LiveWire.describe, ["client": .string(client)]),
                  case .string(let app)? = body["app"], peers[app] == nil,
                  let commands = try? body["commands"]?.decode([CommandDescription].self) else { continue }
            let title: String = if case .string(let given)? = body["title"] { given } else { app.capitalized }
            peers[app] = Peer(link: link, app: app, title: title, commands: commands.filter { $0.app == app })
        }
        return peers.values.sorted { $0.app < $1.app }
    }

    /// `live.<app>.<id>` for every command of every running app, apps by name and commands by id.
    public func tools(client: String) -> [MCPTool] {
        peers(client: client).flatMap { peer in peer.commands.sorted { $0.id < $1.id }.map { Self.tool($0, in: peer.title) } }
    }

    /// The live tool for `command`: the headless tool's title, output and hints, input `{params}` (the window's document).
    static func tool(_ command: CommandDescription, in title: String) -> MCPTool {
        var tool = MCPTools.tool(command)
        tool.name = "\(LiveWire.prefix).\(MCPTools.name(app: command.app, command: command.id))"
        tool.description = "In the open \(title) window: " + tool.description
        tool.inputSchema = MCPTools.object(["params": command.params], required: [])
        return tool
    }

    /// Runs the live tool `name` for `client`; nil when `name` is no live tool of a running app's catalog (-32602).
    public func call(_ name: String, _ arguments: JSONValue, client: String) -> MCPToolResult? {
        let head = LiveWire.prefix + "."
        guard name.hasPrefix(head) else { return nil }
        let rest = name.dropFirst(head.count)
        guard let dot = rest.firstIndex(of: ".") else { return nil }
        let app = String(rest[..<dot]), id = String(rest[rest.index(after: dot)...])
        let running = peers(client: client)
        guard let peer = running.first(where: { $0.app == app }) else {
            return .error("\(app.capitalized) is not running; open it with a document, then list the tools again")
        }
        guard peer.commands.contains(where: { $0.id == id }) else { return nil }
        guard case .object(let args) = arguments else { return .error("the arguments must be an object") }
        let params: [String: JSONValue] = ["client": .string(client), "id": .string(id), "params": args["params"] ?? .object([:])]
        switch Self.ask(peer.link, LiveWire.run, params) {
        case .success(.object(let fields)): return .ok(fields)
        case .success: return .error("\(peer.title) answered \(id) with something other than an object")
        case .failure(let error) where error.code == LiveWire.needsGrant:
            return .error("\(peer.title) asked you to approve this client; answer it in \(peer.title), then call again")
        case .failure(let error): return .error(error.message)
        }
    }

    /// One request to `link`: its result, or its error (a dead link or a reply that isn't JSON-RPC is -32603).
    static func ask(_ link: any LiveLink, _ method: String, _ params: [String: JSONValue]) -> Result<JSONValue, RPCError> {
        let request = JSONRPC.encode(["jsonrpc": .string("2.0"), "id": .number(1), "method": .string(method), "params": .object(params)])
        let lost = { (why: String) in RPCError(code: RPCError.internalError, message: "the app stopped answering: \(why)") }
        let line: Data
        do { line = try link.exchange(request) } catch { return .failure(lost("\(error)")) }
        guard case .object(let body)? = try? JSONValue(json: line), body["id"] == .number(1) else { return .failure(lost("not a reply")) }
        if case .object(let error)? = body["error"] {
            guard case .number(let code)? = error["code"], let whole = Int(exactly: code) else { return .failure(lost("no error code")) }
            let message: String = if case .string(let text)? = error["message"] { text } else { "the app refused" }
            return .failure(RPCError(code: whole, message: message, data: error["data"]))
        }
        guard let result = body["result"] else { return .failure(lost("no result")) }
        return .success(result)
    }
}

/// Why a socket exchange failed.
public struct LiveLinkError: Error, CustomStringConvertible, Sendable {
    public let description: String
    init(_ description: String) { self.description = description }
}

/// A link over a Unix stream socket: connected on first use, reconnected after a failure; a reply waits at most 120 s
/// (an app may be asking its user for a grant).
public final class UnixSocketLink: LiveLink {
    /// The socket's path; nil for a socket handed in already connected.
    public let path: String?
    private struct Socket: Sendable { var fd: Int32; var buffer: [UInt8] = [] }
    private let socket: Mutex<Socket>

    /// A link to the socket at `path`.
    public init(path: String) {
        self.path = path
        socket = Mutex(Socket(fd: -1))
    }
    /// A link over `fd`, already connected (one end of a socket pair); the link closes it.
    public init(connected fd: Int32) {
        path = nil
        socket = Mutex(Socket(fd: fd))
        Self.configure(fd)
    }
    deinit { socket.withLock { if $0.fd >= 0 { close($0.fd) } } }

    public func exchange(_ request: Data) throws -> Data {
        try socket.withLock { (state: inout Socket) throws(LiveLinkError) -> Data in
            do throws(LiveLinkError) {
                if state.fd < 0 { state.fd = try Self.dial(path) }
                try Self.post(state.fd, Array(request) + [UInt8(ascii: "\n")])
                return try Self.line(state.fd, &state.buffer)
            } catch {
                if state.fd >= 0 { close(state.fd) }
                state = Socket(fd: -1)
                throw error
            }
        }
    }

    static func dial(_ path: String?) throws(LiveLinkError) -> Int32 {
        guard let path else { throw LiveLinkError("the socket closed") }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        guard bytes.count < MemoryLayout.size(ofValue: address.sun_path) else { throw LiveLinkError("the socket path is too long: \(path)") }
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
        #if canImport(Darwin)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        #endif
        let fd = Glue.socket(AF_UNIX, Glue.stream, 0)
        guard fd >= 0 else { throw LiveLinkError("no socket: errno \(errno)") }
        let joined = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Glue.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard joined == 0 else {
            let code = errno
            close(fd)
            throw LiveLinkError("nothing listens at \(path): errno \(code)")
        }
        configure(fd)
        return fd
    }

    /// No SIGPIPE on a closed peer, and send and receive time out after 120 s.
    static func configure(_ fd: Int32) {
        var wait = timeval(tv_sec: 120, tv_usec: 0)
        let size = socklen_t(MemoryLayout<timeval>.size)
        _ = setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &wait, size)
        _ = setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &wait, size)
        #if canImport(Darwin)
        var one: Int32 = 1
        _ = setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))
        #endif
    }

    static func post(_ fd: Int32, _ bytes: [UInt8]) throws(LiveLinkError) {
        var sent = 0
        while sent < bytes.count {
            let count = bytes.withUnsafeBytes { Glue.send(fd, $0.baseAddress.map { $0 + sent }, bytes.count - sent, Glue.noSignal) }
            if count < 0, errno == EINTR { continue }
            guard count > 0 else { throw LiveLinkError("the app closed the socket: errno \(errno)") }
            sent += count
        }
    }

    /// The next line on `fd`, reading into `buffer` until a newline; what follows it stays in `buffer`.
    static func line(_ fd: Int32, _ buffer: inout [UInt8]) throws(LiveLinkError) -> Data {
        var chunk = [UInt8](repeating: 0, count: 64 << 10)
        while true {
            if let end = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                defer { buffer.removeSubrange(...end) }
                return Data(buffer[..<end])
            }
            guard buffer.count <= JSONRPC.maxLineBytes else { throw LiveLinkError("the app's reply is over \(JSONRPC.maxLineBytes) bytes") }
            let count = chunk.withUnsafeMutableBytes { recv(fd, $0.baseAddress, $0.count, 0) }
            if count < 0, errno == EINTR { continue }
            if count < 0, errno == EAGAIN || errno == EWOULDBLOCK { throw LiveLinkError("the app took over 120 s to answer") }
            guard count > 0 else { throw LiveLinkError("the app closed the socket") }
            buffer += chunk[..<count]
        }
    }
}

/// The C calls whose names the link's own members would shadow, and the platform's socket constants.
enum Glue {
    #if canImport(Glibc)
    static let stream = Int32(SOCK_STREAM.rawValue), noSignal = Int32(MSG_NOSIGNAL)
    static func socket(_ domain: Int32, _ type: Int32, _ proto: Int32) -> Int32 { Glibc.socket(domain, type, proto) }
    static func connect(_ fd: Int32, _ address: UnsafePointer<sockaddr>, _ size: socklen_t) -> Int32 { Glibc.connect(fd, address, size) }
    static func send(_ fd: Int32, _ bytes: UnsafeRawPointer?, _ count: Int, _ flags: Int32) -> Int { Glibc.send(fd, bytes, count, flags) }
    #elseif canImport(Musl)
    static let stream = SOCK_STREAM, noSignal = MSG_NOSIGNAL
    static func socket(_ domain: Int32, _ type: Int32, _ proto: Int32) -> Int32 { Musl.socket(domain, type, proto) }
    static func connect(_ fd: Int32, _ address: UnsafePointer<sockaddr>, _ size: socklen_t) -> Int32 { Musl.connect(fd, address, size) }
    static func send(_ fd: Int32, _ bytes: UnsafeRawPointer?, _ count: Int, _ flags: Int32) -> Int { Musl.send(fd, bytes, count, flags) }
    #else
    static let stream = SOCK_STREAM, noSignal: Int32 = 0
    static func socket(_ domain: Int32, _ type: Int32, _ proto: Int32) -> Int32 { Darwin.socket(domain, type, proto) }
    static func connect(_ fd: Int32, _ address: UnsafePointer<sockaddr>, _ size: socklen_t) -> Int32 { Darwin.connect(fd, address, size) }
    static func send(_ fd: Int32, _ bytes: UnsafeRawPointer?, _ count: Int, _ flags: Int32) -> Int { Darwin.send(fd, bytes, count, flags) }
    #endif
}

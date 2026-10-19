// LiveBridge.swift (afterglow-mcp MC-11): `afterglow mcp --live` lists each
// running app's catalog (its `<app>-<pid>.sock`, MC-10) as `live.<app>.<id>`,
// skips dead sockets, forwards calls, and turns a missing grant into "<App>
// asked you to approve this client". Plain POSIX, tested on Linux.
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
    /// `live/describe {client}` → `{app, title, commands}`; `live/run {client, id, params}` → `{result, undoStep?}`;
    /// `needsGrant`, the error while the client has no grant; `prefix`, of every tool name (`live.photo.layer.add`).
    public static let describe = "live/describe", run = "live/run", needsGrant = -32010, prefix = "live"
    /// The folder the running apps' sockets are in, under the user's home.
    public static func directory(home: String) -> String { home + "/Library/Application Support/AfterGlow/live" }
}

/// One running app's end of the wire: `exchange` sends one request line and returns the reply line (no newlines),
/// or throws when the app is gone or silent.
public protocol LiveLink: Sendable {
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
        return LiveBridge { sockets(in: LiveWire.directory(home: NSHomeDirectory())) }
        #else
        return nil
        #endif
    }

    /// A link to each `*.sock` in `dir`, by name; none when the folder is missing.
    public static func sockets(in dir: String) -> [any LiveLink] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []
        return names.filter { $0.hasSuffix(".sock") }.sorted().map { UnixSocketLink(path: dir + "/" + $0) }
    }

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

    /// `live.<app>.<id>` for every command of every running app, apps by name and commands by id: the headless tool's
    /// title, output and hints, with input `{params}` (the document is the window's).
    public func tools(client: String) -> [MCPTool] {
        peers(client: client).flatMap { peer in
            peer.commands.sorted { $0.id < $1.id }.map { command in
                var tool = MCPTools.tool(command)
                tool.name = "\(LiveWire.prefix).\(MCPTools.name(app: command.app, command: command.id))"
                tool.description = "In the open \(peer.title) window: " + tool.description
                tool.inputSchema = MCPTools.object(["params": command.params], required: [])
                return tool
            }
        }
    }

    /// Runs the live tool `name` for `client`; nil when `name` is no live tool of a running app's catalog (-32602).
    public func call(_ name: String, _ arguments: JSONValue, client: String) -> MCPToolResult? {
        let head = LiveWire.prefix + "."
        guard name.hasPrefix(head) else { return nil }
        let rest = name.dropFirst(head.count)
        guard let dot = rest.firstIndex(of: ".") else { return nil }
        let app = String(rest[..<dot]), id = String(rest[rest.index(after: dot)...])
        guard let peer = peers(client: client).first(where: { $0.app == app }) else {
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
        guard let line = try? link.exchange(request) else { return .failure(lost("the socket failed")) }
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

public struct LiveLinkError: Error, CustomStringConvertible, Sendable { public let description: String }

/// A link over a Unix stream socket: connected on first use, reconnected after a failure; a reply waits at most 120 s
/// (an app may be asking its user for a grant).
public final class UnixSocketLink: LiveLink {
    /// The socket's path; nil for a socket handed in already connected.
    public let path: String?
    private struct Socket: Sendable { var fd: Int32; var buffer: [UInt8] = [] }
    private let held: Mutex<Socket>

    /// A link to the socket at `path`, or over `fd` already connected (one end of a socket pair), which it then closes.
    public init(path: String) { self.path = path; held = Mutex(Socket(fd: -1)) }
    public init(connected fd: Int32) { path = nil; held = Mutex(Socket(fd: fd)); Self.configure(fd) }
    deinit { held.withLock { if $0.fd >= 0 { close($0.fd) } } }

    public func exchange(_ request: Data) throws -> Data {
        try held.withLock { (state: inout Socket) throws(LiveLinkError) -> Data in
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
        guard let path else { throw LiveLinkError(description: "the socket closed") }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        guard bytes.count < MemoryLayout.size(ofValue: address.sun_path) else { throw LiveLinkError(description: "the socket path is too long: \(path)") }
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
        #if canImport(Darwin)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        #endif
        let fd = socket(AF_UNIX, Glue.stream, 0)
        guard fd >= 0 else { throw LiveLinkError(description: "no socket: errno \(errno)") }
        let size = socklen_t(MemoryLayout<sockaddr_un>.size)
        guard withUnsafePointer(to: &address, { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, size) } }) == 0 else {
            let code = errno
            close(fd)
            throw LiveLinkError(description: "nothing listens at \(path): errno \(code)")
        }
        configure(fd)
        return fd
    }

    /// No SIGPIPE on a closed peer, and send and receive time out after 120 s.
    static func configure(_ fd: Int32) {
        var wait = timeval(tv_sec: 120, tv_usec: 0), size = socklen_t(MemoryLayout<timeval>.size)
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
            let count = bytes.withUnsafeBytes { send(fd, $0.baseAddress.map { $0 + sent }, bytes.count - sent, Glue.noSignal) }
            if count < 0, errno == EINTR { continue }
            guard count > 0 else { throw LiveLinkError(description: "the app closed the socket: errno \(errno)") }
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
            guard buffer.count <= JSONRPC.maxLineBytes else { throw LiveLinkError(description: "the app's reply is over \(JSONRPC.maxLineBytes) bytes") }
            let count = chunk.withUnsafeMutableBytes { recv(fd, $0.baseAddress, $0.count, 0) }
            if count < 0, errno == EINTR { continue }
            if count < 0, errno == EAGAIN || errno == EWOULDBLOCK { throw LiveLinkError(description: "the app took over 120 s to answer") }
            guard count > 0 else { throw LiveLinkError(description: "the app closed the socket") }
            buffer += chunk[..<count]
        }
    }
}

/// The platform's stream socket type, and the send flag that turns SIGPIPE off (Darwin sets SO_NOSIGPIPE instead).
enum Glue {
    #if canImport(Glibc)
    static let stream = Int32(SOCK_STREAM.rawValue), noSignal = Int32(MSG_NOSIGNAL)
    #elseif canImport(Musl)
    static let stream = SOCK_STREAM, noSignal = MSG_NOSIGNAL
    #else
    static let stream = SOCK_STREAM, noSignal: Int32 = 0
    #endif
}

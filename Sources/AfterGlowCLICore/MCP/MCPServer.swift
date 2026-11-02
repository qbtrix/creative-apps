// MCPServer.swift (afterglow-cli CL-2 stub; afterglow-mcp MC-1 contract, MC-4
// body): `afterglow mcp`, every app's command catalog as MCP tools over
// stdio. `handle` answers one JSON-RPC line: the version a request names
// (`_meta`, or `initialize`'s `protocolVersion`) is negotiated first, and an
// unsupported one is -32602 listing `supportedVersions`; then
// `server/discover`, `initialize`, `ping`, `tools/list` and `tools/call` (rate
// limited, run by MCPSessions). A notification is never answered, and
// `handle` never prints. `serve` parses `[--app <name>]… --root <dir>…
// [--live]` strictly (`--root` is optional with `--live`; the file tools then refuse), then answers stdin line by line until it ends; `--live`
// (MC-11, macOS) adds the running apps' tools through LiveBridge.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Synchronization

/// What one `afterglow mcp` run serves: its apps, the folders it may read and write, and its limits.
public struct MCPOptions: Sendable {
    /// The apps whose catalogs become tools, the allowed roots, and whether `--live` bridges running apps (macOS).
    public var apps: [HeadlessApp]; public var roots: [String]; public var live: Bool
    /// The most documents open at once, how long an idle handle lives, and the call rate limit.
    public var maxOpen = 16; public var idleSeconds = 3600.0; public var maxCallsPerSecond = 50

    public init(apps: [HeadlessApp], roots: [String], live: Bool = false) { (self.apps, self.roots, self.live) = (apps, roots, live) }
}

/// The MCP server behind `afterglow mcp`: one JSON-RPC line in, at most one line out.
public final class MCPServer: Sendable {
    /// The packet that builds the server.
    public static let slice = "afterglow-mcp"
    /// The name `server/discover` and `initialize` give.
    public static let name = "afterglow"

    /// What this server serves, where it reads and writes, and its time source in seconds.
    public let options: MCPOptions
    let io: any CLIIO
    let clock: @Sendable () -> Double

    /// The running apps `--live` bridges; nil without `--live`.
    let live: LiveBridge?
    /// The handshake era's negotiated version and client name, the open documents, and the recent calls' times.
    private struct State: Sendable {
        var sessionVersion: String?; var client = LiveBridge.unnamedClient; var sessions: MCPSessions; var calls = RateWindow()
    }
    private let state: Mutex<State>

    public init(_ options: MCPOptions, io: any CLIIO, live: LiveBridge? = nil, clock: @escaping @Sendable () -> Double) {
        (self.options, self.io, self.live, self.clock) = (options, io, live, clock)
        state = Mutex(State(sessions: MCPSessions(options, io: io)))
    }

    /// Answers one message: the reply line without its newline, or nil for a notification.
    public func handle(_ line: Data) -> Data? {
        let request: RPCRequest
        switch JSONRPC.parse(line) {
        case .success(let read): request = read
        case .failure(let error): return JSONRPC.reply(nil, error: error)
        }
        // A notification gets no reply; `notifications/cancelled` has nothing to stop, as every request is answered at once.
        guard let id = request.id else { return nil }
        switch answer(request) {
        case .success(let result): return JSONRPC.reply(id, result: result)
        case .failure(let error): return JSONRPC.reply(id, error: error)
        }
    }

    /// The result of one request, or the error it is refused with.
    func answer(_ request: RPCRequest) -> Result<JSONValue, RPCError> {
        let params: [String: JSONValue]
        if case .object(let given)? = request.params { params = given } else { params = [:] }
        let version: String
        switch Self.version(of: request.method, params) {
        case .success(let named): version = named ?? state.withLock { $0.sessionVersion } ?? MCPVersions.current
        case .failure(let error): return .failure(error)
        }
        switch request.method {
        case "server/discover":
            return .success(.object(["supportedVersions": Self.supported, "capabilities": Self.capabilities, "serverInfo": Self.info]))
        case "initialize":
            let client: String? = if case .object(let info)? = params["clientInfo"], case .string(let name)? = info["name"] { name } else { nil }
            state.withLock { ($0.sessionVersion, $0.client) = (version, client.flatMap { $0.isEmpty ? nil : $0 } ?? LiveBridge.unnamedClient) }
            return .success(.object(["protocolVersion": .string(version), "capabilities": Self.capabilities, "serverInfo": Self.info]))
        case "ping": return .success(.object([:]))
        case "tools/list":
            let running = live?.tools(client: state.withLock { $0.client }) ?? []
            return .success(.object(["tools": .array((MCPTools.list(options.apps) + running).compactMap { try? JSONValue(encoding: $0) })]))
        case "tools/call": return call(params).map(Self.encode)
        default: return .failure(RPCError(code: RPCError.methodNotFound, message: "Method not found: \(request.method)"))
        }
    }

    /// Runs one `tools/call`: an unknown tool or arguments that aren't an object are -32602; over the rate limit, a tool error.
    func call(_ params: [String: JSONValue]) -> Result<MCPToolResult, RPCError> {
        guard case .string(let name)? = params["name"] else { return .failure(Self.invalidParams("tools/call needs a tool name")) }
        let arguments = params["arguments"] ?? .object([:])
        guard case .object = arguments else { return .failure(Self.invalidParams("the arguments of \(name) must be an object")) }
        let now = clock()
        if let live, name.hasPrefix(LiveWire.prefix + ".") {
            let (admitted, client) = state.withLock { ($0.calls.admit(at: now, limit: options.maxCallsPerSecond), $0.client) }
            guard admitted else { return .success(.error("slow down: at most \(options.maxCallsPerSecond) calls a second")) }
            guard let result = live.call(name, arguments, client: client) else { return .failure(Self.invalidParams("Unknown tool: \(name)")) }
            return .success(result)
        }
        guard let route = MCPTools.route(name, in: options.apps) else { return .failure(Self.invalidParams("Unknown tool: \(name)")) }
        return .success(state.withLock { state in
            guard state.calls.admit(at: now, limit: options.maxCallsPerSecond) else {
                return .error("slow down: at most \(options.maxCallsPerSecond) calls a second")
            }
            return state.sessions.call(route, arguments, now: now)
        })
    }

    /// The version `params` name for `method`: nil when they name none; -32602 listing the supported ones when unsupported.
    static func version(of method: String, _ params: [String: JSONValue]) -> Result<String?, RPCError> {
        var named: JSONValue?
        if case .object(let meta)? = params["_meta"] { named = meta[MCPVersions.metaKey] }
        if method == "initialize" { named = params["protocolVersion"] ?? named }
        guard let named else {
            return method == "initialize" ? .failure(invalidParams("initialize needs a protocolVersion")) : .success(nil)
        }
        if case .string(let text) = named, let agreed = MCPVersions.negotiate(text) { return .success(agreed) }
        var error = invalidParams("Unsupported protocol version")
        error.data = .object(["supportedVersions": supported, "requested": named])
        return .failure(error)
    }

    /// A tool result as `tools/call` returns it: one text content, the structured content and `isError`.
    static func encode(_ result: MCPToolResult) -> JSONValue {
        .object(["content": .array([.object(["type": .string("text"), "text": .string(result.text)])]),
                 "structuredContent": result.structured, "isError": .bool(result.isError)])
    }

    static func invalidParams(_ message: String) -> RPCError { RPCError(code: RPCError.invalidParams, message: message) }
    static let supported = JSONValue.array(MCPVersions.supported.map(JSONValue.string))
    static let capabilities = JSONValue.object(["tools": .object(["listChanged": .bool(false)])])
    static let liveOffMac = "afterglow mcp --live runs only on macOS, where the apps listen"
    static let info = JSONValue.object(["name": .string(name), "version": .string(CLI.version)])

    /// Serves `apps` over MCP with `arguments` (what follows `afterglow mcp`): one reply line on stdout per request
    /// line on stdin, until stdin ends (0). Bad arguments are usage (64); `--live` off macOS is unavailable (69).
    public static func serve(_ arguments: [String], apps: [HeadlessApp], io: any CLIIO) -> Int32 {
        let options: MCPOptions
        do { options = try parse(arguments, apps: apps) } catch { return CLI.refuse(error, io: io) }
        let live = options.live ? LiveBridge.local() : nil
        if options.live, live == nil { return CLI.refuse(Refusal(code: CLI.Exit.unavailable, kind: "unavailable", message: liveOffMac), io: io) }
        let start = ContinuousClock.now
        let server = MCPServer(options, io: io, live: live) {
            let elapsed = start.duration(to: .now).components
            return Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
        }
        while let line = io.readLine() {
            if line.allSatisfy({ $0 == UInt8(ascii: " ") || $0 == UInt8(ascii: "\r") || $0 == UInt8(ascii: "\t") }) { continue }
            if let reply = server.handle(line) { io.out(String(decoding: reply, as: UTF8.self)) }
        }
        return CLI.Exit.ok
    }

    /// Reads `--app <name>` (each at most once; none means every app), `--root <dir>` (one or more; none only with
    /// `--live`) and `--live`.
    static func parse(_ arguments: [String], apps: [HeadlessApp]) throws(Refusal) -> MCPOptions {
        var names: [String] = [], roots: [String] = [], live = false
        var rest = arguments[...]
        while let token = rest.popFirst() {
            switch token {
            case "--app", "--root":
                guard let value = rest.popFirst(), !value.isEmpty else { throw .usage("\(token) needs a value") }
                if token == "--root" { roots.append(value); continue }
                guard Apps.named(value, in: apps) != nil else { throw .usage("unknown app \(value)") }
                guard !names.contains(value) else { throw .usage("--app \(value) is given twice") }
                names.append(value)
            case "--live":
                guard !live else { throw .usage("--live is given twice") }
                live = true
            default: throw .usage(token.hasPrefix("-") ? "unknown flag \(token)" : "unexpected operand \(token)")
            }
        }
        // Live tools reach running apps, not files, so `--live` alone needs no root; the file tools then refuse.
        guard !roots.isEmpty || live else { throw .usage("afterglow mcp needs --root <dir>, the folder its tools may read and write") }
        return MCPOptions(apps: names.isEmpty ? apps : apps.filter { names.contains($0.name) }, roots: roots, live: live)
    }
}

/// The calls of the last second, for the rate limit.
struct RateWindow: Sendable {
    private(set) var times: [Double] = []

    /// Records a call at `now` and returns true when fewer than `limit` ran in the second before it; false (unrecorded) otherwise.
    mutating func admit(at now: Double, limit: Int) -> Bool {
        times.removeAll { now - $0 >= 1 }
        guard times.count < limit else { return false }
        times.append(now)
        return true
    }
}
